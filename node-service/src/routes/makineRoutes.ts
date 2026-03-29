import { Router } from "express";
import { makineEkle, qrileMakineGetir } from "../controllers/makineKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();

// Makine ekleme (Sadece yönetici erişebilir)
router.post("/makine-ekle",
    oturumKontrol,
    rolKontrol("YONETICI"),
    makineEkle
);

// QR ile makine bilgisi getir (Tüm roller erişebilir)
router.get("/qr/:qr_uuid",
    oturumKontrol,
    rolKontrol("YONETICI", "OPERATOR", "TEKNISYEN"),
    qrileMakineGetir
);

export default router;