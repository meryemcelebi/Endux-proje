import { Router } from "express";
import { formKaydet, sablonGetir, qrIleSablonGetir } from "../controllers/checklistYonetici";
import { oturumKontrol } from "../middlewares/yetki";

const router = Router();

// Checklist formu kaydetme (operatör giriş yapmış olmalı)
router.post("/form", oturumKontrol, formKaydet);

// Şablon maddelerini doğrudan id ile getir
router.get("/sablon/:sablon_id", oturumKontrol, sablonGetir);

// QR Kodu (uuid) ile o makineye ait formu dinamik getir
router.get("/qr/:makine_qr", oturumKontrol, qrIleSablonGetir);

export default router;
