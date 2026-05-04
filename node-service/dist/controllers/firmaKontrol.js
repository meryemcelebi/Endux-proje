"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.tumTedarikcileriGetir = tumTedarikcileriGetir;
exports.tedarikciEkle = tedarikciEkle;
exports.tumServisFirmalariniGetir = tumServisFirmalariniGetir;
exports.servisFirmasiEkle = servisFirmasiEkle;
exports.tedarikciSil = tedarikciSil;
exports.servisFirmasiSil = servisFirmasiSil;
const prisma_1 = __importDefault(require("../config/prisma"));
async function tumTedarikcileriGetir(req, res) {
    try {
        const tedarikciler = await prisma_1.default.tedarikci.findMany({
            include: {
                iletisim: true,
                tedarikci_puan: {
                    select: {
                        puan: true,
                        yorum: true,
                        tarih: true
                    },
                    orderBy: {
                        tarih: "desc"
                    }
                }
            },
            orderBy: {
                tedarikci_id: "asc"
            }
        });
        res.status(200).json({
            success: true,
            message: `${tedarikciler.length} adet tedarikçi getirildi.`,
            data: tedarikciler
        });
    }
    catch (error) {
        console.error("Tedarikçileri getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Tedarikçiler getirilirken bir hata oluştu.'
        });
    }
}
async function tedarikciEkle(req, res) {
    try {
        const { firma_adi, telefon, email, adres, il, ilce, aktiflik, yetkili_kisi, vergi_no } = req.body;
        if (!firma_adi || aktiflik === undefined) {
            return res.status(400).json({
                success: false,
                message: "Firma adı ve aktiflik alanları zorunludur."
            });
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
                firma_adi: firma_adi,
                aktiflik: Boolean(aktiflik),
                yetkili_kisi: yetkili_kisi ? String(yetkili_kisi) : null,
                vergi_no: vergi_no ? String(vergi_no) : null,
                iletisim_id: iletisim_id,
                kayit_tarihi: new Date(),
            }
        });
        res.status(201).json({
            success: true,
            message: 'Tedarikçi başarıyla eklendi.',
            data: yeniTedarikci
        });
    }
    catch (error) {
        console.error("Tedarikçi ekleme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Tedarikçi eklenirken bir hata oluştu.'
        });
    }
}
//servis firmaları işlemleri
async function tumServisFirmalariniGetir(req, res) {
    try {
        const servisFirmalari = await prisma_1.default.servis_firma.findMany({
            include: {
                servis_sorumlusu: {
                    select: {
                        sorumlu_id: true,
                        ad: true,
                        soyad: true,
                        telefon: true,
                        unvan: true,
                        aktiflik: true,
                    }
                },
                iletisim: true,
                servis_firma_uzmanlik: true,
                servis_puan: {
                    select: {
                        puan: true
                    }
                }
            },
            orderBy: {
                servis_firma_id: "asc"
            }
        });
        const dataWithAvg = servisFirmalari.map(f => {
            const puanlar = f.servis_puan.map(sp => Number(sp.puan));
            const ortalama = puanlar.length > 0
                ? Number((puanlar.reduce((a, b) => a + b, 0) / puanlar.length).toFixed(1))
                : 0;
            return {
                ...f,
                ortalama_puan: ortalama,
                toplam_islem: puanlar.length,
                servis_puan: undefined // Veriyi şişirmemek için
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
        res.status(500).json({
            success: false,
            message: 'Servis firmaları getirilirken bir hata oluştu.'
        });
    }
}
async function servisFirmasiEkle(req, res) {
    try {
        const { firma_adi, telefon, email, adres, il, ilce, uzmanlik_alani } = req.body;
        if (!firma_adi) {
            res.status(400).json({
                success: false,
                message: "Firma adı zorunludur."
            });
            return;
        }
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
            data: {
                firma_adi: String(firma_adi),
                aktiflik: true,
                iletisim_id: iletisim_id,
            }
        });
        // uzmanlık alanı ayrı tabloda (servis_firma_uzmanlik)
        if (uzmanlik_alani) {
            await prisma_1.default.servis_firma_uzmanlik.create({
                data: {
                    servis_firma_id: yeniServisFirmasi.servis_firma_id,
                    uzmanlik_adi: String(uzmanlik_alani),
                }
            });
        }
        res.status(201).json({
            success: true,
            message: 'Servis firması başarıyla eklendi.',
            data: yeniServisFirmasi
        });
    }
    catch (error) {
        console.error("Servis firması ekleme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Servis firması eklenirken bir hata oluştu.'
        });
    }
}
async function tedarikciSil(req, res) {
    try {
        const id = Number(req.params.id);
        // Hard delete yerine Soft Delete (aktiflik = false) yapıyoruz
        // Bu sayede geçmiş satın alma ve puanlama verileri korunur
        await prisma_1.default.tedarikci.update({
            where: { tedarikci_id: id },
            data: { aktiflik: false }
        });
        res.status(200).json({
            success: true,
            message: 'Tedarikçi sözleşmesi iptal edildi (Pasif duruma getirildi).'
        });
    }
    catch (error) {
        console.error("Tedarikçi iptal hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Tedarikçi iptal edilirken bir hata oluştu.'
        });
    }
}
async function servisFirmasiSil(req, res) {
    try {
        const id = Number(req.params.id);
        // Bu sayede geçmiş bakım kayıtları ve teknisyen bilgileri korunur
        await prisma_1.default.servis_firma.update({
            where: { servis_firma_id: id },
            data: { aktiflik: false }
        });
        res.status(200).json({
            success: true,
            message: 'Servis firması sözleşmesi iptal edildi (Pasif duruma getirildi).'
        });
    }
    catch (error) {
        console.error("Servis firması iptal hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Servis firması iptal edilirken bir hata oluştu.'
        });
    }
}
