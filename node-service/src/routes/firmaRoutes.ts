import { Router } from "express";
import {
    tumTedarikcileriGetir,
    tedarikciEkle,
    tumServisFirmalariniGetir,
    servisFirmasiEkle,
    tedarikciSil,
    servisFirmasiSil
} from "../controllers/firmaKontrol";
servisFirmasiEkle,
    tedarikciSil,
    servisFirmasiSil
} from "../controllers/firmaKontrol";
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

// GET /api/firma/servis-firmalari  — Tüm servis firmalarını getirir
ServisFirmasiRouter.get('/', oturumKontrol, tumServisFirmalariniGetir);

// POST /api/firma/servis-firmalari  — Yeni servis firması ekler
ServisFirmasiRouter.post('/', oturumKontrol, rolKontrol('YONETICI'), servisFirmasiEkle);

<<<<<<< HEAD
// DELETE /api/servis-firmalari/:id — Servis firması siler
ServisFirmasiRouter.delete('/:id', oturumKontrol, rolKontrol('YONETICI'), servisFirmasiSil);
=======
// DELETE /api/firma/servis-firmalari/:id — Servis firması siler
ServisFirmasiRouter.delete('/:id', oturumKontrol, rolKontrol('YONETICI'), servisFirmasiSil);

>>>>>>> 5b8a9a331802ed33037242851251595a72e68397

export { TedarikciRouter, ServisFirmasiRouter };
