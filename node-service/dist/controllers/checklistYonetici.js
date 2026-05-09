"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.formKaydet = formKaydet;
exports.sablonGetir = sablonGetir;
exports.qrIleSablonGetir = qrIleSablonGetir;
const prisma_1 = __importDefault(require("../config/prisma"));
const aiKontrol_1 = require("./aiKontrol");
//operatorlerden gelen form verilerini database'e ekler:
async function formKaydet(req, res, next) {
    try {
        const { makine_id, sablon_id, genel_not, cevaplar } = req.body;
        // Token'dan giriş yapan operatörün ID'sini alıyoruz
        const operator_id = Number(req.user?.userId);
        if (!makine_id || !sablon_id) {
            res.status(400).json({ success: false, hata: "Makine ID ve Şablon ID zorunludur." });
            return;
        }
        if (!Array.isArray(cevaplar) || cevaplar.length === 0) {
            res.status(400).json({ success: false, hata: "Geçerli bir cevap listesi sunulmadı." });
            return;
        }
        if (!operator_id) {
            res.status(401).json({ success: false, message: "Kullanıcı kimliği bulunamadı." });
            return;
        }
        // jsonb_to_recordset beklentisine göre isimlendiriyoruz
        // res_id, s_tipi, s_durum, s_deger, s_not
        const formatliCevaplar = cevaplar.map((c) => ({
            res_id: Number(c.madde_id),
            s_durum: c.durum,
            // PostgreSQL NUMERIC beklediği için sayıya çeviriyoruz (veya null bırakıyoruz)
            s_deger: c.girilen_deger ? Number(c.girilen_deger) : null,
            s_tipi: c.soru_tipi || 'Bilinmiyor', // Eğer frontend göndermiyorsa varsayılan
            s_not: c.aciklama || null
        }));
        // 2. Prisma için JSON dizisini string'e çeviriyoruz
        const cevaplarJson = JSON.stringify(formatliCevaplar);
        // 3. Transaction ve createMany yerine doğrudan Prosedür çağırıyoruz
        await prisma_1.default.$executeRaw `
            CALL public.pr_kontrol_kaydet(
                ${Number(makine_id)}::integer, 
                ${operator_id}::integer, 
                ${Number(sablon_id)}::integer, 
                ${genel_not || null}::text, 
                ${cevaplarJson}::jsonb
            )
        `;
        // SEÇENEK B: Arka Planda AI Risk Analizini Başlat!
        // Prosedür ID dönmediği için, yeni oluşan formu son eklenen olarak buluyoruz
        const yeniForm = await prisma_1.default.gunluk_kontrol_formu.findFirst({
            where: { makine_id: Number(makine_id), kullanici_id: operator_id },
            orderBy: { form_id: 'desc' }
        });
        if (yeniForm) {
            console.log(`[AI-TETIKLEYICI] Makine ${makine_id} Form ${yeniForm.form_id} için AI başlatılıyor...`);
            (0, aiKontrol_1.tekMakineTahmin)(Number(makine_id), yeniForm.form_id, operator_id).catch(err => {
                console.error("[AI-ARKA-PLAN-HATA] AI tahmin işlemi tamamlanamadı:", err);
            });
        }
        res.status(201).json({
            success: true,
            message: "Form başarıyla kaydedildi."
        });
    }
    catch (error) {
        console.error("Form kaydetme hatası:", error);
        res.status(500).json({ success: false, message: "Form kaydedilirken bir hata oluştu." });
    }
}
async function sablonGetir(req, res, next) {
    try {
        const sablon_id = Number(req.params.sablon_id); //sablon_id'yi parametrelerden alıyoruz
        const sablon = await prisma_1.default.kontrol_sablonu.findUnique({
            where: { sablon_id }
        });
        if (!sablon) {
            res.status(404).json({ success: false, message: "Sablon bulunamadi." });
            return;
        }
        const maddeler = await prisma_1.default.kontrol_maddesi.findMany({
            where: { sablon_id: sablon.sablon_id }
        });
        res.status(200).json({ success: true, data: { ...sablon, kontrol_maddesi: maddeler } });
    }
    catch (error) {
        console.error("Sablon getirme hatası:", error);
        res.status(500).json({ success: false, message: "Sablon getirilirken bir hata oluştu." });
    }
}
// QR Kod Okutulduğunda Makineyi Bulup Form Şablonunu Döndüren Endpoint
async function qrIleSablonGetir(req, res, next) {
    try {
        const makine_qr = req.params.makine_qr;
        // 1. Zincirin İlk Halkası: Makineyi QR kodundan bul
        const makine = await prisma_1.default.makine.findUnique({
            where: { makine_qr }
        });
        if (!makine) {
            res.status(404).json({ success: false, message: "Bu QR koda ait makine bulunamadı." });
            return;
        }
        //
        const sablon = await prisma_1.default.kontrol_sablonu.findFirst({
            where: {
                makine_tur_id: makine.makine_tur_id,
                aktiflik: true
            }
        });
        if (!sablon) {
            res.status(404).json({ success: false, message: "Bu makine türü için tanımlanmış aktif bir form şablonu bulunamadı." });
            return;
        }
        const sorular = await prisma_1.default.kontrol_maddesi.findMany({
            where: { sablon_id: sablon.sablon_id }
        });
        res.status(200).json({
            success: true,
            data: {
                makine_id: makine.makine_id,
                makine_adi: makine.makine_adi,
                seri_no: makine.seri_no,
                sablon_id: sablon.sablon_id,
                sablon_adi: sablon.sablon_adi,
                sorular: sorular
            }
        });
    }
    catch (error) {
        console.error("QR ile şablon getirme hatası:", error);
        res.status(500).json({ success: false, message: "Şablon getirilirken bir hata oluştu." });
    }
}
