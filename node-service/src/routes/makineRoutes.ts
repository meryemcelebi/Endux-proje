import { Router } from "express";
import { makineEkle, qrileMakineGetir, tumMakineBilgileriGetir, makineDetayGetir, QRKodYazdir, makineDurumGuncelle } from "../controllers/makineKontrol";
import { maliyetAnalizi, lokasyonHaritasi } from "../controllers/analizKontrol";
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

// Durum Güncelle (Aktif/Pasif)
router.patch("/:id/durum",
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN"),
    makineDurumGuncelle
);

// QR ile makine bilgisi getir (Tüm roller erişebilir)
router.get("/qr/:qr_uuid",
    oturumKontrol,
    rolKontrol("YONETICI", "OPERATOR", "TEKNISYEN", "SERVIS"),
    qrileMakineGetir

);

router.get("/lokasyon-haritasi",
    oturumKontrol,
    rolKontrol("YONETICI"),
    lokasyonHaritasi
);
router.get("/:id/qr-yazdir",
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN"),
    QRKodYazdir
);



router.get('/:id/maliyet-analizi',
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN"),
    maliyetAnalizi
);

router.patch('/:id/durum',
    oturumKontrol,
    rolKontrol("YONETICI"),
    makineDurumGuncelle
);



router.get('/:id',
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN", "OPERATOR", "SERVIS"),
    makineDetayGetir
);


export default router;


