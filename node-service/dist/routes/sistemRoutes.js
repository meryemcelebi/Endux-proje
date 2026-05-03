"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const sistemKontrol_1 = require("../controllers/sistemKontrol");
const router = (0, express_1.Router)();
router.get('/firmalar', sistemKontrol_1.siralaFirmalar);
router.get('/roller', sistemKontrol_1.siralaRoller);
router.get('/makine-turleri', sistemKontrol_1.siralaMakineTurleri);
exports.default = router;
