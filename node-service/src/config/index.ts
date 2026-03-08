import dotenv from "dotenv";
import path from "path";

// .env dosyasını projenin kök dizininden yükle
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

export const config = {
  port: parseInt(process.env.PORT || "3000", 10),
  databaseUrl: process.env.DATABASE_URL || "",
  nodeEnv: process.env.NODE_ENV || "development",
};

