"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.setVardiyaSaatleri = exports.getVardiyaSaatleri = exports.setMakineTuruDurusMaliyetleri = exports.getMakineTuruDurusMaliyetleri = exports.siralaMakineTurleri = exports.siralaRoller = exports.siralaFirmalar = void 0;
const prisma_1 = __importDefault(require("../config/prisma"));
const ensureMakineTuruDurusMaliyetiColumn = async () => {
    await prisma_1.default.$executeRawUnsafe(`
        ALTER TABLE "makine_turu"
        ADD COLUMN IF NOT EXISTS "saatlik_durus_maliyeti" DOUBLE PRECISION DEFAULT 0
    `);
};
const siralaFirmalar = async (req, res) => {
    try {
        const firmalar = await prisma_1.default.firma.findMany({ select: { firma_id: true, firma_adi: true } });
        res.json({ success: true, firmalar });
    }
    catch (error) {
        res.status(500).json({ success: false, message: "Firmalar listelenirken bir hata olustu." });
    }
};
exports.siralaFirmalar = siralaFirmalar;
const siralaRoller = async (req, res) => {
    try {
        const roller = await prisma_1.default.rol.findMany({ select: { rol_id: true, rol_adi: true } });
        res.json({ success: true, roller });
    }
    catch (error) {
        res.status(500).json({ success: false, message: "Roller listelenirken bir hata olustu." });
    }
};
exports.siralaRoller = siralaRoller;
const siralaMakineTurleri = async (req, res) => {
    try {
        await ensureMakineTuruDurusMaliyetiColumn();
        const makineTurleri = await prisma_1.default.$queryRaw `
            SELECT
                makine_tur_id,
                makine_tur_adi,
                saatlik_durus_maliyeti
            FROM makine_turu
            ORDER BY makine_tur_adi ASC
        `;
        res.json({ success: true, makineTurleri });
    }
    catch (error) {
        console.error("Makine turleri listeleme hatasi:", error);
        res.status(500).json({ success: false, message: "Makine turleri listelenirken bir hata olustu." });
    }
};
exports.siralaMakineTurleri = siralaMakineTurleri;
const getMakineTuruDurusMaliyetleri = async (req, res) => {
    try {
        await ensureMakineTuruDurusMaliyetiColumn();
        const makineTurleri = await prisma_1.default.$queryRaw `
            SELECT
                makine_tur_id,
                makine_tur_adi,
                saatlik_durus_maliyeti
            FROM makine_turu
            ORDER BY makine_tur_adi ASC
        `;
        res.json({ success: true, makineTurleri });
    }
    catch (error) {
        console.error("Durus maliyetleri listeleme hatasi:", error);
        res.status(500).json({ success: false, message: "Durus maliyetleri cekilemedi." });
    }
};
exports.getMakineTuruDurusMaliyetleri = getMakineTuruDurusMaliyetleri;
const setMakineTuruDurusMaliyetleri = async (req, res) => {
    try {
        await ensureMakineTuruDurusMaliyetiColumn();
        const { makineTurleri } = req.body;
        if (!Array.isArray(makineTurleri)) {
            return res.status(400).json({ success: false, message: "Makine turleri listesi gecersiz." });
        }
        await prisma_1.default.$transaction(makineTurleri.map((tur) => prisma_1.default.$executeRaw `
                    UPDATE makine_turu
                    SET saatlik_durus_maliyeti = ${Number(tur.saatlik_durus_maliyeti) || 0}
                    WHERE makine_tur_id = ${Number(tur.makine_tur_id)}
                `));
        res.json({ success: true, message: "Saatlik durus maliyetleri basariyla guncellendi." });
    }
    catch (error) {
        console.error("Durus maliyetleri guncelleme hatasi:", error);
        res.status(500).json({ success: false, message: "Saatlik durus maliyetleri guncellenirken hata olustu." });
    }
};
exports.setMakineTuruDurusMaliyetleri = setMakineTuruDurusMaliyetleri;
const getVardiyaSaatleri = async (req, res) => {
    try {
        const vardiyalar = await prisma_1.default.vardiya_saatleri.findMany({
            orderBy: { vardiya_id: "asc" }
        });
        res.json({ success: true, vardiyalar });
    }
    catch (error) {
        res.status(500).json({ success: false, message: "Vardiya saatleri cekilemedi." });
    }
};
exports.getVardiyaSaatleri = getVardiyaSaatleri;
const setVardiyaSaatleri = async (req, res) => {
    try {
        const { vardiyalar } = req.body;
        if (!Array.isArray(vardiyalar)) {
            return res.status(400).json({ success: false, message: "Vardiya listesi gecersiz." });
        }
        await prisma_1.default.vardiya_saatleri.deleteMany({});
        const result = await prisma_1.default.vardiya_saatleri.createMany({
            data: vardiyalar
        });
        res.json({ success: true, message: "Vardiya saatleri basariyla guncellendi.", count: result.count });
    }
    catch (error) {
        res.status(500).json({ success: false, message: "Vardiya saatleri guncellenirken hata olustu." });
    }
};
exports.setVardiyaSaatleri = setVardiyaSaatleri;
