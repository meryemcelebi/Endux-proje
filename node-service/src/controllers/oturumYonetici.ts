import { Request, Response, NextFunction } from 'express';
import { generateToken } from '../utils/jwt';
import prisma from '../config/prisma';
import { sifreKarsilastir } from '../utils/hash';

// Login — `POST /api/auth/login`
export async function login(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const { kullanici_adi, sifre } = req.body;

        if (!kullanici_adi || !sifre) {
            res.status(400).json({
                success: false,
                message: 'Kullanıcı adı ve şifre gereklidir.'
            });
            return;
        }

        // Kullanıcıyı bul ve rol bilgisini include et
        const kullanici = await prisma.kullanici.findUnique({
            where: { kullanici_adi },
            include: { rol: true }
        });

        if (!kullanici) {
            res.status(401).json({
                success: false,
                message: 'Giriş başarısız. Kullanıcı bulunamadı.'
            });
            return;
        }

        const sifreDogruMu = await sifreKarsilastir(sifre, kullanici.sifre);
        if (!sifreDogruMu) {
            res.status(401).json({
                success: false,
                message: 'Giriş başarısız. Şifre hatalı.'
            });
            return;
        }

        // Token'a rol_adi (string) koyuyoruz — middleware'de string karşılaştırma yapılabilsin
        const token = generateToken({
            userId: kullanici.kullanici_id.toString(),
            kullanici_adi: kullanici.kullanici_adi,
            rol: kullanici.rol.rol_adi
        });

        const { sifre: _, rol: __, ...guvenliVeri } = kullanici;
        res.status(200).json({
            success: true,
            message: 'Giriş başarılı.',
            token,
            data: { ...guvenliVeri, rol: kullanici.rol.rol_adi }
        });
    } catch (error) {
        next(error);
    }
}

// Ben Kimim — `GET /api/auth/me`
export async function benKimim(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const kullanici = await prisma.kullanici.findUnique({
            where: { kullanici_id: Number(req.user!.userId) },
            include: { rol: true, firma: true }
        });

        if (!kullanici) {
            res.status(404).json({
                success: false,
                message: 'Kullanıcı bulunamadı.'
            });
            return;
        }

        const { sifre: _, ...guvenliVeri } = kullanici;
        res.status(200).json({ success: true, data: guvenliVeri });
    } catch (error) {
        next(error);
    }
}

//dısarıdan gelen servis firması 
/*POST /api/auth/servis-giris
 * Servis elemanları için PIN + Telefon ile giriş. */

export async function servisGiris(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const { telefon, servis_pin, ad, soyad, unvan, servis_firma_id, qr_uuid } = req.body;
        if (!telefon || !ad || !soyad || !unvan) {
            res.status(400).json({
                success: false,
                message: 'Tüm alanlar zorunludur'
            });
            return;
        }

        const makine = await prisma.makine.findFirst({
            where : { servis_pin: Number(servis_pin) }
        });

        if(!makine || (qr_uuid && makine.makine_qr !== qr_uuid)){
            res.status(401).json({
                success: false,
                message: 'Geçersiz Pin Kodu.'
            });
            return;
        }

        const servisFirma = await prisma.servis_firma.findUnique({
            where : { servis_firma_id : Number(servis_firma_id) }

        });

        if(!servisFirma){
            res.status(401).json({
                success: false,
                message: 'Servis firması bulunamadi.'
            });
            return ;
        }

       let servisSorumlusu = await prisma.servis_sorumlusu.findFirst({
        where : {
            servis_firma_id: Number(servis_firma_id),
            telefon: String(telefon)
        }
    });

    let yeniKayitMi = false;

    if(!servisSorumlusu){
        //kişi sisteme daha önce girmemis - kayıt olusturulur
        servisSorumlusu = await prisma.servis_sorumlusu.create({
            data: {
                    ad: String(ad),
                    soyad: String(soyad),
                    telefon: String(telefon),
                    unvan: unvan ? String(unvan) : null,
                    servis_firma_id: Number(servis_firma_id),
                    aktiflik: true
            }
        });
        yeniKayitMi = true ;
    }
        else {
             // Kişi zaten var — bilgilerini güncelle (ad/soyad/unvan değişmiş olabilir)
             servisSorumlusu = await prisma.servis_sorumlusu.update({
                where : {
                    sorumlu_id: servisSorumlusu.sorumlu_id
                },
                data : {
                      ad: String(ad),
                    soyad: String(soyad),
                    unvan: unvan ? String(unvan) : servisSorumlusu.unvan,
                    aktiflik: true
                }
             });

        }
        //token uret
        const token = generateToken({
           userId: servisSorumlusu.sorumlu_id.toString(),
            kullanici_adi: `servis_${servisSorumlusu.ad.toLowerCase()}_${servisSorumlusu.soyad.toLowerCase()}`,
            rol: 'SERVIS' 
        });
        res.status(200).json({
            succes: true,
            message: yeniKayitMi
             ? 'Yeni servis sorumlusu kaydedildi ve giriş başarılı.'
             : 'Mevcut servis sorumlusu ile giriş başarılı.',
            yeniKayit: yeniKayitMi,
            token,
            data: {
                 sorumlu_id: servisSorumlusu.sorumlu_id,
                ad: servisSorumlusu.ad,
                soyad: servisSorumlusu.soyad,
                unvan: servisSorumlusu.unvan,
                telefon: servisSorumlusu.telefon,
                servis_firma: {
                    servis_firma_id: servisFirma.servis_firma_id,
                    firma_adi: servisFirma.firma_adi
                },
                makine: {
                    makine_id: makine.makine_id,
                    makine_adi: makine.makine_adi
                }
            }
        });
    } catch (error) {
        next(error);
    }
            }
     





    