"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const aiKontrol_1 = require("../controllers/aiKontrol");
const yetki_1 = require("../middlewares/yetki");
const router = (0, express_1.Router)();
router.post('/toplu-tahmin', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI', 'TEKNISYEN'), aiKontrol_1.topluMakineTahmin);
exports.default = router;
