import { Router } from 'express';
import {
     siralaFirmalar,
     siralaRoller,
     siralaMakineTurleri,
     getVardiyaSaatleri,
     setVardiyaSaatleri,
     getMakineTuruDurusMaliyetleri,
     setMakineTuruDurusMaliyetleri,
     siralaArizaTurleri,
     siralaBakimTurleri
} from '../controllers/sistemKontrol';

const router = Router();

router.get('/firmalar', siralaFirmalar);
router.get('/roller', siralaRoller);
router.get('/makine-turleri', siralaMakineTurleri);
router.get('/vardiya-saatleri', getVardiyaSaatleri);
router.post('/vardiya-saatleri', setVardiyaSaatleri);
router.get('/makine-turu-durus-maliyetleri', getMakineTuruDurusMaliyetleri);
router.post('/makine-turu-durus-maliyetleri', setMakineTuruDurusMaliyetleri);
router.get('/ariza-turleri', siralaArizaTurleri);
router.get('/bakim-turleri', siralaBakimTurleri);

export default router;
