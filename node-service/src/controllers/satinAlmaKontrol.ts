import { Request, Response } from "express";
import prisma from "../config/prisma";

const parseLocaleNumber = (value: unknown): number => {
    if (typeof value === "number") return value;
    const normalized = String(value ?? "")
        .trim()
        .replace(/\./g, "")
        .replace(",", ".");
    return Number(normalized);
};

export const satinAlmaKaydet = async (req: Request, res: Response): Promise<void> => {
    try {
        const {
            tedarikci_id,
            parca_adi,
            adet,
            birim_fiyat,
            tedarik_suresi,
            tarih,
            puan
        } = req.body;

        if (
            !tedarikci_id ||
            !parca_adi ||
            adet === undefined ||
            birim_fiyat === undefined
        ) {
            res.status(400).json({ hata: 'Lütfen zorunlu alanları (Tedarikçi, Parça Adı, Adet, Birim Fiyat) doldurun.' });
            return;
        }

        // Tedarikçi adını veritabanından bul
        const tedarikci = await prisma.tedarikci.findUnique({
            where: { tedarikci_id: Number(tedarikci_id) }
        });

        const p_tedarikci_firma_adi = tedarikci ? tedarikci.firma_adi : 'Bilinmeyen Tedarikçi';
        
        const p_parca_adi = parca_adi;
        const p_tahmini_omur_saati = 0; // Varsayılan değer
        const parsedBirimFiyat = parseLocaleNumber(birim_fiyat);
        const p_parca_maliyeti = Math.round(parsedBirimFiyat);
        const p_stok_miktari = Math.trunc(parseLocaleNumber(adet));
        const p_min_stok_seviyesi = 5; // Varsayılan değer
        const p_tedarik_gun_suresi = Math.trunc(parseLocaleNumber(tedarik_suresi || 0));
        const p_kategori_adi = 'Genel'; // Varsayılan değer

        if (!Number.isFinite(parsedBirimFiyat) || !Number.isFinite(p_stok_miktari) || p_stok_miktari <= 0) {
            res.status(400).json({ hata: 'Adet ve birim fiyat geçerli sayısal değerler olmalıdır.' });
            return;
        }

        // Parça Ekleme Prosedürünü Çağır
        await prisma.$executeRawUnsafe(
            `CALL public.sp_parca_ekle($1, $2, $3, $4, $5, $6, $7, $8)`,
            p_parca_adi,
            p_tahmini_omur_saati,
            p_parca_maliyeti,
            p_stok_miktari,
            p_min_stok_seviyesi,
            p_tedarik_gun_suresi,
            p_kategori_adi,
            p_tedarikci_firma_adi
        );

        // İsteğe bağlı: Puan geldiyse tedarikçi puan tablosuna ekleyelim
        if (puan && parseInt(puan, 10) > 0) {
            const authKullaniciId = Number((req as any).user?.userId);
            let kullanici_id = Number.isFinite(authKullaniciId) && authKullaniciId > 0 ? authKullaniciId : null;

            if (!kullanici_id) {
                const varsayilanKullanici = await prisma.kullanici.findFirst({
                    where: { OR: [{ aktiflik: true }, { aktiflik: null }] },
                    select: { kullanici_id: true },
                    orderBy: { kullanici_id: 'asc' }
                });
                kullanici_id = varsayilanKullanici?.kullanici_id ?? null;
            }

            if (!kullanici_id) {
                throw new Error('Tedarikçi puanı için geçerli bir kullanıcı bulunamadı.');
            }

            await prisma.tedarikci_puan.create({
                data: {
                    tedarikci_id: Number(tedarikci_id),
                    puanlayan_kullanici_id: kullanici_id,
                    puan: parseInt(puan, 10),
                    yorum: 'Satın alma işlemi ile otomatik puanlandı',
                    tarih: tarih ? new Date(tarih) : new Date()
                }
            });
        }

        res.status(201).json({
            mesaj: 'Satın alma kaydı ve parça ekleme işlemi başarıyla tamamlandı.'
        });

    } catch (error: any) {
        console.error('Satın alma kaydetme hatası:', error);
        const hataMesaji = error.message || 'Veritabanı işlemi sırasında bir hata oluştu.';
        res.status(500).json({
            hata: hataMesaji
        });
    }
};

// GET /api/satin-alma
export const getAlimGecmisi = async (req: Request, res: Response): Promise<void> => {
    try {
        const alimGecmisi = await prisma.$queryRaw<Array<{
            parca_adi: string | null;
            kategori_adi: string | null;
            stok_giris_tarihi: Date | null;
            girilen_adet: number | null;
        }>>`
            SELECT
                parca_adi,
                kategori_adi,
                stok_giris_tarihi,
                girilen_adet
            FROM public.vw_parca_alim_gecmisi
        `;

        res.json({
            success: true,
            message: `${alimGecmisi.length} adet alım geçmişi kaydı getirildi.`,
            data: alimGecmisi
        });
    } catch (error) {
        console.error("Alım geçmişi çekme hatası:", error);
        res.status(500).json({ hata: "Alım geçmişi çekilirken bir hata oluştu." });
    }
};

// GET /api/satin-alma/stok
export const getStokDurumu = async (req: Request, res: Response): Promise<void> => {
    try {
        const parcalar = await prisma.parca.findMany({
            orderBy: {
                parca_adi: 'asc'
            }
        });

        // Frontend'in beklediği veri yapısına çeviriyoruz
        const formatliStoklar = parcalar.map((p: any) => ({
            stok_id: p.parca_id,
            parca_adi: p.parca_adi,
            miktar: p.stok_miktari || 0,
            min_stok: p.min_stok_seviyesi || 5,
            son_guncelleme: new Date() 
        }));

        res.json({ data: formatliStoklar });
    } catch (error) {
        console.error("Stok çekme hatası:", error);
        res.status(500).json({ hata: "Stok verileri çekilirken bir hata oluştu." });
    }
};
