"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.oturumKontrol = oturumKontrol;
exports.rolKontrol = rolKontrol;
const jwt_1 = require("../utils/jwt");
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
//JWT tokenini doğrulayan ve geçerliyse req.user'a kullanıcı bilgilerini ekleyen middleware
function oturumKontrol(req, res, next) {
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
        const cozulenToken = (0, jwt_1.verifyToken)(token);
        req.user = cozulenToken;
        next();
    }
    catch (error) {
        // Token expired mi yoksa geçersiz mi ayır
        if (error instanceof jsonwebtoken_1.default.TokenExpiredError) {
            res.status(401).json({
                success: false,
                code: 'TOKEN_EXPIRED',
                message: 'Oturum süreniz doldu. Lütfen tekrar giriş yapın.'
            });
        }
        else {
            res.status(401).json({
                success: false,
                code: 'TOKEN_INVALID',
                message: 'Geçersiz token. Lütfen tekrar giriş yapın.'
            });
        }
    }
}
// Rol bazlı yetkilendirme — Geçerli roller: "YONETICI", "OPERATOR", "TEKNISYEN" , SERVIS
function rolKontrol(...roles) {
    return (req, res, next) => {
        if (!req.user || !roles.includes(req.user.rol)) {
            res.status(403).json({ success: false, message: 'Erisim reddedildi. Kullanıcı doğrulanamadı.' });
            return;
        }
        next();
    };
}
