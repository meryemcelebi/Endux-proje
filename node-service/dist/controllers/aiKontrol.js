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
async function aiTahminIstegiGonder(payload) {
    try {
        const response = await axios_1.default.post(`${AI_SERVICE_URL}/predict`, payload, { timeout: AI_TIMEOUT_MS });
        return response.data;
    }
    catch (error) {
        const axiosError = error;
        if (axiosError.code === 'ECONNREFUSED') {
            console.error('AI servisine bağlanılamadı.');
            throw new Error('AI servisine bağlanılamadı. Lütfen daha sonra tekrar deneyin.');
        }
        if (axiosError.code === 'ECONNABORTED') {
            console.error('AI servisi zaman aşımına uğradı.');
            throw new Error('AI servisi zaman aşımına uğradı. Lütfen daha sonra tekrar deneyin.');
        }
        if (axiosError.response) {
            const status = axiosError.response.status;
            console.error(`AI servisi hata yanıtı: ${status}`);
            throw new Error(`AI servisi hata yanıtı: ${status}`);
        }
        console.error('AI servisi isteği sırasında bir hata oluştu:', axiosError.message);
        throw new Error('AI servisi isteği sırasında bir hata oluştu. Lütfen daha sonra tekrar deneyin.');
    }
}
async function riskSkoruKaydet(makineId, formId, kullaniciId, tahmin) {
    //risk skoru tablosuna kaydet
    const riskSeviyesi = tahmin.ariza_riski ? 'YUKSEK' : 'DUSUK';
    const riskKaydi = await prisma_1.default.risk_skoru.create({
        data: {
            makine_id: makineId,
            risk_skoru: tahmin.ariza_riski ? 0.85 : 0.15, //örnek skor
            risk_seviyesi: riskSeviyesi,
            hesaplama_tarihi: new Date(),
        },
    });
    //ai_model_log tablosuna kaydet
    await prisma_1.default.ai_model_log.create({
        data: {
            makine_id: makineId,
            model_versiyon: "xgboost-v1.0",
            kullanilan_veri_sayisi: 1,
            tahmin_risk: tahmin.ariza_riski ? 0.85 : 0.15,
            tahmin_tarihi: new Date(),
            kullanici_id: kullaniciId,
            form_id: formId,
        },
    });
    return riskKaydi;
}
async function tekMakineTahmin(req, res) {
    try {
        const { makine_id, form_id, sicaklik, titresim } = req.body;
        const kullaniciId = Number(req.user?.userId);
        if (!makine_id || !form_id || sicaklik === undefined || titresim === undefined) {
            return res.status(400).json({
                success: false,
                message: ' makine_id, form_id, sicaklik ve titresim alanları gereklidir.'
            });
        }
        const makine = await makineOZetVeriCek(Number(makine_id));
        //teknik özelliklerden tahmini omür saatini çıkar
        const teknikOzellikler = makine.makine_ozellikleri?.teknik_ozellikler;
        const tahminiOmurSaati = teknikOzellikler?.omur_saati || 10000; //örnek değer
        const makineDegeri = Number(makine.satin_alma_maliyeti) || 100000; //örnek değer
        //python API'ye gönderilecek payload:
        const payload = {
            makine_id: makine.makine_id,
            form_id: Number(form_id),
            makine_turu: makine.makine_turu.makine_tur_adi,
            tahmini_omur_saati: tahminiOmurSaati,
            toplam_calisma_saati: Number(makine.toplam_calisma_saati) || 0,
            sicaklik: Number(sicaklik),
            titresim: Number(titresim),
            makine_degeri: makineDegeri,
        };
        console.log('AI tahmin isteği gönderiliyor:', JSON.stringify(payload));
        const tahminSonucu = await aiTahminIstegiGonder(payload);
        console.log('AI tahmin sonucu alındı:', JSON.stringify(tahminSonucu));
        //risk skorunu veritabanına kaydedilme işlemi
        const riskKaydi = await riskSkoruKaydet(makine.makine_id, Number(form_id), kullaniciId, tahminSonucu);
        return res.status(200).json({
            success: true,
            message: tahminSonucu.mesaj,
            data: {
                makine_id: makine.makine_id,
                makine_adi: makine.makine_adi,
                ariza_riski: tahminSonucu.ariza_riski,
                tahmini_durus_suresi_saat: tahminSonucu.tahmini_durus_suresi_saat,
                tahmini_onarim_maliyeti_tl: tahminSonucu.tahmini_onarim_maliyeti_tl,
                risk_kaydi_id: riskKaydi.risk_id,
            },
        });
    }
    catch (error) {
        console.error('AI tahmin işlemi sırasında hata:', error);
        return res.status(500).json({
            success: false,
            message: 'AI tahmin işlemi sırasında bir hata oluştu.',
        });
    }
}
async function topluMakineTahmin(req, res) {
    try {
        const { form_id, varsayilan_sicaklik, varsayilan_titresim } = req.body;
        const kullaniciId = Number(req.user?.userId);
        if (!form_id) {
            return res.status(400).json({
                success: false,
                message: 'form_id alanı gereklidir.'
            });
        }
        //tüm aktif makineleri çekmem için kullanılan prisma sorgusu
        const makineler = await prisma_1.default.makine.findMany({
            where: { aktiflik_durumu: true },
            include: {
                makine_turu: true,
                makine_ozellikleri: true,
            },
        });
        if (makineler.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Aktif makine bulunamadı.'
            });
        }
        const snuclar = [];
        const hatalar = [];
        for (const makine of makineler) {
            try {
                const teknikOzellikler = makine.makine_ozellikleri?.teknik_ozellikler;
                const tahminiOmurSaati = teknikOzellikler?.omur_saati || 10000;
                const payload = {
                    makine_id: makine.makine_id,
                    form_id: Number(form_id),
                    makine_turu: makine.makine_turu.makine_tur_adi,
                    tahmini_omur_saati: tahminiOmurSaati,
                    toplam_calisma_saati: Number(makine.toplam_calisma_saati) || 0,
                    sicaklik: Number(varsayilan_sicaklik) || 45, //varsayılan değer
                    titresim: Number(varsayilan_titresim) || 3, //varsayılan değer
                    makine_degeri: Number(makine.satin_alma_maliyeti) || 100000,
                };
                const tahmin = await aiTahminIstegiGonder(payload);
                await riskSkoruKaydet(makine.makine_id, Number(form_id), kullaniciId, tahmin);
                snuclar.push({
                    makine_id: makine.makine_id,
                    makine_adi: makine.makine_adi,
                    ariza_riski: tahmin.ariza_riski,
                    mesaj: tahmin.mesaj,
                });
            }
            catch (err) {
                // Tek makine hatası tüm döngüyü durdurmaz
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
            message: `${snuclar.length} makine başarılı, ${hatalar.length} makine hatalı.`,
            data: { basarili: snuclar, hatali: hatalar },
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
