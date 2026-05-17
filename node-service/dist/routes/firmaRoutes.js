"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ServisFirmasiRouter = exports.TedarikciRouter = void 0;
const express_1 = require("express");
const firmaKontrol_1 = require("../controllers/firmaKontrol");
const yetki_1 = require("../middlewares/yetki");
const TedarikciRouter = (0, express_1.Router)();
exports.TedarikciRouter = TedarikciRouter;
const ServisFirmasiRouter = (0, express_1.Router)();
exports.ServisFirmasiRouter = ServisFirmasiRouter;
// GET /api/firma/tedarikciler  — Tüm tedarikçileri getirir
TedarikciRouter.get('/', yetki_1.oturumKontrol, firmaKontrol_1.tumTedarikcileriGetir);
// POST /api/firma/tedarikciler  — Yeni tedarikçi ekler
TedarikciRouter.post('/', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI'), firmaKontrol_1.tedarikciEkle);
// DELETE /api/tedarikciler/:id — Tedarikçi siler
// DELETE /api/firma/tedarikciler/:id — Tedarikçi siler
TedarikciRouter.delete('/:id', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI'), firmaKontrol_1.tedarikciSil);
// GET /api/servis-firmalari — Tüm servis firmalarını getirir (token gerektirmez — misafir girişi için gerekli)
ServisFirmasiRouter.get('/', firmaKontrol_1.tumServisFirmalariniGetir);
// POST /api/firma/servis-firmalari  — Yeni servis firması ekler
ServisFirmasiRouter.post('/', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI'), firmaKontrol_1.servisFirmasiEkle);
// DELETE /api/firma/servis-firmalari/:id — Servis firması siler
ServisFirmasiRouter.delete('/:id', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI'), firmaKontrol_1.servisFirmasiSil);
// PUT /api/firma/servis-firmalari/:id — Servis firması günceller
ServisFirmasiRouter.put('/:id', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI'), firmaKontrol_1.servisFirmasiGuncelle);
