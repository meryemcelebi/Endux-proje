"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const checklistYonetici_1 = require("../controllers/checklistYonetici");
const yetki_1 = require("../middlewares/yetki");
const router = (0, express_1.Router)();
// Checklist formu kaydetme (operatör giriş yapmış olmalı)
router.post("/form", yetki_1.oturumKontrol, checklistYonetici_1.formKaydet);
// Şablon maddelerini doğrudan id ile getir
router.get("/sablon/:sablon_id", yetki_1.oturumKontrol, checklistYonetici_1.sablonGetir);
// QR Kodu (uuid) ile o makineye ait formu dinamik getir
router.get("/qr/:makine_qr", yetki_1.oturumKontrol, checklistYonetici_1.qrIleSablonGetir);
exports.default = router;
