import { Router } from "express";
import { login, benKimim } from '../controllers/oturumYonetici';
import { kullaniciOlustur } from '../controllers/kullaniciYonetici';
import { oturumKontrol,rolKontrol } from '../middlewares/yetki';

const router = Router();

router.post("/auth/login", login);
router.get("/auth/me", oturumKontrol, benKimim);
router.post("/kullanicilar",
     oturumKontrol,
     rolKontrol("admin", "yönetici"),
     kullaniciOlustur);
    
// Diğer route modülleri burada tanımlanacak

// İleride eklenecek route modülleri:
// router.use("/makineler", makinelerRoutes);
// router.use("/kontrol", kontrolRoutes);
// router.use("/bakim", bakimRoutes);
// router.use("/kullanicilar", kullanicilarRoutes);

export default router;
