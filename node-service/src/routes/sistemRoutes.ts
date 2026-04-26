import { Router } from 'express';
import {
     siralaFirmalar,
     siralaRoller,
     siralaMakineTurleri
} from '../controllers/sistemKontrol';

const router = Router();

router.get('/firmalar', siralaFirmalar);
router.get('/roller', siralaRoller);
router.get('/makine-turleri', siralaMakineTurleri);

export default router;