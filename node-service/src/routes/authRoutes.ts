import { Router } from "express";
import { login, benKimim, servisGiris} from "../controllers/oturumYonetici";
import { oturumKontrol } from "../middlewares/yetki";

const router = Router();

// Giriş yap
router.post("/login", login);

// Servis girişi pin + telefon ile
router.post("/servis-giris", servisGiris);

// Oturum açmış kullanıcı bilgisi
router.get("/me", oturumKontrol, benKimim);




export default router;
