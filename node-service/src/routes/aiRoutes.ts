import { Router } from 'express';
import { topluMakineTahmin } from '../controllers/aiKontrol';
import {rolKontrol, oturumKontrol} from '../middlewares/yetki';

const router = Router();

router.post('/toplu-tahmin',
     oturumKontrol,
     rolKontrol('YONETICI', 'TEKNISYEN'),
     topluMakineTahmin
    );

export default router;
