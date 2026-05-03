"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.login = login;
exports.benKimim = benKimim;
exports.servisGiris = servisGiris;
const jwt_1 = require("../utils/jwt");
const prisma_1 = __importDefault(require("../config/prisma"));
const hash_1 = require("../utils/hash");
// Login — `POST /api/auth/login`
async function login(req, res, next) {
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
        const kullanici = await prisma_1.default.kullanici.findUnique({
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
        const sifreDogruMu = await (0, hash_1.sifreKarsilastir)(sifre, kullanici.sifre);
        if (!sifreDogruMu) {
            res.status(401).json({
                success: false,
                message: 'Giriş başarısız. Şifre hatalı.'
            });
            return;
        }
        // Token'a rol_adi (string) koyuyoruz — middleware'de string karşılaştırma yapılabilsin
        const token = (0, jwt_1.generateToken)({
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
    }
    catch (error) {
        next(error);
    }
}
// Ben Kimim — `GET /api/auth/me`
async function benKimim(req, res, next) {
    try {
        const kullanici = await prisma_1.default.kullanici.findUnique({
            where: { kullanici_id: Number(req.user.userId) },
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
    }
    catch (error) {
        next(error);
    }
}
//dısarıdan gelen servis firması 
/*POST /api/auth/servis-giris
 * Servis elemanları için PIN + Telefon ile giriş. */
async function servisGiris(req, res, next) {
    try {
        const { telefon, servis_pin, ad, soyad, unvan, servis_firma_id, qr_uuid } = req.body;
        if (!telefon || !ad || !soyad || !unvan) {
            res.status(400).json({
                success: false,
                message: 'Tüm alanlar zorunludur'
            });
            return;
        }
        const makine = await prisma_1.default.makine.findFirst({
            where: { servis_pin: Number(servis_pin) }
        });
        if (!makine || (qr_uuid && makine.makine_qr !== qr_uuid)) {
            res.status(401).json({
                success: false,
                message: 'Geçersiz Pin Kodu.'
            });
            return;
        }
        const servisFirma = await prisma_1.default.servis_firma.findUnique({
            where: { servis_firma_id: Number(servis_firma_id) }
        });
        if (!servisFirma) {
            res.status(401).json({
                success: false,
                message: 'Servis firması bulunamadi.'
            });
            return;
        }
        let servisSorumlusu = await prisma_1.default.servis_sorumlusu.findFirst({
            where: {
                servis_firma_id: Number(servis_firma_id),
                telefon: String(telefon)
            }
        });
        let yeniKayitMi = false;
        if (!servisSorumlusu) {
            //kişi sisteme daha önce girmemis - kayıt olusturulur
            servisSorumlusu = await prisma_1.default.servis_sorumlusu.create({
                data: {
                    ad: String(ad),
                    soyad: String(soyad),
                    telefon: String(telefon),
                    unvan: unvan ? String(unvan) : null,
                    servis_firma_id: Number(servis_firma_id),
                    aktiflik: true
                }
            });
            yeniKayitMi = true;
        }
        else {
            // Kişi zaten var — bilgilerini güncelle (ad/soyad/unvan değişmiş olabilir)
            servisSorumlusu = await prisma_1.default.servis_sorumlusu.update({
                where: {
                    sorumlu_id: servisSorumlusu.sorumlu_id
                },
                data: {
                    ad: String(ad),
                    soyad: String(soyad),
                    unvan: unvan ? String(unvan) : servisSorumlusu.unvan,
                    aktiflik: true
                }
            });
        }
        //token uret
        const token = (0, jwt_1.generateToken)({
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
    }
    catch (error) {
        next(error);
    }
}
