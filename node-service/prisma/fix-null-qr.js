require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { Pool } = require('pg');
const { PrismaPg } = require('@prisma/adapter-pg');
const { v4: uuidv4 } = require('uuid');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const p = new PrismaClient({ adapter });

async function main() {
    const eksik = await p.makine.findMany({
        where: { makine_qr: null },
        select: { makine_id: true, makine_adi: true }
    });
    console.log('NULL QR makine sayisi:', eksik.length);
    for (const m of eksik) {
        const qr = uuidv4();
        await p.makine.update({ where: { makine_id: m.makine_id }, data: { makine_qr: qr } });
        console.log('Fixed QR:', m.makine_id, m.makine_adi, '->', qr);
    }

    const eksikPin = await p.makine.findMany({
        where: { servis_pin: null },
        select: { makine_id: true, makine_adi: true }
    });
    console.log('NULL PIN makine sayisi:', eksikPin.length);
    for (const m of eksikPin) {
        const pin = Math.floor(1000 + Math.random() * 9000);
        await p.makine.update({ where: { makine_id: m.makine_id }, data: { servis_pin: pin } });
        console.log('Fixed PIN:', m.makine_id, m.makine_adi, '->', pin);
    }
    console.log('Done!');
}

main().catch(console.error).finally(function() { return p['$disconnect'](); });
