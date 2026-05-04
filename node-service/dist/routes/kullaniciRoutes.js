"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const kullaniciKontrol_1 = require("../controllers/kullaniciKontrol");
const yetki_1 = require("../middlewares/yetki");
const router = (0, express_1.Router)();
router.get("/", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI"), kullaniciKontrol_1.tumKullanicilariGetir);
// Personel ekle (Sadece yönetici erişebilir)
router.post("/", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI"), kullaniciKontrol_1.personelEkle);
// Personel sil/pasif yap
router.delete("/:id", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI"), kullaniciKontrol_1.personelSil);
exports.default = router;
