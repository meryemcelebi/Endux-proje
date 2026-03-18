import { Router } from "express";
import { login, benKimim } from '../controllers/oturumYonetici';
import { kullaniciOlustur } from '../controllers/kullaniciYonetici';
import { oturumKontrol,rolKontrol } from '../middlewares/yetki';
import { formKaydet, sablonGetir } from '../controllers/checklistYonetici';


const router = Router();

router.post("/auth/login", login);
router.get("/auth/me", oturumKontrol, benKimim);
router.post("/kullanicilar",
     oturumKontrol,
     rolKontrol("admin", "yönetici"),
     kullaniciOlustur);
// Checklist formu kaydetme route'u
/// İşçi giriş yapmış mı kontrol etmek için 'oturumKontrol' yetkisini kullanıyoruz
router.post("/checklist/form", oturumKontrol, formKaydet);
//operatörün seçtiği şablona göre form maddelerini getiren route
router.get("/checklist/sablon/:sablon_id", oturumKontrol, sablonGetir);






export default router;
