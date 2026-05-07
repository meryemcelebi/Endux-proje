require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function test() {
  try {
    await prisma.makine.findUnique({
      where: { makine_id: 102 },
      include: {
        firma: true,
        garanti_firma: { include: { iletisim: true } },
        makine_turu: true,
        bakim_kaydi: true,
        gunluk_kontrol_formu: true,
        makine_kullanim: true,
        ariza_kaydi: true,
        makine_ozellikleri: true,
        lokasyon: true
      }
    });
  } catch(e) {
    console.error('PRISMA ERROR:', e.message);
  } finally {
    await prisma.$disconnect();
  }
}
test();
