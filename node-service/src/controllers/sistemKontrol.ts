import { Request, Response } from "express";
import prisma from "../config/prisma";

const ensureMakineTuruDurusMaliyetiColumn = async () => {
    await prisma.$executeRawUnsafe(`
        ALTER TABLE "makine_turu"
        ADD COLUMN IF NOT EXISTS "saatlik_durus_maliyeti" DOUBLE PRECISION DEFAULT 0
    `);
};

export const siralaFirmalar = async (req: Request, res: Response) => {
    try {
        const firmalar = await prisma.firma.findMany({ select: { firma_id: true, firma_adi: true } });
        res.json({ success: true, firmalar });
    } catch (error) {
        res.status(500).json({ success: false, message: "Firmalar listelenirken bir hata olustu." });
    }
};

export const siralaRoller = async (req: Request, res: Response) => {
    try {
        const roller = await prisma.rol.findMany({ select: { rol_id: true, rol_adi: true } });
        res.json({ success: true, roller });
    } catch (error) {
        res.status(500).json({ success: false, message: "Roller listelenirken bir hata olustu." });
    }
};

export const siralaMakineTurleri = async (req: Request, res: Response) => {
    try {
        await ensureMakineTuruDurusMaliyetiColumn();
        const makineTurleri = await prisma.$queryRaw<any[]>`
            SELECT
                makine_tur_id,
                makine_tur_adi,
                saatlik_durus_maliyeti
            FROM makine_turu
            ORDER BY makine_tur_adi ASC
        `;

        res.json({ success: true, makineTurleri });
    } catch (error) {
        console.error("Makine turleri listeleme hatasi:", error);
        res.status(500).json({ success: false, message: "Makine turleri listelenirken bir hata olustu." });
    }
};

export const getMakineTuruDurusMaliyetleri = async (req: Request, res: Response) => {
    try {
        await ensureMakineTuruDurusMaliyetiColumn();
        const makineTurleri = await prisma.$queryRaw<any[]>`
            SELECT
                makine_tur_id,
                makine_tur_adi,
                saatlik_durus_maliyeti
            FROM makine_turu
            ORDER BY makine_tur_adi ASC
        `;

        res.json({ success: true, makineTurleri });
    } catch (error) {
        console.error("Durus maliyetleri listeleme hatasi:", error);
        res.status(500).json({ success: false, message: "Durus maliyetleri cekilemedi." });
    }
};

export const setMakineTuruDurusMaliyetleri = async (req: Request, res: Response) => {
    try {
        await ensureMakineTuruDurusMaliyetiColumn();
        const { makineTurleri } = req.body;

        if (!Array.isArray(makineTurleri)) {
            return res.status(400).json({ success: false, message: "Makine turleri listesi gecersiz." });
        }

        await prisma.$transaction(
            makineTurleri.map((tur: { makine_tur_id: number; saatlik_durus_maliyeti: number }) =>
                prisma.$executeRaw`
                    UPDATE makine_turu
                    SET saatlik_durus_maliyeti = ${Number(tur.saatlik_durus_maliyeti) || 0}
                    WHERE makine_tur_id = ${Number(tur.makine_tur_id)}
                `
            )
        );

        res.json({ success: true, message: "Saatlik durus maliyetleri basariyla guncellendi." });
    } catch (error) {
        console.error("Durus maliyetleri guncelleme hatasi:", error);
        res.status(500).json({ success: false, message: "Saatlik durus maliyetleri guncellenirken hata olustu." });
    }
};

export const getVardiyaSaatleri = async (req: Request, res: Response) => {
    try {
        const vardiyalar = await prisma.vardiya_saatleri.findMany({
            orderBy: { vardiya_id: "asc" }
        });
        res.json({ success: true, vardiyalar });
    } catch (error) {
        res.status(500).json({ success: false, message: "Vardiya saatleri cekilemedi." });
    }
};

export const setVardiyaSaatleri = async (req: Request, res: Response) => {
    try {
        const { vardiyalar } = req.body;

        if (!Array.isArray(vardiyalar)) {
            return res.status(400).json({ success: false, message: "Vardiya listesi gecersiz." });
        }

        await prisma.vardiya_saatleri.deleteMany({});
        const result = await prisma.vardiya_saatleri.createMany({
            data: vardiyalar
        });

        res.json({ success: true, message: "Vardiya saatleri basariyla guncellendi.", count: result.count });
    } catch (error) {
        res.status(500).json({ success: false, message: "Vardiya saatleri guncellenirken hata olustu." });
    }
};

//ariza türleri listesi API
export const siralaArizaTurleri = async (req: Request, res: Response) => {
    try {
        const makine_tur_id = req.query.makine_tur_id;
        let whereClause = {};
        if (makine_tur_id) {
             whereClause = {
                  OR: [
                      { makine_tur_id: Number(makine_tur_id) },
                      { makine_tur_id: null }
                  ]
             };
        }
        const arizaTurleri = await prisma.ariza_turu.findMany({ 
             where: whereClause,
             select: { ariza_tur_id: true, ariza_tur: true } 
        });
        res.json({ success: true, arizaTurleri });
    } catch (error) {
        res.status(500).json({ success: false, message: "Arıza türleri listelenirken bir hata oluştu." });
    }
};
