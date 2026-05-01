import { Router } from "express";
import { aktifGorevleriGetir } from "../controllers/gorevKontrol";
import { oturumKontrol } from "../middlewares/yetki";

const router = Router();

// Aktif görevleri getir
router.get('/', oturumKontrol, aktifGorevleriGetir);

// Görev durumunu güncelle (Onaylama vb.)
router.patch('/:id/durum', oturumKontrol, async (req, res) => {
    const { id } = req.params;
    const { durum } = req.body;
    try {
        const update = await (require("../config/prisma")).default.bakim_kaydi.update({
            where: { bakim_id: Number(id) },
            data: { durum }
        });
        res.json({ success: true, data: update });
    } catch (error) {
        res.status(500).json({ success: false, message: "Güncelleme hatası" });
    }
});

export default router;