"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const oeeKontrol_1 = require("../controllers/oeeKontrol");
const yetki_1 = require("../middlewares/yetki");
const router = (0, express_1.Router)();
// Toplu OEE Getirme Endpointi
// RESTful kullanım için rotayı /toplu olarak belirliyoruz
router.get("/toplu", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI"), oeeKontrol_1.topluOeeGetir);
// Tekil Makine OEE Getirme Endpointi
router.get("/:id", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI", "TEKNISYEN"), oeeKontrol_1.oeeGetir);
exports.default = router;
