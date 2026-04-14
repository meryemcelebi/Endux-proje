import { Router } from "express";
import { makineEkle, qrileMakineGetir, tumMakineBilgileriGetir, makineDetayGetir } from "../controllers/makineKontrol";
import { maliyetAnalizi } from "../controllers/analizKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();


/// ! kontrol edilmeliii !!!!


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
// QR ile makine bilgisi getir (Tüm roller erişebilir)
router.get("/qr/:qr_uuid",
    oturumKontrol,
    rolKontrol("YONETICI", "OPERATOR", "TEKNISYEN", "SERVIS"),
    qrileMakineGetir

);


router.get('/:id/maliyet-analizi',
    oturumKontrol,
    maliyetAnalizi
);


router.get('/:id',
   oturumKontrol,
   rolKontrol("YONETICI", "TEKNISYEN"),
   makineDetayGetir
    );


export default router;


