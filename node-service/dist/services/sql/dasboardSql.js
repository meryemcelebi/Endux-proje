"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getKritikUyarilar = getKritikUyarilar;
const prisma_1 = __importDefault(require("../../config/prisma"));
async function getKritikUyarilar() {
    return prisma_1.default.$queryRaw `
        SELECT * FROM public.view_dashboard_kritik_uyarilar
    `;
}
