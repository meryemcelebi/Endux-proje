import { Router } from "express";
import { makineEkle, qrileMakineGetir } from "../controllers/makineKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();

//Makine ekleme route'u (Sadece admin ve yönetici erişebilir)
router.post("/makine-ekle", oturumKontrol, rolKontrol("admin", "yönetici"), makineEkle);


router.get("/qr/:qr_uuid", oturumKontrol, rolKontrol("admin", "yönetici", "operatör"), qrileMakineGetir);

export default router;