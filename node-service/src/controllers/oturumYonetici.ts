import { Request, Response,NextFunction } from 'express';
import { generateToken } from '../utils/jwt';
import prisma  from '../config/prisma';
import { sifreKarsilastir } from '../utils/hash';

//Login — `POST /api/auth/login`

export async function login(req: Request, res: Response, next: NextFunction): Promise<void>   
 {
    // DB tablosunda kullanici_adi olmadığı için benzersiz sütun olan 'eposta' kullanıyoruz.
    const epostaGirisi = req.body.kullanici_adi || req.body.eposta;
    const sifre = req.body.sifre;

    const kullanici= await prisma.kullanici.findUnique({where:{ eposta: epostaGirisi }});

    if(!kullanici) {
        res.status(401).json({success: false, message: 'Giriş başarısız. Kullanıcı bulunamadı.'});
        return;
    }

    const sifreDogruMu = await sifreKarsilastir(sifre, kullanici.sifre);
    if(!sifreDogruMu) {
        res.status(401).json({success: false, message: 'Giriş başarısız. Şifre hatalı.'});
        return;
    }
  const token = generateToken({
     userId: kullanici.kullanici_id.toString(),
     email: kullanici.eposta ?? "",
     rol: kullanici.rol_id.toString()
  });
  res.status(200).json({success: true, data: {...kullanici}, token});

}
//Ben kimim — `GET /api/auth/me`
export async function benKimim(req: Request, res: Response, next: NextFunction): Promise<void> {
    const kullanici=await prisma.kullanici.findUnique({ where: { kullanici_id:Number(req.user!.userId) } });
    res.status(200).json({success: true, data: kullanici});
    
}