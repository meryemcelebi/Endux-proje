"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getStokDurumu = exports.satinAlmaKaydet = void 0;
const prisma_1 = __importDefault(require("../config/prisma"));
const satinAlmaKaydet = async (req, res) => {
    try {
        const { tedarikci_id, parca_adi, adet, birim_fiyat, tedarik_suresi, tarih, puan } = req.body;
        if (!tedarikci_id ||
            !parca_adi ||
            adet === undefined ||
            birim_fiyat === undefined) {
            res.status(400).json({ hata: 'Lütfen zorunlu alanları (Tedarikçi, Parça Adı, Adet, Birim Fiyat) doldurun.' });
            return;
        }
        // Tedarikçi adını veritabanından bul
        const tedarikci = await prisma_1.default.tedarikci.findUnique({
            where: { tedarikci_id: Number(tedarikci_id) }
        });
        const p_tedarikci_firma_adi = tedarikci ? tedarikci.firma_adi : 'Bilinmeyen Tedarikçi';
        const p_parca_adi = parca_adi;
        const p_tahmini_omur_saati = 0; // Varsayılan değer
        const p_parca_maliyeti = parseFloat(birim_fiyat);
        const p_stok_miktari = parseInt(adet, 10);
        const p_min_stok_seviyesi = 5; // Varsayılan değer
        const p_tedarik_gun_suresi = parseInt(tedarik_suresi || '0', 10);
        const p_kategori_adi = 'Genel'; // Varsayılan değer
        // Parça Ekleme Prosedürünü Çağır
        await prisma_1.default.$executeRawUnsafe(`CALL public.sp_parca_ekle($1, $2, $3, $4, $5, $6, $7, $8)`, p_parca_adi, p_tahmini_omur_saati, p_parca_maliyeti, p_stok_miktari, p_min_stok_seviyesi, p_tedarik_gun_suresi, p_kategori_adi, p_tedarikci_firma_adi);
        // İsteğe bağlı: Puan geldiyse tedarikçi puan tablosuna ekleyelim
        if (puan && parseInt(puan, 10) > 0) {
            const authKullaniciId = Number(req.user?.userId);
            let kullanici_id = Number.isFinite(authKullaniciId) && authKullaniciId > 0 ? authKullaniciId : null;
            if (!kullanici_id) {
                const varsayilanKullanici = await prisma_1.default.kullanici.findFirst({
                    where: { OR: [{ aktiflik: true }, { aktiflik: null }] },
                    select: { kullanici_id: true },
                    orderBy: { kullanici_id: 'asc' }
                });
                kullanici_id = varsayilanKullanici?.kullanici_id ?? null;
            }
            if (!kullanici_id) {
                throw new Error('Tedarikçi puanı için geçerli bir kullanıcı bulunamadı.');
            }
            await prisma_1.default.tedarikci_puan.create({
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
    }
    catch (error) {
        console.error('Satın alma kaydetme hatası:', error);
        const hataMesaji = error.message || 'Veritabanı işlemi sırasında bir hata oluştu.';
        res.status(500).json({
            hata: hataMesaji
        });
    }
};
exports.satinAlmaKaydet = satinAlmaKaydet;
// GET /api/satin-alma/stok
const getStokDurumu = async (req, res) => {
    try {
        const parcalar = await prisma_1.default.parca.findMany({
            orderBy: {
                parca_adi: 'asc'
            }
        });
        // Frontend'in beklediği veri yapısına çeviriyoruz
        const formatliStoklar = parcalar.map((p) => ({
            stok_id: p.parca_id,
            parca_adi: p.parca_adi,
            miktar: p.stok_miktari || 0,
            min_stok: p.min_stok_seviyesi || 5,
            son_guncelleme: new Date()
        }));
        res.json({ data: formatliStoklar });
    }
    catch (error) {
        console.error("Stok çekme hatası:", error);
        res.status(500).json({ hata: "Stok verileri çekilirken bir hata oluştu." });
    }
};
exports.getStokDurumu = getStokDurumu;
