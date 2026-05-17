import express from "express";
import cors from "cors";
import { config } from "./config";
import routes from "./routes";
import { connectDB } from "./config/prisma";
import swaggerUi from 'swagger-ui-express';
import fs from 'fs';
import path from 'path';


const app = express();
// Veritabanı bağlantısını başlat
connectDB();


app.use(cors());

app.use(express.json());


app.use(express.urlencoded({ extended: true }));
// swagger.json dosyasını güvenli bir şekilde oku
const swaggerDocument = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'swagger.json'), 'utf8')
);

// Express uygulmana middleware olarak ekle (Örn: app.use altındaki rotaların oraya)
app.use(
    '/api-docs', 
    swaggerUi.serve as any, 
    swaggerUi.setup(swaggerDocument) as any
);
app.get("/api/health", (_req, res) => {
  res.status(200).json({
    success: true,
    message: "Endux Backend API çalışıyor!",
    timestamp: new Date().toISOString(),
  });
});

// API route'ları
app.use("/api", routes);

// 404 Catch-All (Bulunamayan rotalar için JSON döndür)
app.use((_req, res, _next) => {
  res.status(404).json({
    success: false,
    message: "İstek yapılan API rotası bulunamadı."
  });
});

// Global Error Handler (Hata durumlarında HTML yerine JSON döndürmek için)
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error("🚀 Sistem Hatası Yakalandı: ", err);

  // Veritabanı (Prisma) kaynaklı hataları tespit et
  if (err.name === "PrismaClientKnownRequestError" || err.name === "PrismaClientInitializationError") {
    res.status(500).json({
      success: false,
      message: "Veritabanına ulaşılamıyor veya veritabanı bağlantısında bir hata oluştu. Lütfen servislerin çalıştığından emin olun.",
      error: config.nodeEnv === "development" ? err.message : undefined
    });
    return;
  }

  // Varsayılan kaba sistem hata fırlatıcısı
  res.status(err.status || 500).json({
    success: false,
    message: err.message || "Sunucu tarafında beklenmeyen bir hata oluştu.",
    error: config.nodeEnv === "development" ? err.stack : undefined
  });
});
// swagger.json dosyasını güvenli bir şekilde oku

export default app;
