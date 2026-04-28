import prisma from "./src/config/prisma";

async function main() {
  try {
    const res = await prisma.$queryRawUnsafe(`
      SELECT MAX(iletisim_id) FROM iletisim;
    `);
    console.log("Max iletisim_id:", res);

    const seq = await prisma.$queryRawUnsafe(`
      SELECT nextval('iletisim_iletisim_id_seq');
    `);
    console.log("Next val:", seq);

    await prisma.$queryRawUnsafe(`
      SELECT setval('iletisim_iletisim_id_seq', (SELECT MAX(iletisim_id) FROM iletisim));
    `);
    console.log("Sequence updated.");
  } catch (e) {
    console.error(e);
  } finally {
    await prisma.$disconnect();
  }
}
main();
