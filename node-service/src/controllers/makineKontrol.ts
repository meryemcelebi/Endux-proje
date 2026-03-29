import { Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import prisma from "../config/prisma";

// Makine Ekle — POST /api/makineler/makine-ekle
export const makineEkle = async (req: Request, res: Response) => {
    try {
        const {
            makine_ad,
            firma_id,
            m_tur_id,
            seri_no,
            satin_alma_tarihi,
            satin_alma_maliyeti,
            aktiflik_durumu
        } = req.body;

        if (!makine_ad || !firma_id || !m_tur_id || !seri_no || !satin_alma_tarihi || !satin_alma_maliyeti || aktiflik_durumu === undefined) {
            return res.status(400).json({ hata: "Tüm alanlar zorunludur." });
        }

        if (typeof satin_alma_maliyeti !== "number") {
            return res.status(400).json({ hata: "Satın alma maliyeti sayısal bir değer olmalıdır." });
        }

        if (typeof aktiflik_durumu !== "boolean") {
            return res.status(400).json({ hata: "Aktiflik durumu boolean (true/false) olmalıdır." });
        }

        if (Array.isArray(seri_no) && seri_no.length === 0) {
            return res.status(400).json({ hata: "En az bir adet seri numarası girilmelidir." });
        }

        const yeniMakine = await prisma.makine.create({
            data: {
                makine_ad: makine_ad,
                firma_id: Number(firma_id),
                m_tur_id: Number(m_tur_id),
                seri_no: Array.isArray(seri_no) ? seri_no : [seri_no],
                satin_alma_tarihi: new Date(satin_alma_tarihi),
                satin_alma_maliyeti: Number(satin_alma_maliyeti),
                aktiflik_durumu: Boolean(aktiflik_durumu),
                makine_qr: uuidv4(),
                mevcut_risk_skoru: 0,
                top_cal_sma_saati: [],
                makine_ozellikleri: []
            }
        });

        res.status(201).json({
            success: true,
            message: "Makine başarıyla eklendi.",
            makine: yeniMakine
        });
    } catch (error) {
        console.error("Makine ekleme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Makine eklenirken bir hata oluştu."
        });
    }
};

// QR ile Makine Getir — GET /api/makineler/qr/:qr_uuid
export const qrileMakineGetir = async (req: Request, res: Response) => {
    try {
        const kullaniciRol = req.user!.rol;

        // Rol kontrolü (standardize edilmiş BÜYÜK HARF)
        if (!["TEKNISYEN", "YONETICI", "OPERATOR"].includes(kullaniciRol)) {
            return res.status(403).json({
                success: false,
                message: "Bu işlemi gerçekleştirmek için yeterli yetkiniz yok."
            });
        }

        const { qr_uuid } = req.params;

        const makine = await prisma.makine.findUnique({
            where: { makine_qr: qr_uuid },
            include: {
                firma: true,
                makine_turu: true,
                bakim_kaydi: true,
                gunluk_kontrol_formu: true,
                makine_kullanim: true,
                ariza_kaydi: true
            }
        });

        if (!makine) {
            return res.status(404).json({
                success: false,
                message: "Makine bulunamadı."
            });
        }

        // Temel bilgiler — tüm roller için ortak
        const temelBilgiler = {
            makine_id: makine.makine_id,
            makine_ad: makine.makine_ad,
            makine_qr: makine.makine_qr,
            seri_no: makine.seri_no,
            makine_turu: makine.makine_turu,
            aktiflik_durumu: makine.aktiflik_durumu,
            mevcut_risk_skoru: makine.mevcut_risk_skoru
        };

        // Role göre farklı veri döndür
        switch (kullaniciRol) {
            case "TEKNISYEN":
                return res.status(200).json({
                    success: true,
                    rol: "TEKNISYEN",
                    makine: temelBilgiler,
                    ariza_kaydi: makine.ariza_kaydi,
                    bakim_kaydi: makine.bakim_kaydi,
                    bakimFormu: {
                        sablon: true,
                        alanlar: [
                            { alan: "ariza_tipi", tip: "select", etiket: "Arıza Tipi", secenekler: ["Mekanik", "Elektrik", "Hidrolik", "Pnömatik", "Yazılım"], zorunlu: true },
                            { alan: "ariza_aciklamasi", tip: "textarea", etiket: "Arıza Açıklaması", zorunlu: true },
                            { alan: "yapilan_islem", tip: "textarea", etiket: "Yapılan İşlem", zorunlu: true },
                            { alan: "degisen_parcalar", tip: "text", etiket: "Değişen Parçalar", zorunlu: false },
                            { alan: "tahmini_sure", tip: "number", etiket: "Tahmini Süre (saat)", zorunlu: true },
                        ],
                    },
                });

            case "YONETICI":
                return res.status(200).json({
                    success: true,
                    rol: "YONETICI",
                    makine: {
                        ...temelBilgiler,
                        firma: makine.firma,
                        satin_alma_tarihi: makine.satin_alma_tarihi,
                        satin_alma_maliyeti: makine.satin_alma_maliyeti,
                        makine_ozellikleri: makine.makine_ozellikleri,
                        top_cal_sma_saati: makine.top_cal_sma_saati
                    },
                    ariza_gecmis: makine.ariza_kaydi,
                    bakim_gecmis: makine.bakim_kaydi,
                    gunluk_kontroller: makine.gunluk_kontrol_formu,
                    istatistikler: {
                        toplam_ariza: makine.ariza_kaydi.length,
                        toplam_bakim: makine.bakim_kaydi.length,
                        toplam_kontrol: makine.gunluk_kontrol_formu.length,
                    }
                });

            case "OPERATOR":
                return res.status(200).json({
                    success: true,
                    rol: "OPERATOR",
                    makine: temelBilgiler,
                    gunluk_kontrol_formu: {
                        sablon: true,
                        alanlar: [
                            { alan: "sicaklik", tip: "number", etiket: "Sıcaklık (°C)", zorunlu: true },
                            { alan: "titresim", tip: "number", etiket: "Titreşim Seviyesi", zorunlu: true },
                            { alan: "yag_seviyesi", tip: "select", etiket: "Yağ Seviyesi", secenekler: ["Normal", "Düşük", "Kritik"], zorunlu: true },
                            { alan: "genel_durum", tip: "select", etiket: "Genel Durum", secenekler: ["İyi", "Orta", "Kötü"], zorunlu: true },
                            { alan: "notlar", tip: "textarea", etiket: "Ek Notlar", zorunlu: false },
                        ],
                    },
                    onceki_formlar: makine.gunluk_kontrol_formu,
                });

            default:
                return res.status(403).json({
                    success: false,
                    message: "Bu işlemi gerçekleştirmek için yeterli yetkiniz yok."
                });
        }
    } catch (error) {
        console.error("Makine bilgileri getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Makine bilgileri getirilirken bir hata oluştu."
        });
    }
};