"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const gorevKontrol_1 = require("../controllers/gorevKontrol");
const yetki_1 = require("../middlewares/yetki");
const router = (0, express_1.Router)();
// Aktif görevleri getir
router.get('/', yetki_1.oturumKontrol, gorevKontrol_1.aktifGorevleriGetir);
// Görev durumunu güncelle (Onaylama vb.)
router.patch('/:id/durum', yetki_1.oturumKontrol, async (req, res) => {
    const { id } = req.params;
    const { durum } = req.body;
    try {
        const update = await (require("../config/prisma")).default.bakim_kaydi.update({
            where: { bakim_id: Number(id) },
            data: { durum }
        });
        res.json({ success: true, data: update });
    }
    catch (error) {
        res.status(500).json({ success: false, message: "Güncelleme hatası" });
    }
});
exports.default = router;
