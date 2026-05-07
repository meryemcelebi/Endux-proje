require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { Pool } = require('pg');
const { PrismaPg } = require('@prisma/adapter-pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function test() {
  try {
    const users = await prisma.kullanici.findMany();
    console.log("USERS:", users);
  } catch (err) {
    console.error("DB ERROR:", err);
  } finally {
    await prisma.$disconnect();
    await pool.end();
  }
}

test();
