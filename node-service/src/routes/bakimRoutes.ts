import { Router } from "express";
import { bakimKaydiGir, makineBakimKayitlari, dusukStokUyarisi, bakimlariOnayla, bakimiYokSay, getOnayBekleyenler } from "../controllers/bakimKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();
// GET /api/bakimlar/onay-bekleyenler — Bekleyen bakımları zenginleştirilmiş formatta getirir
router.get('/onay-bekleyenler', oturumKontrol, getOnayBekleyenler);

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

// PUT /api/bakimlar/onayla — Bekleyen bakımları onaylar (Teknik Servis'e aktarır)
router.put('/onayla', oturumKontrol, rolKontrol('YONETICI'), bakimlariOnayla);

// PUT /api/bakimlar/yoksay — Bekleyen bakımları reddeder/yoksayar
router.put('/yoksay', oturumKontrol, rolKontrol('YONETICI'), bakimiYokSay);

export default router;