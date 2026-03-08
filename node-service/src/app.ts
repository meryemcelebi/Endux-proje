import express from "express";
import cors from "cors";
import { config } from "./config";
import routes from "./routes";


const app = express();




app.use(cors());

app.use(express.json());


app.use(express.urlencoded({ extended: true }));


app.get("/api/health", (_req, res) => {
  res.status(200).json({
    success: true,
    message: "Endux Backend API çalışıyor!",
    timestamp: new Date().toISOString(),
  });
});

// API route'ları
app.use("/api", routes);



export default app;
