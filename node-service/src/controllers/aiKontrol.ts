import { Request, Response } from "express";
import axios, { AxiosError } from "axios";
import prisma from "../config/prisma";
import { config } from "../config";

const AI_SERVICE_URL = config.aiServiceUrl;
const AI_TIMEOUT_MS = 10_000; // 10 saniye timeout

//python api'ye gönderilecek payload

interface AITahminPayload {
    makine_turu: string;
    form_doldurma_suresi_sn: number;
    toplam_calisma_saati: number;
    [key: string]: number | string;  // dinamik form cevapları (sicaklik, titresim, vb.)
}

//python APİ'den dönen yanıt 
interface IAiTahminYanit {
    sistem_mesaji: string;
    makine_turu: string;
    guvenilirlik_notu: string;
    tahmin_edilen_ariza: string;
    risk_skoru: number;           // 0.00-1.00 arası
    rul_tahmini_saat: number;     // Tahmini Kalan Faydalı Ömür
    bakim_tavsiyesi: string;
    uyari_durumu: string;
    detaylar: {
        tahmini_maliyet: number;
        tahmini_durus_suresi: number;
        ekip: string;
        parca: string;
    };
}

//veri tabanı sorgusu
async function makineOZetVeriCek(makineID: number) {
    const makine = await prisma.makine.findUnique({
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
async function formCevaplariToAIPayload(formId: number): Promise<Record<string, number>> {
    const cevaplar = await prisma.form_madde_cevap.findMany({
        where: { form_id: formId },
        include: {
            kontrol_maddesi: true, // soru_referans_id → kontrol_maddesi.madde_id
        },
    });

    const payload: Record<string, number> = {};
    for (const cevap of cevaplar) {
        const parametre = cevap.kontrol_maddesi?.teknik_parametre;
        if (parametre) {
            // girilen_deger "0", "1", "2" şeklinde geliyor → sayıya çevir
            payload[parametre] = Number(cevap.girilen_deger) || 0;
        }
    }
    return payload;
}

async function aiTahminIstegiGonder(payload: AITahminPayload): Promise<IAiTahminYanit> {
    try {
        const response = await axios.post<IAiTahminYanit>(
            `${AI_SERVICE_URL}/tahmin-et`,
            payload,
            { timeout: AI_TIMEOUT_MS }
        );
        return response.data;
    } catch (error) {
        const axiosError = error as AxiosError;
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

async function riskSkoruKaydet(
    makineId: number,
    formId: number,
    kullaniciId: number,
    tahmin: IAiTahminYanit,
    maddeId: number
) {
    //risk skoru tablosuna kaydet
    const riskSeviyesi = tahmin.risk_skoru >= 0.50 ? 'YUKSEK' : 'DUSUK';

    const riskKaydi = await prisma.risk_skoru.create({
        data: {
            makine_id: makineId,
            risk_skoru: tahmin.risk_skoru,
            risk_seviyesi: riskSeviyesi,
            hesaplama_tarihi: new Date(),
        },
    });

    //ai_ariza_tespit tablosuna kaydet
    await prisma.ai_ariza_tespit.create({
        data: {
            makine_id: makineId,
            form_id: formId,
            madde_id: maddeId,
            tahmin_edilen_ariza: tahmin.tahmin_edilen_ariza,
            risk_skoru: tahmin.risk_skoru,
            tespit_tarihi: new Date(),
            model_versiyon: "xgboost-v4.0",
            tahmini_durus_suresi: tahmin.detaylar.tahmini_durus_suresi,
            tahmini_maliyet: tahmin.detaylar.tahmini_maliyet,
        },
    });

    //ai_model_log tablosuna kaydet
    await prisma.ai_model_log.create({
        data: {
            makine_id: makineId,
            model_versiyon: "xgboost-v4.0",
            kullanilan_veri_sayisi: 1,
            tahmin_risk: tahmin.risk_skoru,
            tahmin_tarihi: new Date(),
            kullanici_id: kullaniciId,
            form_id: formId,
        },
    });

    // gunluk_kontrol_formu.ai_on_risk_durumu güncelle
    await prisma.gunluk_kontrol_formu.update({
        where: { form_id: formId },
        data: { ai_on_risk_durumu: tahmin.risk_skoru },
    });

    // AI EĞER YÜKSEK RİSK VEYA ARIZA TESPİT EDERSE OTOMATİK OLARAK "ONAY BEKLEYEN" BAKIM KAYDI OLUŞTURUR
    if (tahmin.risk_skoru >= 0.50 || (tahmin.tahmin_edilen_ariza && tahmin.tahmin_edilen_ariza !== "YOK")) {
        await prisma.bakim_kaydi.create({
            data: {
                makine_id: makineId,
                kullanici_id: kullaniciId,
                bakim_maliyet: tahmin.detaylar.tahmini_maliyet || 0,
                durus_suresi: tahmin.detaylar.tahmini_durus_suresi || 0,
                aciklama: `[AI Otonom Tespit] ${tahmin.tahmin_edilen_ariza} - ${tahmin.bakim_tavsiyesi}`,
                bakim_tarihi: new Date(),
                durum: "Onay Bekliyor"
            }
        });
    }

    return riskKaydi;
}

export async function tekMakineTahmin(makineId: number, formId: number, kullaniciId: number) {
    try {
        // 1. Makine özet bilgilerini getir
        const makine = await makineOZetVeriCek(makineId);

        // 2. Form verilerini DB'den çek ve sayısal değerlere dönüştür
        const formCevaplari = await formCevaplariToAIPayload(formId);

        // 3. AI Service için payload hazırla
        const formSuresi = 60; // TODO: İleride form_doldurma_suresi_sn tablodan alınabilir
        const payload: AITahminPayload = {
            makine_turu: makine.makine_turu.makine_tur_adi,
            form_doldurma_suresi_sn: formSuresi,
            toplam_calisma_saati: Number(makine.toplam_calisma_saati) || 0,
            ...formCevaplari // sicaklik, titresim, yag_kacak vb. dinamik veriler eklendi
        };

        console.log(`[AI-TAHMİN] Makine ${makineId} için istek gönderiliyor... Payload:`, payload);

        // 4. AI Service'e istek at
        const tahminSonucu = await aiTahminIstegiGonder(payload);

        console.log(`[AI-TAHMİN] Sonuç alındı. Risk Skoru: ${tahminSonucu.risk_skoru}`);

        // 5. DB'ye risk skorunu ve tahmin detaylarını kaydet
        const ilkCevap = await prisma.form_madde_cevap.findFirst({ where: { form_id: formId } });
        let maddeId = ilkCevap?.soru_referans_id;
        if (!maddeId) {
            const herhangiBirMadde = await prisma.kontrol_maddesi.findFirst();
            maddeId = herhangiBirMadde ? herhangiBirMadde.madde_id : 1;
        }

        await riskSkoruKaydet(
            makine.makine_id,
            formId,
            kullaniciId,
            tahminSonucu,
            maddeId
        );

        return {
            success: true,
            message: tahminSonucu.sistem_mesaji,
            data: {
                makine_id: makine.makine_id,
                makine_adi: makine.makine_adi,
                risk_skoru: tahminSonucu.risk_skoru,
                tahmin_edilen_ariza: tahminSonucu.tahmin_edilen_ariza,
                uyari_durumu: tahminSonucu.uyari_durumu
            }
        };

    } catch (error: any) {
        console.error('[AI-TAHMİN HATA]', error.message);
        // Backend içi çağrım olduğu için throw atıyoruz, express'e json dönmüyoruz
        throw error;
    }
}


export async function topluMakineTahmin(req: Request, res: Response) {
    try {
        const kullaniciId = Number(req.user?.userId);

        //tüm aktif makineleri çekmem için kullanılan prisma sorgusu
        const makineler = await prisma.makine.findMany({
            where: { aktiflik_durumu: true },
        });

        if (makineler.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Aktif makine bulunamadı.'
            });
        }

        const sonuclar: any[] = [];
        const hatalar: any[] = [];

        for (const makine of makineler) {
            try {
                // Her makine için EN SON doldurulan formu bul
                const enSonForm = await prisma.gunluk_kontrol_formu.findFirst({
                    where: { makine_id: makine.makine_id },
                    orderBy: { form_id: 'desc' }
                });

                if (!enSonForm) {
                    throw new Error("Bu makine için daha önce doldurulmuş form bulunamadı.");
                }

                // Az önce yazdığımız iç fonksiyonu çağırıyoruz (Otonom)
                const tahmin = await tekMakineTahmin(makine.makine_id, enSonForm.form_id, kullaniciId);

                sonuclar.push(tahmin.data);

            } catch (err: any) {
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
    } catch (error) {
        console.error('Toplu makine tahmin işlemi sırasında hata:', error);
        return res.status(500).json({
            success: false,
            message: 'Toplu makine tahmin işlemi sırasında bir hata oluştu.',
        });
    }

}