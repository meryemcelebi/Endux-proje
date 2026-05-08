import { Router } from 'express';
import { getDashboardOzet } from '../controllers/dashboardKontrol';
import { oturumKontrol} from "../middlewares/yetki";

const router = Router();

router.get(
    "/ozet", 
    oturumKontrol,
    getDashboardOzet);


export default router;
