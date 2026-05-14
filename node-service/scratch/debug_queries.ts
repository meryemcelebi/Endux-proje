import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import 'dotenv/config';

const connectionString = process.env.DATABASE_URL;
const pool = new Pool({ connectionString });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function checkQueries() {
    try {
        console.log("Checking Query 6 (maliyetAnalizi)...");
        const maliyetAnalizi = await prisma.$queryRawUnsafe<any[]>(`
                SELECT 
                    (SELECT COALESCE(SUM(bakim_maliyet), 0)::FLOAT FROM bakim_kaydi bk 
                     JOIN bakim_turu bt ON bk.bakim_tur_id = bt.bakim_tur_id 
                     WHERE bt.bakim_tur_adi IN ('Planlı Bakım', 'Önleyici Bakım')) as planli_bakim_maliyeti,
                    
                    (SELECT COALESCE(SUM(bakim_maliyet), 0)::FLOAT FROM bakim_kaydi bk 
                     JOIN bakim_turu bt ON bk.bakim_tur_id = bt.bakim_tur_id 
                     WHERE bt.bakim_tur_adi NOT IN ('Planlı Bakım', 'Önleyici Bakım')) as arizi_bakim_maliyeti,
                    
                    (SELECT COALESCE(SUM(p.parca_maliyeti * COALESCE(pd.adet, 1)), 0)::FLOAT 
                     FROM parca_degisim pd 
                     JOIN parca p ON pd.parca_id = p.parca_id) as toplam_parca_masrafi,
                    
                    (SELECT COALESCE(SUM(bakim_maliyet), 0)::FLOAT FROM bakim_kaydi WHERE sorumlu_id IS NOT NULL) as dis_servis_maliyeti,
                    
                    (SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (bk.bakim_tarihi - ak.olusturma_tarihi))/3600), 0)::FLOAT * 500 
                     FROM bakim_kaydi bk 
                     JOIN ariza_kaydi ak ON bk.ariza_id = ak.ariza_id) as durus_maliyeti,

                    (SELECT COALESCE(SUM(satin_alma_maliyeti), 0)::FLOAT FROM makine) as toplam_makine_alim
        `);
        console.log("Query 6 OK");

        console.log("Checking Query 7 (makineBazliMaliyetler)...");
        const makineBazliMaliyetler = await prisma.$queryRawUnsafe<any[]>(`
                SELECT 
                    m.makine_id,
                    m.makine_adi,
                    l.lokasyon_adi,
                    COALESCE(SUM(CASE WHEN bt.bakim_tur_adi IN ('Planlı Bakım', 'Önleyici Bakım') THEN bk.bakim_maliyet ELSE 0 END), 0)::FLOAT as planli_maliyet,
                    COALESCE(SUM(CASE WHEN bt.bakim_tur_adi NOT IN ('Planlı Bakım', 'Önleyici Bakım') THEN bk.bakim_maliyet ELSE 0 END), 0)::FLOAT as arizi_maliyet,
                    COALESCE(SUM(CASE WHEN bk.sorumlu_id IS NOT NULL THEN bk.bakim_maliyet ELSE 0 END), 0)::FLOAT as dis_servis_maliyet,
                    COALESCE((SELECT SUM(p.parca_maliyeti * COALESCE(pd.adet, 1)) FROM parca_degisim pd JOIN parca p ON pd.parca_id = p.parca_id WHERE pd.bakim_id IN (SELECT bakim_id FROM bakim_kaydi WHERE makine_id = m.makine_id)), 0)::FLOAT as parca_maliyeti,
                    COALESCE(SUM(EXTRACT(EPOCH FROM (bk.bakim_tarihi - ak.olusturma_tarihi))/3600), 0)::FLOAT as toplam_durus_suresi,
                    (COALESCE(SUM(EXTRACT(EPOCH FROM (bk.bakim_tarihi - ak.olusturma_tarihi))/3600), 0)::FLOAT * 500) as durus_kaybi_maliyeti
                FROM makine m
                LEFT JOIN lokasyon l ON m.makine_id = l.makine_id
                LEFT JOIN bakim_kaydi bk ON m.makine_id = bk.makine_id
                LEFT JOIN bakim_turu bt ON bk.bakim_tur_id = bt.bakim_tur_id
                LEFT JOIN ariza_kaydi ak ON bk.ariza_id = ak.ariza_id
                GROUP BY m.makine_id, m.makine_adi, l.lokasyon_adi
                LIMIT 20
        `);
        console.log("Query 7 OK");

        console.log("Checking Query 8 (parcaKategoriMaliyetleri)...");
        const parcaKategoriMaliyetleri = await prisma.$queryRawUnsafe<any[]>(`
                SELECT 
                    pk.kategori_adi as kategori,
                    l.lokasyon_adi as lokasyon,
                    SUM(p.parca_maliyeti * COALESCE(pd.adet, 1))::FLOAT as maliyet
                FROM parca_degisim pd
                JOIN parca p ON pd.parca_id = p.parca_id
                JOIN parca_kategori pk ON p.kategori_id = pk.kategori_id
                JOIN bakim_kaydi bk ON pd.bakim_id = bk.bakim_id
                JOIN makine m ON bk.makine_id = m.makine_id
                LEFT JOIN lokasyon l ON m.makine_id = l.makine_id
                GROUP BY pk.kategori_adi, l.lokasyon_adi
        `);
        console.log("Query 8 OK");

    } catch (e: any) {
        console.error("ERROR FOUND:");
        console.error(e.message);
        if (e.meta) console.error("META:", e.meta);
        if (e.code) console.error("CODE:", e.code);
    } finally {
        await prisma.$disconnect();
    }
}

checkQueries();
