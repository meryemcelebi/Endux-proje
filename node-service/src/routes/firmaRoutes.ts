import {Router} from "express";
import { 
    tumTedarikcileriGetir, 
    tedarikciEkle, 
    tumServisFirmalariniGetir,
     servisFirmasiEkle } from "../controllers/firmaKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";




const TedarikciRouter = Router();
const ServisFirmasiRouter = Router();
// GET /api/firma/tedarikciler  — Tüm tedarikçileri getirir
TedarikciRouter.get('/', oturumKontrol, tumTedarikcileriGetir);

// POST /api/firma/tedarikciler  — Yeni tedarikçi ekler
TedarikciRouter.post('/', oturumKontrol, rolKontrol('YONETICI'), tedarikciEkle);

// GET /api/firma/servis-firmalari  — Tüm servis firmalarını getirir
ServisFirmasiRouter.get('/', oturumKontrol, tumServisFirmalariniGetir);

// POST /api/firma/servis-firmalari  — Yeni servis firması ekler
ServisFirmasiRouter.post('/', oturumKontrol, rolKontrol('YONETICI'), servisFirmasiEkle);


export { TedarikciRouter, ServisFirmasiRouter };
