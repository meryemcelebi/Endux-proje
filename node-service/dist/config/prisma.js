"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.connectDB = void 0;
const client_1 = require("@prisma/client");
const pg_1 = require("pg");
const adapter_pg_1 = require("@prisma/adapter-pg");
require("dotenv/config");
// Çevresel değişkenlerden bağlantı adresini alıyoruz
const connectionString = process.env.DATABASE_URL;
// pg kütüphanesi ile bir bağlantı havuzu (connection pool) oluşturuyoruz
const pool = new pg_1.Pool({ connectionString });
// Prisma adaptörünü PostgreSQL havuzu ile bağlıyoruz
const adapter = new adapter_pg_1.PrismaPg(pool);
// PrismaClient'ı yeni adaptör yapısıyla başlatıyoruz
const prisma = new client_1.PrismaClient({ adapter });
const connectDB = async () => {
    try {
        await prisma.$connect();
        console.log('Prisma ile veri tabanına bağlantı başarılı!');
    }
    catch (error) {
        console.error('Prisma veri tabanı bağlantısı hatalı:', error);
        process.exit(1);
    }
};
exports.connectDB = connectDB;
exports.default = prisma;
