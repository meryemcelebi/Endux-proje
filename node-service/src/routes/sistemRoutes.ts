import { Router } from 'express';
import {
     siralaFirmalar,
     siralaRoller,
     siralaMakineTurleri,
     siralaArizaTurleri
} from '../controllers/sistemKontrol';

const router = Router();

router.get('/firmalar', siralaFirmalar);
router.get('/roller', siralaRoller);
router.get('/makine-turleri', siralaMakineTurleri);
router.get('/ariza-turleri', siralaArizaTurleri);

export default router;