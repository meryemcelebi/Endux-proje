"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.siralaMakineTurleri = exports.siralaRoller = exports.siralaFirmalar = void 0;
const prisma_1 = __importDefault(require("../config/prisma"));
//firma listesi API 
const siralaFirmalar = async (req, res) => {
    try {
        const firmalar = await prisma_1.default.firma.findMany({ select: { firma_id: true, firma_adi: true } });
        res.json({ success: true, firmalar });
    }
    catch (error) {
        res.status(500).json({ success: false, message: "Firmalar listelenirken bir hata oluştu." });
    }
};
exports.siralaFirmalar = siralaFirmalar;
//rol listesi API
const siralaRoller = async (req, res) => {
    try {
        const roller = await prisma_1.default.rol.findMany({ select: { rol_id: true, rol_adi: true } });
        res.json({ success: true, roller });
    }
    catch (error) {
        res.status(500).json({ success: false, message: "Roller listelenirken bir hata oluştu." });
    }
};
exports.siralaRoller = siralaRoller;
//makine türleri listesi API
const siralaMakineTurleri = async (req, res) => {
    try {
        const makineTurleri = await prisma_1.default.makine_turu.findMany({ select: { makine_tur_id: true, makine_tur_adi: true } });
        res.json({ success: true, makineTurleri });
    }
    catch (error) {
        res.status(500).json({ success: false, message: "Makine türleri listelenirken bir hata oluştu." });
    }
};
exports.siralaMakineTurleri = siralaMakineTurleri;
