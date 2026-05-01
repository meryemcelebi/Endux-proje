import { Router } from "express";
import { bakimKaydiGir, makineBakimKayitlari, bakimPuanla, bakimOnayla } from "../controllers/bakimKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();
//— Makinenin bakım geçmişini getirir
router.get('/:makine_id', oturumKontrol, makineBakimKayitlari);

// POST /api/bakimlar  — Yeni bakım kaydı oluşturur
router.post('/',
    oturumKontrol,
    rolKontrol('TEKNISYEN', 'YONETICI', 'SERVIS'),
    bakimKaydiGir
);
// PATCH /api/bakimlar/:id/puan — Bakım işlemini puanlar
router.patch('/:id/puan',
    oturumKontrol,
    rolKontrol('YONETICI'),
    bakimPuanla
);

// PATCH /api/bakimlar/:id/onayla — Bakım işlemini onaylayıp listeden kaldırır
router.patch('/:id/onayla',
    oturumKontrol,
    rolKontrol('YONETICI'),
    bakimOnayla
);


export default router;