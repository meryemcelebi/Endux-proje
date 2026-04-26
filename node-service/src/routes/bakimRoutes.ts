import { Router } from "express";
import { bakimKaydiGir, makineBakimKayitlari, dusukStokUyarisi} from "../controllers/bakimKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();
//— Makinenin bakım geçmişini getirir
router.get('/:makine_id', oturumKontrol, makineBakimKayitlari);

// GET /api/stok-uyarisi  — Düşük stok uyarısı getirir
router.get('/stok-uyarisi', oturumKontrol, dusukStokUyarisi);

// POST /api/bakimlar  — Yeni bakım kaydı oluşturur
router.post('/',
    oturumKontrol,
    rolKontrol('TEKNISYEN', 'YONETICI' , 'SERVIS'),
    bakimKaydiGir
);


export default router;