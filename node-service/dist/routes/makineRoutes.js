"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const makineKontrol_1 = require("../controllers/makineKontrol");
const analizKontrol_1 = require("../controllers/analizKontrol");
const yetki_1 = require("../middlewares/yetki");
const router = (0, express_1.Router)();
/// ! kontrol edilmeliii !!!!
// Makine ekleme (Sadece yönetici erişebilir)
router.post("/", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI"), makineKontrol_1.makineEkle);
router.get("/", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI", "TEKNISYEN"), makineKontrol_1.tumMakineBilgileriGetir);
// QR ile makine bilgisi getir (Tüm roller erişebilir)
router.get("/qr/:qr_uuid", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI", "OPERATOR", "TEKNISYEN", "SERVIS"), makineKontrol_1.qrileMakineGetir);
router.get("/lokasyon-haritasi", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI"), analizKontrol_1.lokasyonHaritasi);
router.get("/:id/qr-yazdir", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI", "TEKNISYEN"), makineKontrol_1.QRKodYazdir);
router.get('/:id/maliyet-analizi', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI", "TEKNISYEN"), analizKontrol_1.maliyetAnalizi);
router.patch('/:id/durum', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI"), makineKontrol_1.makineDurumGuncelle);
router.get('/:id', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI", "TEKNISYEN", "OPERATOR", "SERVIS"), makineKontrol_1.makineDetayGetir);
exports.default = router;
