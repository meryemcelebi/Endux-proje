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