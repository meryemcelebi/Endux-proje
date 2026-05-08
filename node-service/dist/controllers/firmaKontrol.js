"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.tumTedarikcileriGetir = tumTedarikcileriGetir;
exports.tedarikciEkle = tedarikciEkle;
exports.tedarikciSil = tedarikciSil;
exports.tumServisFirmalariniGetir = tumServisFirmalariniGetir;
exports.servisFirmasiEkle = servisFirmasiEkle;
exports.servisFirmasiSil = servisFirmasiSil;
const prisma_1 = __importDefault(require("../config/prisma"));
// --- Tedarikçi İşlemleri ---
async function tumTedarikcileriGetir(req, res) {
    try {
        const tedarikciler = await prisma_1.default.tedarikci.findMany({
            where: { aktiflik: true },
            include: {
                iletisim: true,
                tedarikci_puan: {
                    select: { puan: true, yorum: true, tarih: true },
                    orderBy: { tarih: "desc" }
                }
            },
            orderBy: { tedarikci_id: "asc" }
        });
        const dataWithScores = tedarikciler.map(t => {
            const puanlar = t.tedarikci_puan
                .map(tp => Number(tp.puan))
                .filter(puan => Number.isFinite(puan));
            const ortalama = puanlar.length > 0
                ? Number((puanlar.reduce((a, b) => a + b, 0) / puanlar.length).toFixed(1))
                : 0;
            const guvenilirlikSkoru = puanlar.length > 0
                ? Number((ortalama * 10).toFixed(1))
                : Number(t.guvenilirlik_skoru || 0);
            const sonYorum = t.tedarikci_puan.find(tp => tp.yorum)?.yorum || null;
            return {
                ...t,
                guvenilirlik_skoru: guvenilirlikSkoru,
                ortalama_puan: ortalama,
                toplam_degerlendirme: puanlar.length,
                yorum: sonYorum
            };
        });
        res.status(200).json({
            success: true,
            message: `${tedarikciler.length} adet tedarikçi getirildi.`,
            data: dataWithScores
        });
    }
    catch (error) {
        console.error("Tedarikçileri getirme hatası:", error);
        res.status(500).json({ success: false, message: 'Tedarikçiler getirilirken bir hata oluştu.' });
    }
}
async function tedarikciEkle(req, res) {
    try {
        const { firma_adi, telefon, email, adres, il, ilce, aktiflik, yetkili_kisi, vergi_no } = req.body;
        if (!firma_adi || aktiflik === undefined) {
            return res.status(400).json({ success: false, message: "Firma adı ve aktiflik alanları zorunludur." });
        }
        // iletişim bilgileri ayrı tabloda — önce iletisim kaydı oluştur
        let iletisim_id;
        if (telefon || email || adres || il || ilce) {
            const yeniIletisim = await prisma_1.default.iletisim.create({
                data: {
                    telefon: telefon ? String(telefon) : null,
                    mail: email ? String(email) : null,
                    acik_adres: adres ? String(adres) : null,
                    il: il ? String(il) : null,
                    ilce: ilce ? String(ilce) : null,
                }
            });
            iletisim_id = yeniIletisim.iletisim_id;
        }
        const yeniTedarikci = await prisma_1.default.tedarikci.create({
            data: {
                firma_adi,
                aktiflik: Boolean(aktiflik),
                yetkili_kisi: yetkili_kisi ? String(yetkili_kisi) : null,
                vergi_no: vergi_no ? String(vergi_no) : null,
                iletisim_id,
                kayit_tarihi: new Date(),
            }
        });
        res.status(201).json({ success: true, message: 'Tedarikçi başarıyla eklendi.', data: yeniTedarikci });
    }
    catch (error) {
        console.error("Tedarikçi ekleme hatası:", error);
        res.status(500).json({ success: false, message: 'Tedarikçi eklenirken bir hata oluştu.' });
    }
}
async function tedarikciSil(req, res) {
    try {
        const id = Number(req.params.id);
        if (isNaN(id))
            return res.status(400).json({ success: false, message: "Geçerli bir ID gereklidir." });
        // Hard delete yerine Soft Delete (aktiflik = false) yapıyoruz
        // Bu sayede geçmiş satın alma ve puanlama verileri korunur
        await prisma_1.default.tedarikci.update({
            where: { tedarikci_id: id },
            data: { aktiflik: false }
        });
        res.status(200).json({ success: true, message: "Tedarikçi pasif duruma getirildi." });
    }
    catch (error) {
        console.error("Tedarikçi silme hatası:", error);
        res.status(500).json({ success: false, message: "Tedarikçi silinirken bir hata oluştu." });
    }
}
// --- Servis Firmaları İşlemleri ---
async function tumServisFirmalariniGetir(req, res) {
    try {
        const servisFirmalari = await prisma_1.default.servis_firma.findMany({
            where: { aktiflik: true },
            include: {
                servis_sorumlusu: true,
                iletisim: true,
                servis_firma_uzmanlik: true,
                servis_puan: { select: { puan: true } }
            },
            orderBy: { servis_firma_id: "asc" }
        });
        const dataWithAvg = servisFirmalari.map(f => {
            const puanlar = f.servis_puan.map(sp => Number(sp.puan));
            const ortalama = puanlar.length > 0 ? Number((puanlar.reduce((a, b) => a + b, 0) / puanlar.length).toFixed(1)) : 0;
            return {
                ...f,
                ortalama_puan: ortalama,
                toplam_islem: puanlar.length,
                servis_puan: undefined
            };
        });
        res.status(200).json({
            success: true,
            message: `${servisFirmalari.length} adet servis firması getirildi.`,
            data: dataWithAvg
        });
    }
    catch (error) {
        console.error("Servis firmalarını getirme hatası:", error);
        res.status(500).json({ success: false, message: 'Servis firmaları getirilirken bir hata oluştu.' });
    }
}
async function servisFirmasiEkle(req, res) {
    try {
        const { firma_adi, telefon, email, adres, il, ilce, uzmanlik_alani, sorumlu_ad, sorumlu_telefon, sorumlu_unvan } = req.body;
        if (!firma_adi)
            return res.status(400).json({ success: false, message: "Firma adı zorunludur." });
        // iletişim bilgileri ayrı tabloda
        let iletisim_id;
        if (telefon || email || adres || il || ilce) {
            const yeniIletisim = await prisma_1.default.iletisim.create({
                data: {
                    telefon: telefon ? String(telefon) : null,
                    mail: email ? String(email) : null,
                    acik_adres: adres ? String(adres) : null,
                    il: il ? String(il) : null,
                    ilce: ilce ? String(ilce) : null,
                }
            });
            iletisim_id = yeniIletisim.iletisim_id;
        }
        const yeniServisFirmasi = await prisma_1.default.servis_firma.create({
            data: { firma_adi: String(firma_adi), aktiflik: true, iletisim_id }
        });
        // uzmanlık alanı ayrı tabloda (servis_firma_uzmanlik)
        if (uzmanlik_alani) {
            await prisma_1.default.servis_firma_uzmanlik.create({
                data: { servis_firma_id: yeniServisFirmasi.servis_firma_id, uzmanlik_adi: String(uzmanlik_alani) }
            });
        }
        if (sorumlu_ad) {
            const [ad, ...soyadParts] = String(sorumlu_ad).trim().split(/\s+/);
            await prisma_1.default.servis_sorumlusu.create({
                data: {
                    servis_firma_id: yeniServisFirmasi.servis_firma_id,
                    ad: ad || String(sorumlu_ad).trim(),
                    soyad: soyadParts.join(" ") || "-",
                    telefon: sorumlu_telefon ? String(sorumlu_telefon) : String(telefon || "Belirtilmedi"),
                    aktiflik: true,
                    unvan: sorumlu_unvan ? String(sorumlu_unvan) : null,
                    sorumlu_adi: String(sorumlu_ad).trim()
                }
            });
        }
        const servisFirmasi = await prisma_1.default.servis_firma.findUnique({
            where: { servis_firma_id: yeniServisFirmasi.servis_firma_id },
            include: {
                servis_sorumlusu: true,
                iletisim: true,
                servis_firma_uzmanlik: true
            }
        });
        res.status(201).json({ success: true, message: 'Servis firması başarıyla eklendi.', data: servisFirmasi });
    }
    catch (error) {
        console.error("Servis firması ekleme hatası:", error);
        res.status(500).json({ success: false, message: 'Servis firması eklenirken bir hata oluştu.' });
    }
}
async function servisFirmasiSil(req, res) {
    try {
        const id = Number(req.params.id);
        if (isNaN(id))
            return res.status(400).json({ success: false, message: "Geçerli bir ID gereklidir." });
        // Bu sayede geçmiş bakım kayıtları ve teknisyen bilgileri korunur
        await prisma_1.default.servis_firma.update({
            where: { servis_firma_id: id },
            data: { aktiflik: false }
        });
        res.status(200).json({ success: true, message: "Servis firması pasif duruma getirildi." });
    }
    catch (error) {
        console.error("Servis firması iptal hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Servis firması iptal edilirken bir hata oluştu.'
        });
    }
}
