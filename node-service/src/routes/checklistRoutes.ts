import { Router } from "express";
import { formKaydet, sablonGetir } from "../controllers/checklistYonetici";
import { oturumKontrol } from "../middlewares/yetki";

const router = Router();

// Checklist formu kaydetme (operatör giriş yapmış olmalı)
router.post("/form", oturumKontrol, formKaydet);

// Şablon maddelerini getir
router.get("/sablon/:sablon_id", oturumKontrol, sablonGetir);

export default router;
