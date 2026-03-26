import { Router } from "express";
import { personelEkle } from "../controllers/kullaniciKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();

// Personel ekle (Sadece yönetici erişebilir)
router.post("/",
    oturumKontrol,
    rolKontrol("YONETICI"),
    personelEkle
);

export default router;
