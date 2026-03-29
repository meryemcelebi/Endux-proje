import { Request, Response, NextFunction } from "express";
import prisma from "../config/prisma";
import { turkceKarakterTemizle, rol_on_eki_getir } from "../utils/turkceKarakter";
import { hashSifre } from "../utils/hash";

export async function personelEkle(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const { ad, soyad, rol, sifre, telefon, eposta, firma_id } = req.body;

        // Zorunlu alan kontrolü
        if (!ad || !soyad || !rol || !sifre || telefon === undefined || !firma_id) {
            res.status(400).json({
                success: false,
                message: "Ad, soyad, rol, şifre, telefon ve firma_id alanları zorunludur."
            });
            return;
        }

        // Geçerli rol kontrolü
        const gecerliRoller = ["OPERATOR", "TEKNISYEN", "YONETICI"];
        if (!gecerliRoller.includes(rol)) {
            res.status(400).json({
                success: false,
                message: `Geçersiz rol. Geçerli roller: ${gecerliRoller.join(", ")}`
            });
            return;
        }

        // Rol tablosundan rol_id'yi bul
        const rolKaydi = await prisma.rol.findFirst({
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
        const temizAd = turkceKarakterTemizle(ad);
        const temizSoyad = turkceKarakterTemizle(soyad);
        const on_eki = rol_on_eki_getir(rol);
        const kullanici_adi = `${on_eki}${temizAd}${temizSoyad}`;

        // Tekrar eden kullanıcı adı kontrolü
        const mevcutKullanici = await prisma.kullanici.findUnique({
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
        const hashlenmisSifre = await hashSifre(sifre);

        // Kullanıcıyı veritabanına kaydet (şemaya uyumlu)
        const yeniKullanici = await prisma.kullanici.create({
            data: {
                kullanici_adi: kullanici_adi,
                sifre: hashlenmisSifre,
                rol_id: rolKaydi.rol_id,
                firma_id: Number(firma_id),
                ad: ad,
                soyad: soyad,
                telefon: telefon,
                eposta: eposta || null,
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
    } catch (error) {
        console.error("Personel ekleme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Personel eklenirken bir hata oluştu."
        });
    }
}