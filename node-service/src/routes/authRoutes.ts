import { Router } from "express";
import { login, benKimim } from "../controllers/oturumYonetici";
import { oturumKontrol } from "../middlewares/yetki";

const router = Router();

// Giriş yap
router.post("/login", login);

// Oturum açmış kullanıcı bilgisi
router.get("/me", oturumKontrol, benKimim);

export default router;
