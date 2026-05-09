import { Router } from "express";
import { satinAlmaKaydet, getStokDurumu, getAlimGecmisi, getParcaKategorileri } from "../controllers/satinAlmaKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();

router.get('/', oturumKontrol, getAlimGecmisi);
router.get('/kategoriler', oturumKontrol, getParcaKategorileri);

router.post('/',
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN"),
    satinAlmaKaydet);

router.get('/stok', oturumKontrol, getStokDurumu);

export default router;
