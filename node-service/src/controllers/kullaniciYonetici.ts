import { Request, Response ,NextFunction } from "express";
import prisma from "../config/prisma";
import { hashSifre } from "../utils/hash";

//Kullanıcı Oluştur (Admin) — `POST /api/kullanicilar`

export async function kullaniciOlustur(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const {kullanici_adi, ad, soyad, email, sifre, rol} = req.body;
        
        // Kullanıcı var mı kontrol et
        const mevcutKullanici = await prisma.kullanici.findUnique({ where: { kullanici_adi } });
        if (mevcutKullanici) {
            res.status(400).json({ success: false, message: 'Bu kullanıcı adı zaten kullanılıyor.' });
            return;
        }

        // Şifreyi hashle
        const hashlenmisSifre = await hashSifre(sifre);
        
        // Kullanıcıyı veritabanına kaydet
        const yeniKullanici = await prisma.kullanici.create({
            data: {
                kullanici_adi,
                ad: ad || "Belirtilmedi",
                soyad: soyad || "Belirtilmedi",
                email,
                sifre: hashlenmisSifre,
                rol: rol || "operator"
            }
        });

        res.status(201).json({success: true, message: 'Kullanıcı başarıyla oluşturuldu.', data: yeniKullanici});
    } catch (error) {
        res.status(500).json({success: false, message: 'Kullanıcı oluşturulurken bir hata oluştu.', error});
    }
}
