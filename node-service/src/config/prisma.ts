import { PrismaClient } from "@prisma/client";

// Singleton pattern: Tek bir PrismaClient instance'ı kullan
const prisma = new PrismaClient({
  log: ["query", "info", "warn", "error"],
});

export default prisma;
