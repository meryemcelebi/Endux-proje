import { Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import prisma from "../config/prisma";
import { IMakineOzellikleri } from '../interfaces/makine.types';

const isDatabaseReachabilityError = (error: any) =>
    ["P1001", "ETIMEDOUT", "ECONNREFUSED", "ENOTFOUND"].includes(error?.code) ||
    error?.message?.includes("Can't reach database server") ||
    error?.message?.includes("Connection terminated unexpectedly");

const databaseUnavailableMessage =
    "Veritabanına ulaşılamıyor. Yerel geliştirmede Docker/PostgreSQL servisinin çalıştığından emin olun.";

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
            lokasyon_id,
            // TPM: Yapılandırılmış teknik özellik alanları
            kapasite,
            guc_tuketimi,
            max_rpm,
            max_basinc_ton,
            enjeksiyon_hacmi,
            tabla_boyutu,
            guncel_calisma_saati,
            tedarikci
        } = req.body;

        const ozellikler = makine_ozellikleri as IMakineOzellikleri;

        if (!makine_adi || !firma_id || !makine_tur_id || !seri_no || !satin_alma_tarihi || satin_alma_maliyeti === undefined || satin_alma_maliyeti === null || aktiflik_durumu === undefined) {
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


        // 1. Rastgele 4 haneli PIN üret
        const pin = Math.floor(1000 + Math.random() * 9000);

        // 2. Makineyi oluştur (QR UUID + PIN dahil)
        const yeniMakine = await prisma.makine.create({
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
                toplam_calisma_saati: guncel_calisma_saati ? Number(guncel_calisma_saati) : 0,
                garanti_firma_id: garanti_firma_id ? Number(garanti_firma_id) : undefined,
                garanti_suresi: garanti_suresi ? Number(garanti_suresi) : undefined,
            }
        });

        // 2.5 Garanti Firması — Eğer ID yoksa ama isim varsa garanti_firma tablosunda oluştur/bul
        if (!garanti_firma_id && tedarikci && tedarikci.firma_adi) {
            try {
                // Önce iletişim kaydı oluştur
                const newIletisim = await prisma.iletisim.create({
                    data: {
                        telefon: tedarikci.telefon || null,
                        mail: tedarikci.email || null,
                        acik_adres: tedarikci.adres || null,
                        il: tedarikci.il_ilce?.split('/')[0]?.trim() || null,
                        ilce: tedarikci.il_ilce?.split('/')[1]?.trim() || null
                    }
                });

                // garanti_firma tablosunda ara veya oluştur 
                let g_firma = await prisma.garanti_firma.findFirst({
                    where: { firma_adi: tedarikci.firma_adi }
                });

                if (!g_firma) {
                    g_firma = await prisma.garanti_firma.create({
                        data: {
                            firma_adi: tedarikci.firma_adi,
                            iletisim_id: newIletisim.iletisim_id
                        }
                    });
                }

                // Makineyi garanti firmasına bağla
                await prisma.makine.update({
                    where: { makine_id: yeniMakine.makine_id },
                    data: { garanti_firma_id: g_firma.garanti_firma_id }
                });
            } catch (err) {
                console.error("Garanti firması oluşturma/atama hatası:", err);
            }
        }

        // 3. makine_ozellikleri: Yapılandırılmış alanlar + eski JSON desteği
        let teknik_json: any = ozellikler ? { ...ozellikler } : {};

        if (kapasite) teknik_json.kapasite = String(kapasite);
        if (guc_tuketimi) teknik_json.guc_tuketimi = String(guc_tuketimi);
        if (max_rpm) teknik_json.max_rpm = Number(max_rpm);
        if (max_basinc_ton) teknik_json.max_basinc_ton = Number(max_basinc_ton);
        if (enjeksiyon_hacmi) teknik_json.enjeksiyon_hacmi = String(enjeksiyon_hacmi);
        if (tabla_boyutu) teknik_json.tabla_boyutu = String(tabla_boyutu);

        const ozellikData: any = {
            makine_id: yeniMakine.makine_id,
            teknik_ozellikler: Object.keys(teknik_json).length > 0 ? teknik_json : null,
        };

        await prisma.makine_ozellikleri.create({ data: ozellikData });

        // 4. Lokasyon bağlantısı varsa güncelle
        if (lokasyon_id) {
            let actual_lo_id: number | null = null;
            if (isNaN(Number(lokasyon_id))) {
                const foundLo = await prisma.lokasyon.findFirst({
                    where: { fabrika_alani: String(lokasyon_id) }
                });
                if (foundLo) actual_lo_id = foundLo.lokasyon_id;
            } else {
                actual_lo_id = Number(lokasyon_id);
            }

            if (actual_lo_id) {
                await prisma.lokasyon.update({
                    where: { lokasyon_id: actual_lo_id },
                    data: { makine_id: yeniMakine.makine_id }
                });
            }
        }

        // Tüm ilişkileriyle makineyi tekrar çek
        const finalMachine = await prisma.makine.findUnique({
            where: { makine_id: yeniMakine.makine_id },
            include: {
                firma: true,
                makine_turu: true,
                lokasyon: true,
                makine_ozellikleri: true,
                garanti_firma: { include: { iletisim: true } }
            }
        });

        res.status(201).json({
            success: true,
            message: "Makine başarıyla eklendi.",
            makine: finalMachine
        });
    } catch (error) {
        console.error("Makine ekleme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Makine eklenirken bir hata oluştu.",
            hata_detayi: error instanceof Error ? error.message : JSON.stringify(error)
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
                gunluk_kontrol_formu: {
                    orderBy: { kontrol_tarihi: 'desc' },
                    include: {
                        form_madde_cevap: {
                            include: { kontrol_maddesi: true }
                        }
                    }
                },
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
                ariza_kaydi: { orderBy: { olusturma_tarihi: 'desc' }, take: 5 }
            }
        });
        res.status(200).json({
            success: true,
            message: "Tüm makineler başarıyla getirildi.",
            data: makineler
        });
    } catch (error) {
        if (isDatabaseReachabilityError(error)) {
            console.error("Tüm makine bilgileri getirme hatası: veritabanına ulaşılamıyor.");
            return res.status(503).json({
                success: false,
                message: databaseUnavailableMessage
            });
        }
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
                lokasyon: true,
                risk_skoru: { orderBy: { hesaplama_tarihi: 'desc' }, take: 1 }
            }
        });
        if (!makine) {
            return res.status(404).json({
                success: false,
                message: "Belirtilen ID ile makine bulunamadı."
            });

        }
        const sonRisk = makine.risk_skoru?.[0] ?? null;

        res.status(200).json({
            success: true,
            message: "Makine detayları başarıyla getirildi.",
            data: {
                ...makine,
                mevcut_risk_skoru: sonRisk?.risk_skoru ?? null,
                risk_seviyesi: sonRisk?.risk_seviyesi ?? null
            }
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

        const sonuc = await prisma.makine.update({
            where: { makine_id },
            data: { aktiflik_durumu },
            select: {
                makine_id: true,
                makine_adi: true,
                aktiflik_durumu: true,
                firma_id: true
            }
        });

        // Eğer makine PASİF'e çekiliyorsa otomatik BEKLEYEN bakım kaydı oluştur.
        // Supabase pooler üzerinde kısa işlemlerde interactive transaction P2028 üretebildiği
        // için bu akış bilinçli olarak sıralı, normal Prisma çağrılarıyla çalışır.
        if (aktiflik_durumu === false) {
            const mevcutBekleyen = await prisma.bakim_kaydi.findFirst({
                where: {
                    makine_id,
                    durum: { in: ['BEKLEYEN', 'Onay Bekliyor', 'ONAYLANDI', 'Teknik Serviste', 'Bakımda'] }
                }
            });

            if (!mevcutBekleyen) {
                await prisma.bakim_kaydi.create({
                    data: {
                        makine_id,
                        bakim_maliyet: 0,
                        durum: 'BEKLEYEN',
                        aciklama: `Sistem tarafından otomatik oluşturuldu — "${sonuc.makine_adi || 'Makine #' + makine_id}" Pasif duruma alındı.`,
                        bakim_tarihi: new Date()
                    }
                });

                console.log(`[AUTO-BAKIM] Makine #${makine_id} (${sonuc.makine_adi}) Pasife alındı → BEKLEYEN bakım kaydı oluşturuldu.`);
            }
        }

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

