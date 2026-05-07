import { Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import prisma from "../config/prisma";
import { IMakineOzellikleri } from '../interfaces/makine.types';

// Makine Ekle — POST /api/makineler/makine-ekle
export const makineEkle = async (req: Request, res: Response) => {
    try {
        const {
            makine_adi,
            firma_id,
            makine_tur_id,
            seri_no,
            satin_alma_tarihi,
            satin_alma_maliyeti,
            aktiflik_durumu,
            makine_ozellikleri,
            garanti_firma_id,
            garanti_suresi,
            lokasyon_id

        } = req.body;

        const ozellikler = makine_ozellikleri as IMakineOzellikleri;

        if (!makine_adi || !firma_id || !makine_tur_id || !seri_no || !satin_alma_tarihi || !satin_alma_maliyeti || aktiflik_durumu === undefined) {
            return res.status(400).json({ hata: "Tüm alanlar zorunludur." });
        }

        if (typeof satin_alma_maliyeti !== "number") {
            return res.status(400).json({ hata: "Satın alma maliyeti sayısal bir değer olmalıdır." });
        }

        if (typeof aktiflik_durumu !== "boolean") {
            return res.status(400).json({ hata: "Aktiflik durumu boolean (true/false) olmalıdır." });
        }

        if (typeof seri_no !== "string" || seri_no.trim().length === 0) {
            return res.status(400).json({ hata: "Geçerli bir seri numarası girilmelidir." });
        }


        const yeniMakine = await prisma.$transaction(async (tx) => {
            // 1. Rastgele 4 haneli PIN üret
            const pin = Math.floor(1000 + Math.random() * 9000);

            // 2. Makineyi oluştur (QR UUID + PIN dahil)
            const makine = await tx.makine.create({
                data: {
                    makine_adi: makine_adi,
                    firma_id: Number(firma_id),
                    makine_tur_id: Number(makine_tur_id),
                    seri_no: String(seri_no),
                    satin_alma_tarihi: new Date(satin_alma_tarihi),
                    satin_alma_maliyeti: Number(satin_alma_maliyeti),
                    aktiflik_durumu: Boolean(aktiflik_durumu),
                    makine_qr: uuidv4(),
                    servis_pin: pin,
                    toplam_calisma_saati: 0,
                    garanti_firma_id: garanti_firma_id ? Number(garanti_firma_id) : undefined,
                    garanti_suresi: garanti_suresi ? Number(garanti_suresi) : undefined,
                }
            });

            // 3. makine_ozellikleri varsa ayrı tabloya ekle
            if (ozellikler) {
                await tx.makine_ozellikleri.create({
                    data: {
                        makine_id: makine.makine_id,
                        teknik_ozellikler: ozellikler as any,
                    }
                });
            }

            // 4. Lokasyon bağlantısı varsa güncelle
            if (lokasyon_id) {
                await tx.lokasyon.update({
                    where: { lokasyon_id: Number(lokasyon_id) },
                    data: { makine_id: makine.makine_id }
                });
            }

            return makine;
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
        if (!["TEKNISYEN", "YONETICI", "OPERATOR", "SERVIS"].includes(kullaniciRol)) {
            return res.status(403).json({
                success: false,
                message: "Bu işlemi gerçekleştirmek için yeterli yetkiniz yok."
            });
        }
        const kullaniciId = req.user!.userId;
        const { qr_uuid } = req.params;
        // ─── AUDIT LOG: QR erişim kaydı ───
        console.log(JSON.stringify({
            event: 'QR_ACCESS',
            userId: kullaniciId,
            rol: kullaniciRol,
            qr_uuid: qr_uuid,
            ip: req.ip,
            timestamp: new Date().toISOString(),
        }));
        const makine = await prisma.makine.findUnique({
            where: { makine_qr: qr_uuid },
            include: {
                firma: true,
                makine_turu: true,
                bakim_kaydi: true,
                gunluk_kontrol_formu: true,
                makine_kullanim: true,
                ariza_kaydi: true,
                makine_ozellikleri: true,
                lokasyon: true,
                risk_skoru: { orderBy: { hesaplama_tarihi: 'desc' }, take: 1 }
            }
        });

        if (!makine) {
            if (!makine) {
                // ─── Başarısız erişim logu ───
                console.warn(JSON.stringify({
                    event: 'QR_ACCESS_FAILED',
                    userId: kullaniciId,
                    qr_uuid: qr_uuid,
                    ip: req.ip,
                    reason: 'MACHINE_NOT_FOUND',
                    timestamp: new Date().toISOString(),
                }));

                return res.status(404).json({
                    success: false,
                    message: "Bu QR koda ait makine bulunamadı."
                });
            }

        }

        // risk_skoru ayrı tabloda — en son kaydı çekiyoruz
        const sonRisk = makine.risk_skoru?.[0] ?? null;

        // Temel bilgiler — tüm roller için ortak
        const temelBilgiler = {
            makine_id: makine.makine_id,
            makine_adi: makine.makine_adi,
            makine_qr: makine.makine_qr,
            seri_no: makine.seri_no,
            makine_turu: makine.makine_turu,
            aktiflik_durumu: makine.aktiflik_durumu,
            mevcut_risk_skoru: sonRisk?.risk_skoru ?? null,
            risk_seviyesi: sonRisk?.risk_seviyesi ?? null
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
                        toplam_calisma_saati: makine.toplam_calisma_saati,
                        lokasyon: makine.lokasyon
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
            case "SERVIS":
                return res.status(200).json({
                    success: true,
                    rol: "SERVIS",
                    makine: {
                        ...temelBilgiler,
                        firma: makine.firma,
                        // satin_alma_tarihi: makine.satin_alma_tarihi,
                        //satin_alma_maliyeti: makine.satin_alma_maliyeti,
                        makine_ozellikleri: makine.makine_ozellikleri,
                        toplam_calisma_saati: makine.toplam_calisma_saati,
                    },
                    ariza_gecmis: makine.ariza_kaydi,
                    bakim_gecmis: makine.bakim_kaydi,
                    ariza_sebepleri: makine.ariza_kaydi,
                    istatistikler: {
                        toplam_ariza: makine.ariza_kaydi.length,
                        toplam_bakim: makine.bakim_kaydi.length,
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

export async function tumMakineBilgileriGetir(req: Request, res: Response) {
    try {
        const makineler = await prisma.makine.findMany({
            include: {
                firma: true,
                makine_turu: true,
                lokasyon: true,
                garanti_firma: {
                    include: { iletisim: true }
                },
                risk_skoru: { orderBy: { hesaplama_tarihi: 'desc' }, take: 1 },
                bakim_kaydi: { orderBy: { bakim_tarihi: 'desc' }, take: 5 },
                ariza_kaydi: { orderBy: { olusturma_tarihi: 'desc' }, take: 5 },
                makine_ozellikleri: true
            }
        });
        res.status(200).json({
            success: true,
            message: "Tüm makineler başarıyla getirildi.",
            data: makineler
        });
    } catch (error) {
        console.error("Tüm makine bilgileri getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Tüm makine bilgileri getirilirken bir hata oluştu."
        });
    }
};

export async function makineDetayGetir(req: Request, res: Response) {
    try {
        const makine_id = parseInt(req.params.id);
        if (isNaN(makine_id)) {
            return res.status(400).json({
                success: false,
                message: "Geçersiz makine ID'si."
            });
        }
        const makine = await prisma.makine.findUnique({
            where: { makine_id },
            include: {
                firma: true,
                garanti_firma: {
                    include: { iletisim: true }
                },
                makine_turu: true,
                bakim_kaydi: true,
                gunluk_kontrol_formu: true,
                makine_kullanim: true,
                ariza_kaydi: true,
                makine_ozellikleri: true,
                lokasyon: true
            }
        });
        if (!makine) {
            return res.status(404).json({
                success: false,
                message: "Belirtilen ID ile makine bulunamadı."
            });

        }
        res.status(200).json({
            success: true,
            message: "Makine detayları başarıyla getirildi.",
            data: makine
        });

    } catch (error) {
        console.error("Makine detayları getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Makine detayları getirilirken bir hata oluştu."
        });
    }
};

export async function QRKodYazdir(req: Request, res: Response) {
    try {
        const makine_id = Number(req.params.id);
        if (isNaN(makine_id)) {
            return res.status(400).json({
                success: false,
                message: "Geçersiz makine ID'si."
            });
        }
        const makine = await prisma.makine.findUnique({
            where: { makine_id },
            select: {
                makine_id: true,
                makine_adi: true,
                makine_qr: true,
                seri_no: true
            }
        });


        if (!makine) {
            return res.status(404).json({
                success: false,
                message: "makine bulunamadı."
            });
        }
        return res.status(200).json({
            success: true,
            message: "Makine QR kod bilgileri başarıyla getirildi.",
            data: makine
        });
    } catch (error) {
        console.error("Makine QR kod yazdırma hatası:", error);
        res.status(500).json({
            success: false,
            message: "Makine QR kod yazdırılırken bir hata oluştu."
        });
    }

}

// Makine Durum Güncelle — PATCH /api/makineler/:id/durum
// Pasife çekildiğinde otomatik bakim_kaydi (BEKLEYEN) oluşturur
export const makineDurumGuncelle = async (req: Request, res: Response) => {
    try {
        const makine_id = parseInt(req.params.id);
        if (isNaN(makine_id)) {
            return res.status(400).json({ success: false, message: "Geçersiz makine ID." });
        }

        const { aktiflik_durumu } = req.body;
        if (typeof aktiflik_durumu !== "boolean") {
            return res.status(400).json({ success: false, message: "aktiflik_durumu boolean olmalıdır." });
        }

        // Prisma Transaction: makine durumunu güncelle + gerekirse bakım kaydı oluştur
        const sonuc = await prisma.$transaction(async (tx) => {
            // 1) Makine durumunu güncelle
            const guncellenen = await tx.makine.update({
                where: { makine_id },
                data: { aktiflik_durumu },
                select: {
                    makine_id: true,
                    makine_adi: true,
                    aktiflik_durumu: true,
                    firma_id: true
                }
            });

            // 2) Eğer makine PASİF'e çekiliyorsa → otomatik BEKLEYEN bakım kaydı oluştur
            if (aktiflik_durumu === false) {
                // Aynı makine için zaten BEKLEYEN bir kayıt var mı kontrol et (çift kayıt önleme)
                const mevcutBekleyen = await tx.bakim_kaydi.findFirst({
                    where: {
                        makine_id: makine_id,
                        durum: { in: ['BEKLEYEN', 'Onay Bekliyor'] }
                    }
                });

                // Henüz bekleyen yoksa yeni bir tane oluştur
                if (!mevcutBekleyen) {
                    await tx.bakim_kaydi.create({
                        data: {
                            makine_id: makine_id,
                            bakim_maliyet: 0,
                            durum: 'BEKLEYEN',
                            aciklama: `Sistem tarafından otomatik oluşturuldu — "${guncellenen.makine_adi || 'Makine #' + makine_id}" Pasif duruma alındı.`,
                            bakim_tarihi: new Date()
                        }
                    });

                    console.log(`[AUTO-BAKIM] Makine #${makine_id} (${guncellenen.makine_adi}) Pasife alındı → BEKLEYEN bakım kaydı oluşturuldu.`);
                }
            }

            return guncellenen;
        });

        res.status(200).json({
            success: true,
            message: `Makine durumu ${aktiflik_durumu ? "Aktif" : "Pasif"} olarak güncellendi.${!aktiflik_durumu ? " Otomatik bakım talebi oluşturuldu." : ""}`,
            data: sonuc,
        });
    } catch (error) {
        console.error("Makine durum güncelleme hatası:", error);
        res.status(500).json({ success: false, message: "Durum güncellenirken hata oluştu." });
    }
};

