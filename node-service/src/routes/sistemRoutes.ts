import { Router } from 'express';
import {
     siralaFirmalar,
     siralaRoller,
     siralaMakineTurleri,
     getVardiyaSaatleri,
     setVardiyaSaatleri,
     getMakineTuruDurusMaliyetleri,
     setMakineTuruDurusMaliyetleri
} from '../controllers/sistemKontrol';

const router = Router();

router.get('/firmalar', siralaFirmalar);
router.get('/roller', siralaRoller);
router.get('/makine-turleri', siralaMakineTurleri);
router.get('/vardiya-saatleri', getVardiyaSaatleri);
router.post('/vardiya-saatleri', setVardiyaSaatleri);
router.get('/makine-turu-durus-maliyetleri', getMakineTuruDurusMaliyetleri);
router.post('/makine-turu-durus-maliyetleri', setMakineTuruDurusMaliyetleri);

export default router;
