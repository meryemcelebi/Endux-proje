import { Request, Response } from "express";
import prisma from "../config/prisma";

/**
 * Yeni satın alma kaydı oluşturur.
 * Aynı transaction içinde stok tablosunu da otomatik günceller (upsert).
 */
export async function satinAlmaEkle(req: Request, res: Response) {
    try {
        const { tedarikci_id, parca_adi, adet, birim_fiyat, tarih, puan, tedarik_suresi } = req.body;

        // ── Zorunlu alan kontrolü (Puan artık zorunlu değil) ──
        if (!tedarikci_id || !parca_adi || !adet || birim_fiyat === undefined) {
            res.status(400).json({
                success: false,
                message: "Tedarikçi ID, parça adı, adet ve birim fiyat alanları zorunludur."
            });
            return;
        }

        let puanDegeri: number | null = null;
        if (puan !== undefined && puan !== null && puan !== 0) {
            puanDegeri = Number(puan);
            if (Number.isNaN(puanDegeri) || !Number.isInteger(puanDegeri) || puanDegeri < 1 || puanDegeri > 10) {
                res.status(400).json({
                    success: false,
                    message: "Puan 1 ile 10 arasında bir tam sayı olmalıdır."
                });
                return;
            }
        }

        const adetDegeri = Number(adet);
        if (Number.isNaN(adetDegeri) || !Number.isInteger(adetDegeri) || adetDegeri < 1) {
            res.status(400).json({
                success: false,
                message: "Adet 1 veya daha büyük bir tam sayı olmalıdır."
            });
            return;
        }

        const tedarikSuresiDegeri = tedarik_suresi ? Number(tedarik_suresi) : null;

        // Tedarikçi var mı kontrol
        const tedarikci = await prisma.tedarikci.findUnique({
            where: { tedarikci_id: Number(tedarikci_id) }
        });
        if (!tedarikci) {
            res.status(404).json({
                success: false,
                message: "Belirtilen ID'ye sahip tedarikçi bulunamadı."
            });
            return;
        }

        // ── Transaction: Satın alma kaydı + Stok güncelleme ──
        const sonuc = await prisma.$transaction(async (tx) => {
            // 1) Satın alma kaydını oluştur
            const yeniSatinAlma = await tx.satin_alma.create({
                data: {
                    tedarikci_id: Number(tedarikci_id),
                    parca_adi: String(parca_adi).trim(),
                    adet: adetDegeri,
                    birim_fiyat: Number(birim_fiyat),
                    tedarik_suresi: tedarikSuresiDegeri,
                    tarih: tarih ? new Date(tarih) : new Date(),
                    puan: puanDegeri
                }
            });

            // 2) Stok tablosunu upsert ile güncelle
            await tx.stok.upsert({
                where: { parca_adi: String(parca_adi).trim() },
                update: {
                    miktar: { increment: adetDegeri },
                    son_guncelleme: new Date()
                },
                create: {
                    parca_adi: String(parca_adi).trim(),
                    miktar: adetDegeri,
                    son_guncelleme: new Date()
                }
            });

            return yeniSatinAlma;
        });

        res.status(201).json({
            success: true,
            message: "Satın alma kaydı başarıyla oluşturuldu ve stok güncellendi.",
            data: sonuc
        });

    } catch (error) {
        console.error("Satın alma ekleme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Satın alma kaydı eklenirken bir hata oluştu."
        });
    }
}

/**
 * Mevcut bir satın alma kaydını (ürünü) sonradan puanlar.
 */
export async function satinAlmaPuanla(req: Request, res: Response) {
    try {
        const id = Number(req.params.id);
        const { puan } = req.body;

        if (Number.isNaN(id)) {
            res.status(400).json({ success: false, message: "Geçerli bir satın alma ID'si giriniz." });
            return;
        }

        const puanDegeri = Number(puan);
        if (Number.isNaN(puanDegeri) || !Number.isInteger(puanDegeri) || puanDegeri < 1 || puanDegeri > 10) {
            res.status(400).json({ success: false, message: "Puan 1 ile 10 arasında olmalıdır." });
            return;
        }

        const guncellenen = await prisma.satin_alma.update({
            where: { satin_alma_id: id },
            data: { puan: puanDegeri }
        });

        res.status(200).json({
            success: true,
            message: "Satın alma puanı başarıyla güncellendi.",
            data: guncellenen
        });
    } catch (error) {
        console.error("Satın alma puanlama hatası:", error);
        res.status(500).json({ success: false, message: "Puan kaydedilirken bir hata oluştu." });
    }
}

/**
 * Tüm satın alma kayıtlarını tedarikçi bilgisiyle listeler.
 */
export async function tumSatinAlmalariGetir(req: Request, res: Response) {
    try {
        const satinAlmalar = await prisma.satin_alma.findMany({
            include: {
                tedarikci: {
                    select: {
                        tedarikci_id: true,
                        firma_adi: true,
                        aktiflik: true
                    }
                }
            },
            orderBy: {
                tarih: "desc"
            }
        });

        res.status(200).json({
            success: true,
            message: `${satinAlmalar.length} adet satın alma kaydı getirildi.`,
            data: satinAlmalar
        });

    } catch (error) {
        console.error("Satın alma listesi getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Satın alma kayıtları getirilirken bir hata oluştu."
        });
    }
}

/**
 * Belirli bir tedarikçinin tüm satın alma puanlarının ortalamasını hesaplar.
 */
export async function tedarikciOrtalamaPuan(req: Request, res: Response) {
    try {
        const tedarikciId = Number(req.params.id);

        if (Number.isNaN(tedarikciId)) {
            res.status(400).json({
                success: false,
                message: "Geçerli bir tedarikçi ID'si giriniz."
            });
            return;
        }

        // Tedarikçi var mı kontrol
        const tedarikci = await prisma.tedarikci.findUnique({
            where: { tedarikci_id: tedarikciId }
        });
        if (!tedarikci) {
            res.status(404).json({
                success: false,
                message: "Belirtilen ID'ye sahip tedarikçi bulunamadı."
            });
            return;
        }

        // Aggregate ile ortalama puan ve tedarik süresi hesapla
        const sonuc = await prisma.satin_alma.aggregate({
            where: { tedarikci_id: tedarikciId },
            _avg: { puan: true, tedarik_suresi: true },
            _count: { puan: true },
            _min: { puan: true, tedarik_suresi: true },
            _max: { puan: true, tedarik_suresi: true }
        });

        res.status(200).json({
            success: true,
            message: "Tedarikçi performans verileri hesaplandı.",
            data: {
                tedarikci_id: tedarikciId,
                firma_adi: tedarikci.firma_adi,
                ortalama_puan: sonuc._avg.puan ? Number(sonuc._avg.puan.toFixed(2)) : 0,
                ortalama_tedarik_suresi: sonuc._avg.tedarik_suresi ? Number(sonuc._avg.tedarik_suresi.toFixed(1)) : null,
                toplam_degerlendirme: sonuc._count.puan,
                min_puan: sonuc._min.puan,
                max_puan: sonuc._max.puan,
                min_tedarik_suresi: sonuc._min.tedarik_suresi,
                max_tedarik_suresi: sonuc._max.tedarik_suresi
            }
        });

    } catch (error) {
        console.error("Tedarikçi ortalama puan hatası:", error);
        res.status(500).json({
            success: false,
            message: "Tedarikçi puan ortalaması hesaplanırken bir hata oluştu."
        });
    }
}

/**
 * Tüm stok kayıtlarını listeler.
 */
export async function tumStoklariGetir(req: Request, res: Response) {
    try {
        const stoklar = await prisma.stok.findMany({
            orderBy: {
                parca_adi: "asc"
            }
        });

        res.status(200).json({
            success: true,
            message: `${stoklar.length} adet stok kaydı getirildi.`,
            data: stoklar
        });

    } catch (error) {
        console.error("Stok listesi getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Stok kayıtları getirilirken bir hata oluştu."
        });
    }
}
