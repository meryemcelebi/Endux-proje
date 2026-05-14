import { Router } from "express";
import {
    tumTedarikcileriGetir,
    tedarikciEkle,
    tumServisFirmalariniGetir,
    servisFirmasiEkle,
    tedarikciSil,
    servisFirmasiSil,
    tedarikciGuncelle,
    servisFirmasiGuncelle
} from "../controllers/firmaKontrol"
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const TedarikciRouter = Router();
const ServisFirmasiRouter = Router();

// GET /api/firma/tedarikciler  — Tüm tedarikçileri getirir
TedarikciRouter.get('/', oturumKontrol, tumTedarikcileriGetir);

// POST /api/firma/tedarikciler  — Yeni tedarikçi ekler
TedarikciRouter.post('/', oturumKontrol, rolKontrol('YONETICI'), tedarikciEkle);

// DELETE /api/tedarikciler/:id — Tedarikçi siler

// DELETE /api/firma/tedarikciler/:id — Tedarikçi siler
TedarikciRouter.delete('/:id', oturumKontrol, rolKontrol('YONETICI'), tedarikciSil);

// PUT /api/firma/tedarikciler/:id — Tedarikçi günceller
TedarikciRouter.put('/:id', oturumKontrol, rolKontrol('YONETICI'), tedarikciGuncelle);

// GET /api/firma/servis-firmalari  — Tüm servis firmalarını getirir
ServisFirmasiRouter.get('/', oturumKontrol, tumServisFirmalariniGetir);

// POST /api/firma/servis-firmalari  — Yeni servis firması ekler
ServisFirmasiRouter.post('/', oturumKontrol, rolKontrol('YONETICI'), servisFirmasiEkle);

// DELETE /api/firma/servis-firmalari/:id — Servis firması siler
ServisFirmasiRouter.delete('/:id', oturumKontrol, rolKontrol('YONETICI'), servisFirmasiSil);

// PUT /api/firma/servis-firmalari/:id — Servis firması günceller
ServisFirmasiRouter.put('/:id', oturumKontrol, rolKontrol('YONETICI'), servisFirmasiGuncelle);



export { TedarikciRouter, ServisFirmasiRouter };
