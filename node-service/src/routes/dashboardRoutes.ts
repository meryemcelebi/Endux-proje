import { Router } from 'express';
import { getDashboardOzet } from '../controllers/dashboardKontrol';
import { oturumKontrol , rolKontrol} from "../middlewares/yetki";

const router = Router();

router.get(
    "/ozet", 
    oturumKontrol,
    rolKontrol("YONETICI"),
    getDashboardOzet);


export default router;
