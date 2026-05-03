"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const app_1 = __importDefault(require("./app"));
const config_1 = require("./config");
const PORT = config_1.config.port;
app_1.default.listen(PORT, () => {
    console.log(`Endux Backend API ${PORT} portunda calisiyor`);
    console.log(`Ortam: ${config_1.config.nodeEnv}`); //Uygulamanın geliştirme mi yoksa production (canlı) modunda mı çalıştığını gösterir
});
