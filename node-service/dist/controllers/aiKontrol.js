"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.tekMakineTahmin = tekMakineTahmin;
exports.topluMakineTahmin = topluMakineTahmin;
const axios_1 = __importDefault(require("axios"));
const prisma_1 = __importDefault(require("../config/prisma"));
const config_1 = require("../config");
const AI_SERVICE_URL = config_1.config.aiServiceUrl;
const AI_TIMEOUT_MS = 10_000; // 10 saniye timeout
function alternatifAiServisUrlListesi() {
    const urls = [AI_SERVICE_URL];
    if (AI_SERVICE_URL.includes("endux_ai")) {
        urls.push("http://localhost:8000");
        urls.push("http://127.0.0.1:8000");
    }
    return [...new Set(urls)];
}
function yerelRiskTahminiOlustur(payload) {
    const cevaplar = Object.entries(payload)
        .filter(([key, value]) => !["makine_turu", "form_doldurma_suresi_sn", "toplam_calisma_saati"].includes(key) &&
        typeof value === "number")
        .map(([, value]) => Number(value));
    const maksimumCevap = cevaplar.length > 0 ? Math.max(...cevaplar) : 0;
    const ortalamaCevap = cevaplar.length > 0
        ? cevaplar.reduce((toplam, deger) => toplam + deger, 0) / cevaplar.length
        : 0;
    const kritikCevapSayisi = cevaplar.filter((deger) => deger >= 2).length;
    const kritikOran = cevaplar.length > 0 ? kritikCevapSayisi / cevaplar.length : 0;
    let riskOrani = Math.min(1, (ortalamaCevap / 2) * 0.65 + kritikOran * 0.35);
    if (maksimumCevap >= 2 && kritikCevapSayisi >= 3)
        riskOrani = Math.max(riskOrani, 0.80);
    if (maksimumCevap >= 2 && kritikCevapSayisi >= 6)
        riskOrani = Math.max(riskOrani, 0.90);
    const riskSkoru = Number((riskOrani * 100).toFixed(2));
    const tahminEdilenAriza = riskSkoru >= 80
        ? "KRITIK_FORM_ANOMALISI"
        : riskSkoru >= 50
            ? "PLANLI_BAKIM_RISKI"
            : "YOK";
    return {
        sistem_mesaji: "AI servisine ulaşılamadığı için yerel risk analizi kullanıldı.",
        makine_turu: String(payload.makine_turu),
        guvenilirlik_notu: "Yerel yedek analiz",
        tahmin_edilen_ariza: tahminEdilenAriza,
        risk_skoru: riskSkoru,
        rul_tahmini_saat: Math.max(0, Number(payload.toplam_calisma_saati || 0) * (1 - riskOrani) * 0.5),
        bakim_tavsiyesi: riskSkoru >= 80
            ? "ACİL BAKIM GEREKLİ! Makineyi durdurup derhal müdahale edin."
            : riskSkoru >= 50
                ? "Planlı bakımı öne çekin, arıza riski yüksek."
                : "Makine sağlıklı, rutin bakım takvimini takip edin.",
        uyari_durumu: riskSkoru >= 80 ? "KIRMIZI" : riskSkoru >= 50 ? "SARI" : "YEŞİL",
        detaylar: {
            tahmini_maliyet: riskSkoru >= 80 ? 15000 : riskSkoru >= 50 ? 5000 : 0,
            tahmini_durus_suresi: riskSkoru >= 80 ? 8 : riskSkoru >= 50 ? 2 : 0,
            ekip: riskSkoru >= 50 ? "Bakım Ekibi" : "Gerek Yok",
            parca: riskSkoru >= 50 ? "Kontrol sonrası belirlenecek" : "Sorun Yok",
        },
    };
}
function riskSkorunuYuzeCevir(riskSkoru) {
    const skor = Number(riskSkoru || 0);
    return Number((skor <= 1 ? skor * 100 : skor).toFixed(2));
}
//veri tabanı sorgusu
async function makineOZetVeriCek(makineID) {
    const makine = await prisma_1.default.makine.findUnique({
        where: { makine_id: makineID },
        include: {
            makine_turu: true,
            makine_ozellikleri: true
        },
    });
    if (!makine) {
        throw new Error(`Makine Bulunamadı: ID ${makineID}`);
    }
    return makine;
}
// Form cevaplarını AI payload formatına çevir
// form_madde_cevap → kontrol_maddesi JOIN ile {teknik_parametre: girilen_deger} çiftleri oluşturur
async function formCevaplariToAIPayload(formId) {
    const cevaplar = await prisma_1.default.form_madde_cevap.findMany({
        where: { form_id: formId },
        include: {
            kontrol_maddesi: true, // soru_referans_id → kontrol_maddesi.madde_id
        },
    });
    const payload = {};
    for (const cevap of cevaplar) {
        const parametre = cevap.kontrol_maddesi?.teknik_parametre;
        if (parametre) {
            // girilen_deger "0", "1", "2" şeklinde geliyor → sayıya çevir
            payload[parametre] = Number(cevap.girilen_deger) || 0;
        }
    }
    return payload;
}
async function aiTahminIstegiGonder(payload) {
    const hatalar = [];
    for (const servisUrl of alternatifAiServisUrlListesi()) {
        try {
            const response = await axios_1.default.post(`${servisUrl}/tahmin-et`, payload, { timeout: AI_TIMEOUT_MS });
            return response.data;
        }
        catch (error) {
            const axiosError = error;
            hatalar.push(`${servisUrl}: ${axiosError.message}`);
            if (axiosError.response) {
                const status = axiosError.response.status;
                console.error(`AI servisi hata yanıtı: ${status}`);
                throw new Error(`AI servisi hata yanıtı: ${status}`);
            }
        }
    }
    console.warn("AI servisine ulaşılamadı, yerel risk analizi kullanılacak:", hatalar.join(" | "));
    return yerelRiskTahminiOlustur(payload);
}
async function riskSkoruKaydet(makineId, formId, kullaniciId, tahmin, maddeId) {
    //risk skoru tablosuna kaydet
    const riskPuani = riskSkorunuYuzeCevir(tahmin.risk_skoru);
    const riskSeviyesi = riskPuani >= 80 ? 'YUKSEK' : riskPuani >= 50 ? 'ORTA' : 'DUSUK';
    const riskKaydi = await prisma_1.default.risk_skoru.create({
        data: {
            makine_id: makineId,
            risk_skoru: riskPuani,
            risk_seviyesi: riskSeviyesi,
            hesaplama_tarihi: new Date(),
        },
    });
    //ai_ariza_tespit tablosuna kaydet
    await prisma_1.default.ai_ariza_tespit.create({
        data: {
            makine_id: makineId,
            form_id: formId,
            madde_id: maddeId,
            tahmin_edilen_ariza: tahmin.tahmin_edilen_ariza,
            risk_skoru: riskPuani,
            tespit_tarihi: new Date(),
            model_versiyon: "xgboost-v4.0",
            tahmini_durus_suresi: tahmin.detaylar.tahmini_durus_suresi,
            tahmini_maliyet: tahmin.detaylar.tahmini_maliyet,
        },
    });
    //ai_model_log tablosuna kaydet
    await prisma_1.default.ai_model_log.create({
        data: {
            makine_id: makineId,
            model_versiyon: "xgboost-v4.0",
            kullanilan_veri_sayisi: 1,
            tahmin_risk: riskPuani,
            tahmin_tarihi: new Date(),
            kullanici_id: kullaniciId,
            form_id: formId,
        },
    });
    // gunluk_kontrol_formu.ai_on_risk_durumu güncelle
    await prisma_1.default.gunluk_kontrol_formu.update({
        where: { form_id: formId },
        data: { ai_on_risk_durumu: riskPuani },
    });
    return riskKaydi;
}
async function tekMakineTahmin(makineId, formId, kullaniciId) {
    try {
        // 1. Makine özet bilgilerini getir
        const makine = await makineOZetVeriCek(makineId);
        // 2. Form verilerini DB'den çek ve sayısal değerlere dönüştür
        const formCevaplari = await formCevaplariToAIPayload(formId);
        // 3. AI Service için payload hazırla
        const formSuresi = 60; // TODO: İleride form_doldurma_suresi_sn tablodan alınabilir
        const payload = {
            makine_turu: makine.makine_turu.makine_tur_adi,
            form_doldurma_suresi_sn: formSuresi,
            toplam_calisma_saati: Number(makine.toplam_calisma_saati) || 0,
            ...formCevaplari // sicaklik, titresim, yag_kacak vb. dinamik veriler eklendi
        };
        console.log(`[AI-TAHMİN] Makine ${makineId} için istek gönderiliyor... Payload:`, payload);
        // 4. AI Service'e istek at
        const tahminSonucu = await aiTahminIstegiGonder(payload);
        const riskPuani = riskSkorunuYuzeCevir(tahminSonucu.risk_skoru);
        console.log(`[AI-TAHMİN] Sonuç alındı. Risk Skoru: ${riskPuani}`);
        // 5. DB'ye risk skorunu ve tahmin detaylarını kaydet
        // MaddeId olarak formun ana referans maddesini verebiliriz (şimdilik 1)
        const maddeId = 1;
        await riskSkoruKaydet(makine.makine_id, formId, kullaniciId, tahminSonucu, maddeId);
        return {
            success: true,
            message: tahminSonucu.sistem_mesaji,
            data: {
                makine_id: makine.makine_id,
                makine_adi: makine.makine_adi,
                risk_skoru: riskPuani,
                tahmin_edilen_ariza: tahminSonucu.tahmin_edilen_ariza,
                uyari_durumu: tahminSonucu.uyari_durumu
            }
        };
    }
    catch (error) {
        console.error('[AI-TAHMİN HATA]', error.message);
        // Backend içi çağrım olduğu için throw atıyoruz, express'e json dönmüyoruz
        throw error;
    }
}
async function topluMakineTahmin(req, res) {
    try {
        const kullaniciId = Number(req.user?.userId);
        //tüm aktif makineleri çekmem için kullanılan prisma sorgusu
        const makineler = await prisma_1.default.makine.findMany({
            where: { aktiflik_durumu: true },
        });
        if (makineler.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Aktif makine bulunamadı.'
            });
        }
        const sonuclar = [];
        const hatalar = [];
        for (const makine of makineler) {
            try {
                // Her makine için EN SON doldurulan formu bul
                const enSonForm = await prisma_1.default.gunluk_kontrol_formu.findFirst({
                    where: { makine_id: makine.makine_id },
                    orderBy: { form_id: 'desc' }
                });
                if (!enSonForm) {
                    throw new Error("Bu makine için daha önce doldurulmuş form bulunamadı.");
                }
                // Az önce yazdığımız iç fonksiyonu çağırıyoruz (Otonom)
                const tahmin = await tekMakineTahmin(makine.makine_id, enSonForm.form_id, kullaniciId);
                sonuclar.push(tahmin.data);
            }
            catch (err) {
                console.warn(`Makine ${makine.makine_id} için tahmin başarısız:`, err.message);
                hatalar.push({
                    makine_id: makine.makine_id,
                    makine_adi: makine.makine_adi,
                    hata: err.message,
                });
            }
        }
        return res.status(200).json({
            success: true,
            message: `${sonuclar.length} makine başarılı, ${hatalar.length} makine hatalı.`,
            data: { basarili: sonuclar, hatali: hatalar },
        });
    }
    catch (error) {
        console.error('Toplu makine tahmin işlemi sırasında hata:', error);
        return res.status(500).json({
            success: false,
            message: 'Toplu makine tahmin işlemi sırasında bir hata oluştu.',
        });
    }
}
