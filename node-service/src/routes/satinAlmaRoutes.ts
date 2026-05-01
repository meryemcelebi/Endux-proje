import { Router } from "express";
import { satinAlmaKaydet, getStokDurumu } from "../controllers/satinAlmaKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();

router.post('/',
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN"),
    satinAlmaKaydet);

router.get('/stok', oturumKontrol, getStokDurumu);

export default router;
