import { Request, Response } from "express";
import prisma from "../config/prisma";


/**
 * GET /api/gorevler
 * Giriş yapmış teknisyenin/servis sorumlusunun aktif bakım görevlerini listeler.
 *
 * Kullanıcı bilgisi: req.user.userId (JWT token'dan)
 *Mantık:
 *   - Kullanıcı rolü TEKNISYEN/YONETICI ise → bakim_kaydi tablosundan
 *     son 30 gündeki kayıtları listele
 *   - Kullanıcı rolü OPERATOR ise → günlük_kontrol_formu tablosundan
 *     bugünkü kontrolleri listele
 */

 export async function aktifGorevleriGetir(req: Request, res: Response): Promise<void> {
    try {
        const kullaniciId = Number(req.user!.userId);
        const kullaniciRol = req.user!.rol;

        if (kullaniciRol === "TEKNISYEN" || kullaniciRol === "YONETICI") {
            // Son 30 gündeki bakım kayıtları
            const otuzGunOnce = new Date(); 
            // Tarih hesaplama: Bugünden 30 gün öncesine git
            otuzGunOnce.setDate(otuzGunOnce.getDate() - 30);
            //.getDate() ile bugunun gununu alır
            // setDate() javaScript bunu otomatik olarak bir önceki aya taşıyarak doğru tarihi hesaplar

            const bakimGorevleri = await prisma.bakim_kaydi.findMany({
                where: {
                    bakim_tarihi: {
                        gte: otuzGunOnce
                    } },
                    include: {
                        makine: {
                            select: {
                                makine_id: true,
                                makine_adi: true,
                                seri_no: true,
                                makine_qr: true
                            }
                        },
                        servis_sorumlusu: {
                            select: {
                                sorumlu_id: true,
                                ad: true,
                                soyad: true,
                                telefon: true,
                                unvan: true
                            }
                        },
                        servis_firma: {
                            select: {
                                firma_adi: true
                            }
                        },
                    
                        ariza_kaydi: {
                            select: {
                                ariza_id: true,
                                ariza_aciklama: true
                            }
                        }
                    },
                    orderBy: {
                        bakim_tarihi: "desc"
                    }
            });
            res.status(200).json({
                success: true,
                message: `${bakimGorevleri.length} adet aktif bakım bulundu.`,
                data: bakimGorevleri
            });
            return;
        }
        if (kullaniciRol === "OPERATOR") {
            // Bugünkü günlük kontrol formları
            const bugun = new Date();
            bugun.setHours(0, 0, 0, 0); // Bugünün başlangıcı

            const yarinBaslangic = new Date(bugun);
            yarinBaslangic.setDate(yarinBaslangic.getDate() + 1); // Yarının başlangıcı

            const kontroller = await prisma.gunluk_kontrol_formu.findMany({
                where: {
                    kullanici_id: kullaniciId,
                    kontrol_tarihi: {
                        gte: bugun,
                        lt: yarinBaslangic
                    }
                },
                include: {
                    makine: {
                        select: {
                            makine_id: true,
                            makine_adi: true,
                            makine_qr: true
                        }
                    },
                    kontrol_sablonu: {
                        select: {
                           sablon_adi: true
                        }
                    }
                },
                orderBy: {
                    kontrol_tarihi: "desc"
                }
            });
            res.status(200).json({
                success: true,
                message: `${kontroller.length} adet bugünkü kontrol bulundu.`,
                data: kontroller
            });

            return;
        }
        //bilinmeyen rol
        res.status(403).json({
            success: false,
            message: 'Bu rol için görev bilgisi getirilemez.'
        });
    } catch (error) {
        console.error("Görevleri getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Görevler getirilirken bir hata oluştu.'
        });
    }
}









            
                  
