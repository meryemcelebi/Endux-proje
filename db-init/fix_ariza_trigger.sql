-- ═══════════════════════════════════════════════════════════════
-- Arıza Kaydı olusturma_tarihi düzeltmesi
-- 
-- trg_bakim_ariza_kapat trigger'ı init.sql'de zaten mevcut.
-- Bu script sadece olusturma_tarihi NULL sorununu çözer.
-- ═══════════════════════════════════════════════════════════════

-- 1. olusturma_tarihi kolonuna DEFAULT değer ekle
ALTER TABLE public.ariza_kaydi 
ALTER COLUMN olusturma_tarihi SET DEFAULT CURRENT_TIMESTAMP;

-- 2. Mevcut null olusturma_tarihi kayıtlarını düzelt
UPDATE public.ariza_kaydi
SET olusturma_tarihi = COALESCE(baslangic_zamani, CURRENT_TIMESTAMP)
WHERE olusturma_tarihi IS NULL;
