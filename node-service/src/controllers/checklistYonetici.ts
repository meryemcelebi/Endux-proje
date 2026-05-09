import { Request, Response, NextFunction } from "express";
import prisma from "../config/prisma";

import { tekMakineTahmin } from "./aiKontrol";

//operatorlerden gelen form verilerini database'e ekler:

function hesaplaFormRiskSkoru(cevaplar: Array<{ girilen_deger: string | null }>): number {
    const sayisalCevaplar = cevaplar
        .map(c => Number(c.girilen_deger))
        .filter(deger => Number.isFinite(deger));

    if (sayisalCevaplar.length === 0) return 0;

    const maksimumPuan = sayisalCevaplar.length * 2;
    const toplamPuan = sayisalCevaplar.reduce((toplam, deger) => toplam + Math.max(0, Math.min(2, deger)), 0);

    return Number(((toplamPuan / maksimumPuan) * 100).toFixed(2));
}

function riskSeviyesiBelirle(riskSkoru: number) {
    if (riskSkoru >= 80) return "YUKSEK";
    if (riskSkoru >= 50) return "ORTA";
    return "DUSUK";
}

export async function formKaydet(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const { makine_id, sablon_id, genel_not, cevaplar } = req.body;

        // Token'dan giriş yapan operatörün ID'sini alıyoruz
        const operator_id = Number(req.user?.userId);

        if (!makine_id || !sablon_id) {
            res.status(400).json({ success: false, hata: "Makine ID ve Şablon ID zorunludur." });
            return;
        }

        if (!Array.isArray(cevaplar) || cevaplar.length === 0) {
            res.status(400).json({ success: false, hata: "Geçerli bir cevap listesi sunulmadı." });
            return;
        }

        if (!operator_id) {
            res.status(401).json({ success: false, message: "Kullanıcı kimliği bulunamadı." });
            return;
        }


        const formatliCevaplar = cevaplar.map((c: any) => ({
            soru_referans_id: Number(c.madde_id),
            durum: c.durum || null,
            girilen_deger: c.girilen_deger == null ? null : String(c.girilen_deger),
            aciklama: c.aciklama || null
        }));

        const gecersizCevap = formatliCevaplar.find((c: any) => !Number.isInteger(c.soru_referans_id) || c.soru_referans_id <= 0);
        if (gecersizCevap) {
            res.status(400).json({ success: false, hata: "Cevap listesinde geçersiz kontrol maddesi var." });
            return;
        }

        const anlikRiskSkoru = hesaplaFormRiskSkoru(formatliCevaplar);

        const yeniForm = await prisma.$transaction(async (tx) => {
            const form = await tx.gunluk_kontrol_formu.create({
                data: {
                    makine_id: Number(makine_id),
                    kullanici_id: operator_id,
                    sablon_id: Number(sablon_id),
                    kontrol_tarihi: new Date(),
                    genel_not: genel_not || null,
                    ai_on_risk_durumu: anlikRiskSkoru
                }
            });

            const cevapKayitSonucu = await tx.form_madde_cevap.createMany({
                data: formatliCevaplar.map((cevap: any) => ({
                    form_id: form.form_id,
                    soru_referans_id: cevap.soru_referans_id,
                    durum: cevap.durum,
                    girilen_deger: cevap.girilen_deger,
                    aciklama: cevap.aciklama
                }))
            });

            if (cevapKayitSonucu.count !== formatliCevaplar.length) {
                throw new Error(`Form cevapları eksik kaydedildi. Beklenen: ${formatliCevaplar.length}, kaydedilen: ${cevapKayitSonucu.count}`);
            }

            await tx.risk_skoru.create({
                data: {
                    makine_id: Number(makine_id),
                    risk_skoru: anlikRiskSkoru,
                    risk_seviyesi: riskSeviyesiBelirle(anlikRiskSkoru),
                    hesaplama_tarihi: new Date()
                }
            });

            return form;
        });

        if (yeniForm) {
            console.log(`[AI-TETIKLEYICI] Makine ${makine_id} Form ${yeniForm.form_id} için AI başlatılıyor...`);
            tekMakineTahmin(Number(makine_id), yeniForm.form_id, operator_id).catch(err => {
                console.error("[AI-ARKA-PLAN-HATA] AI tahmin işlemi tamamlanamadı:", err);
            });
        }

        res.status(201).json({
            success: true,
            message: "Form başarıyla kaydedildi.",
            data: {
                form_id: yeniForm.form_id,
                cevap_sayisi: formatliCevaplar.length,
                risk_skoru: anlikRiskSkoru
            }
        });



    } catch (error) {
        console.error("Form kaydetme hatası:", error);
        res.status(500).json({ success: false, message: "Form kaydedilirken bir hata oluştu." });
    }
}

export async function sablonGetir(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const sablon_id = Number(req.params.sablon_id);//sablon_id'yi parametrelerden alıyoruz
        const sablon = await prisma.kontrol_sablonu.findUnique({
            where: { sablon_id }
        });
        if (!sablon) {
            res.status(404).json({ success: false, message: "Sablon bulunamadi." });
            return;
        }

        const maddeler = await prisma.kontrol_maddesi.findMany({
            where: { sablon_id: sablon.sablon_id }
        });

        res.status(200).json({ success: true, data: { ...sablon, kontrol_maddesi: maddeler } });
    } catch (error) {
        console.error("Sablon getirme hatası:", error);
        res.status(500).json({ success: false, message: "Sablon getirilirken bir hata oluştu." });
    }

}

// QR Kod Okutulduğunda Makineyi Bulup Form Şablonunu Döndüren Endpoint
export async function qrIleSablonGetir(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const makine_qr = req.params.makine_qr;

        // 1. Zincirin İlk Halkası: Makineyi QR kodundan bul
        const makine = await prisma.makine.findUnique({
            where: { makine_qr }
        });

        if (!makine) {
            res.status(404).json({ success: false, message: "Bu QR koda ait makine bulunamadı." });
            return;
        }

        //
        const sablon = await prisma.kontrol_sablonu.findFirst({
            where: {
                makine_tur_id: makine.makine_tur_id,
                aktiflik: true
            }
        });

        if (!sablon) {
            res.status(404).json({ success: false, message: "Bu makine türü için tanımlanmış aktif bir form şablonu bulunamadı." });
            return;
        }

        const sorular = await prisma.kontrol_maddesi.findMany({
            where: { sablon_id: sablon.sablon_id }
        });

        res.status(200).json({
            success: true,
            data: {
                makine_id: makine.makine_id,
                makine_adi: makine.makine_adi,
                seri_no: makine.seri_no,
                sablon_id: sablon.sablon_id,
                sablon_adi: sablon.sablon_adi,
                sorular: sorular
            }
        });

    } catch (error) {
        console.error("QR ile şablon getirme hatası:", error);
        res.status(500).json({ success: false, message: "Şablon getirilirken bir hata oluştu." });
    }
}
