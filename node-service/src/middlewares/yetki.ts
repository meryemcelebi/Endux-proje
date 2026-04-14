import {Request,Response, NextFunction} from 'express';
import { verifyToken, TokenPayload } from '../utils/jwt';
import jwt from 'jsonwebtoken'

declare global {
    namespace Express {
        interface Request {
            user?: TokenPayload;
        }
    }
}

//JWT tokenini doğrulayan ve geçerliyse req.user'a kullanıcı bilgilerini ekleyen middleware
export function oturumKontrol(req:Request, res:Response, next: NextFunction){
    const yetkiHeader = req.headers.authorization;
    if (!yetkiHeader || !yetkiHeader.startsWith('Bearer ')) {
        res.status(401).json({
            success: false,
            code: 'TOKEN_MISSING',
            message: 'Token bulunamadı. Lütfen tekrar giriş yapın.'
        });
        return;
    }

    const token = yetkiHeader.split(' ')[1];
try {
    const cozulenToken= verifyToken(token) as TokenPayload;
    req.user = cozulenToken;
    next();
}
catch (error) {   
     // Token expired mi yoksa geçersiz mi ayır
        if (error instanceof jwt.TokenExpiredError) {
            res.status(401).json({
                success: false,
                code: 'TOKEN_EXPIRED',
                message: 'Oturum süreniz doldu. Lütfen tekrar giriş yapın.'
            });
        } else {
            res.status(401).json({
                success: false,
                code: 'TOKEN_INVALID',
                message: 'Geçersiz token. Lütfen tekrar giriş yapın.'
            });
}
}}

// Rol bazlı yetkilendirme — Geçerli roller: "YONETICI", "OPERATOR", "TEKNISYEN" , SERVIS
export function rolKontrol(...roles: string[]) {
    return (req: Request, res: Response, next: NextFunction) => {
        if (!req.user || !roles.includes(req.user.rol)) {
            res.status(403).json({ success: false, message: 'Erisim reddedildi. Kullanıcı doğrulanamadı.' });
            return;
        }
        next();}
    }
