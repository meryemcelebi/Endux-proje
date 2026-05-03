"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const authRoutes_1 = __importDefault(require("./authRoutes"));
const kullaniciRoutes_1 = __importDefault(require("./kullaniciRoutes"));
const makineRoutes_1 = __importDefault(require("./makineRoutes"));
const checklistRoutes_1 = __importDefault(require("./checklistRoutes"));
const sistemRoutes_1 = __importDefault(require("./sistemRoutes"));
const bakimRoutes_1 = __importDefault(require("./bakimRoutes"));
const firmaRoutes_1 = require("./firmaRoutes");
const gorevRoutes_1 = __importDefault(require("./gorevRoutes"));
const puanRoute_1 = require("./puanRoute");
const aiRoutes_1 = __importDefault(require("./aiRoutes"));
const oeeRoutes_1 = __importDefault(require("./oeeRoutes"));
const satinAlmaRoutes_1 = __importDefault(require("./satinAlmaRoutes"));
const dashboardRoutes_1 = __importDefault(require("./dashboardRoutes"));
const router = (0, express_1.Router)();
// Auth route'ları — /api/auth/*
router.use("/auth", authRoutes_1.default);
// Kullanıcı (personel) route'ları — /api/kullanicilar/*
router.use("/kullanicilar", kullaniciRoutes_1.default);
// Makine route'ları — /api/makineler/*
router.use("/makineler", makineRoutes_1.default);
// Checklist route'ları — /api/checklist/*
router.use("/checklist", checklistRoutes_1.default);
router.use("/sistem", sistemRoutes_1.default);
router.use("/bakimlar", bakimRoutes_1.default);
router.use("/tedarikciler", firmaRoutes_1.TedarikciRouter); // /api/tedarikciler/*
router.use("/servis-firmalari", firmaRoutes_1.ServisFirmasiRouter); // /api/servis-firmalari/*
router.use("/gorevler", gorevRoutes_1.default);
router.use("/servis-puan", puanRoute_1.ServisPuanRouter);
router.use("/tedarikci-puan", puanRoute_1.TedarikciPuanRouter);
router.use("/ai", aiRoutes_1.default); // /api/ai/*
router.use("/oee", oeeRoutes_1.default); // /api/oee/*
router.use("/satin-alma", satinAlmaRoutes_1.default); // /api/satin-alma/*
router.use("/dashboard", dashboardRoutes_1.default); // /api/dashboard/*
exports.default = router;
