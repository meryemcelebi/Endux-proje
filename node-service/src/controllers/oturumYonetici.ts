import { Request, Response,NextFunction } from 'express';
import { generateToken } from '../utils/jwt';
import prisma  from '../config/prisma';
import { sifreKarsilastir } from '../utils/hash';

//Login — `POST /api/auth/login`

export async function login(req: Request, res: Response, next: NextFunction): Promise<void>   
 {
    const {kullanici_adi, sifre} = req.body;

    const kullanici= await prisma.kullanici.findUnique({where:{kullanici_adi}});

    if(!kullanici) {
        res.status(401).json({success: false, message: 'Giriş başarısız. Kullanıcı bulunamadı.'});
        return;
    }

    const sifreDogruMu = await sifreKarsilastir(sifre, kullanici.sifre);
    if(!sifreDogruMu) {
        res.status(401).json({success: false, message: 'Giriş başarısız. Şifre hatalı.'});
        return;
    }
  const token = generateToken({userId: kullanici.id.toString(),
     email: kullanici.email ?? "",
      rol: kullanici.rol});
  res.status(200).json({success: true, data: {...kullanici}, token});

}
//Ben kimim — `GET /api/auth/me`
export async function benKimim(req: Request, res: Response, next: NextFunction): Promise<void> {
    const kullanici=await prisma.kullanici.findUnique({ where: { id:Number(req.user!.userId) } });
    res.status(200).json({success: true, data: kullanici});
    
}