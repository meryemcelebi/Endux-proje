import { Router } from "express";
import { personelEkle, tumKullanicilariGetir } from "../controllers/kullaniciKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();


router.get("/",
    oturumKontrol,
    rolKontrol("YONETICI"),
    tumKullanicilariGetir
)

// Personel ekle (Sadece yönetici erişebilir)
router.post("/",
    oturumKontrol,
    rolKontrol("YONETICI"),
    personelEkle
);

export default router;
