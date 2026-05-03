"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const dashboardKontrol_1 = require("../controllers/dashboardKontrol");
const yetki_1 = require("../middlewares/yetki");
const router = (0, express_1.Router)();
router.get("/ozet", yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("YONETICI"), dashboardKontrol_1.getDashboardOzet);
exports.default = router;
