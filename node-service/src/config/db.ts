import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';

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