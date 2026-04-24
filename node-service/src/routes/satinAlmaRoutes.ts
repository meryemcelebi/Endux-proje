import { Router } from "express";
import {
    satinAlmaEkle,
    tumSatinAlmalariGetir,
    tedarikciOrtalamaPuan,
    tumStoklariGetir,
    satinAlmaPuanla
} from "../controllers/satinAlmaKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();

// GET /api/satin-alma/stok — Tüm stok kayıtlarını listele
router.get('/stok', oturumKontrol, tumStoklariGetir);

// GET /api/satin-alma — Tüm satın alma kayıtlarını listele
router.get('/', oturumKontrol, tumSatinAlmalariGetir);

// POST /api/satin-alma — Yeni satın alma kaydı ekle
router.post('/', oturumKontrol, rolKontrol('YONETICI', 'TEKNISYEN'), satinAlmaEkle);

// PATCH /api/satin-alma/:id/puan — Alımı sonradan puanla
router.patch('/:id/puan', oturumKontrol, rolKontrol('YONETICI', 'TEKNISYEN'), satinAlmaPuanla);

// GET /api/satin-alma/:id/ortalama-puan — Tedarikçinin satın alma puan ortalaması
router.get('/:id/ortalama-puan', oturumKontrol, tedarikciOrtalamaPuan);

export default router;
