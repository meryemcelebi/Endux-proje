--
-- PostgreSQL database dump
--

\restrict sepMLwq5A1LybXXt70KpFr3uhY5ATccGADNPY2grY7MR9VPZDHTpeiPIfofWPNs

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

-- Started on 2026-04-16 13:00:00

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 4 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- TOC entry 3928 (class 0 OID 0)
-- Dependencies: 4
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 929 (class 1247 OID 16390)
-- Name: du_ort_yuk; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.du_ort_yuk AS ENUM (
    'DUSUK',
    'ORTA',
    'YUKSEK'
);


--
-- TOC entry 296 (class 1255 OID 50070)
-- Name: fn_bakim_girince_arizayi_kapat(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_bakim_girince_arizayi_kapat() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Bakım yapılan makinenin, bitiş tarihi henüz girilmemiş (açık) olan
    -- en son arıza kaydını bul ve bakım tarihiyle güncelle.
    UPDATE public.ariza_kaydi
    SET bitis_zamani = NEW.bakim_tarihi -- Bakım tablosundaki tarih
    WHERE makine_id = NEW.makine_id 
    AND bitis_zamani IS NULL;

    RETURN NEW;
END;
$$;


--
-- TOC entry 294 (class 1255 OID 16397)
-- Name: func_form_sonrasi_tetikle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.func_form_sonrasi_tetikle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
call pr_makine_operator(NEW.kullanim_id, NEW.makine_id);--prosedür cağırdık
update makine  
set mevcut_risk_skoru=NEW.ai_on_risk_durumu
where makine_id=NEW.makine_id;--operatörün girdiği risk degeri ile tabloyu güncelledik
return NEW;
end;
$$;


--
-- TOC entry 309 (class 1255 OID 33187)
-- Name: get_sorular(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_sorular(makine_qr integer) RETURNS TABLE(soru_tipi text, id integer, madde_adi text, teknik_parametre text, kritiklik_durumu boolean)
    LANGUAGE sql
    AS $$

    -- 1. Genel Sorular
    SELECT 
        'genel' AS soru_tipi,
        gs.genel_soru_id AS id,
        gs.madde_adi,
        gs.teknik_parametre,
		gs.kritiklik_durumu
    FROM public.genel_sorular gs
    WHERE gs.aktiflik = true

    UNION ALL

    -- 2. Makineye Özel Sorular
    SELECT 
        'ozel' AS soru_tipi,
        km.madde_id AS id,
        km.madde_adi,
        km.teknik_parametre,
        km.kritiklik_durumu
    FROM public.makine m
    JOIN public.kontrol_sablonu ks 
        ON m.m_tur_id = ks.makine_tur_id
    JOIN public.kontrol_maddesi km 
        ON ks.sablon_id = km.sablon_id
    WHERE m.makine_id = makine_qr::INT
      AND ks.aktiflik = true;

$$;


--
-- TOC entry 312 (class 1255 OID 50074)
-- Name: pr_ariza_kayit(character varying, character varying, character varying, text, date); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pr_ariza_kayit(IN p_makine_adi character varying, IN p_ariza_tur_adi character varying, IN p_tespit_kaynagi character varying, IN p_aciklama text, IN p_baslangic_zamani date)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_makine_id INTEGER;
    v_tur_id INTEGER;
BEGIN
    -- 1. Makine Adından ID'yi bul
    SELECT makine_id INTO v_makine_id 
    FROM public.makine 
    WHERE LOWER(makine_adi) = LOWER(p_makine_adi);

    -- Makine bulunamazsa hata döndür
    IF v_makine_id IS NULL THEN
        RAISE EXCEPTION 'Makine bulunamadı: %', p_makine_adi;
    END IF;

    -- 2. Arıza türü kontrolü (Yoksa ekle)
    SELECT ariza_tur_id INTO v_tur_id 
    FROM public.ariza_turu 
    WHERE LOWER(ariza_tur) = LOWER(p_ariza_tur_adi);

    IF v_tur_id IS NULL THEN
        INSERT INTO public.ariza_turu (ariza_tur) 
        VALUES (p_ariza_tur_adi) 
        RETURNING ariza_tur_id INTO v_tur_id;
    END IF;

    -- 3. Kaydı Ekle
    INSERT INTO public.ariza_kaydi (
        makine_id, 
        ariza_tur_id, 
		makine_adi,
        ariza_tespit_kaynagi, 
        ariza_aciklama, 
        baslangic_zamani, 
        olusturma_tarihi
    )
    VALUES (
        v_makine_id, 
        v_tur_id, 
		p_makine_adi,
        p_tespit_kaynagi, 
        p_aciklama, 
        p_baslangic_zamani, 
        CURRENT_TIMESTAMP
    );
END;
$$;


--
-- TOC entry 310 (class 1255 OID 33189)
-- Name: pr_kontrol_kaydet(integer, integer, integer, text, jsonb); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pr_kontrol_kaydet(IN p_makine_id integer, IN p_kullanici_id integer, IN p_sablon_id integer, IN p_genel_not text, IN p_cevaplar jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_form_id INT;
    v_cevap RECORD;
BEGIN
    -- 1. Ana Formu oluştur ve ID'sini al
    INSERT INTO public.gunluk_kontrol_formu (
        makine_id, kullanici_id, sablon_id, kontrol_tarihi, genel_not
    )
    VALUES (
        p_makine_id, p_kullanici_id, p_sablon_id, CURRENT_DATE, p_genel_not
    )
    RETURNING form_id INTO v_form_id;

    -- 2. JSON'ı satırlara parçala ve tek tek tabloya bas
    FOR v_cevap IN SELECT * FROM jsonb_to_recordset(p_cevaplar) 
        AS x(res_id INT, s_tipi TEXT, s_durum VARCHAR, s_deger NUMERIC, s_not TEXT)
    LOOP
        INSERT INTO public.form_madde_cevap (
            form_id, 
            soru_referans_id, 
            soru_tipi, 
            durum, 
            aciklama, 
            girilen_deger
        )
        VALUES (
            v_form_id, 
            v_cevap.res_id, 
            v_cevap.s_tipi, 
            v_cevap.s_durum, 
            v_cevap.s_not, 
            v_cevap.s_deger
        );
    END LOOP;
END;
$$;


--
-- TOC entry 295 (class 1255 OID 16398)
-- Name: pr_makine_operator(); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pr_makine_operator()
    LANGUAGE sql
    AS $_$--prosedür parametreleri oluşturduk
create or replace procedure pr_makine_kullanim(p_operator_id INT,p_makine_id INT)
as $$
update makine_kullanim set bitis_zamani=CURRENT_TIMESTAMP --operatörün kapanmamış önceki oturumlarını kapattık
where kullanici_id=p_operator_id and bitis_zamani not null;
insert into makine_kullanim(kullanici_id, makine_id, baslangic_zamani)
values(p_operator_id, p_makine_id, CURRENT_TIMESTAMP); $$--yeni oturum için kayıt açtık
$_$;


--
-- TOC entry 297 (class 1255 OID 50095)
-- Name: sp_bakim_ekle(character varying, character varying, character varying, numeric, text, character varying, character varying, numeric, character varying, text[]); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_bakim_ekle(IN p_makine_adi character varying, IN p_bakim_yapan_kisi character varying, IN p_servis_firma_adi character varying, IN p_bakim_maliyet numeric, IN p_aciklama text, IN p_ariza_tanimi character varying, IN p_bakim_turu_adi character varying, IN p_durus_suresi numeric, IN p_firma_telefon character varying, IN p_degisen_parcalar text[] DEFAULT '{}'::text[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- METİN TEMİZLEME
    v_clean_makine_adi varchar := UPPER(TRIM(p_makine_adi));
    v_clean_bakim_yapan varchar := UPPER(TRIM(p_bakim_yapan_kisi));
    v_clean_firma_adi varchar := UPPER(TRIM(p_servis_firma_adi));
    v_clean_ariza_tanimi varchar := UPPER(TRIM(p_ariza_tanimi));
    v_clean_bakim_turu varchar := UPPER(TRIM(p_bakim_turu_adi));
    
    -- BURASI EKLENDİ: Döngü içinde kullandığınız temizlenmiş parça adı değişkeni
    v_clean_parca_adi varchar; 

    -- ID TUTUCULAR
    v_makine_id integer;
    v_sorumlu_id integer;       
    v_servis_firma_id integer;  
    v_ariza_id integer;         
    v_bakim_tur_id integer;     
    v_yeni_bakim_id integer;
    v_iletisim_id integer; 
    
    -- PARÇA İŞLEMLERİ İÇİN
    v_parca_id integer;
    v_parca_adi text;
BEGIN
    -- ==========================================
    -- 1. MAKİNE KONTROLÜ
    -- ==========================================
    SELECT makine_id INTO v_makine_id FROM public.makine WHERE UPPER(TRIM(makine_adi)) = v_clean_makine_adi;
    IF v_makine_id IS NULL THEN
        RAISE EXCEPTION 'İşlem durduruldu: "%" adında bir makine bulunamadı!', v_clean_makine_adi;
    END IF;

    -- ==========================================
    -- 2. BAKIM YAPAN KİŞİ (OPERATÖR / SERVİS) KONTROLÜ
   SELECT kullanici_id INTO v_sorumlu_id FROM public.kullanici WHERE UPPER(TRIM(kullanici_adi)) = v_clean_bakim_yapan;

    -- Eğer kullanıcı tablosunda yoksa, servis sorumlusu tablosuna bakıyoruz
    IF v_sorumlu_id IS NULL THEN
        SELECT sorumlu_id INTO v_sorumlu_id FROM public.servis_sorumlusu WHERE UPPER(TRIM(sorumlu_adi)) = v_clean_bakim_yapan;
        
        IF v_sorumlu_id IS NULL THEN
            RAISE EXCEPTION 'İşlem durduruldu! "%" isimli personel ne kullanıcı ne de servis sorumlusu listesinde bulunamadı.', v_clean_bakim_yapan;
        END IF;
    END IF;
        
    -- ==========================================
    -- 3. SERVİS FİRMASI VE İLETİŞİM KONTROLÜ
    -- ==========================================
    IF p_firma_telefon IS NOT NULL AND TRIM(p_firma_telefon) <> '' THEN
        SELECT iletisim_id INTO v_iletisim_id FROM public.iletisim WHERE TRIM(telefon) = TRIM(p_firma_telefon);
        
        IF v_iletisim_id IS NULL THEN
             v_iletisim_id := NULL; 
        END IF;
    ELSE
        v_iletisim_id := NULL;
    END IF;
    
    IF v_clean_firma_adi IS NOT NULL AND v_clean_firma_adi <> '' THEN
        SELECT servis_firma_id INTO v_servis_firma_id FROM public.servis_firma WHERE UPPER(TRIM(firma_adi)) = v_clean_firma_adi;
        
        IF v_servis_firma_id IS NULL THEN
            INSERT INTO public.servis_firma (firma_adi, aktiflik, iletisim_id) 
            VALUES (v_clean_firma_adi, TRUE, v_iletisim_id) 
            RETURNING servis_firma_id INTO v_servis_firma_id;
        END IF;
    ELSE
        v_servis_firma_id := NULL;
    END IF;

    -- ==========================================
    -- 4. ARIZA KAYDI KONTROLÜ
    -- ==========================================
	
  IF v_clean_ariza_tanimi IS NOT NULL AND v_clean_ariza_tanimi <> '' THEN
    SELECT ak.ariza_id INTO v_ariza_id 
    FROM public.ariza_kaydi ak
    INNER JOIN public.ariza_turu at ON at.ariza_tur_id = ak.ariza_tur_id -- 'ON' kullanılmalı
    WHERE UPPER(TRIM(at.ariza_tur)) = v_clean_ariza_tanimi
    LIMIT 1; -- Birden fazla kayıt gelme ihtimaline karşı
        
        IF v_ariza_id IS NULL THEN 
            RAISE NOTICE 'Girilen arıza tanımı sistemde bulunamadı, ariza_id boş geçiliyor.';
            v_ariza_id := NULL;
        END IF;
    ELSE
        v_ariza_id := NULL;
    END IF;

    -- ==========================================
    -- 5. BAKIM TÜRÜ KONTROLÜ
    -- ==========================================
    SELECT bakim_tur_id INTO v_bakim_tur_id FROM public.bakim_turu WHERE UPPER(TRIM(bakim_tur_adi)) = v_clean_bakim_turu;
    
    IF v_bakim_tur_id IS NULL THEN
        INSERT INTO public.bakim_turu (bakim_tur_adi) VALUES (v_clean_bakim_turu) RETURNING bakim_tur_id INTO v_bakim_tur_id;
    END IF;

    -- ==========================================
    -- 6. BAKIM KAYDINI OLUŞTUR
    -- ==========================================
    INSERT INTO public.bakim_kaydi (
        makine_id, 
        sorumlu_id,       
        servis_firma_id,  
        bakim_tarihi,
        bakim_maliyet, 
        aciklama, 
        ariza_id,       
        bakim_tur_id,   
        durus_suresi
    ) VALUES (
        v_makine_id, 
        v_sorumlu_id,    
        v_servis_firma_id, 
        CURRENT_TIMESTAMP, 
        p_bakim_maliyet, 
        p_aciklama, 
        v_ariza_id,       
        v_bakim_tur_id,   
        p_durus_suresi
    ) RETURNING bakim_id INTO v_yeni_bakim_id;

    -- ==========================================
    -- 7. DEĞİŞEN PARÇALARI EKLE (KATI KONTROL)
    -- ==========================================
    IF array_length(p_degisen_parcalar, 1) > 0 THEN
        FOREACH v_parca_adi IN ARRAY p_degisen_parcalar
        LOOP
            v_clean_parca_adi := UPPER(TRIM(v_parca_adi)); 
            
            -- 1. Parça var mı kontrol et
            SELECT parca_id INTO v_parca_id
            FROM public.parca
            WHERE UPPER(TRIM(parca_adi)) = v_clean_parca_adi
            LIMIT 1;

            -- 2. PARÇA YOKSA İŞLEMİ İPTAL ET (Frontend'i uyar)
            IF v_parca_id IS NULL THEN
                RAISE EXCEPTION 'Kayıt Hatası: "%" isimli parça sistemde tanımlı değil! Lütfen önce parçayı Parça Tanımlama ekranından sisteme ekleyin.', v_clean_parca_adi;
            END IF;

            -- 3. Parça bulunduysa Bakım-parça ilişkisini ekle
            INSERT INTO public.parca_degisim (bakim_id, parca_id)
            VALUES (v_yeni_bakim_id, v_parca_id);

        END LOOP;
    END IF;

-- BURASI DÜZELTİLDİ: Ana BEGIN bloğunun kapanışı ve dil tanımlaması
END;
$$;


--
-- TOC entry 311 (class 1255 OID 50034)
-- Name: sp_garanti_firmasi_kaydet(character varying, character varying, character varying, character varying, character varying, character varying, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_garanti_firmasi_kaydet(IN p_garanti_firma_adi character varying, IN p_telefon character varying, IN p_email character varying, IN p_il character varying, IN p_ilce character varying, IN p_acik_adres character varying, INOUT p_out_garanti_firma_id integer DEFAULT NULL::integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_iletisim_id INTEGER;
    v_clean_g_firma VARCHAR := UPPER(TRIM(p_garanti_firma_adi));
BEGIN
    -- 1. İLETİŞİM BİLGİSİ KONTROLÜ VE EKLENMESİ
    SELECT iletisim_id INTO v_iletisim_id 
    FROM iletisim 
    WHERE telefon = p_telefon AND email = p_email; 

    IF v_iletisim_id IS NULL THEN
        INSERT INTO iletisim (telefon, email, il, ilce, acik_adres) 
        VALUES (p_telefon, p_email, p_il, p_ilce, p_acik_adres) 
        RETURNING iletisim_id INTO v_iletisim_id;
    END IF;

    -- 2. GARANTİ FİRMASI KONTROLÜ VE EKLENMESİ
    SELECT garanti_firma_id INTO p_out_garanti_firma_id 
    FROM garanti_firma 
    WHERE UPPER(TRIM(g_firma_adi)) = v_clean_g_firma;

    IF p_out_garanti_firma_id IS NULL THEN
        INSERT INTO garanti_firma (g_firma_adi, iletisim_id) 
        VALUES (v_clean_g_firma, v_iletisim_id) 
        RETURNING garanti_firma_id INTO p_out_garanti_firma_id;
    END IF;

    COMMIT;
END;
$$;


--
-- TOC entry 313 (class 1255 OID 50037)
-- Name: sp_makine_temel_kaydet(character varying, character varying, character varying, character varying, character varying, date, numeric, integer, integer, numeric, integer, jsonb, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_makine_temel_kaydet(IN p_firma_adi character varying, IN p_makine_tur_adi character varying, IN p_makine_ad character varying, IN p_makine_qr character varying, IN p_seri_no character varying, IN p_satin_alma_tarihi date, IN p_satin_alma_maliyeti numeric, IN p_garanti_suresi integer, IN p_toplam_calisma_saati integer, IN p_risk_katsayisi numeric, IN p_servis_pin integer, IN p_teknik_ozellikler jsonb, IN p_telefon character varying DEFAULT NULL::character varying, IN p_email character varying DEFAULT NULL::character varying, IN p_il character varying DEFAULT NULL::character varying, IN p_ilce character varying DEFAULT NULL::character varying, IN p_acik_adres character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_firma_id INTEGER;
    v_m_tur_id INTEGER;
    v_makine_id INTEGER;
    v_garanti_firma_id INTEGER := NULL; -- Başlangıçta NULL olarak belirliyoruz
    v_garanti_suresi INTEGER := p_garanti_suresi; -- Süreyi değiştirebilmek için değişkene atıyoruz
    
    v_clean_firma VARCHAR := UPPER(TRIM(p_firma_adi));
    v_clean_tur VARCHAR := UPPER(TRIM(p_makine_tur_adi));
BEGIN
    -- 1. SAHİP FİRMA KONTROLÜ
    SELECT firma_id INTO v_firma_id FROM firma WHERE UPPER(TRIM(firma_adi)) = v_clean_firma;
    IF v_firma_id IS NULL THEN
        INSERT INTO firma (firma_adi) VALUES (v_clean_firma) RETURNING firma_id INTO v_firma_id;
    END IF;

    -- 2. MAKİNE TÜRÜ KONTROLÜ
    SELECT makine_tur_id INTO v_m_tur_id FROM makine_turu WHERE UPPER(TRIM(makine_tur_adi)) = v_clean_tur;
    IF v_m_tur_id IS NULL THEN
        INSERT INTO makine_turu (makine_tur_adi, risk_katsayisi) VALUES (v_clean_tur, p_risk_katsayisi) RETURNING makine_tur_id INTO v_m_tur_id;
    END IF;


    -- 4. ANA MAKİNE TABLOSUNA KAYIT
    INSERT INTO makine (
        firma_id, makine_tur_id, garanti_firma_id, 
        makine_qr, makine_adi, seri_no, 
        satin_alma_tarihi, satin_alma_maliyeti, 
        garanti_suresi, toplam_calisma_saati, 
        servis_pin, aktiflik_durumu
    )
    VALUES (
        v_firma_id, v_m_tur_id, v_garanti_firma_id, 
        p_makine_qr, p_makine_ad, p_seri_no, 
        p_satin_alma_tarihi, p_satin_alma_maliyeti, 
        v_garanti_suresi, p_toplam_calisma_saati, 
        p_servis_pin, true
    )
    RETURNING makine_id INTO v_makine_id;

    -- 5. MAKİNE ÖZELLİKLERİ TABLOSUNA KAYIT
    INSERT INTO makine_ozellikleri (makine_id, teknik_ozellikler, guncelleme_tarihi)
    VALUES (v_makine_id, p_teknik_ozellikler, CURRENT_TIMESTAMP);

    COMMIT;
    RAISE NOTICE 'İşlem Başarılı: Makine % kaydedildi. Garanti ID: %', p_makine_ad, v_garanti_firma_id;
END;
$$;


--
-- TOC entry 314 (class 1255 OID 50100)
-- Name: sp_parca_ekle(text, numeric, integer, integer, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_parca_ekle(IN p_parca_adi text, IN p_tahmini_omur_saati numeric, IN p_parca_maliyeti integer, IN p_tedarik_gun_suresi integer, IN p_kategori_adi character varying, IN p_tedarikci_firma_adi character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_clean_parca_adi text := UPPER(TRIM(p_parca_adi));
    v_clean_kategori_adi varchar := UPPER(TRIM(p_kategori_adi));
    v_clean_tedarikci_adi varchar := UPPER(TRIM(p_tedarikci_firma_adi));
    
    v_kategori_id integer;
    v_tedarikci_id integer;
    v_yeni_parca_id integer;
BEGIN
    -- 1. Parça mükerrer kontrolü
    IF EXISTS (SELECT 1 FROM public.parca WHERE UPPER(TRIM(parca_adi)) = v_clean_parca_adi) THEN
        RAISE EXCEPTION 'HATA: % isimli parça zaten mevcut!', v_clean_parca_adi;
    END IF;

    -- 2. Kategori kontrolü/ekleme
    SELECT kategori_id INTO v_kategori_id FROM public.parca_kategori 
    WHERE UPPER(TRIM(kategori_adi)) = v_clean_kategori_adi;

    IF v_kategori_id IS NULL THEN
        INSERT INTO public.parca_kategori (kategori_adi) VALUES (v_clean_kategori_adi)
        RETURNING kategori_id INTO v_kategori_id;
    END IF;

    -- 3. Tedarikçi Kontrolü (KRİTİK NOKTA)
    SELECT tedarikci_id INTO v_tedarikci_id FROM public.tedarikci 
    WHERE UPPER(TRIM(firma_adi)) = v_clean_tedarikci_adi;

    -- Firma bulunamazsa hata fırlat ve işlemi durdur
    IF v_tedarikci_id IS NULL THEN
        RAISE EXCEPTION 'Kayıt Başarısız: "%" isimli tedarikçi sistemde kayıtlı değil! Lütfen önce Tedarikçi Ekleme ekranından firma ve iletişim bilgilerini tanımlayınız.', v_clean_tedarikci_adi;
    END IF;

    -- 4. Parçayı Ekle
    INSERT INTO public.parca (
        parca_adi, tahmini_omur_saati, parca_maliyeti, 
        tedarik_gun_suresi, kategori_id, tedarikci_id
    )
    VALUES (
        v_clean_parca_adi, p_tahmini_omur_saati, p_parca_maliyeti, 
        p_tedarik_gun_suresi, v_kategori_id, v_tedarikci_id
    ) RETURNING parca_id INTO v_yeni_parca_id;

    RAISE NOTICE 'Parça başarıyla eklendi. ID: %', v_yeni_parca_id;
END;
$$;


--
-- TOC entry 315 (class 1255 OID 50108)
-- Name: sp_tedarikci_ekle(character varying, character varying, character varying, character varying, character varying, text, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_tedarikci_ekle(IN p_firma_adi character varying, IN p_telefon character varying, IN p_mail character varying, IN p_il character varying, IN p_ilce character varying, IN p_acik_adres text, IN p_vergi_no character varying, IN p_yetkili_kisi character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_iletisim_id integer;
    v_tedarikci_id integer; -- Kendi içinde tutması için yerel değişken
    v_clean_firma text := UPPER(TRIM(p_firma_adi));
BEGIN
    -- 1. İLETİŞİM KONTROLÜ
    SELECT iletisim_id INTO v_iletisim_id FROM public.iletisim WHERE telefon = p_telefon;

    IF v_iletisim_id IS NULL THEN
        INSERT INTO public.iletisim (telefon, mail, il, ilce, acik_adres)
        VALUES (p_telefon, p_mail, p_il, p_ilce, p_acik_adres)
        RETURNING iletisim_id INTO v_iletisim_id;
    END IF;

    -- 2. TEDARİKÇİ KAYDI
    -- Burada SERIAL/IDENTITY devreye girer, kullanıcı hiçbir şey girmez.
    INSERT INTO public.tedarikci (firma_adi, aktiflik, iletisim_id, vergi_no, yetkili_kisi, kayit_tarihi)
    VALUES (v_clean_firma, true, v_iletisim_id, p_vergi_no, p_yetkili_kisi, CURRENT_DATE)
    RETURNING tedarikci_id INTO v_tedarikci_id;

    -- İşlem sonucu bilgi mesajı olarak döner
    RAISE NOTICE 'Sisteme yeni tedarikçi başarıyla tanımlandı: % (Atanan ID: %)', v_clean_firma, v_tedarikci_id;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 285 (class 1259 OID 49938)
-- Name: abonelik_tipi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.abonelik_tipi (
    abonelik_tip_id integer NOT NULL,
    abonelik_adi character varying(50) NOT NULL
);


--
-- TOC entry 284 (class 1259 OID 49937)
-- Name: abonelik_tipi_abonelik_tip_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.abonelik_tipi_abonelik_tip_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3929 (class 0 OID 0)
-- Dependencies: 284
-- Name: abonelik_tipi_abonelik_tip_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.abonelik_tipi_abonelik_tip_id_seq OWNED BY public.abonelik_tipi.abonelik_tip_id;


--
-- TOC entry 215 (class 1259 OID 16399)
-- Name: ai_ariza_tespit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_ariza_tespit (
    tespit_id integer NOT NULL,
    makine_id integer NOT NULL,
    form_id integer NOT NULL,
    madde_id integer NOT NULL,
    tahmin_edilen_ariza character varying(200),
    risk_skoru numeric(3,2),
    tespit_tarihi timestamp with time zone,
    model_versiyon character varying(100),
    tahmini_durus_suresi numeric(6,2),
    tahmini_maliyet numeric(12,2)
);


--
-- TOC entry 216 (class 1259 OID 16402)
-- Name: ai_ariza_tespit_tespit_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_ariza_tespit_tespit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3930 (class 0 OID 0)
-- Dependencies: 216
-- Name: ai_ariza_tespit_tespit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_ariza_tespit_tespit_id_seq OWNED BY public.ai_ariza_tespit.tespit_id;


--
-- TOC entry 217 (class 1259 OID 16403)
-- Name: ai_model_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_model_log (
    log_id integer NOT NULL,
    makine_id integer NOT NULL,
    model_versiyon character varying(100),
    kullanilan_veri_sayisi integer,
    tahmin_risk numeric(5,2),
    tahmin_tarihi timestamp with time zone,
    kullanici_id integer NOT NULL,
    form_id integer
);


--
-- TOC entry 218 (class 1259 OID 16408)
-- Name: ai_model_log_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_model_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3931 (class 0 OID 0)
-- Dependencies: 218
-- Name: ai_model_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_model_log_log_id_seq OWNED BY public.ai_model_log.log_id;


--
-- TOC entry 219 (class 1259 OID 16409)
-- Name: ariza_kaydi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ariza_kaydi (
    ariza_id integer NOT NULL,
    makine_id integer NOT NULL,
    ariza_tespit_kaynagi character varying(100) NOT NULL,
    ariza_aciklama text,
    baslangic_zamani timestamp with time zone,
    bitis_zamani timestamp with time zone,
    olusturma_tarihi timestamp with time zone,
    ariza_tur_id integer NOT NULL,
    makine_adi character varying(50)
);


--
-- TOC entry 220 (class 1259 OID 16414)
-- Name: ariza_kaydi_ariza_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ariza_kaydi_ariza_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3932 (class 0 OID 0)
-- Dependencies: 220
-- Name: ariza_kaydi_ariza_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ariza_kaydi_ariza_id_seq OWNED BY public.ariza_kaydi.ariza_id;


--
-- TOC entry 262 (class 1259 OID 33191)
-- Name: ariza_turu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ariza_turu (
    ariza_tur_id integer NOT NULL,
    ariza_tur character varying(150) NOT NULL
);


--
-- TOC entry 261 (class 1259 OID 33190)
-- Name: ariza_turu_ariza_tur_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ariza_turu_ariza_tur_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3933 (class 0 OID 0)
-- Dependencies: 261
-- Name: ariza_turu_ariza_tur_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ariza_turu_ariza_tur_id_seq OWNED BY public.ariza_turu.ariza_tur_id;


--
-- TOC entry 221 (class 1259 OID 16415)
-- Name: arizayi_tetikleyen_form; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.arizayi_tetikleyen_form (
    tetik_id integer NOT NULL,
    ariza_id integer NOT NULL,
    form_id integer NOT NULL,
    madde_id integer NOT NULL,
    tetikleyici_deger character varying(100),
    sapma_orani numeric(3,2),
    ai_tespit_mi boolean,
    tespit_tarihi timestamp with time zone,
    aciklama text
);


--
-- TOC entry 222 (class 1259 OID 16420)
-- Name: arizayi_tetikleyen_form_tetik_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.arizayi_tetikleyen_form_tetik_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3934 (class 0 OID 0)
-- Dependencies: 222
-- Name: arizayi_tetikleyen_form_tetik_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.arizayi_tetikleyen_form_tetik_id_seq OWNED BY public.arizayi_tetikleyen_form.tetik_id;


--
-- TOC entry 223 (class 1259 OID 16421)
-- Name: bakim_kaydi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bakim_kaydi (
    bakim_id integer NOT NULL,
    makine_id integer NOT NULL,
    sorumlu_id integer,
    servis_firma_id integer NOT NULL,
    bakim_tarihi timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    bakim_maliyet numeric NOT NULL,
    aciklama text,
    ariza_id integer,
    bakim_tur_id integer,
    durus_suresi numeric(15,2),
    kullanici_id integer
);


--
-- TOC entry 224 (class 1259 OID 16426)
-- Name: bakim_kaydi_bakim_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bakim_kaydi_bakim_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3935 (class 0 OID 0)
-- Dependencies: 224
-- Name: bakim_kaydi_bakim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bakim_kaydi_bakim_id_seq OWNED BY public.bakim_kaydi.bakim_id;


--
-- TOC entry 278 (class 1259 OID 49872)
-- Name: bakim_turu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bakim_turu (
    bakim_tur_id integer NOT NULL,
    bakim_tur_adi character varying(55) NOT NULL
);


--
-- TOC entry 277 (class 1259 OID 49871)
-- Name: bakim_turu_bakim_tur_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bakim_turu_bakim_tur_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3936 (class 0 OID 0)
-- Dependencies: 277
-- Name: bakim_turu_bakim_tur_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bakim_turu_bakim_tur_id_seq OWNED BY public.bakim_turu.bakim_tur_id;


--
-- TOC entry 225 (class 1259 OID 16427)
-- Name: firma; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firma (
    firma_id integer NOT NULL,
    firma_adi character varying(255) NOT NULL,
    vergi_no character varying(30),
    aktif_mi boolean,
    abonelik_tip_id integer,
    iletisim_id integer,
    sektor_id integer
);


--
-- TOC entry 226 (class 1259 OID 16432)
-- Name: firma_firma_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.firma_firma_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3937 (class 0 OID 0)
-- Dependencies: 226
-- Name: firma_firma_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.firma_firma_id_seq OWNED BY public.firma.firma_id;


--
-- TOC entry 227 (class 1259 OID 16433)
-- Name: form_madde_cevap; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.form_madde_cevap (
    cevap_id integer NOT NULL,
    form_id integer NOT NULL,
    soru_referans_id integer NOT NULL,
    durum character varying(100),
    aciklama text,
    girilen_deger character varying(50)
);
ALTER TABLE ONLY public.form_madde_cevap ALTER COLUMN girilen_deger SET STORAGE PLAIN;


--
-- TOC entry 228 (class 1259 OID 16438)
-- Name: form_madde_cevap_cevap_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.form_madde_cevap_cevap_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3938 (class 0 OID 0)
-- Dependencies: 228
-- Name: form_madde_cevap_cevap_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.form_madde_cevap_cevap_id_seq OWNED BY public.form_madde_cevap.cevap_id;


--
-- TOC entry 266 (class 1259 OID 33220)
-- Name: garanti_firma; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.garanti_firma (
    garanti_firma_id integer NOT NULL,
    firma_adi character varying(150),
    iletisim_id integer
);


--
-- TOC entry 265 (class 1259 OID 33219)
-- Name: garanti_firma_garanti_firma_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.garanti_firma_garanti_firma_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3939 (class 0 OID 0)
-- Dependencies: 265
-- Name: garanti_firma_garanti_firma_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.garanti_firma_garanti_firma_id_seq OWNED BY public.garanti_firma.garanti_firma_id;


--
-- TOC entry 260 (class 1259 OID 33168)
-- Name: genel_sorular; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.genel_sorular (
    genel_soru_id integer NOT NULL,
    madde_adi character varying(255),
    teknik_parametre character varying(200),
    aktiflik boolean,
    kritiklik_durumu boolean
);


--
-- TOC entry 259 (class 1259 OID 33167)
-- Name: genel_sorular_genel_soru_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.genel_sorular_genel_soru_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3940 (class 0 OID 0)
-- Dependencies: 259
-- Name: genel_sorular_genel_soru_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.genel_sorular_genel_soru_id_seq OWNED BY public.genel_sorular.genel_soru_id;


--
-- TOC entry 229 (class 1259 OID 16439)
-- Name: gunluk_kontrol_formu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gunluk_kontrol_formu (
    form_id integer NOT NULL,
    makine_id integer NOT NULL,
    kullanici_id integer NOT NULL,
    sablon_id integer NOT NULL,
    kontrol_tarihi date NOT NULL,
    genel_not text,
    ai_on_risk_durumu numeric(5,2)
);


--
-- TOC entry 230 (class 1259 OID 16444)
-- Name: gunluk_kontrol_formu_form_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gunluk_kontrol_formu_form_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3941 (class 0 OID 0)
-- Dependencies: 230
-- Name: gunluk_kontrol_formu_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gunluk_kontrol_formu_form_id_seq OWNED BY public.gunluk_kontrol_formu.form_id;


--
-- TOC entry 281 (class 1259 OID 49922)
-- Name: iletisim; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iletisim (
    iletisim_id integer NOT NULL,
    telefon character varying(20),
    mail character varying(200),
    il character varying(50),
    ilce character varying(100),
    acik_adres text
);


--
-- TOC entry 280 (class 1259 OID 49921)
-- Name: iletisim_iletisim_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iletisim_iletisim_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3942 (class 0 OID 0)
-- Dependencies: 280
-- Name: iletisim_iletisim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iletisim_iletisim_id_seq OWNED BY public.iletisim.iletisim_id;


--
-- TOC entry 231 (class 1259 OID 16445)
-- Name: kontrol_maddesi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kontrol_maddesi (
    madde_id integer NOT NULL,
    sablon_id integer NOT NULL,
    madde_adi character varying(150),
    teknik_parametre character varying(150),
    kritiklik_durumu boolean
);


--
-- TOC entry 232 (class 1259 OID 16450)
-- Name: kontrol_maddesi_madde_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.kontrol_maddesi_madde_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3943 (class 0 OID 0)
-- Dependencies: 232
-- Name: kontrol_maddesi_madde_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.kontrol_maddesi_madde_id_seq OWNED BY public.kontrol_maddesi.madde_id;


--
-- TOC entry 233 (class 1259 OID 16451)
-- Name: kontrol_sablonu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kontrol_sablonu (
    sablon_id integer NOT NULL,
    makine_tur_id integer NOT NULL,
    sablon_adi character varying(150),
    aciklama text,
    aktiflik boolean NOT NULL
);


--
-- TOC entry 234 (class 1259 OID 16456)
-- Name: kontrol_sablonu_sablon_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.kontrol_sablonu_sablon_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3944 (class 0 OID 0)
-- Dependencies: 234
-- Name: kontrol_sablonu_sablon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.kontrol_sablonu_sablon_id_seq OWNED BY public.kontrol_sablonu.sablon_id;


--
-- TOC entry 235 (class 1259 OID 16457)
-- Name: kullanici; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kullanici (
    kullanici_id integer NOT NULL,
    firma_id integer NOT NULL,
    rol_id integer NOT NULL,
    ad character varying(50) NOT NULL,
    soyad character varying(50) NOT NULL,
    telefon character varying(20) NOT NULL,
    eposta character varying(100),
    sifre character varying(255) NOT NULL,
    aktiflik boolean,
    baslama_tarihi date,
    kullanici_adi character varying NOT NULL
);


--
-- TOC entry 236 (class 1259 OID 16460)
-- Name: kullanici_kullanici_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.kullanici_kullanici_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3945 (class 0 OID 0)
-- Dependencies: 236
-- Name: kullanici_kullanici_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.kullanici_kullanici_id_seq OWNED BY public.kullanici.kullanici_id;


--
-- TOC entry 237 (class 1259 OID 16461)
-- Name: lokasyon; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lokasyon (
    lokasyon_id integer NOT NULL,
    fabrika_alani character varying(150) NOT NULL,
    kat character varying(5) NOT NULL,
    x_koor numeric NOT NULL,
    y_koor numeric NOT NULL,
    guncelleme_tarihi timestamp with time zone,
    firma_id integer,
    makine_id integer
);


--
-- TOC entry 238 (class 1259 OID 16466)
-- Name: lokasyon_lokasyon_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.lokasyon_lokasyon_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3946 (class 0 OID 0)
-- Dependencies: 238
-- Name: lokasyon_lokasyon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lokasyon_lokasyon_id_seq OWNED BY public.lokasyon.lokasyon_id;


--
-- TOC entry 239 (class 1259 OID 16467)
-- Name: makine; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.makine (
    makine_id integer NOT NULL,
    firma_id integer NOT NULL,
    makine_tur_id integer NOT NULL,
    makine_qr character varying(100),
    makine_adi character varying(100),
    satin_alma_tarihi date,
    satin_alma_maliyeti numeric(15,4),
    aktiflik_durumu boolean,
    seri_no character varying(150),
    garanti_suresi integer,
    garanti_firma_id integer,
    servis_pin integer,
    toplam_calisma_saati numeric(10,2) DEFAULT 0
);


--
-- TOC entry 240 (class 1259 OID 16472)
-- Name: makine_kullanim; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.makine_kullanim (
    kullanim_id integer NOT NULL,
    kullanici_id integer NOT NULL,
    makine_id integer NOT NULL,
    baslangic_zamani timestamp with time zone NOT NULL,
    bitis_zamani timestamp with time zone NOT NULL,
    gunluk_top_calisma_saati bigint DEFAULT 0 NOT NULL
);


--
-- TOC entry 241 (class 1259 OID 16477)
-- Name: makine_makine_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.makine_makine_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3947 (class 0 OID 0)
-- Dependencies: 241
-- Name: makine_makine_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.makine_makine_id_seq OWNED BY public.makine.makine_id;


--
-- TOC entry 264 (class 1259 OID 33203)
-- Name: makine_ozellikleri; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.makine_ozellikleri (
    ozellik_id integer NOT NULL,
    makine_id integer NOT NULL,
    teknik_ozellikler jsonb,
    guncelleme_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- TOC entry 263 (class 1259 OID 33202)
-- Name: makine_ozellikleri_ozellik_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.makine_ozellikleri_ozellik_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3948 (class 0 OID 0)
-- Dependencies: 263
-- Name: makine_ozellikleri_ozellik_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.makine_ozellikleri_ozellik_id_seq OWNED BY public.makine_ozellikleri.ozellik_id;


--
-- TOC entry 242 (class 1259 OID 16478)
-- Name: makine_turu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.makine_turu (
    makine_tur_id integer NOT NULL,
    makine_tur_adi character varying(50) NOT NULL,
    risk_katsayisi numeric(5,2)
);
ALTER TABLE ONLY public.makine_turu ALTER COLUMN risk_katsayisi SET STORAGE PLAIN;


--
-- TOC entry 243 (class 1259 OID 16483)
-- Name: makine_turu_m_tur_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.makine_turu_m_tur_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3949 (class 0 OID 0)
-- Dependencies: 243
-- Name: makine_turu_m_tur_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.makine_turu_m_tur_id_seq OWNED BY public.makine_turu.makine_tur_id;


--
-- TOC entry 244 (class 1259 OID 16484)
-- Name: operator_makine_kullanim_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operator_makine_kullanim_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3950 (class 0 OID 0)
-- Dependencies: 244
-- Name: operator_makine_kullanim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operator_makine_kullanim_id_seq OWNED BY public.makine_kullanim.kullanim_id;


--
-- TOC entry 245 (class 1259 OID 16485)
-- Name: parca; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parca (
    parca_id integer NOT NULL,
    parca_adi character varying(100) NOT NULL,
    tahmini_omur_saati numeric(8,2) NOT NULL,
    parca_maliyeti integer NOT NULL,
    tedarik_gun_suresi integer NOT NULL,
    kategori_id integer,
    tedarikci_id integer NOT NULL
);


--
-- TOC entry 246 (class 1259 OID 16490)
-- Name: parca_degisim; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parca_degisim (
    parca_degisim_id integer NOT NULL,
    bakim_id integer NOT NULL,
    parca_id integer
);


--
-- TOC entry 247 (class 1259 OID 16493)
-- Name: parca_degisim_degisim_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parca_degisim_degisim_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3951 (class 0 OID 0)
-- Dependencies: 247
-- Name: parca_degisim_degisim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parca_degisim_degisim_id_seq OWNED BY public.parca_degisim.parca_degisim_id;


--
-- TOC entry 273 (class 1259 OID 49703)
-- Name: parca_kategori; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parca_kategori (
    kategori_id integer NOT NULL,
    kategori_adi character varying(155)
);


--
-- TOC entry 272 (class 1259 OID 49702)
-- Name: parca_kategori_kategori_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parca_kategori_kategori_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3952 (class 0 OID 0)
-- Dependencies: 272
-- Name: parca_kategori_kategori_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parca_kategori_kategori_id_seq OWNED BY public.parca_kategori.kategori_id;


--
-- TOC entry 248 (class 1259 OID 16494)
-- Name: parca_parca_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parca_parca_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3953 (class 0 OID 0)
-- Dependencies: 248
-- Name: parca_parca_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parca_parca_id_seq OWNED BY public.parca.parca_id;


--
-- TOC entry 249 (class 1259 OID 16495)
-- Name: risk_skoru; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.risk_skoru (
    risk_id integer NOT NULL,
    makine_id integer NOT NULL,
    risk_skoru numeric(5,2),
    risk_seviyesi public.du_ort_yuk NOT NULL,
    hesaplama_tarihi timestamp with time zone
);
ALTER TABLE ONLY public.risk_skoru ALTER COLUMN risk_skoru SET STORAGE PLAIN;


--
-- TOC entry 250 (class 1259 OID 16500)
-- Name: risk_skoru_risk_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.risk_skoru_risk_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3954 (class 0 OID 0)
-- Dependencies: 250
-- Name: risk_skoru_risk_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.risk_skoru_risk_id_seq OWNED BY public.risk_skoru.risk_id;


--
-- TOC entry 251 (class 1259 OID 16501)
-- Name: rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rol (
    rol_id integer NOT NULL,
    rol_adi character varying NOT NULL
);


--
-- TOC entry 252 (class 1259 OID 16506)
-- Name: rol_rol_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rol_rol_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3955 (class 0 OID 0)
-- Dependencies: 252
-- Name: rol_rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rol_rol_id_seq OWNED BY public.rol.rol_id;


--
-- TOC entry 283 (class 1259 OID 49931)
-- Name: sektor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sektor (
    sektor_id integer NOT NULL,
    sektor_adi character varying(150) NOT NULL
);


--
-- TOC entry 282 (class 1259 OID 49930)
-- Name: sektor_sektor_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sektor_sektor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3956 (class 0 OID 0)
-- Dependencies: 282
-- Name: sektor_sektor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sektor_sektor_id_seq OWNED BY public.sektor.sektor_id;


--
-- TOC entry 253 (class 1259 OID 16507)
-- Name: servis_firma; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.servis_firma (
    servis_firma_id integer NOT NULL,
    firma_adi character varying(100) NOT NULL,
    aktiflik boolean NOT NULL,
    iletisim_id integer
);


--
-- TOC entry 254 (class 1259 OID 16512)
-- Name: servis_firma_servis_firma_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.servis_firma_servis_firma_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3957 (class 0 OID 0)
-- Dependencies: 254
-- Name: servis_firma_servis_firma_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.servis_firma_servis_firma_id_seq OWNED BY public.servis_firma.servis_firma_id;


--
-- TOC entry 271 (class 1259 OID 41524)
-- Name: servis_firma_uzmanlik; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.servis_firma_uzmanlik (
    servis_firma_id integer NOT NULL,
    uzmanlik_adi character varying NOT NULL
);


--
-- TOC entry 268 (class 1259 OID 33259)
-- Name: servis_puan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.servis_puan (
    puan_id integer NOT NULL,
    servis_firma_id integer NOT NULL,
    puanlayan_kullanici_id integer NOT NULL,
    puan integer NOT NULL,
    yorum text,
    tarih date
);


--
-- TOC entry 267 (class 1259 OID 33258)
-- Name: servis_puan_puan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.servis_puan_puan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3958 (class 0 OID 0)
-- Dependencies: 267
-- Name: servis_puan_puan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.servis_puan_puan_id_seq OWNED BY public.servis_puan.puan_id;


--
-- TOC entry 258 (class 1259 OID 24689)
-- Name: servis_sorumlusu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.servis_sorumlusu (
    sorumlu_id integer NOT NULL,
    servis_firma_id integer NOT NULL,
    ad character varying(55) NOT NULL,
    soyad character varying(55) NOT NULL,
    telefon character varying(20) NOT NULL,
    aktiflik boolean,
    unvan character varying,
    sorumlu_adi character varying(100)
);


--
-- TOC entry 270 (class 1259 OID 33278)
-- Name: tedarikci_puan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tedarikci_puan (
    puan_id integer NOT NULL,
    tedarikci_id integer NOT NULL,
    puanlayan_kullanici_id integer NOT NULL,
    puan integer,
    yorum text,
    tarih date
);


--
-- TOC entry 269 (class 1259 OID 33277)
-- Name: tedarakci_puan_puan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tedarakci_puan_puan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3959 (class 0 OID 0)
-- Dependencies: 269
-- Name: tedarakci_puan_puan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tedarakci_puan_puan_id_seq OWNED BY public.tedarikci_puan.puan_id;


--
-- TOC entry 255 (class 1259 OID 16513)
-- Name: tedarikci; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tedarikci (
    tedarikci_id integer NOT NULL,
    firma_adi character varying(200) NOT NULL,
    aktiflik boolean NOT NULL,
    guvenilirlik_skoru numeric(5,2),
    vergi_no character varying(155),
    yetkili_kisi character varying(100),
    kayit_tarihi timestamp with time zone,
    iletisim_id integer
);


--
-- TOC entry 287 (class 1259 OID 49995)
-- Name: tedarikci_parca; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tedarikci_parca (
    tedarikci_parca_id integer NOT NULL,
    tedarik_id integer NOT NULL,
    parca_id integer NOT NULL,
    tedarik_maliyeti numeric(15,3) NOT NULL
);


--
-- TOC entry 286 (class 1259 OID 49994)
-- Name: tedarikci_parca_tedarikci_parca_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tedarikci_parca_tedarikci_parca_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3960 (class 0 OID 0)
-- Dependencies: 286
-- Name: tedarikci_parca_tedarikci_parca_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tedarikci_parca_tedarikci_parca_id_seq OWNED BY public.tedarikci_parca.tedarikci_parca_id;


--
-- TOC entry 256 (class 1259 OID 16518)
-- Name: tedarikci_tedarikci_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tedarikci_tedarikci_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3961 (class 0 OID 0)
-- Dependencies: 256
-- Name: tedarikci_tedarikci_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tedarikci_tedarikci_id_seq OWNED BY public.tedarikci.tedarikci_id;


--
-- TOC entry 257 (class 1259 OID 24688)
-- Name: teknisyen_teknisyen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.teknisyen_teknisyen_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3962 (class 0 OID 0)
-- Dependencies: 257
-- Name: teknisyen_teknisyen_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.teknisyen_teknisyen_id_seq OWNED BY public.servis_sorumlusu.sorumlu_id;


--
-- TOC entry 292 (class 1259 OID 50065)
-- Name: v_dashboard_bakim_rapor; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_dashboard_bakim_rapor AS
 SELECT m.makine_adi AS "makine adı",
    ak.olusturma_tarihi AS "Arıza Kaydı Giriş Tarihi",
    bk.bakim_tarihi AS "Makine Bakımı Tamamlanan Tarih",
    bk.durus_suresi AS "duruş süresi saat",
    bt.bakim_tur_adi AS "Bakım Türü",
    bk.bakim_maliyet AS "Bakım Maliyeti",
    NULLIF(bk.aciklama, 'Açıklama yapılmadı!'::text) AS "Açıklama",
    (((ss.ad)::text || ' '::text) || (ss.soyad)::text) AS "Servis Sorumlusu Ad/Soyad",
    ss.telefon AS "servis sorumlusu telefon",
    ss.unvan AS "servis sorumlusu unvan",
    ( SELECT avg(sp.puan) AS avg
           FROM public.servis_puan sp
          WHERE (sp.servis_firma_id = sf.servis_firma_id)) AS "Servis Firma Değerlendirme",
        CASE
            WHEN (m.garanti_firma_id = sf.servis_firma_id) THEN ( SELECT gf.firma_adi
               FROM public.garanti_firma gf
              WHERE (gf.garanti_firma_id = m.garanti_firma_id))
            ELSE sf.firma_adi
        END AS "Servis Firması Adı",
    t.firma_adi AS "Tedarikçi Firma Adı",
    p.parca_adi AS "parça adı",
    p.parca_maliyeti AS "Parça Maliyeti",
    pk.kategori_adi AS "Parça Kategorisi",
    p.tahmini_omur_saati AS "Parçanın Tahmini Ömrü",
    p.tedarik_gun_suresi AS "Parça Tedarik Süresi"
   FROM (((((((((public.bakim_kaydi bk
     JOIN public.makine m ON ((bk.makine_id = m.makine_id)))
     LEFT JOIN public.bakim_turu bt ON ((bk.bakim_tur_id = bt.bakim_tur_id)))
     LEFT JOIN public.servis_sorumlusu ss ON ((bk.sorumlu_id = ss.sorumlu_id)))
     LEFT JOIN public.servis_firma sf ON ((bk.servis_firma_id = sf.servis_firma_id)))
     LEFT JOIN public.ariza_kaydi ak ON ((bk.ariza_id = ak.ariza_id)))
     LEFT JOIN public.parca_degisim pd ON ((bk.bakim_id = pd.bakim_id)))
     LEFT JOIN public.parca p ON ((pd.parca_id = p.parca_id)))
     LEFT JOIN public.tedarikci t ON ((t.tedarikci_id = p.tedarikci_id)))
     LEFT JOIN public.parca_kategori pk ON ((p.kategori_id = pk.kategori_id)));


--
-- TOC entry 293 (class 1259 OID 50114)
-- Name: v_parca_detay_listesi; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_parca_detay_listesi AS
 SELECT p.parca_id,
    p.parca_adi AS "PARÇA ADI",
    p.tahmini_omur_saati AS "PARCANIN TAHMİNİ ÖMRÜ",
    p.parca_maliyeti AS "PARCA MALİYETİ",
    p.tedarik_gun_suresi AS "PARCA TEDARİK SÜRESİ",
    pk.kategori_adi AS "PARCA KATEGORİ ADI",
    t.firma_adi AS "TEDARİKCİ FİRMA",
    t.yetkili_kisi AS "TEDARİKCİ FİRMA YETKİLİSİ",
    t.vergi_no AS "TEDARİKCİ FİRMA VERGİ NO",
    t.aktiflik AS "AKTİFLİK",
    i.telefon AS "FİRMA TELEFON",
    i.mail AS "FİRMA MAİL",
    (((i.il)::text || ' / '::text) || (i.ilce)::text) AS "İL/İLCE",
    i.acik_adres AS "AÇIK ADRES"
   FROM (((public.parca p
     LEFT JOIN public.parca_kategori pk ON ((p.kategori_id = pk.kategori_id)))
     LEFT JOIN public.tedarikci t ON ((p.tedarikci_id = t.tedarikci_id)))
     LEFT JOIN public.iletisim i ON ((t.iletisim_id = i.iletisim_id)))
  ORDER BY p.parca_id DESC;


--
-- TOC entry 288 (class 1259 OID 50016)
-- Name: view_dashboard_bakim_bekleyenler; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_dashboard_bakim_bekleyenler AS
 SELECT m.makine_adi AS "makine adı",
    ak.olusturma_tarihi AS "Arıza Kaydı Giriş Tarihi",
    ak.ariza_tespit_kaynagi AS "Arıza Tespit Kaynağı",
    att.ariza_tur AS "Arıza Türü",
    l.kat AS "Kaçıncı Katta",
    l.fabrika_alani AS "Arızalı Makine Alanı",
    rs.risk_skoru AS "Risk Skoru",
        CASE
            WHEN (rs.risk_skoru >= (75)::numeric) THEN 'KRİTİK'::text
            WHEN (rs.risk_skoru >= (50)::numeric) THEN 'ORTA'::text
            ELSE 'NORMAL'::text
        END AS "Aciliyet Durumu"
   FROM ((((public.ariza_kaydi ak
     JOIN public.makine m ON ((ak.makine_id = m.makine_id)))
     JOIN public.ariza_turu att ON ((ak.ariza_id = att.ariza_tur_id)))
     JOIN public.risk_skoru rs ON ((m.makine_id = rs.makine_id)))
     JOIN public.lokasyon l ON ((m.makine_id = l.makine_id)))
  WHERE (ak.bitis_zamani IS NULL)
  ORDER BY rs.risk_skoru DESC;


--
-- TOC entry 276 (class 1259 OID 49793)
-- Name: view_dashboard_kritik_uyarilar; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_dashboard_kritik_uyarilar AS
 SELECT m.makine_id,
    m.makine_adi AS makine_ad,
    'YÜKSEK RİSK'::text AS uyari_tipi,
    (rs.risk_skoru)::text AS deger,
    'Makine risk seviyesi kritik eşiği (80+) aştı.'::text AS mesaj,
    rs.hesaplama_tarihi AS tarih,
    1 AS oncelik_sirasi
   FROM (public.makine m
     JOIN public.risk_skoru rs ON ((m.makine_id = rs.makine_id)))
  WHERE (rs.risk_skoru >= (80)::numeric)
UNION ALL
 SELECT m.makine_id,
    m.makine_adi AS makine_ad,
    'AI TAHMİNİ'::text AS uyari_tipi,
    (ai.tahmini_durus_suresi || ' Saat'::text) AS deger,
    'Yapay zeka yakın zamanda uzun süreli duruş öngörüyor.'::text AS mesaj,
    ai.tespit_tarihi AS tarih,
    2 AS oncelik_sirasi
   FROM (public.makine m
     JOIN public.ai_ariza_tespit ai ON ((m.makine_id = ai.makine_id)))
  WHERE (ai.tahmini_durus_suresi > (4)::numeric)
UNION ALL
 SELECT m.makine_id,
    m.makine_adi AS makine_ad,
    'KRİTİK ARIZA'::text AS uyari_tipi,
    ak.ariza_tespit_kaynagi AS deger,
    'Henüz bitiş zamanı girilmemiş aktif arıza kaydı mevcut.'::text AS mesaj,
    ak.baslangic_zamani AS tarih,
    1 AS oncelik_sirasi
   FROM (public.makine m
     JOIN public.ariza_kaydi ak ON ((m.makine_id = ak.makine_id)))
  WHERE (ak.bitis_zamani IS NULL)
  ORDER BY 7, 6 DESC;


--
-- TOC entry 279 (class 1259 OID 49883)
-- Name: view_dashboard_makine_masraf_detayli; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_dashboard_makine_masraf_detayli AS
 SELECT m.makine_id,
    m.makine_adi AS makine_ad,
    bt.bakim_tur_adi,
    bk.bakim_maliyet,
    p.parca_maliyeti,
    (bk.bakim_maliyet + COALESCE((p.parca_maliyeti)::numeric, (0)::numeric)) AS genel_toplam_maliyet
   FROM ((((public.makine m
     LEFT JOIN public.bakim_kaydi bk ON ((m.makine_id = bk.makine_id)))
     LEFT JOIN public.bakim_turu bt ON ((bk.bakim_id = bt.bakim_tur_id)))
     LEFT JOIN public.parca_degisim pd ON ((bk.bakim_id = pd.bakim_id)))
     LEFT JOIN public.parca p ON ((pd.parca_degisim_id = p.parca_id)))
  ORDER BY m.makine_id, 'detay'::text DESC, bk.bakim_id, pd.parca_degisim_id;


--
-- TOC entry 274 (class 1259 OID 49719)
-- Name: view_dashboard_masraf_analizi; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_dashboard_masraf_analizi AS
 WITH bakim_toplam AS (
         SELECT bakim_kaydi.makine_id,
            COALESCE(sum(bakim_kaydi.bakim_maliyet), (0)::numeric) AS toplam_bakim_maliyeti
           FROM public.bakim_kaydi
          GROUP BY bakim_kaydi.makine_id
        ), parca_toplam AS (
         SELECT bk.makine_id,
            COALESCE((sum(p.parca_maliyeti))::numeric, (0)::numeric) AS toplam_parca_maliyeti
           FROM ((public.parca p
             JOIN public.parca_degisim pd ON ((p.parca_id = pd.parca_degisim_id)))
             JOIN public.bakim_kaydi bk ON ((pd.bakim_id = bk.bakim_id)))
          GROUP BY bk.makine_id
        )
 SELECT m.makine_id,
    m.makine_adi AS makine_ad,
    COALESCE(bt.toplam_bakim_maliyeti, (0)::numeric) AS toplam_bakim_maliyeti,
    COALESCE(pt.toplam_parca_maliyeti, (0)::numeric) AS toplam_parca_maliyeti,
    (COALESCE(bt.toplam_bakim_maliyeti, (0)::numeric) + COALESCE(pt.toplam_parca_maliyeti, (0)::numeric)) AS genel_toplam_maliyet
   FROM ((public.makine m
     LEFT JOIN bakim_toplam bt ON ((m.makine_id = bt.makine_id)))
     LEFT JOIN parca_toplam pt ON ((m.makine_id = pt.makine_id)));


--
-- TOC entry 289 (class 1259 OID 50025)
-- Name: view_garanti_firmalari; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_garanti_firmalari AS
 SELECT gf.firma_adi AS "Garanti Firması Adı",
    i.telefon AS "Telefon",
    i.mail AS "E-posta",
    i.il AS "İl",
    i.ilce AS "İlçe",
    i.acik_adres AS "Açık Adres"
   FROM (public.garanti_firma gf
     LEFT JOIN public.iletisim i ON ((gf.iletisim_id = i.iletisim_id)));


--
-- TOC entry 290 (class 1259 OID 50029)
-- Name: view_makineler; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_makineler AS
 SELECT m.makine_adi AS "Makine Adı",
    m.makine_qr AS "QR Kod",
    m.seri_no AS "Seri No",
    m.aktiflik_durumu AS "Aktiflik",
    f.firma_adi AS "Müşteri / Sahip Firma",
    mt.makine_tur_adi AS "Makine Türü",
    mt.risk_katsayisi AS "Risk Katsayısı",
    m.satin_alma_maliyeti AS "Maliyet",
    m.garanti_suresi AS "Garanti Süresi",
    mo.teknik_ozellikler AS "Teknik Özellikler (JSON)"
   FROM (((public.makine m
     LEFT JOIN public.firma f ON ((m.firma_id = f.firma_id)))
     LEFT JOIN public.makine_turu mt ON ((m.makine_tur_id = mt.makine_tur_id)))
     LEFT JOIN public.makine_ozellikleri mo ON ((m.makine_id = mo.makine_id)));


--
-- TOC entry 275 (class 1259 OID 49729)
-- Name: view_operator_makine_ozeti; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_operator_makine_ozeti AS
 SELECT mk.kullanici_id,
    mk.makine_id,
    rs.risk_skoru,
    mk.baslangic_zamani,
    mk.bitis_zamani,
    gkf.ai_on_risk_durumu AS formdaki_risk_degeri
   FROM (((public.makine_kullanim mk
     JOIN public.makine m ON ((mk.makine_id = m.makine_id)))
     JOIN public.risk_skoru rs ON ((mk.makine_id = rs.makine_id)))
     LEFT JOIN public.gunluk_kontrol_formu gkf ON (((mk.kullanici_id = gkf.kullanici_id) AND (mk.makine_id = gkf.makine_id))))
  ORDER BY mk.baslangic_zamani DESC;


--
-- TOC entry 291 (class 1259 OID 50040)
-- Name: view_teknisyen_bakim_ozeti; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_teknisyen_bakim_ozeti AS
 SELECT t.sorumlu_id AS teknisyen_id,
    concat("left"((t.ad)::text, 1), '*** ', "left"((t.soyad)::text, 1), '***') AS teknisyen_ad_maskeli,
    m.makine_adi AS makine_ad,
    bt.bakim_tur_adi,
    bk.bakim_tarihi,
    bk.durus_suresi,
    bk.bakim_maliyet
   FROM (((public.servis_sorumlusu t
     JOIN public.bakim_kaydi bk ON ((t.sorumlu_id = bk.sorumlu_id)))
     JOIN public.bakim_turu bt ON ((bk.bakim_id = bt.bakim_tur_id)))
     JOIN public.makine m ON ((bk.makine_id = m.makine_id)))
  WHERE (t.aktiflik = true);


--
-- TOC entry 3523 (class 2604 OID 49941)
-- Name: abonelik_tipi abonelik_tip_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonelik_tipi ALTER COLUMN abonelik_tip_id SET DEFAULT nextval('public.abonelik_tipi_abonelik_tip_id_seq'::regclass);


--
-- TOC entry 3487 (class 2604 OID 16524)
-- Name: ai_ariza_tespit tespit_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit ALTER COLUMN tespit_id SET DEFAULT nextval('public.ai_ariza_tespit_tespit_id_seq'::regclass);


--
-- TOC entry 3488 (class 2604 OID 16525)
-- Name: ai_model_log log_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log ALTER COLUMN log_id SET DEFAULT nextval('public.ai_model_log_log_id_seq'::regclass);


--
-- TOC entry 3489 (class 2604 OID 16526)
-- Name: ariza_kaydi ariza_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi ALTER COLUMN ariza_id SET DEFAULT nextval('public.ariza_kaydi_ariza_id_seq'::regclass);


--
-- TOC entry 3513 (class 2604 OID 33194)
-- Name: ariza_turu ariza_tur_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_turu ALTER COLUMN ariza_tur_id SET DEFAULT nextval('public.ariza_turu_ariza_tur_id_seq'::regclass);


--
-- TOC entry 3490 (class 2604 OID 16527)
-- Name: arizayi_tetikleyen_form tetik_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form ALTER COLUMN tetik_id SET DEFAULT nextval('public.arizayi_tetikleyen_form_tetik_id_seq'::regclass);


--
-- TOC entry 3491 (class 2604 OID 16528)
-- Name: bakim_kaydi bakim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi ALTER COLUMN bakim_id SET DEFAULT nextval('public.bakim_kaydi_bakim_id_seq'::regclass);


--
-- TOC entry 3520 (class 2604 OID 49875)
-- Name: bakim_turu bakim_tur_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_turu ALTER COLUMN bakim_tur_id SET DEFAULT nextval('public.bakim_turu_bakim_tur_id_seq'::regclass);


--
-- TOC entry 3493 (class 2604 OID 16529)
-- Name: firma firma_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma ALTER COLUMN firma_id SET DEFAULT nextval('public.firma_firma_id_seq'::regclass);


--
-- TOC entry 3494 (class 2604 OID 16530)
-- Name: form_madde_cevap cevap_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap ALTER COLUMN cevap_id SET DEFAULT nextval('public.form_madde_cevap_cevap_id_seq'::regclass);


--
-- TOC entry 3516 (class 2604 OID 33223)
-- Name: garanti_firma garanti_firma_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.garanti_firma ALTER COLUMN garanti_firma_id SET DEFAULT nextval('public.garanti_firma_garanti_firma_id_seq'::regclass);


--
-- TOC entry 3512 (class 2604 OID 33171)
-- Name: genel_sorular genel_soru_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genel_sorular ALTER COLUMN genel_soru_id SET DEFAULT nextval('public.genel_sorular_genel_soru_id_seq'::regclass);


--
-- TOC entry 3495 (class 2604 OID 16531)
-- Name: gunluk_kontrol_formu form_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu ALTER COLUMN form_id SET DEFAULT nextval('public.gunluk_kontrol_formu_form_id_seq'::regclass);


--
-- TOC entry 3521 (class 2604 OID 49925)
-- Name: iletisim iletisim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iletisim ALTER COLUMN iletisim_id SET DEFAULT nextval('public.iletisim_iletisim_id_seq'::regclass);


--
-- TOC entry 3496 (class 2604 OID 16532)
-- Name: kontrol_maddesi madde_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_maddesi ALTER COLUMN madde_id SET DEFAULT nextval('public.kontrol_maddesi_madde_id_seq'::regclass);


--
-- TOC entry 3497 (class 2604 OID 16533)
-- Name: kontrol_sablonu sablon_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_sablonu ALTER COLUMN sablon_id SET DEFAULT nextval('public.kontrol_sablonu_sablon_id_seq'::regclass);


--
-- TOC entry 3498 (class 2604 OID 16534)
-- Name: kullanici kullanici_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici ALTER COLUMN kullanici_id SET DEFAULT nextval('public.kullanici_kullanici_id_seq'::regclass);


--
-- TOC entry 3499 (class 2604 OID 16535)
-- Name: lokasyon lokasyon_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon ALTER COLUMN lokasyon_id SET DEFAULT nextval('public.lokasyon_lokasyon_id_seq'::regclass);


--
-- TOC entry 3500 (class 2604 OID 16536)
-- Name: makine makine_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine ALTER COLUMN makine_id SET DEFAULT nextval('public.makine_makine_id_seq'::regclass);


--
-- TOC entry 3502 (class 2604 OID 16537)
-- Name: makine_kullanim kullanim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim ALTER COLUMN kullanim_id SET DEFAULT nextval('public.operator_makine_kullanim_id_seq'::regclass);


--
-- TOC entry 3514 (class 2604 OID 33206)
-- Name: makine_ozellikleri ozellik_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_ozellikleri ALTER COLUMN ozellik_id SET DEFAULT nextval('public.makine_ozellikleri_ozellik_id_seq'::regclass);


--
-- TOC entry 3504 (class 2604 OID 16538)
-- Name: makine_turu makine_tur_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_turu ALTER COLUMN makine_tur_id SET DEFAULT nextval('public.makine_turu_m_tur_id_seq'::regclass);


--
-- TOC entry 3505 (class 2604 OID 16539)
-- Name: parca parca_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca ALTER COLUMN parca_id SET DEFAULT nextval('public.parca_parca_id_seq'::regclass);


--
-- TOC entry 3506 (class 2604 OID 16540)
-- Name: parca_degisim parca_degisim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim ALTER COLUMN parca_degisim_id SET DEFAULT nextval('public.parca_degisim_degisim_id_seq'::regclass);


--
-- TOC entry 3519 (class 2604 OID 49706)
-- Name: parca_kategori kategori_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_kategori ALTER COLUMN kategori_id SET DEFAULT nextval('public.parca_kategori_kategori_id_seq'::regclass);


--
-- TOC entry 3507 (class 2604 OID 16541)
-- Name: risk_skoru risk_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_skoru ALTER COLUMN risk_id SET DEFAULT nextval('public.risk_skoru_risk_id_seq'::regclass);


--
-- TOC entry 3508 (class 2604 OID 16542)
-- Name: rol rol_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol ALTER COLUMN rol_id SET DEFAULT nextval('public.rol_rol_id_seq'::regclass);


--
-- TOC entry 3522 (class 2604 OID 49934)
-- Name: sektor sektor_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sektor ALTER COLUMN sektor_id SET DEFAULT nextval('public.sektor_sektor_id_seq'::regclass);


--
-- TOC entry 3509 (class 2604 OID 16543)
-- Name: servis_firma servis_firma_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma ALTER COLUMN servis_firma_id SET DEFAULT nextval('public.servis_firma_servis_firma_id_seq'::regclass);


--
-- TOC entry 3517 (class 2604 OID 33262)
-- Name: servis_puan puan_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan ALTER COLUMN puan_id SET DEFAULT nextval('public.servis_puan_puan_id_seq'::regclass);


--
-- TOC entry 3511 (class 2604 OID 24692)
-- Name: servis_sorumlusu sorumlu_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_sorumlusu ALTER COLUMN sorumlu_id SET DEFAULT nextval('public.teknisyen_teknisyen_id_seq'::regclass);


--
-- TOC entry 3510 (class 2604 OID 16544)
-- Name: tedarikci tedarikci_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci ALTER COLUMN tedarikci_id SET DEFAULT nextval('public.tedarikci_tedarikci_id_seq'::regclass);


--
-- TOC entry 3524 (class 2604 OID 49998)
-- Name: tedarikci_parca tedarikci_parca_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca ALTER COLUMN tedarikci_parca_id SET DEFAULT nextval('public.tedarikci_parca_tedarikci_parca_id_seq'::regclass);


--
-- TOC entry 3518 (class 2604 OID 33281)
-- Name: tedarikci_puan puan_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan ALTER COLUMN puan_id SET DEFAULT nextval('public.tedarakci_puan_puan_id_seq'::regclass);


--
-- TOC entry 3920 (class 0 OID 49938)
-- Dependencies: 285
-- Data for Name: abonelik_tipi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.abonelik_tipi (abonelik_tip_id, abonelik_adi) FROM stdin;
\.


--
-- TOC entry 3854 (class 0 OID 16399)
-- Dependencies: 215
-- Data for Name: ai_ariza_tespit; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ai_ariza_tespit (tespit_id, makine_id, form_id, madde_id, tahmin_edilen_ariza, risk_skoru, tespit_tarihi, model_versiyon, tahmini_durus_suresi, tahmini_maliyet) FROM stdin;
\.


--
-- TOC entry 3856 (class 0 OID 16403)
-- Dependencies: 217
-- Data for Name: ai_model_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ai_model_log (log_id, makine_id, model_versiyon, kullanilan_veri_sayisi, tahmin_risk, tahmin_tarihi, kullanici_id, form_id) FROM stdin;
\.


--
-- TOC entry 3858 (class 0 OID 16409)
-- Dependencies: 219
-- Data for Name: ariza_kaydi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ariza_kaydi (ariza_id, makine_id, ariza_tespit_kaynagi, ariza_aciklama, baslangic_zamani, bitis_zamani, olusturma_tarihi, ariza_tur_id, makine_adi) FROM stdin;
2	23	SCADA Otomasyon	Termokupül 2 numaralı sensörden veri alınamıyor, yüksek ısı riski.	2026-04-14 00:00:00+00	2026-04-15 21:13:17.275825+00	2026-04-14 15:10:28.292624+00	1	CNC Panel ebatlama
3	23	Operatör Bildirimi	Ana mil üzerinde aşırı ısınma ve sürtünme sesi tespit edildi. Makine güvenlik amaçlı durduruldu.	2026-04-15 00:00:00+00	2026-04-15 21:16:35.808839+00	2026-04-15 21:16:12.272711+00	2	CNC panel ebatlama
\.


--
-- TOC entry 3901 (class 0 OID 33191)
-- Dependencies: 262
-- Data for Name: ariza_turu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ariza_turu (ariza_tur_id, ariza_tur) FROM stdin;
1	Elektriksel
2	Mekanik Arıza
\.


--
-- TOC entry 3860 (class 0 OID 16415)
-- Dependencies: 221
-- Data for Name: arizayi_tetikleyen_form; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.arizayi_tetikleyen_form (tetik_id, ariza_id, form_id, madde_id, tetikleyici_deger, sapma_orani, ai_tespit_mi, tespit_tarihi, aciklama) FROM stdin;
\.


--
-- TOC entry 3862 (class 0 OID 16421)
-- Dependencies: 223
-- Data for Name: bakim_kaydi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bakim_kaydi (bakim_id, makine_id, sorumlu_id, servis_firma_id, bakim_tarihi, bakim_maliyet, aciklama, ariza_id, bakim_tur_id, durus_suresi, kullanici_id) FROM stdin;
10	23	1	12	2026-04-15 21:13:17.275825+00	15500.50	Yıllık periyodik bakım yapıldı, filtreler ve sensörler yenilendi.	\N	10	4.50	\N
11	23	1	12	2026-04-15 21:16:35.808839+00	15500.50	Yıllık periyodik bakım yapıldı, filtreler ve sensörler yenilendi.	\N	10	4.50	\N
\.


--
-- TOC entry 3914 (class 0 OID 49872)
-- Dependencies: 278
-- Data for Name: bakim_turu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bakim_turu (bakim_tur_id, bakim_tur_adi) FROM stdin;
10	PERIYODIK BAKIM
\.


--
-- TOC entry 3864 (class 0 OID 16427)
-- Dependencies: 225
-- Data for Name: firma; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.firma (firma_id, firma_adi, vergi_no, aktif_mi, abonelik_tip_id, iletisim_id, sektor_id) FROM stdin;
1	logo	12345werty	t	\N	\N	\N
6	ASELSAN İZMIR	\N	\N	\N	\N	\N
8	ASELSAN İSTANBUL	\N	\N	\N	\N	\N
9	ABC ENDÜSTRI A.Ş.	\N	\N	\N	\N	\N
15	KARADENIZ AHŞAP VE MOBILYA	\N	\N	\N	\N	\N
\.


--
-- TOC entry 3866 (class 0 OID 16433)
-- Dependencies: 227
-- Data for Name: form_madde_cevap; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.form_madde_cevap (cevap_id, form_id, soru_referans_id, durum, aciklama, girilen_deger) FROM stdin;
\.


--
-- TOC entry 3905 (class 0 OID 33220)
-- Dependencies: 266
-- Data for Name: garanti_firma; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.garanti_firma (garanti_firma_id, firma_adi, iletisim_id) FROM stdin;
\.


--
-- TOC entry 3899 (class 0 OID 33168)
-- Dependencies: 260
-- Data for Name: genel_sorular; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.genel_sorular (genel_soru_id, madde_adi, teknik_parametre, aktiflik, kritiklik_durumu) FROM stdin;
\.


--
-- TOC entry 3868 (class 0 OID 16439)
-- Dependencies: 229
-- Data for Name: gunluk_kontrol_formu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.gunluk_kontrol_formu (form_id, makine_id, kullanici_id, sablon_id, kontrol_tarihi, genel_not, ai_on_risk_durumu) FROM stdin;
\.


--
-- TOC entry 3916 (class 0 OID 49922)
-- Dependencies: 281
-- Data for Name: iletisim; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.iletisim (iletisim_id, telefon, mail, il, ilce, acik_adres) FROM stdin;
1	+902125551020	info@globalteknik.com	İstanbul	İkitelli	İkitelli Organize Sanayi Bölgesi, Metal İş Sanayi Sitesi, 12. Blok No:45
5	0224 243 10 00	satis@marmarametal.com.tr	Bursa	Nilüfer	Organize Sanayi Bölgesi, 75. Yıl Bulvarı No:12/A
\.


--
-- TOC entry 3870 (class 0 OID 16445)
-- Dependencies: 231
-- Data for Name: kontrol_maddesi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.kontrol_maddesi (madde_id, sablon_id, madde_adi, teknik_parametre, kritiklik_durumu) FROM stdin;
\.


--
-- TOC entry 3872 (class 0 OID 16451)
-- Dependencies: 233
-- Data for Name: kontrol_sablonu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.kontrol_sablonu (sablon_id, makine_tur_id, sablon_adi, aciklama, aktiflik) FROM stdin;
\.


--
-- TOC entry 3874 (class 0 OID 16457)
-- Dependencies: 235
-- Data for Name: kullanici; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.kullanici (kullanici_id, firma_id, rol_id, ad, soyad, telefon, eposta, sifre, aktiflik, baslama_tarihi, kullanici_adi) FROM stdin;
1	1	1	Ahmet	Yılmaz	+905551234567	ahmet.yilmaz@firma.com	e10a56e057f20f883e	t	2022-01-15	ahmetyilmaz
\.


--
-- TOC entry 3876 (class 0 OID 16461)
-- Dependencies: 237
-- Data for Name: lokasyon; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lokasyon (lokasyon_id, fabrika_alani, kat, x_koor, y_koor, guncelleme_tarihi, firma_id, makine_id) FROM stdin;
\.


--
-- TOC entry 3878 (class 0 OID 16467)
-- Dependencies: 239
-- Data for Name: makine; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine (makine_id, firma_id, makine_tur_id, makine_qr, makine_adi, satin_alma_tarihi, satin_alma_maliyeti, aktiflik_durumu, seri_no, garanti_suresi, garanti_firma_id, servis_pin, toplam_calisma_saati) FROM stdin;
23	15	16	QR-KSM-9004	CNC Panel Ebatlama	2021-06-15	85000.0000	t	SN-KRD-4040	12	\N	3344	8500.00
\.


--
-- TOC entry 3879 (class 0 OID 16472)
-- Dependencies: 240
-- Data for Name: makine_kullanim; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine_kullanim (kullanim_id, kullanici_id, makine_id, baslangic_zamani, bitis_zamani, gunluk_top_calisma_saati) FROM stdin;
\.


--
-- TOC entry 3903 (class 0 OID 33203)
-- Dependencies: 264
-- Data for Name: makine_ozellikleri; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine_ozellikleri (ozellik_id, makine_id, teknik_ozellikler, guncelleme_tarihi) FROM stdin;
5	23	{"motor_gucu_kw": 5.5, "testere_capi_mm": 300, "otomatik_besleme": false}	2026-04-04 20:06:40.420105
\.


--
-- TOC entry 3881 (class 0 OID 16478)
-- Dependencies: 242
-- Data for Name: makine_turu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine_turu (makine_tur_id, makine_tur_adi, risk_katsayisi) FROM stdin;
5	lazer kesim	\N
6	Abkant Pres	0.45
8	CNC TEZGAHI	\N
9	CNC2 TEZGAHI	2.20
10	CNC TORNA	1.75
16	KESIM MAKINESI	1.40
\.


--
-- TOC entry 3884 (class 0 OID 16485)
-- Dependencies: 245
-- Data for Name: parca; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parca (parca_id, parca_adi, tahmini_omur_saati, parca_maliyeti, tedarik_gun_suresi, kategori_id, tedarikci_id) FROM stdin;
1	HAVA FILTRESI	2000.00	450	2	1	1
2	RULMAN 6205-ZZ	15000.50	450	3	3	1
\.


--
-- TOC entry 3885 (class 0 OID 16490)
-- Dependencies: 246
-- Data for Name: parca_degisim; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parca_degisim (parca_degisim_id, bakim_id, parca_id) FROM stdin;
1	10	1
2	11	1
\.


--
-- TOC entry 3912 (class 0 OID 49703)
-- Dependencies: 273
-- Data for Name: parca_kategori; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parca_kategori (kategori_id, kategori_adi) FROM stdin;
1	rullmanlar
3	MEKANIK BILEŞENLER
\.


--
-- TOC entry 3888 (class 0 OID 16495)
-- Dependencies: 249
-- Data for Name: risk_skoru; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.risk_skoru (risk_id, makine_id, risk_skoru, risk_seviyesi, hesaplama_tarihi) FROM stdin;
\.


--
-- TOC entry 3890 (class 0 OID 16501)
-- Dependencies: 251
-- Data for Name: rol; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rol (rol_id, rol_adi) FROM stdin;
1	OPERATOR
2	TEKNİSYEN
3	YONETİCİ
4	SERVİS
\.


--
-- TOC entry 3918 (class 0 OID 49931)
-- Dependencies: 283
-- Data for Name: sektor; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sektor (sektor_id, sektor_adi) FROM stdin;
\.


--
-- TOC entry 3892 (class 0 OID 16507)
-- Dependencies: 253
-- Data for Name: servis_firma; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_firma (servis_firma_id, firma_adi, aktiflik, iletisim_id) FROM stdin;
12	ABC MAKINE SERVIS LTD.	t	\N
\.


--
-- TOC entry 3910 (class 0 OID 41524)
-- Dependencies: 271
-- Data for Name: servis_firma_uzmanlik; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_firma_uzmanlik (servis_firma_id, uzmanlik_adi) FROM stdin;
\.


--
-- TOC entry 3907 (class 0 OID 33259)
-- Dependencies: 268
-- Data for Name: servis_puan; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_puan (puan_id, servis_firma_id, puanlayan_kullanici_id, puan, yorum, tarih) FROM stdin;
\.


--
-- TOC entry 3897 (class 0 OID 24689)
-- Dependencies: 258
-- Data for Name: servis_sorumlusu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_sorumlusu (sorumlu_id, servis_firma_id, ad, soyad, telefon, aktiflik, unvan, sorumlu_adi) FROM stdin;
\.


--
-- TOC entry 3894 (class 0 OID 16513)
-- Dependencies: 255
-- Data for Name: tedarikci; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tedarikci (tedarikci_id, firma_adi, aktiflik, guvenilirlik_skoru, vergi_no, yetkili_kisi, kayit_tarihi, iletisim_id) FROM stdin;
1	Global Teknik Parça A.Ş.	t	95.50	1234567890	Mustafa Yılmaz	2023-01-10 00:00:00+00	1
2	MARMARA METAL ŞEKILLENDIRME A.Ş.	t	\N	6120345981	Kenan Özdemir	2026-04-16 00:00:00+00	5
\.


--
-- TOC entry 3922 (class 0 OID 49995)
-- Dependencies: 287
-- Data for Name: tedarikci_parca; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tedarikci_parca (tedarikci_parca_id, tedarik_id, parca_id, tedarik_maliyeti) FROM stdin;
\.


--
-- TOC entry 3909 (class 0 OID 33278)
-- Dependencies: 270
-- Data for Name: tedarikci_puan; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tedarikci_puan (puan_id, tedarikci_id, puanlayan_kullanici_id, puan, yorum, tarih) FROM stdin;
\.


--
-- TOC entry 3963 (class 0 OID 0)
-- Dependencies: 284
-- Name: abonelik_tipi_abonelik_tip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.abonelik_tipi_abonelik_tip_id_seq', 1, false);


--
-- TOC entry 3964 (class 0 OID 0)
-- Dependencies: 216
-- Name: ai_ariza_tespit_tespit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ai_ariza_tespit_tespit_id_seq', 1, false);


--
-- TOC entry 3965 (class 0 OID 0)
-- Dependencies: 218
-- Name: ai_model_log_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ai_model_log_log_id_seq', 1, false);


--
-- TOC entry 3966 (class 0 OID 0)
-- Dependencies: 220
-- Name: ariza_kaydi_ariza_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ariza_kaydi_ariza_id_seq', 3, true);


--
-- TOC entry 3967 (class 0 OID 0)
-- Dependencies: 261
-- Name: ariza_turu_ariza_tur_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ariza_turu_ariza_tur_id_seq', 2, true);


--
-- TOC entry 3968 (class 0 OID 0)
-- Dependencies: 222
-- Name: arizayi_tetikleyen_form_tetik_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.arizayi_tetikleyen_form_tetik_id_seq', 1, false);


--
-- TOC entry 3969 (class 0 OID 0)
-- Dependencies: 224
-- Name: bakim_kaydi_bakim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bakim_kaydi_bakim_id_seq', 12, true);


--
-- TOC entry 3970 (class 0 OID 0)
-- Dependencies: 277
-- Name: bakim_turu_bakim_tur_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bakim_turu_bakim_tur_id_seq', 10, true);


--
-- TOC entry 3971 (class 0 OID 0)
-- Dependencies: 226
-- Name: firma_firma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.firma_firma_id_seq', 15, true);


--
-- TOC entry 3972 (class 0 OID 0)
-- Dependencies: 228
-- Name: form_madde_cevap_cevap_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.form_madde_cevap_cevap_id_seq', 1, false);


--
-- TOC entry 3973 (class 0 OID 0)
-- Dependencies: 265
-- Name: garanti_firma_garanti_firma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.garanti_firma_garanti_firma_id_seq', 6, true);


--
-- TOC entry 3974 (class 0 OID 0)
-- Dependencies: 259
-- Name: genel_sorular_genel_soru_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.genel_sorular_genel_soru_id_seq', 1, false);


--
-- TOC entry 3975 (class 0 OID 0)
-- Dependencies: 230
-- Name: gunluk_kontrol_formu_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.gunluk_kontrol_formu_form_id_seq', 1, false);


--
-- TOC entry 3976 (class 0 OID 0)
-- Dependencies: 280
-- Name: iletisim_iletisim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.iletisim_iletisim_id_seq', 5, true);


--
-- TOC entry 3977 (class 0 OID 0)
-- Dependencies: 232
-- Name: kontrol_maddesi_madde_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.kontrol_maddesi_madde_id_seq', 1, false);


--
-- TOC entry 3978 (class 0 OID 0)
-- Dependencies: 234
-- Name: kontrol_sablonu_sablon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.kontrol_sablonu_sablon_id_seq', 1, false);


--
-- TOC entry 3979 (class 0 OID 0)
-- Dependencies: 236
-- Name: kullanici_kullanici_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.kullanici_kullanici_id_seq', 1, false);


--
-- TOC entry 3980 (class 0 OID 0)
-- Dependencies: 238
-- Name: lokasyon_lokasyon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lokasyon_lokasyon_id_seq', 1, false);


--
-- TOC entry 3981 (class 0 OID 0)
-- Dependencies: 241
-- Name: makine_makine_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_makine_id_seq', 23, true);


--
-- TOC entry 3982 (class 0 OID 0)
-- Dependencies: 263
-- Name: makine_ozellikleri_ozellik_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_ozellikleri_ozellik_id_seq', 5, true);


--
-- TOC entry 3983 (class 0 OID 0)
-- Dependencies: 243
-- Name: makine_turu_m_tur_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_turu_m_tur_id_seq', 16, true);


--
-- TOC entry 3984 (class 0 OID 0)
-- Dependencies: 244
-- Name: operator_makine_kullanim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.operator_makine_kullanim_id_seq', 1, false);


--
-- TOC entry 3985 (class 0 OID 0)
-- Dependencies: 247
-- Name: parca_degisim_degisim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parca_degisim_degisim_id_seq', 2, true);


--
-- TOC entry 3986 (class 0 OID 0)
-- Dependencies: 272
-- Name: parca_kategori_kategori_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parca_kategori_kategori_id_seq', 3, true);


--
-- TOC entry 3987 (class 0 OID 0)
-- Dependencies: 248
-- Name: parca_parca_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parca_parca_id_seq', 2, true);


--
-- TOC entry 3988 (class 0 OID 0)
-- Dependencies: 250
-- Name: risk_skoru_risk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.risk_skoru_risk_id_seq', 1, false);


--
-- TOC entry 3989 (class 0 OID 0)
-- Dependencies: 252
-- Name: rol_rol_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.rol_rol_id_seq', 1, false);


--
-- TOC entry 3990 (class 0 OID 0)
-- Dependencies: 282
-- Name: sektor_sektor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.sektor_sektor_id_seq', 1, false);


--
-- TOC entry 3991 (class 0 OID 0)
-- Dependencies: 254
-- Name: servis_firma_servis_firma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.servis_firma_servis_firma_id_seq', 12, true);


--
-- TOC entry 3992 (class 0 OID 0)
-- Dependencies: 267
-- Name: servis_puan_puan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.servis_puan_puan_id_seq', 1, false);


--
-- TOC entry 3993 (class 0 OID 0)
-- Dependencies: 269
-- Name: tedarakci_puan_puan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tedarakci_puan_puan_id_seq', 1, false);


--
-- TOC entry 3994 (class 0 OID 0)
-- Dependencies: 286
-- Name: tedarikci_parca_tedarikci_parca_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tedarikci_parca_tedarikci_parca_id_seq', 1, false);


--
-- TOC entry 3995 (class 0 OID 0)
-- Dependencies: 256
-- Name: tedarikci_tedarikci_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tedarikci_tedarikci_id_seq', 2, true);


--
-- TOC entry 3996 (class 0 OID 0)
-- Dependencies: 257
-- Name: teknisyen_teknisyen_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.teknisyen_teknisyen_id_seq', 1, false);


--
-- TOC entry 3646 (class 2606 OID 49943)
-- Name: abonelik_tipi abonelik_tipi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonelik_tipi
    ADD CONSTRAINT abonelik_tipi_pkey PRIMARY KEY (abonelik_tip_id);


--
-- TOC entry 3526 (class 2606 OID 16546)
-- Name: ai_ariza_tespit ai_ariza_tespit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT ai_ariza_tespit_pkey PRIMARY KEY (tespit_id);


--
-- TOC entry 3531 (class 2606 OID 16548)
-- Name: ai_model_log ai_model_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT ai_model_log_pkey PRIMARY KEY (log_id);


--
-- TOC entry 3533 (class 2606 OID 16550)
-- Name: ariza_kaydi ariza_kaydi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi
    ADD CONSTRAINT ariza_kaydi_pkey PRIMARY KEY (ariza_id);


--
-- TOC entry 3617 (class 2606 OID 33196)
-- Name: ariza_turu ariza_turu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_turu
    ADD CONSTRAINT ariza_turu_pkey PRIMARY KEY (ariza_tur_id);


--
-- TOC entry 3537 (class 2606 OID 16552)
-- Name: arizayi_tetikleyen_form arizayi_tetikleyen_form_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT arizayi_tetikleyen_form_pkey PRIMARY KEY (tetik_id);


--
-- TOC entry 3542 (class 2606 OID 16554)
-- Name: bakim_kaydi bakim_kaydi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT bakim_kaydi_pkey PRIMARY KEY (bakim_id);


--
-- TOC entry 3638 (class 2606 OID 49877)
-- Name: bakim_turu bakim_turu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_turu
    ADD CONSTRAINT bakim_turu_pkey PRIMARY KEY (bakim_tur_id);


--
-- TOC entry 3547 (class 2606 OID 16556)
-- Name: firma firma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT firma_pkey PRIMARY KEY (firma_id);


--
-- TOC entry 3551 (class 2606 OID 16558)
-- Name: form_madde_cevap form_madde_cevap_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap
    ADD CONSTRAINT form_madde_cevap_pkey PRIMARY KEY (cevap_id);


--
-- TOC entry 3623 (class 2606 OID 33225)
-- Name: garanti_firma garanti_firma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.garanti_firma
    ADD CONSTRAINT garanti_firma_pkey PRIMARY KEY (garanti_firma_id);


--
-- TOC entry 3615 (class 2606 OID 33173)
-- Name: genel_sorular genel_sorular_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genel_sorular
    ADD CONSTRAINT genel_sorular_pkey PRIMARY KEY (genel_soru_id);


--
-- TOC entry 3555 (class 2606 OID 16560)
-- Name: gunluk_kontrol_formu gunluk_kontrol_formu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT gunluk_kontrol_formu_pkey PRIMARY KEY (form_id);


--
-- TOC entry 3640 (class 2606 OID 49929)
-- Name: iletisim iletisim_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iletisim
    ADD CONSTRAINT iletisim_pkey PRIMARY KEY (iletisim_id);


--
-- TOC entry 3563 (class 2606 OID 16562)
-- Name: kontrol_maddesi kontrol_maddesi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_maddesi
    ADD CONSTRAINT kontrol_maddesi_pkey PRIMARY KEY (madde_id);


--
-- TOC entry 3566 (class 2606 OID 16564)
-- Name: kontrol_sablonu kontrol_sablonu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_sablonu
    ADD CONSTRAINT kontrol_sablonu_pkey PRIMARY KEY (sablon_id);


--
-- TOC entry 3572 (class 2606 OID 16566)
-- Name: kullanici kullanici_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT kullanici_pkey PRIMARY KEY (kullanici_id);


--
-- TOC entry 3576 (class 2606 OID 16568)
-- Name: lokasyon lokasyon_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon
    ADD CONSTRAINT lokasyon_pkey PRIMARY KEY (lokasyon_id);


--
-- TOC entry 3619 (class 2606 OID 33213)
-- Name: makine_ozellikleri makine_ozellikleri_makine_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_ozellikleri
    ADD CONSTRAINT makine_ozellikleri_makine_id_key UNIQUE (makine_id);


--
-- TOC entry 3621 (class 2606 OID 33211)
-- Name: makine_ozellikleri makine_ozellikleri_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_ozellikleri
    ADD CONSTRAINT makine_ozellikleri_pkey PRIMARY KEY (ozellik_id);


--
-- TOC entry 3581 (class 2606 OID 16570)
-- Name: makine makine_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT makine_pkey PRIMARY KEY (makine_id);


--
-- TOC entry 3592 (class 2606 OID 16572)
-- Name: makine_turu makine_turu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_turu
    ADD CONSTRAINT makine_turu_pkey PRIMARY KEY (makine_tur_id);


--
-- TOC entry 3590 (class 2606 OID 16574)
-- Name: makine_kullanim operator_makine_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim
    ADD CONSTRAINT operator_makine_pkey PRIMARY KEY (kullanim_id);


--
-- TOC entry 3594 (class 2606 OID 50076)
-- Name: parca parca_adi; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT parca_adi UNIQUE (parca_adi);


--
-- TOC entry 3601 (class 2606 OID 16576)
-- Name: parca_degisim parca_degisim_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT parca_degisim_pkey PRIMARY KEY (parca_degisim_id);


--
-- TOC entry 3634 (class 2606 OID 49708)
-- Name: parca_kategori parca_kategori_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_kategori
    ADD CONSTRAINT parca_kategori_pkey PRIMARY KEY (kategori_id);


--
-- TOC entry 3596 (class 2606 OID 16578)
-- Name: parca parca_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT parca_pkey PRIMARY KEY (parca_id);


--
-- TOC entry 3605 (class 2606 OID 16580)
-- Name: risk_skoru risk_skoru_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_skoru
    ADD CONSTRAINT risk_skoru_pkey PRIMARY KEY (risk_id);


--
-- TOC entry 3607 (class 2606 OID 16582)
-- Name: rol rol_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (rol_id);


--
-- TOC entry 3644 (class 2606 OID 49936)
-- Name: sektor sektor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sektor
    ADD CONSTRAINT sektor_pkey PRIMARY KEY (sektor_id);


--
-- TOC entry 3609 (class 2606 OID 16584)
-- Name: servis_firma servis_firma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma
    ADD CONSTRAINT servis_firma_pkey PRIMARY KEY (servis_firma_id);


--
-- TOC entry 3632 (class 2606 OID 41542)
-- Name: servis_firma_uzmanlik servis_firma_uzmanlik_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma_uzmanlik
    ADD CONSTRAINT servis_firma_uzmanlik_pkey PRIMARY KEY (servis_firma_id);


--
-- TOC entry 3627 (class 2606 OID 33266)
-- Name: servis_puan servis_puan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan
    ADD CONSTRAINT servis_puan_pkey PRIMARY KEY (puan_id);


--
-- TOC entry 3613 (class 2606 OID 24694)
-- Name: servis_sorumlusu servis_sorumlusu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_sorumlusu
    ADD CONSTRAINT servis_sorumlusu_pkey PRIMARY KEY (sorumlu_id);


--
-- TOC entry 3630 (class 2606 OID 33285)
-- Name: tedarikci_puan tedarakci_puan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan
    ADD CONSTRAINT tedarakci_puan_pkey PRIMARY KEY (puan_id);


--
-- TOC entry 3648 (class 2606 OID 50000)
-- Name: tedarikci_parca tedarikci_parca_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca
    ADD CONSTRAINT tedarikci_parca_pkey PRIMARY KEY (tedarikci_parca_id);


--
-- TOC entry 3611 (class 2606 OID 16586)
-- Name: tedarikci tedarikci_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci
    ADD CONSTRAINT tedarikci_pkey PRIMARY KEY (tedarikci_id);


--
-- TOC entry 3636 (class 2606 OID 50102)
-- Name: parca_kategori unique_kategori_adi; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_kategori
    ADD CONSTRAINT unique_kategori_adi UNIQUE (kategori_adi);


--
-- TOC entry 3574 (class 2606 OID 50039)
-- Name: kullanici unique_kullanici; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT unique_kullanici UNIQUE (kullanici_adi);


--
-- TOC entry 3598 (class 2606 OID 50080)
-- Name: parca unique_parca_adi; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT unique_parca_adi UNIQUE (parca_adi);


--
-- TOC entry 3642 (class 2606 OID 50078)
-- Name: iletisim unique_telefon; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iletisim
    ADD CONSTRAINT unique_telefon UNIQUE (telefon);


--
-- TOC entry 3583 (class 2606 OID 49910)
-- Name: makine uq_makine_qr; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT uq_makine_qr UNIQUE (makine_qr);


--
-- TOC entry 3585 (class 2606 OID 49912)
-- Name: makine uq_seri_no; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT uq_seri_no UNIQUE (seri_no);


--
-- TOC entry 3549 (class 2606 OID 49908)
-- Name: firma uq_vergi_no; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT uq_vergi_no UNIQUE (vergi_no);


--
-- TOC entry 3534 (class 1259 OID 49745)
-- Name: idx_ariza_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ariza_tarih ON public.ariza_kaydi USING btree (baslangic_zamani);


--
-- TOC entry 3543 (class 1259 OID 16588)
-- Name: idx_bakim_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bakim_makine ON public.bakim_kaydi USING btree (makine_id);


--
-- TOC entry 3544 (class 1259 OID 16589)
-- Name: idx_bakim_servis; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bakim_servis ON public.bakim_kaydi USING btree (servis_firma_id);


--
-- TOC entry 3545 (class 1259 OID 16590)
-- Name: idx_bakim_teknisyen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bakim_teknisyen ON public.bakim_kaydi USING btree (sorumlu_id);


--
-- TOC entry 3552 (class 1259 OID 16591)
-- Name: idx_cevap_form; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cevap_form ON public.form_madde_cevap USING btree (form_id);


--
-- TOC entry 3553 (class 1259 OID 16592)
-- Name: idx_cevap_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cevap_madde ON public.form_madde_cevap USING btree (soru_referans_id);


--
-- TOC entry 3599 (class 1259 OID 16593)
-- Name: idx_degisim_bakim; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_degisim_bakim ON public.parca_degisim USING btree (bakim_id);


--
-- TOC entry 3560 (class 1259 OID 16596)
-- Name: idx_kontrol_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kontrol_madde ON public.kontrol_maddesi USING btree (madde_id);


--
-- TOC entry 3561 (class 1259 OID 16597)
-- Name: idx_kontrol_sablon; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kontrol_sablon ON public.kontrol_maddesi USING btree (sablon_id);


--
-- TOC entry 3567 (class 1259 OID 24687)
-- Name: idx_kullanici_adi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kullanici_adi ON public.kullanici USING btree (kullanici_adi);


--
-- TOC entry 3568 (class 1259 OID 16598)
-- Name: idx_kullanici_eposta; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_kullanici_eposta ON public.kullanici USING btree (eposta);


--
-- TOC entry 3569 (class 1259 OID 16599)
-- Name: idx_kullanici_firma_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kullanici_firma_id ON public.kullanici USING btree (firma_id);


--
-- TOC entry 3570 (class 1259 OID 16600)
-- Name: idx_kullanici_rol_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kullanici_rol_id ON public.kullanici USING btree (rol_id);


--
-- TOC entry 3535 (class 1259 OID 16601)
-- Name: idx_m_ariza; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_m_ariza ON public.ariza_kaydi USING btree (makine_id);


--
-- TOC entry 3577 (class 1259 OID 24630)
-- Name: idx_m_qr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_m_qr ON public.makine USING btree (makine_qr);


--
-- TOC entry 3578 (class 1259 OID 16604)
-- Name: idx_makine_firma; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_firma ON public.makine USING btree (firma_id);


--
-- TOC entry 3556 (class 1259 OID 16605)
-- Name: idx_makine_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_id ON public.gunluk_kontrol_formu USING btree (makine_id);


--
-- TOC entry 3586 (class 1259 OID 16606)
-- Name: idx_makine_kullanim_baslangic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_kullanim_baslangic ON public.makine_kullanim USING btree (baslangic_zamani);


--
-- TOC entry 3587 (class 1259 OID 16607)
-- Name: idx_makine_kullanim_kullanici_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_kullanim_kullanici_id ON public.makine_kullanim USING btree (kullanici_id);


--
-- TOC entry 3579 (class 1259 OID 16609)
-- Name: idx_makine_turu; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_turu ON public.makine USING btree (makine_tur_id);


--
-- TOC entry 3588 (class 1259 OID 49920)
-- Name: idx_mkullanim_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mkullanim_makine ON public.makine_kullanim USING btree (makine_id);


--
-- TOC entry 3557 (class 1259 OID 16610)
-- Name: idx_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_id ON public.gunluk_kontrol_formu USING btree (kullanici_id);


--
-- TOC entry 3602 (class 1259 OID 16612)
-- Name: idx_risk_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_risk_makine ON public.risk_skoru USING btree (makine_id);


--
-- TOC entry 3603 (class 1259 OID 49780)
-- Name: idx_risk_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_risk_tarih ON public.risk_skoru USING btree (hesaplama_tarihi);


--
-- TOC entry 3558 (class 1259 OID 16614)
-- Name: idx_sablon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sablon_id ON public.gunluk_kontrol_formu USING btree (sablon_id);


--
-- TOC entry 3564 (class 1259 OID 16615)
-- Name: idx_sablon_m_turu; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sablon_m_turu ON public.kontrol_sablonu USING btree (makine_tur_id);


--
-- TOC entry 3624 (class 1259 OID 49917)
-- Name: idx_spuan_firma; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_spuan_firma ON public.servis_puan USING btree (servis_firma_id);


--
-- TOC entry 3625 (class 1259 OID 49918)
-- Name: idx_spuan_kullanici; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_spuan_kullanici ON public.servis_puan USING btree (puanlayan_kullanici_id);


--
-- TOC entry 3559 (class 1259 OID 32997)
-- Name: idx_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tarih ON public.gunluk_kontrol_formu USING btree (kontrol_tarihi);


--
-- TOC entry 3527 (class 1259 OID 16617)
-- Name: idx_tespit_form; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tespit_form ON public.ai_ariza_tespit USING btree (form_id);


--
-- TOC entry 3528 (class 1259 OID 16618)
-- Name: idx_tespit_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tespit_madde ON public.ai_ariza_tespit USING btree (madde_id);


--
-- TOC entry 3529 (class 1259 OID 16619)
-- Name: idx_tespit_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tespit_makine ON public.ai_ariza_tespit USING btree (makine_id);


--
-- TOC entry 3538 (class 1259 OID 16620)
-- Name: idx_tetik_form; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tetik_form ON public.arizayi_tetikleyen_form USING btree (form_id);


--
-- TOC entry 3539 (class 1259 OID 16621)
-- Name: idx_tetik_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tetik_madde ON public.arizayi_tetikleyen_form USING btree (madde_id);


--
-- TOC entry 3540 (class 1259 OID 49770)
-- Name: idx_tetik_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tetik_tarih ON public.arizayi_tetikleyen_form USING btree (tespit_tarihi);


--
-- TOC entry 3628 (class 1259 OID 49919)
-- Name: idx_tpuan_tedarikci; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tpuan_tedarikci ON public.tedarikci_puan USING btree (tedarikci_id);


--
-- TOC entry 3699 (class 2620 OID 50071)
-- Name: bakim_kaydi trg_bakim_sonrasi_ariza_kapat; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_bakim_sonrasi_ariza_kapat AFTER INSERT ON public.bakim_kaydi FOR EACH ROW EXECUTE FUNCTION public.fn_bakim_girince_arizayi_kapat();


--
-- TOC entry 3700 (class 2620 OID 16623)
-- Name: gunluk_kontrol_formu trg_form_sonasi; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_form_sonasi AFTER INSERT ON public.gunluk_kontrol_formu FOR EACH ROW EXECUTE FUNCTION public.func_form_sonrasi_tetikle();


--
-- TOC entry 3692 (class 2606 OID 33267)
-- Name: servis_puan firma_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan
    ADD CONSTRAINT firma_fk FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3664 (class 2606 OID 49960)
-- Name: firma fk_abonelik; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT fk_abonelik FOREIGN KEY (abonelik_tip_id) REFERENCES public.abonelik_tipi(abonelik_tip_id) NOT VALID;


--
-- TOC entry 3652 (class 2606 OID 16624)
-- Name: ai_model_log fk_ai_log; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT fk_ai_log FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3657 (class 2606 OID 16629)
-- Name: arizayi_tetikleyen_form fk_ariza; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT fk_ariza FOREIGN KEY (ariza_id) REFERENCES public.ariza_kaydi(ariza_id);


--
-- TOC entry 3660 (class 2606 OID 16634)
-- Name: bakim_kaydi fk_ariza; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_ariza FOREIGN KEY (ariza_id) REFERENCES public.ariza_kaydi(ariza_id) NOT VALID;


--
-- TOC entry 3655 (class 2606 OID 33197)
-- Name: ariza_kaydi fk_ariza_tur; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi
    ADD CONSTRAINT fk_ariza_tur FOREIGN KEY (ariza_tur_id) REFERENCES public.ariza_turu(ariza_tur_id) NOT VALID;


--
-- TOC entry 3661 (class 2606 OID 49878)
-- Name: bakim_kaydi fk_bakim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_bakim FOREIGN KEY (bakim_tur_id) REFERENCES public.bakim_turu(bakim_tur_id) NOT VALID;


--
-- TOC entry 3684 (class 2606 OID 16639)
-- Name: parca_degisim fk_bakim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT fk_bakim FOREIGN KEY (bakim_id) REFERENCES public.bakim_kaydi(bakim_id);


--
-- TOC entry 3673 (class 2606 OID 16644)
-- Name: kullanici fk_firma; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT fk_firma FOREIGN KEY (firma_id) REFERENCES public.firma(firma_id);


--
-- TOC entry 3677 (class 2606 OID 16649)
-- Name: makine fk_firma; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT fk_firma FOREIGN KEY (firma_id) REFERENCES public.firma(firma_id);


--
-- TOC entry 3649 (class 2606 OID 16654)
-- Name: ai_ariza_tespit fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3653 (class 2606 OID 16659)
-- Name: ai_model_log fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id) NOT VALID;


--
-- TOC entry 3658 (class 2606 OID 16664)
-- Name: arizayi_tetikleyen_form fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3667 (class 2606 OID 16669)
-- Name: form_madde_cevap fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3678 (class 2606 OID 33226)
-- Name: makine fk_garanti_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT fk_garanti_id FOREIGN KEY (garanti_firma_id) REFERENCES public.garanti_firma(garanti_firma_id) NOT VALID;


--
-- TOC entry 3665 (class 2606 OID 49950)
-- Name: firma fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id) NOT VALID;


--
-- TOC entry 3691 (class 2606 OID 49945)
-- Name: garanti_firma fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.garanti_firma
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id) NOT VALID;


--
-- TOC entry 3687 (class 2606 OID 49965)
-- Name: servis_firma fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id) NOT VALID;


--
-- TOC entry 3688 (class 2606 OID 49970)
-- Name: tedarikci fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id) NOT VALID;


--
-- TOC entry 3682 (class 2606 OID 49709)
-- Name: parca fk_kategori; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT fk_kategori FOREIGN KEY (kategori_id) REFERENCES public.parca_kategori(kategori_id) NOT VALID;


--
-- TOC entry 3654 (class 2606 OID 16674)
-- Name: ai_model_log fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id) NOT VALID;


--
-- TOC entry 3669 (class 2606 OID 16684)
-- Name: gunluk_kontrol_formu fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id) NOT VALID;


--
-- TOC entry 3680 (class 2606 OID 16689)
-- Name: makine_kullanim fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id) NOT VALID;


--
-- TOC entry 3694 (class 2606 OID 33291)
-- Name: tedarikci_puan fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (puanlayan_kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3650 (class 2606 OID 16699)
-- Name: ai_ariza_tespit fk_madde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT fk_madde FOREIGN KEY (madde_id) REFERENCES public.kontrol_maddesi(madde_id);


--
-- TOC entry 3659 (class 2606 OID 16704)
-- Name: arizayi_tetikleyen_form fk_madde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT fk_madde FOREIGN KEY (madde_id) REFERENCES public.kontrol_maddesi(madde_id);


--
-- TOC entry 3668 (class 2606 OID 16709)
-- Name: form_madde_cevap fk_madde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap
    ADD CONSTRAINT fk_madde FOREIGN KEY (soru_referans_id) REFERENCES public.kontrol_maddesi(madde_id);


--
-- TOC entry 3651 (class 2606 OID 16714)
-- Name: ai_ariza_tespit fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3656 (class 2606 OID 16719)
-- Name: ariza_kaydi fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3662 (class 2606 OID 16724)
-- Name: bakim_kaydi fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3670 (class 2606 OID 16729)
-- Name: gunluk_kontrol_formu fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3675 (class 2606 OID 50011)
-- Name: lokasyon fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id) NOT VALID;


--
-- TOC entry 3681 (class 2606 OID 16734)
-- Name: makine_kullanim fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3690 (class 2606 OID 33214)
-- Name: makine_ozellikleri fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_ozellikleri
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id) ON DELETE CASCADE;


--
-- TOC entry 3686 (class 2606 OID 16744)
-- Name: risk_skoru fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_skoru
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3679 (class 2606 OID 49822)
-- Name: makine fk_makine_turu; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT fk_makine_turu FOREIGN KEY (makine_tur_id) REFERENCES public.makine_turu(makine_tur_id) NOT VALID;


--
-- TOC entry 3685 (class 2606 OID 49977)
-- Name: parca_degisim fk_parca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT fk_parca FOREIGN KEY (parca_id) REFERENCES public.parca(parca_id) NOT VALID;


--
-- TOC entry 3697 (class 2606 OID 50006)
-- Name: tedarikci_parca fk_parca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca
    ADD CONSTRAINT fk_parca FOREIGN KEY (parca_id) REFERENCES public.parca(parca_id);


--
-- TOC entry 3674 (class 2606 OID 16764)
-- Name: kullanici fk_rol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT fk_rol FOREIGN KEY (rol_id) REFERENCES public.rol(rol_id);


--
-- TOC entry 3671 (class 2606 OID 16769)
-- Name: gunluk_kontrol_formu fk_sablon; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT fk_sablon FOREIGN KEY (sablon_id) REFERENCES public.kontrol_sablonu(sablon_id);


--
-- TOC entry 3672 (class 2606 OID 16774)
-- Name: kontrol_sablonu fk_sablon_kontrol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_sablonu
    ADD CONSTRAINT fk_sablon_kontrol FOREIGN KEY (makine_tur_id) REFERENCES public.makine_turu(makine_tur_id);


--
-- TOC entry 3666 (class 2606 OID 49955)
-- Name: firma fk_sektor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT fk_sektor FOREIGN KEY (sektor_id) REFERENCES public.sektor(sektor_id) NOT VALID;


--
-- TOC entry 3663 (class 2606 OID 16779)
-- Name: bakim_kaydi fk_servis; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_servis FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3689 (class 2606 OID 33253)
-- Name: servis_sorumlusu fk_sorumlusu; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_sorumlusu
    ADD CONSTRAINT fk_sorumlusu FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id) NOT VALID;


--
-- TOC entry 3683 (class 2606 OID 50060)
-- Name: parca fk_tedarikci; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT fk_tedarikci FOREIGN KEY (tedarikci_id) REFERENCES public.tedarikci(tedarikci_id) NOT VALID;


--
-- TOC entry 3698 (class 2606 OID 50001)
-- Name: tedarikci_parca fk_tedarikci; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca
    ADD CONSTRAINT fk_tedarikci FOREIGN KEY (tedarik_id) REFERENCES public.tedarikci(tedarikci_id);


--
-- TOC entry 3693 (class 2606 OID 33272)
-- Name: servis_puan kullanici_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan
    ADD CONSTRAINT kullanici_fk FOREIGN KEY (puanlayan_kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3676 (class 2606 OID 49898)
-- Name: lokasyon lokasyon_firma_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon
    ADD CONSTRAINT lokasyon_firma_id_fkey FOREIGN KEY (firma_id) REFERENCES public.firma(firma_id);


--
-- TOC entry 3696 (class 2606 OID 41529)
-- Name: servis_firma_uzmanlik servis_firma_uzmanlik_servis_firma_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma_uzmanlik
    ADD CONSTRAINT servis_firma_uzmanlik_servis_firma_id_fkey FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3695 (class 2606 OID 33286)
-- Name: tedarikci_puan tk_tedarikci; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan
    ADD CONSTRAINT tk_tedarikci FOREIGN KEY (tedarikci_id) REFERENCES public.tedarikci(tedarikci_id);


-- Completed on 2026-04-16 13:00:02

--
-- PostgreSQL database dump complete
--

\unrestrict sepMLwq5A1LybXXt70KpFr3uhY5ATccGADNPY2grY7MR9VPZDHTpeiPIfofWPNs

