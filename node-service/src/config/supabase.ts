import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as ws from 'ws';

dotenv.config();

// .env dosyasındaki bilgileri alıyoruz
const supabaseUrl = process.env.SUPABASE_URL as string;
// Not: Backend tarafında tam yetki için ANON_KEY yerine SERVICE_ROLE_KEY kullanman daha güvenlidir, 
// ama şimdilik elindeki .env değişkeni neyse onu yazabilirsin.
const supabaseKey = process.env.SUPABASE_ANON_KEY as string; 

// İstemciyi yarat ve dışa aktar
export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    persistSession: false,
  },
  realtime: {
    transport: ws as any,
  },
});