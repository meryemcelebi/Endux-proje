import { Router } from "express";
import { aktifGorevleriGetir } from "../controllers/gorevKontrol";
import { oturumKontrol } from "../middlewares/yetki";

const router = Router();

// Aktif görevleri getir
// GET /api/gorevler — Giriş yapmış kullanıcının aktif görevleri
router.get('/', oturumKontrol, aktifGorevleriGetir);

export default router;