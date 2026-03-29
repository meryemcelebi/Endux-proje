import { Router } from "express";
import { bakimKaydiGir, makineBakimKaytlari } from "../controllers/bakimKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();

router.post('/', oturumKontrol,
     rolKontrol('TEKNİSYEN', 'YÖNETİCİ'), 
bakimKaydiGir);

router.get('/',oturumKontrol,
    makineBakimKaytlari
);

export default router;