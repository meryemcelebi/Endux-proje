import { Request, Response ,NextFunction } from "express";
import prisma from "../config/prisma";
import { hashSifre } from "../utils/hash";

//Kullanıcı Oluştur (Admin) — `POST /api/kullanicilar`

export async function kullaniciOlustur(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const {kullanici_adi, ad, soyad, email, sifre, rol} = req.body;
        const epostaKayit = email || kullanici_adi;
        
        // Kullanıcı var mı kontrol et (artık eposta üzerinden kontrol ediliyor)
        const mevcutKullanici = await prisma.kullanici.findUnique({ where: { eposta: epostaKayit } });
        if (mevcutKullanici) {
            res.status(400).json({ success: false, message: 'Bu kullanıcı adı zaten kullanılıyor.' });
            return;
        }

        // Şifreyi hashle
        const hashlenmisSifre = await hashSifre(sifre);
        
        // Kullanıcıyı veritabanına kaydet (Yeni DB şemasına göre zorunlu alanlar eklendi)
        const yeniKullanici = await prisma.kullanici.create({
            data: {
                ad: ad || "Belirsiz",
                soyad: soyad || "Belirsiz",
                eposta: epostaKayit,
                sifre: hashlenmisSifre,
                telefon: "0000000000",
                firma_id: 1, // DB gerekliliği
                rol_id: 1,   // DB gerekliliği
                aktiflik: true
            }
        });

        res.status(201).json({success: true, message: 'Kullanıcı başarıyla oluşturuldu.', data: yeniKullanici});
    } catch (error) {
        res.status(500).json({success: false, message: 'Kullanıcı oluşturulurken bir hata oluştu.', error});
    }
}
