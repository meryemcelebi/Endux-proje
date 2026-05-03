"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.personelEkle = personelEkle;
exports.tumKullanicilariGetir = tumKullanicilariGetir;
exports.personelSil = personelSil;
const prisma_1 = __importDefault(require("../config/prisma"));
const client_1 = require("@prisma/client");
const turkceKarakter_1 = require("../utils/turkceKarakter");
const hash_1 = require("../utils/hash");
async function personelEkle(req, res, next) {
    try {
        const { ad, soyad, rol, sifre, telefon, eposta, firma_id, baslama_tarihi } = req.body;
        // Zorunlu alan kontrolü (firma_id opsiyonel, varsayılan 1)
        if (!ad || !soyad || !rol || !sifre || telefon === undefined) {
            res.status(400).json({
                success: false,
                message: "Ad, soyad, rol, şifre ve telefon alanları zorunludur."
            });
            return;
        }
        // Geçerli rol kontrolü
        const gecerliRoller = ["OPERATOR", "TEKNISYEN", "YONETICI", "SERVIS"];
        if (!gecerliRoller.includes(rol)) {
            res.status(400).json({
                success: false,
                message: `Geçersiz rol. Geçerli roller: ${gecerliRoller.join(", ")}`
            });
            return;
        }
        // Rol tablosundan rol_id'yi bul
        const rolKaydi = await prisma_1.default.rol.findFirst({
            where: { rol_adi: rol }
        });
        if (!rolKaydi) {
            res.status(400).json({
                success: false,
                message: `"${rol}" rolü veritabanında bulunamadı.`
            });
            return;
        }
        // Kullanıcı adı oluştur (Türkçe karakter temizle + rol ön eki)
        const temizAd = (0, turkceKarakter_1.turkceKarakterTemizle)(ad);
        const temizSoyad = (0, turkceKarakter_1.turkceKarakterTemizle)(soyad);
        const on_eki = (0, turkceKarakter_1.rol_on_eki_getir)(rol);
        const kullanici_adi = `${on_eki}${temizAd}${temizSoyad}`;
        // Tekrar eden kullanıcı adı kontrolü
        const mevcutKullanici = await prisma_1.default.kullanici.findUnique({
            where: { kullanici_adi: kullanici_adi }
        });
        if (mevcutKullanici) {
            res.status(400).json({
                success: false,
                message: "Oluşturulan kullanıcı adı zaten mevcut. Lütfen farklı bir ad veya soyad deneyin."
            });
            return;
        }
        // Şifreyi hashle
        const hashlenmisSifre = await (0, hash_1.hashSifre)(sifre);
        // Kullanıcıyı veritabanına kaydet (şemaya uyumlu)
        const yeniKullanici = await prisma_1.default.kullanici.create({
            data: {
                kullanici_adi: kullanici_adi,
                sifre: hashlenmisSifre,
                rol_id: rolKaydi.rol_id,
                firma_id: Number(firma_id) || 1,
                ad: ad,
                soyad: soyad,
                telefon: telefon,
                eposta: eposta || null,
                baslama_tarihi: baslama_tarihi ? new Date(baslama_tarihi) : null,
                aktiflik: true
            }
        });
        // Şifreyi response'dan çıkar
        const { sifre: _, ...guvenliVeri } = yeniKullanici;
        res.status(201).json({
            success: true,
            message: "Personel başarıyla eklendi.",
            kullanici: guvenliVeri
        });
    }
    catch (error) {
        console.error("Personel ekleme hatası:", error);
        if (error instanceof client_1.Prisma.PrismaClientKnownRequestError) {
            if (error.code === "P2002") {
                res.status(400).json({
                    success: false,
                    message: "Bu e-posta veya kullanıcı adı zaten kayıtlı."
                });
                return;
            }
            if (error.code === "P2003") {
                res.status(400).json({
                    success: false,
                    message: "Seçilen firma veya rol bilgisi geçersiz."
                });
                return;
            }
        }
        res.status(500).json({
            success: false,
            message: "Personel eklenirken bir hata oluştu."
        });
    }
}
async function tumKullanicilariGetir(req, res) {
    try {
        const kullanicilar = await prisma_1.default.kullanici.findMany({
            where: {
                OR: [
                    { aktiflik: true },
                    { aktiflik: null }
                ]
            },
            select: {
                kullanici_id: true,
                kullanici_adi: true,
                firma_id: true,
                rol_id: true,
                ad: true,
                soyad: true,
                telefon: true,
                eposta: true,
                aktiflik: true,
                baslama_tarihi: true,
                //sifre:false, //select kullanıldığında eklenmediği sürece gelmez
                firma: {
                    select: {
                        firma_id: true,
                        firma_adi: true
                    }
                },
                rol: {
                    select: {
                        rol_id: true,
                        rol_adi: true
                    }
                }
            }
        });
        res.status(200).json({
            success: true,
            message: "Kullanıcılar başarıyla getirildi.",
            kullanicilar: kullanicilar
        });
    }
    catch (error) {
        console.error("Kullanıcıları getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Kullanıcılar getirilirken bir hata oluştu."
        });
    }
}
async function personelSil(req, res, next) {
    try {
        const { id } = req.params;
        if (!id) {
            res.status(400).json({
                success: false,
                message: "Kullanıcı ID gereklidir."
            });
            return;
        }
        // Kullanıcıyı bul
        const kullanici = await prisma_1.default.kullanici.findUnique({
            where: { kullanici_id: Number(id) }
        });
        if (!kullanici) {
            res.status(404).json({
                success: false,
                message: "Kullanıcı bulunamadı."
            });
            return;
        }
        // Önce silmeyi dene (eğer ilişkili kayıt yoksa)
        // Eğer hata alırsa aktifliğini false yap (soft delete)
        try {
            await prisma_1.default.kullanici.delete({
                where: { kullanici_id: Number(id) }
            });
            res.status(200).json({
                success: true,
                message: "Personel başarıyla silindi."
            });
        }
        catch (error) {
            // İlişkili kayıtlar varsa silinemez, bu durumda pasife çekiyoruz
            await prisma_1.default.kullanici.update({
                where: { kullanici_id: Number(id) },
                data: { aktiflik: false }
            });
            res.status(200).json({
                success: true,
                message: "Personel ilişkili kayıtları olduğu için silinemedi ancak erişimi kesildi (pasif yapıldı)."
            });
        }
    }
    catch (error) {
        console.error("Personel silme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Personel silinirken bir hata oluştu."
        });
    }
}
