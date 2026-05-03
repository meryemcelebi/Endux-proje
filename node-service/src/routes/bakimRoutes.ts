import { Router } from "express";

import { 
    bakimKaydiGir, 
    makineBakimKayitlari, 
    dusukStokUyarisi, 
    bakimlariOnayla, 
    bakimiYokSay, 
    getOnayBekleyenler, 
    getTeknikServisIsleri, 
    TumBakimlarToplu,
    bakimPuaniKaydet,
    bakimIsleminiOnayla
} from "../controllers/bakimKontrol";

import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();



// GET /api/bakimlar/onay-bekleyenler — Bekleyen bakımları zenginleştirilmiş formatta getirir
router.get('/onay-bekleyenler', oturumKontrol, getOnayBekleyenler);

// GET /api/bakimlar/stok-uyarisi  — Düşük stok uyarısı getirir
router.get('/stok-uyarisi', oturumKontrol, dusukStokUyarisi);

// GET /api/bakimlar/teknik-servis — Teknik servis işlerini getirir
router.get('/teknik-servis', oturumKontrol, rolKontrol('YONETICI', 'TEKNISYEN'), getTeknikServisIsleri);

// GET /api/bakimlar/tum-bakimlar — Tüm bakım geçmişini toplu getirir
router.get('/tum-bakimlar', oturumKontrol, rolKontrol('YONETICI'), TumBakimlarToplu);



// POST /api/bakimlar  — Yeni bakım kaydı oluşturur
router.post('/', oturumKontrol, rolKontrol('TEKNISYEN', 'YONETICI', 'SERVIS'), bakimKaydiGir);

// PUT /api/bakimlar/onayla — Bekleyen bakımları onaylar (Teknik Servis'e aktarır)
router.put('/onayla', oturumKontrol, rolKontrol('YONETICI'), bakimlariOnayla);

// PUT /api/bakimlar/yoksay — Bekleyen bakımları reddeder/yoksayar
router.put('/yoksay', oturumKontrol, rolKontrol('YONETICI'), bakimiYokSay);

// PATCH /api/bakimlar/:bakim_id/puan — Teknik servis işlemi için puan kaydeder
router.patch('/:bakim_id/puan', oturumKontrol, rolKontrol('YONETICI', 'TEKNISYEN'), bakimPuaniKaydet);

// PATCH /api/bakimlar/:bakim_id/onayla — Teknik servis işlemini tamamlandı olarak işaretler
router.patch('/:bakim_id/onayla', oturumKontrol, rolKontrol('YONETICI', 'TEKNISYEN'), bakimIsleminiOnayla);



// GET /api/bakimlar/:makine_id — Makinenin bakım geçmişini getirir
// DİKKAT: Bu kural her şeyi yutabileceği için daima en altta durmalıdır!
router.get('/:makine_id', oturumKontrol, makineBakimKayitlari);

export default router;
