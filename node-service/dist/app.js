"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const config_1 = require("./config");
const routes_1 = __importDefault(require("./routes"));
const prisma_1 = require("./config/prisma");
const app = (0, express_1.default)();
// Veritabanı bağlantısını başlat
(0, prisma_1.connectDB)();
const corsOrigins = config_1.config.corsOrigin
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
app.use((0, cors_1.default)({
    origin: corsOrigins.includes("*") ? true : corsOrigins,
    credentials: true,
}));
app.use(express_1.default.json());
app.use(express_1.default.urlencoded({ extended: true }));
app.get("/api/health", (_req, res) => {
    res.status(200).json({
        success: true,
        message: "Endux Backend API çalışıyor!",
        timestamp: new Date().toISOString(),
    });
});
// API route'ları
app.use("/api", routes_1.default);
// 404 Catch-All (Bulunamayan rotalar için JSON döndür)
app.use((_req, res, _next) => {
    res.status(404).json({
        success: false,
        message: "İstek yapılan API rotası bulunamadı."
    });
});
// Global Error Handler (Hata durumlarında HTML yerine JSON döndürmek için)
app.use((err, _req, res, _next) => {
    console.error("🚀 Sistem Hatası Yakalandı: ", err);
    // Veritabanı (Prisma) kaynaklı hataları tespit et
    if (err.name === "PrismaClientKnownRequestError" || err.name === "PrismaClientInitializationError") {
        res.status(500).json({
            success: false,
            message: "Veritabanına ulaşılamıyor veya veritabanı bağlantısında bir hata oluştu. Lütfen servislerin çalıştığından emin olun.",
            error: config_1.config.nodeEnv === "development" ? err.message : undefined
        });
        return;
    }
    // Varsayılan kaba sistem hata fırlatıcısı
    res.status(err.status || 500).json({
        success: false,
        message: err.message || "Sunucu tarafında beklenmeyen bir hata oluştu.",
        error: config_1.config.nodeEnv === "development" ? err.stack : undefined
    });
});
exports.default = app;
