"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const oturumYonetici_1 = require("../controllers/oturumYonetici");
const yetki_1 = require("../middlewares/yetki");
const router = (0, express_1.Router)();
// Giriş yap
router.post("/login", oturumYonetici_1.login);
// Servis girişi pin + telefon ile
router.post("/servis-giris", oturumYonetici_1.servisGiris);
// Oturum açmış kullanıcı bilgisi
router.get("/me", yetki_1.oturumKontrol, oturumYonetici_1.benKimim);
exports.default = router;
