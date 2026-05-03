"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.supabase = void 0;
const supabase_js_1 = require("@supabase/supabase-js");
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
// .env dosyasındaki bilgileri alıyoruz
const supabaseUrl = process.env.SUPABASE_URL;
// Not: Backend tarafında tam yetki için ANON_KEY yerine SERVICE_ROLE_KEY kullanman daha güvenlidir, 
// ama şimdilik elindeki .env değişkeni neyse onu yazabilirsin.
const supabaseKey = process.env.SUPABASE_ANON_KEY;
// İstemciyi yarat ve dışa aktar
exports.supabase = (0, supabase_js_1.createClient)(supabaseUrl, supabaseKey);
