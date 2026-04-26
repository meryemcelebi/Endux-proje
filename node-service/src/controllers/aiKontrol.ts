import { Request, Response } from "express";
import axios, { AxiosError } from "axios";
import prisma from "../config/prisma";
import { config } from "../config";

const AI_SERVICE_URL = config.aiServiceUrl;
const AI_TIMEOUT_MS  = 10_000; // 10 saniye timeout

//python api'ye gönderilecek payload

interface AITahminPayload {
    makine_id: number;
    form_id: number;
    makine_turu :string;
    tahmini_omur_saati: number;
    toplam_calisma_saati:number;
    sicaklik:number;
    titresim:number;
    makine_degeri:number;
}
//python APİ'den dönen yanıt 
interface IAiTahminYanit {
    makine_id: number;
    form_id: number;
    makine: string;
    ariza_riski: boolean;
    tahmini_durus_suresi_saat: number;
    tahmini_onarim_maliyeti_tl: number;
    mesaj: string;
}

//veri tabanı sorgusu
async function makineOZetVeriCek(makineID : number){
    const makine=await prisma.makine.findUnique({
        where: {makine_id: makineID},
        include: {
            makine_turu: true,
            makine_ozellikleri: true
        },
    });
    if(!makine){
        throw new Error (`Makine Bulunamadı: ID ${makineID}`);
    }
    return makine;
}
async function aiTahminIstegiGonder(payload: AITahminPayload): Promise<IAiTahminYanit> {
    try {
        const response = await axios.post<IAiTahminYanit>(
            `${AI_SERVICE_URL}/predict`,
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
    tahmin: IAiTahminYanit
) {
    //risk skoru tablosuna kaydet
    const riskSeviyesi = tahmin.ariza_riski ? 'YUKSEK' : 'DUSUK';

    const riskKaydi = await prisma.risk_skoru.create({
        data: {
            makine_id: makineId,
            risk_skoru: tahmin.ariza_riski ? 0.85 : 0.15, //örnek skor
            risk_seviyesi: riskSeviyesi,
            hesaplama_tarihi: new Date(),
        },
    
    });
    //ai_model_log tablosuna kaydet
    await prisma.ai_model_log.create({
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

export async function tekMakineTahmin(req: Request, res: Response) {
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
        const teknikOzellikler = makine.makine_ozellikleri?.teknik_ozellikler as any;
        const tahminiOmurSaati = teknikOzellikler?.omur_saati || 10000; //örnek değer
        const makineDegeri = Number(makine.satin_alma_maliyeti) || 100000;  //örnek değer


        //python API'ye gönderilecek payload:
        const payload: AITahminPayload = {
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

        console.log('AI tahmin sonucu alındı:',JSON.stringify(tahminSonucu));

        //risk skorunu veritabanına kaydedilme işlemi
        const riskKaydi = await riskSkoruKaydet(
            makine.makine_id,
            Number(form_id),
            kullaniciId,
            tahminSonucu
        );

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
    } catch (error) {
        console.error('AI tahmin işlemi sırasında hata:', error);
        return res.status(500).json({
            success: false,
            message: 'AI tahmin işlemi sırasında bir hata oluştu.' ,
        });
    }
}


export async function topluMakineTahmin(req: Request, res: Response) {
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
        const makineler = await prisma.makine.findMany({
            where: { aktiflik_durumu: true },
            include: {
                makine_turu: true,
                makine_ozellikleri: true,
            },
        });
        if(makineler.length === 0){
            return res.status(404).json({
                success: false,
                message: 'Aktif makine bulunamadı.'
            });
        }
        const snuclar: any[] = [];
        const hatalar: any[] = [];
        
        for (const makine of makineler) {
            try {
                const teknikOzellikler = makine.makine_ozellikleri?.teknik_ozellikler as any;
                const tahminiOmurSaati = teknikOzellikler?.omur_saati || 10000;

                const payload: AITahminPayload = {
                    makine_id: makine.makine_id,
                    form_id: Number(form_id),
                    makine_turu: makine.makine_turu.makine_tur_adi,
                    tahmini_omur_saati: tahminiOmurSaati,
                    toplam_calisma_saati: Number(makine.toplam_calisma_saati) || 0,
                    sicaklik: Number(varsayilan_sicaklik) ||45 , //varsayılan değer
                    titresim: Number(varsayilan_titresim) || 3, //varsayılan değer
                    makine_degeri: Number(makine.satin_alma_maliyeti) || 100000,
                };

                const tahmin = await aiTahminIstegiGonder(payload);

                await riskSkoruKaydet(
                    makine.makine_id,
                    Number(form_id),
                    kullaniciId,
                    tahmin
                );

                snuclar.push({
                    makine_id: makine.makine_id,
                    makine_adi: makine.makine_adi,
                    ariza_riski: tahmin.ariza_riski,
                    mesaj: tahmin.mesaj,
                });
            } catch (err: any) {
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
    } catch (error) {
        console.error('Toplu makine tahmin işlemi sırasında hata:', error);
        return res.status(500).json({
            success: false,
            message: 'Toplu makine tahmin işlemi sırasında bir hata oluştu.',
        });
    }

}