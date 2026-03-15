import { Request, Response ,NextFunction } from "express";

//Kullanıcı Oluştur (Admin) — `POST /api/kullanicilar

export async function kullaniciOlustur(req: Request, res: Response, next: NextFunction): Promise<void> {
    const {kullanici_adi, email, sifre, rol} = req.body;
    //Kullanıcı oluşturma işlemi burada yapılacak
    //Örneğin, veritabanına kaydetme işlemi
    //Bu örnekte sadece başarılı bir yanıt döndürüyoruz
    res.status(201).json({success: true, message: 'Kullanıcı başarıyla oluşturuldu.'});
}

