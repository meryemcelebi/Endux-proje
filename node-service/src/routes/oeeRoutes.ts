import { Router } from 'express';
import { oeeGetir, topluOeeGetir } from '../controllers/oeeKontrol';
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";


const router = Router();

// Toplu OEE Getirme Endpointi
// RESTful kullanım için rotayı /toplu olarak belirliyoruz
router.get(
    "/toplu",
    oturumKontrol,
    rolKontrol("YONETICI"),
    topluOeeGetir
);

// Tekil Makine OEE Getirme Endpointi
router.get(
    "/:id",
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN"),
    oeeGetir
);

export default router;
