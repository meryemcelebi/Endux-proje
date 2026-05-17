"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const bakimKontrol_1 = require("../controllers/bakimKontrol");
const yetki_1 = require("../middlewares/yetki");
const router = (0, express_1.Router)();
// GET /api/bakimlar/onay-bekleyenler — Bekleyen bakımları zenginleştirilmiş formatta getirir
router.get('/onay-bekleyenler', yetki_1.oturumKontrol, bakimKontrol_1.getOnayBekleyenler);
// GET /api/bakimlar/stok-uyarisi  — Düşük stok uyarısı getirir
router.get('/stok-uyarisi', yetki_1.oturumKontrol, bakimKontrol_1.dusukStokUyarisi);
// GET /api/bakimlar/teknik-servis — Teknik servis işlerini getirir
router.get('/teknik-servis', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI', 'TEKNISYEN', 'SERVIS'), bakimKontrol_1.getTeknikServisIsleri);
// GET /api/bakimlar/tum-bakimlar — Tüm bakım geçmişini toplu getirir
router.get('/tum-bakimlar', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI'), bakimKontrol_1.TumBakimlarToplu);
// POST /api/bakimlar/qr-tamamla — QR okutarak sahada bakım tamamlama
router.post('/qr-tamamla', yetki_1.oturumKontrol, bakimKontrol_1.qrBakimTamamla);
// POST /api/bakimlar/acil-bildir — Riskli makineden doğrudan teknik servis iş emri oluşturur
router.post('/acil-bildir', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI'), bakimKontrol_1.acilBakimBildir);
// POST /api/bakimlar/durus-yeniden-hesapla — Mevcut kayıtların duruş sürelerini vardiya bazlı yeniden hesaplar
router.post('/durus-yeniden-hesapla', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI'), bakimKontrol_1.durusSuresiYenidenHesapla);
// POST /api/bakimlar  — Yeni bakım kaydı oluşturur
router.post('/', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('TEKNISYEN', 'YONETICI', 'SERVIS'), bakimKontrol_1.bakimKaydiGir);
// PUT /api/bakimlar/onayla — Bekleyen bakımları onaylar (Teknik Servis'e aktarır)
router.put('/onayla', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI'), bakimKontrol_1.bakimlariOnayla);
// PUT /api/bakimlar/yoksay — Bekleyen bakımları reddeder/yoksayar
router.put('/yoksay', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI'), bakimKontrol_1.bakimiYokSay);
// PATCH /api/bakimlar/:bakim_id/puan — Teknik servis işlemi için puan kaydeder
router.patch('/:bakim_id/puan', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI', 'TEKNISYEN'), bakimKontrol_1.bakimPuaniKaydet);
// PATCH /api/bakimlar/:bakim_id/onayla — Teknik servis işlemini tamamlandı olarak işaretler
router.patch('/:bakim_id/onayla', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)('YONETICI', 'TEKNISYEN'), bakimKontrol_1.bakimIsleminiOnayla);
router.patch('/:bakim_id/baslat', yetki_1.oturumKontrol, (0, yetki_1.rolKontrol)("TEKNISYEN", "YONETICI"), bakimKontrol_1.bakimBaslat);
// GET /api/bakimlar/:makine_id — Makinenin bakım geçmişini getirir
// DİKKAT: Bu kural her şeyi yutabileceği için daima en altta durmalıdır!
router.get('/:makine_id', yetki_1.oturumKontrol, bakimKontrol_1.makineBakimKayitlari);
exports.default = router;
