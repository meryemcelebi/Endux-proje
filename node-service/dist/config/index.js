"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
exports.config = {
    port: process.env.PORT || "3000",
    databaseUrl: process.env.DATABASE_URL || "",
    jwtSecret: process.env.JWT_SECRET || "denemekey",
    jwtExpiresIn: process.env.JWT_EXPIRES_IN || "7d",
    nodeEnv: process.env.NODE_ENV || "development",
    aiServiceUrl: process.env.AI_SERVICE_URL || "http://endux_ai:8000",
    corsOrigin: process.env.CORS_ORIGIN || "*",
};
