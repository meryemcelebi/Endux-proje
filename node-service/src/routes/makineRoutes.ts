import { Router } from "express";
import { makineEkle, qrileMakineGetir, tumMakineBilgileriGetir, makineDetayGetir } from "../controllers/makineKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();

// Makine ekleme (Sadece yönetici erişebilir)
router.post("/",
    oturumKontrol,
    rolKontrol("YONETICI"),
    makineEkle
);
router.get("/",
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN"),
    tumMakineBilgileriGetir
);
router.get("/:makine_id",
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN"),
    makineDetayGetir
    
)
// QR ile makine bilgisi getir (Tüm roller erişebilir)
router.get("/qr/:qr_uuid",
    oturumKontrol,
    rolKontrol("YONETICI", "OPERATOR", "TEKNISYEN"),
    qrileMakineGetir

);


export default router;