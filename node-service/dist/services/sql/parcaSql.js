"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getParcaDetayListesi = getParcaDetayListesi;
const prisma_1 = __importDefault(require("../../config/prisma"));
async function getParcaDetayListesi() {
    return prisma_1.default.$queryRaw `
        SELECT * FROM public.v_parca_detay_listesi
    `;
}
