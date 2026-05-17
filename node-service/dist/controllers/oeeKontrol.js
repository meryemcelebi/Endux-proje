"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getMakineOee = getMakineOee;
exports.oeeGetir = oeeGetir;
exports.topluOeeGetir = topluOeeGetir;
const oeeService_1 = require("../services/oeeService");
function tarihAraligiOku(req) {
    const baslangic = req.query.baslangic;
    const bitis = req.query.bitis;
    if (!baslangic || !bitis) {
        throw new Error('baslangic ve bitis tarih parametreleri zorunludur. Örnek: ?baslangic=2026-01-01&bitis=2026-01-31');
    }
    const baslangicTarihi = new Date(baslangic);
    const bitisTarihi = new Date(bitis);
    if (isNaN(baslangicTarihi.getTime()) || isNaN(bitisTarihi.getTime())) {
        throw new Error('Geçersiz tarih formatı. YYYY-MM-DD formatında giriniz.');
    }
    if (baslangicTarihi > bitisTarihi) {
        throw new Error('Başlangıç tarihi, bitiş tarihinden sonra olamaz.');
    }
    return { baslangic, bitis, baslangicTarihi, bitisTarihi };
}
async function getMakineOee(makineId, baslangicTarihi, bitisTarihi) {
    return (0, oeeService_1.makineOeeHesapla)(makineId, baslangicTarihi, bitisTarihi);
}
async function oeeGetir(req, res) {
    try {
        const makineId = parseInt(req.params.id);
        if (isNaN(makineId)) {
            return res.status(400).json({ success: false, message: 'Geçerli bir makine ID giriniz.' });
        }
        const { baslangicTarihi, bitisTarihi } = tarihAraligiOku(req);
        const sonuc = await (0, oeeService_1.makineOeeHesapla)(makineId, baslangicTarihi, bitisTarihi);
        return res.status(200).json({
            success: true,
            message: `${sonuc.makine_adi} makinesi için OEE hesaplandı.`,
            data: sonuc,
        });
    }
    catch (error) {
        console.error('OEE hesaplama hatası:', error);
        const status = error.message?.includes('tarih') || error.message?.includes('zorunludur') ? 400 : 500;
        return res.status(status).json({ success: false, message: error.message || 'OEE hesaplanırken bir hata oluştu.' });
    }
}
async function topluOeeGetir(req, res) {
    try {
        const { baslangic, bitis, baslangicTarihi, bitisTarihi } = tarihAraligiOku(req);
        const sonuc = await (0, oeeService_1.fabrikaOeeHesapla)(baslangicTarihi, bitisTarihi);
        return res.status(200).json({
            success: true,
            message: `${sonuc.makineler.length} makine için OEE hesaplandı.`,
            data: {
                ...sonuc,
                donem: { baslangic, bitis },
            },
        });
    }
    catch (error) {
        console.error('Toplu OEE hesaplama hatası:', error);
        const status = error.message?.includes('tarih') || error.message?.includes('zorunludur') ? 400 : 500;
        return res.status(status).json({ success: false, message: error.message || 'Toplu OEE hesaplanırken bir hata oluştu.' });
    }
}
