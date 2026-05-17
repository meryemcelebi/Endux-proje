"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.servisPuanVer = servisPuanVer;
exports.tedarikciPuanVer = tedarikciPuanVer;
const prisma_1 = __importDefault(require("../config/prisma"));
// 1 - 5 arasında servise puan verilir, 5 en yüksek puandır
async function servisPuanVer(req, res) {
    try {
        const { servis_firma_id, puan, yorum, bakim_id } = req.body;
        const puanlayanID = Number(req.user?.userId);
        if (!servis_firma_id || puan === undefined || puan === null) {
            res.status(400).json({
                success: false,
                message: "Servis firma ID'si ve puan alanları zorunludur."
            });
            return;
        }
        const puanDegeri = Number(puan);
        // puan yerine puanDegeri üzerinden kontrol ediyoruz
        if (Number.isNaN(puanDegeri) || !Number.isInteger(puanDegeri) || puanDegeri < 1 || puanDegeri > 5) {
            res.status(400).json({
                success: false,
                message: "Puan 1 ile 5 arasında olmalıdır ve tam sayı olmalıdır."
            });
            return;
        }
        //servis firma var mı 
        const servisFirma = await prisma_1.default.servis_firma.findUnique({
            where: { servis_firma_id: Number(servis_firma_id) }
        });
        if (!servisFirma) {
            res.status(404).json({
                success: false,
                message: "Belirtilen ID'ye sahip servis firması bulunamadı."
            });
            return;
        }
        const sonuc = await prisma_1.default.$transaction(async (tx) => {
            //puan kaydı oluştur
            const yeniPuan = await tx.servis_puan.create({
                data: {
                    servis_firma_id: Number(servis_firma_id),
                    puan: puanDegeri,
                    yorum: yorum ? String(yorum) : null,
                    puanlayan_kullanici_id: puanlayanID,
                    bakim_id: bakim_id ? Number(bakim_id) : null, // BUG FIX: bakim_id kaydediliyor
                    tarih: new Date()
                }
            });
            return yeniPuan;
        });
        res.status(201).json({
            success: true,
            message: 'Puan başarıyla verildi.',
            data: sonuc
        });
    }
    catch (error) {
        console.error("Puan verme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Puan verirken bir hata oluştu.'
        });
    }
}
async function tedarikciPuanVer(req, res) {
    try {
        const { tedarikci_id, puan, yorum } = req.body;
        const puanlayanID = Number(req.user?.userId);
        if (!tedarikci_id || puan === undefined || puan === null) {
            res.status(400).json({
                success: false,
                message: "Tedarikçi ID'si ve puan alanları zorunludur."
            });
            return;
        }
        const puanDegeri = Number(puan);
        // puan yerine puanDegeri üzerinden kontrol ediyoruz
        if (Number.isNaN(puanDegeri) || !Number.isInteger(puanDegeri) || puanDegeri < 1 || puanDegeri > 5) {
            res.status(400).json({
                success: false,
                message: "Puan 1 ile 5 arasında olmalıdır ve tam sayı olmalıdır."
            });
            return;
        }
        //tedarikçi var mı
        const tedarikci = await prisma_1.default.tedarikci.findUnique({
            where: { tedarikci_id: Number(tedarikci_id) }
        });
        if (!tedarikci) {
            res.status(404).json({
                success: false,
                message: "Belirtilen ID'ye sahip tedarikçi bulunamadı."
            });
            return;
        }
        const sonuc = await prisma_1.default.$transaction(async (tx) => {
            //puan kaydı oluştur
            const yeniPuan = await tx.tedarikci_puan.create({
                data: {
                    tedarikci_id: Number(tedarikci_id),
                    puan: puanDegeri,
                    yorum: yorum ? String(yorum) : null,
                    puanlayan_kullanici_id: puanlayanID,
                    tarih: new Date()
                }
            });
            //  guvenilirlik_skoru alanını güncel ortalamaya göre güncelle
            const tumPuanlar = await tx.tedarikci_puan.findMany({
                where: { tedarikci_id: Number(tedarikci_id) },
                select: { puan: true }
            });
            const gecerliPuanlar = tumPuanlar
                .map(tp => Number(tp.puan))
                .filter(p => Number.isFinite(p) && p > 0);
            if (gecerliPuanlar.length > 0) {
                const ortalama = gecerliPuanlar.reduce((a, b) => a + b, 0) / gecerliPuanlar.length;
                // guvenilirlik_skoru = ortalama * 10 (1-5 puan → 10-50 skor)
                await tx.tedarikci.update({
                    where: { tedarikci_id: Number(tedarikci_id) },
                    data: { guvenilirlik_skoru: Number((ortalama * 10).toFixed(1)) }
                });
            }
            return yeniPuan;
        });
        res.status(201).json({
            success: true,
            message: 'Puan başarıyla verildi.',
            data: sonuc
        });
    }
    catch (error) {
        console.error("Puan verme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Puan verirken bir hata oluştu.'
        });
    }
}
;
