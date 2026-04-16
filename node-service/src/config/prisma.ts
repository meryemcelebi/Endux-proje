import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import * as dotenv from 'dotenv';
import * as path from 'path';
dotenv.config({ path: path.join(__dirname, '../../../.env') }); // It is located at project root C:\Users\LENOVO\bitirme-projesi\.env
// But __dirname is inside src/config. Let's make it simpler, dotenv looks at cwd.

// Çevresel değişkenlerden bağlantı adresini alıyoruz
const connectionString = process.env.DATABASE_URL;

// pg kütüphanesi ile bir bağlantı havuzu (connection pool) oluşturuyoruz
const pool = new Pool({ connectionString });

// Prisma adaptörünü PostgreSQL havuzu ile bağlıyoruz
const adapter = new PrismaPg(pool);

// PrismaClient'ı yeni adaptör yapısıyla başlatıyoruz
const prisma = new PrismaClient({ adapter });

export const connectDB = async (): Promise<void> => {
  try {
    await prisma.$connect();
    console.log('Prisma ile veri tabanına bağlantı başarılı!');
  } catch (error) {
    console.error('Prisma veri tabanı bağlantısı hatalı:', error);
    process.exit(1);
  }
};

export default prisma;