"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getParcaKategorileri = exports.parcaSil = exports.getStokDurumu = exports.getAlimGecmisi = exports.satinAlmaKaydet = void 0;
const prisma_1 = __importDefault(require("../config/prisma"));
const parseLocaleNumber = (value) => {
    if (typeof value === "number")
        return value;
    const normalized = String(value ?? "")
        .trim()
        .replace(/\./g, "")
        .replace(",", ".");
    return Number(normalized);
};
const satinAlmaKaydet = async (req, res) => {
    try {
        const { tedarikci_id, parca_adi, adet, birim_fiyat, tedarik_suresi, tarih, puan, makine_tur_id } = req.body;
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
        // Kategori adını belirle (Seçilen makine türü varsa onun adını al)
        let resolvedKategoriAdi = req.body.kategori_adi || 'Genel';
        if (makine_tur_id) {
            const mTur = await prisma_1.default.makine_turu.findUnique({
                where: { makine_tur_id: Number(makine_tur_id) }
            });
            if (mTur) {
                resolvedKategoriAdi = mTur.makine_tur_adi;
            }
        }
        const p_parca_adi = parca_adi;
        const p_tahmini_omur_saati = req.body.tahmini_omur ? parseLocaleNumber(req.body.tahmini_omur) : 0;
        const parsedBirimFiyat = parseLocaleNumber(birim_fiyat);
        const p_parca_maliyeti = Math.round(parsedBirimFiyat);
        const p_stok_miktari = Math.trunc(parseLocaleNumber(adet));
        const p_min_stok_seviyesi = 5; // Varsayılan değer
        const p_tedarik_gun_suresi = Math.trunc(parseLocaleNumber(tedarik_suresi || 0));
        const p_kategori_adi = resolvedKategoriAdi;
        if (!Number.isFinite(parsedBirimFiyat) || !Number.isFinite(p_stok_miktari) || p_stok_miktari <= 0) {
            res.status(400).json({ hata: 'Adet ve birim fiyat geçerli sayısal değerler olmalıdır.' });
            return;
        }
        // Prosedür çağrısı (Loglar ve diğer işlemler için korunuyor)
        try {
            await prisma_1.default.$executeRawUnsafe(`CALL public.sp_parca_ekle($1, $2, $3, $4, $5, $6, $7, $8)`, p_parca_adi, p_tahmini_omur_saati, p_parca_maliyeti, p_stok_miktari, p_min_stok_seviyesi, p_tedarik_gun_suresi, p_kategori_adi, p_tedarikci_firma_adi);
        }
        catch (spError) {
            console.error("SP Çağrı Hatası (Devam ediliyor...):", spError);
        }
        // ─── KRİTİK GÜNCELLEME: Prisma ile Doğrudan Stok Yazma ───
        // Prosedürün yapamadığı veya eksik bıraktığı güncellemeleri burada kesinleştiriyoruz.
        // 1. Kategori ID'sini çöz
        let finalKatId = null;
        if (p_kategori_adi && p_kategori_adi !== 'Genel') {
            const kategori = await prisma_1.default.parca_kategori.upsert({
                where: { kategori_adi: p_kategori_adi },
                update: {},
                create: { kategori_adi: p_kategori_adi }
            });
            finalKatId = kategori.kategori_id;
        }
        // 2. Parçayı bul ve stoku/bilgileri güncelle (yoksa oluştur)
        const parca = await prisma_1.default.parca.upsert({
            where: { parca_adi: p_parca_adi },
            update: {
                stok_miktari: { increment: p_stok_miktari },
                kategori_id: finalKatId || undefined,
                tahmini_omur_saati: p_tahmini_omur_saati > 0 ? p_tahmini_omur_saati : undefined,
                tedarikci_id: Number(tedarikci_id)
            },
            create: {
                parca_adi: p_parca_adi,
                stok_miktari: p_stok_miktari,
                kategori_id: finalKatId,
                tedarikci_id: Number(tedarikci_id),
                min_stok_seviyesi: p_min_stok_seviyesi,
                tahmini_omur_saati: p_tahmini_omur_saati,
                parca_maliyeti: p_parca_maliyeti,
                tedarik_gun_suresi: p_tedarik_gun_suresi
            }
        });
        // 3. Stok hareketini manuel kaydet (Girişin tarihçede görünmesi için)
        await prisma_1.default.parca_stok_hareketleri.create({
            data: {
                parca_id: parca.parca_id,
                eklenen_miktar: p_stok_miktari,
                islem_tarihi: tarih ? new Date(tarih) : new Date()
            }
        });
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
                // Eğer hala kullanıcı bulunamadıysa puanlamayı atla (hata verme)
                console.warn('Tedarikçi puanı için geçerli bir kullanıcı bulunamadı, puanlama atlandı.');
            }
            else {
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
// GET /api/satin-alma
const getAlimGecmisi = async (req, res) => {
    try {
        const alimGecmisi = await prisma_1.default.$queryRaw `
            SELECT * FROM public.vw_parca_alim_gecmisi
            ORDER BY stok_giris_tarihi DESC
        `;
        // Frontend'in beklediği yapıya dönüştür (Resilient Mapping)
        const formatliGecmis = alimGecmisi.map(item => {
            // Tarih dönüşümü: Date objesini ISO string'e çeviriyoruz (split('T') hatasını önlemek için)
            let isoTarih = "-";
            if (item.stok_giris_tarihi) {
                isoTarih = new Date(item.stok_giris_tarihi).toISOString();
            }
            return {
                ...item, // Tüm orijinal alanları koru
                satin_alma_id: item.hareket_id || Math.floor(Math.random() * 1000000),
                tarih: isoTarih,
                stok_giris_tarihi: isoTarih,
                adet: item.girilen_adet || item.adet || 0,
                girilen_adet: item.girilen_adet || item.adet || 0,
                birim_fiyat: item.birim_fiyat || 0,
                makine_turu: {
                    makine_tur_adi: item.kategori_adi || 'Genel'
                },
                tedarikci: {
                    firma_adi: item.tedarikci_adi || item.firma_adi || '-'
                },
                puan: item.tedarikci_puani || item.puan || 0,
                tahmini_omur_saati: item.tahmini_omur_saati || 0
            };
        });
        res.json({
            success: true,
            message: `${alimGecmisi.length} adet alım geçmişi kaydı getirildi.`,
            data: formatliGecmis
        });
    }
    catch (error) {
        console.error("Alım geçmişi çekme hatası:", error);
        res.status(500).json({ hata: "Alım geçmişi çekilirken bir hata oluştu." });
    }
};
exports.getAlimGecmisi = getAlimGecmisi;
// GET /api/satin-alma/stok
const getStokDurumu = async (req, res) => {
    try {
        // Sadece stok_miktari > 0 olanları getir (tükenmiş parçaları hariç tut)
        const parcalar = await prisma_1.default.parca.findMany({
            where: {
                stok_miktari: { gt: 0 }
            },
            orderBy: {
                parca_adi: 'asc'
            }
        });
        // frontend için
        const formatliStoklar = parcalar.map((p) => ({
            stok_id: p.parca_id,
            parca_adi: p.parca_adi,
            miktar: p.stok_miktari || 0,
            min_stok: p.min_stok_seviyesi || 5,
            tahmini_omur_saati: p.tahmini_omur_saati || 0,
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
// DELETE /api/satin-alma/stok/:id
const parcaSil = async (req, res) => {
    try {
        const parcaId = Number(req.params.id);
        if (!Number.isInteger(parcaId) || parcaId <= 0) {
            res.status(400).json({ hata: "Geçersiz parça ID." });
            return;
        }
        const parca = await prisma_1.default.parca.findUnique({
            where: { parca_id: parcaId },
            select: { parca_id: true, parca_adi: true }
        });
        if (!parca) {
            res.status(404).json({ hata: "Silinecek parça bulunamadı." });
            return;
        }
        await prisma_1.default.$transaction(async (tx) => {
            await tx.parca_stok_hareketleri.deleteMany({
                where: { parca_id: parcaId }
            });
            await tx.tedarikci_parca.deleteMany({
                where: { parca_id: parcaId }
            });
            await tx.parca_degisim.updateMany({
                where: { parca_id: parcaId },
                data: { parca_id: null }
            });
            await tx.parca.delete({
                where: { parca_id: parcaId }
            });
        });
        res.json({
            success: true,
            message: `${parca.parca_adi} stoktan silindi.`,
            data: { parca_id: parcaId }
        });
    }
    catch (error) {
        console.error("Parça silme hatası:", error);
        res.status(500).json({ hata: error.message || "Parça silinirken bir hata oluştu." });
    }
};
exports.parcaSil = parcaSil;
const getParcaKategorileri = async (req, res) => {
    try {
        const kategoriler = await prisma_1.default.parca_kategori.findMany({
            orderBy: {
                kategori_adi: 'asc'
            }
        });
        res.json({
            success: true,
            data: kategoriler
        });
    }
    catch (error) {
        console.error("Kategori çekme hatası:", error);
        res.status(500).json({ hata: "Kategoriler çekilirken bir hata oluştu." });
    }
};
exports.getParcaKategorileri = getParcaKategorileri;
