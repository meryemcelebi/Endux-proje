/**
 * makine_qr alanı NULL olan makinelere UUID atar.
 * Kullanım: npx ts-node prisma/fix-null-qr.ts
 */
import { PrismaClient } from '@prisma/client';
import { v4 as uuidv4 } from 'uuid';

const prisma = new PrismaClient();

async function main() {
    const eksikQR = await prisma.makine.findMany({
        where: { makine_qr: null },
        select: { makine_id: true, makine_adi: true }
    });

    if (eksikQR.length === 0) {
        console.log('✅ Tüm makinelerde makine_qr tanımlı. İşlem gerekmiyor.');
        return;
    }

    console.log(`⚠️ ${eksikQR.length} makinede makine_qr NULL. UUID atanıyor...\n`);

    for (const m of eksikQR) {
        const yeniQR = uuidv4();
        await prisma.makine.update({
            where: { makine_id: m.makine_id },
            data: { makine_qr: yeniQR }
        });
        console.log(`  ✔ [${m.makine_id}] ${m.makine_adi} → ${yeniQR}`);
    }

    // servis_pin de NULL olanlara PIN ata
    const eksikPIN = await prisma.makine.findMany({
        where: { servis_pin: null },
        select: { makine_id: true, makine_adi: true }
    });

    if (eksikPIN.length > 0) {
        console.log(`\n⚠️ ${eksikPIN.length} makinede servis_pin NULL. PIN atanıyor...\n`);
        for (const m of eksikPIN) {
            const pin = Math.floor(1000 + Math.random() * 9000);
            await prisma.makine.update({
                where: { makine_id: m.makine_id },
                data: { servis_pin: pin }
            });
            console.log(`  ✔ [${m.makine_id}] ${m.makine_adi} → PIN: ${pin}`);
        }
    }

    console.log('\n✅ Tüm eksik QR kodları ve PIN\'ler atandı.');
}

main()
    .catch(e => { console.error('Hata:', e); process.exit(1); })
    .finally(() => prisma.$disconnect());
