import app from "./app";
import { config } from "./config";

const PORT = config.port;

app.listen(PORT, () => {
  console.log(`Endux Backend API ${PORT} portunda calisiyor`);
  console.log(`Ortam: ${config.nodeEnv}`);//Uygulamanın geliştirme mi yoksa production (canlı) modunda mı çalıştığını gösterir
});
