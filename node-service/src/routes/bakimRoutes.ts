import { Router } from "express";
import { bakimKaydiGir, makineBakimKayitlari } from "../controllers/bakimKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();
//— Makinenin bakım geçmişini getirir
router.get('/:makine_id', oturumKontrol, makineBakimKayitlari);

// POST /api/bakimlar  — Yeni bakım kaydı oluşturur
router.post('/',
    oturumKontrol,
    rolKontrol('TEKNISYEN', 'YONETICI' , 'SERVIS'),
    bakimKaydiGir
);


export default router;