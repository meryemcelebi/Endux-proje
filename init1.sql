--
-- PostgreSQL database dump
--

\restrict dan7cXjsjdQiC2KHIfCjYCEOeAviTWRTwoLwivGRJa7qcYcIJYE5LWQ1TQfaCzY

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

-- Started on 2026-04-27 16:02:41

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
-- TOC entry 5 (class 2615 OID 89527)
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- TOC entry 951 (class 1247 OID 89538)
-- Name: du_ort_yuk; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.du_ort_yuk AS ENUM (
    'DUSUK',
    'ORTA',
    'YUKSEK'
);


--
-- TOC entry 313 (class 1255 OID 90167)
-- Name: fn_bakim_girince_arizayi_kapat(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_bakim_girince_arizayi_kapat() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE public.ariza_kaydi
    SET bitis_zamani = NEW.bakim_tarihi
    WHERE makine_id = NEW.makine_id 
    AND bitis_zamani IS NULL;

    RETURN NEW;
END;
$$;


--
-- TOC entry 314 (class 1255 OID 90117)
-- Name: func_form_sonrasi_tetikle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.func_form_sonrasi_tetikle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  -- Not: pr_makine_operator prosedürü mevcut değilse bu trigger hata verir.
  -- Gerekirse bu satırı düzenleyin.
  return NEW;
end;
$$;


--
-- TOC entry 315 (class 1255 OID 90168)
-- Name: get_sorular(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_sorular(p_makine_id integer) RETURNS TABLE(soru_tipi text, id integer, madde_adi text, teknik_parametre text, kritiklik_durumu boolean)
    LANGUAGE sql
    AS $$
    -- 1. Genel Sorular
    SELECT 
        'genel'::text AS soru_tipi,
        gs.genel_soru_id AS id,
        gs.madde_adi::text,
        gs.teknik_parametre::text,
        gs.kritiklik_durumu
    FROM public.genel_sorular gs
    WHERE gs.aktiflik = true

    UNION ALL

    -- 2. Makineye Özel Sorular
    SELECT 
        'ozel'::text AS soru_tipi,
        km.madde_id AS id,
        km.madde_adi::text,
        km.teknik_parametre::text,
        km.kritiklik_durumu
    FROM public.makine m
    JOIN public.kontrol_sablonu ks 
        ON m.makine_tur_id = ks.makine_tur_id
    JOIN public.kontrol_maddesi km 
        ON ks.sablon_id = km.sablon_id
    WHERE m.makine_id = p_makine_id
      AND ks.aktiflik = true;
$$;


--
-- TOC entry 316 (class 1255 OID 90169)
-- Name: pr_ariza_kayit(character varying, character varying, character varying, text, date); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pr_ariza_kayit(IN p_makine_adi character varying, IN p_ariza_tur_adi character varying, IN p_tespit_kaynagi character varying, IN p_aciklama text, IN p_baslangic_zamani date)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_makine_id INTEGER;
    v_tur_id INTEGER;
BEGIN
    SELECT makine_id INTO v_makine_id 
    FROM public.makine 
    WHERE LOWER(makine_adi) = LOWER(p_makine_adi);

    IF v_makine_id IS NULL THEN
        RAISE EXCEPTION 'Makine bulunamadı: %', p_makine_adi;
    END IF;

    SELECT ariza_tur_id INTO v_tur_id 
    FROM public.ariza_turu 
    WHERE LOWER(ariza_tur) = LOWER(p_ariza_tur_adi);

    IF v_tur_id IS NULL THEN
        INSERT INTO public.ariza_turu (ariza_tur) 
        VALUES (p_ariza_tur_adi) 
        RETURNING ariza_tur_id INTO v_tur_id;
    END IF;

    INSERT INTO public.ariza_kaydi (
        makine_id, ariza_tur_id, makine_adi,
        ariza_tespit_kaynagi, ariza_aciklama, 
        baslangic_zamani, olusturma_tarihi
    )
    VALUES (
        v_makine_id, v_tur_id, p_makine_adi,
        p_tespit_kaynagi, p_aciklama, 
        p_baslangic_zamani, CURRENT_TIMESTAMP
    );
END;
$$;


--
-- TOC entry 317 (class 1255 OID 90170)
-- Name: pr_kontrol_kaydet(integer, integer, integer, text, jsonb); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pr_kontrol_kaydet(IN p_makine_id integer, IN p_kullanici_id integer, IN p_sablon_id integer, IN p_genel_not text, IN p_cevaplar jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_form_id INT;
    v_cevap RECORD;
BEGIN
    INSERT INTO public.gunluk_kontrol_formu (
        makine_id, kullanici_id, sablon_id, kontrol_tarihi, genel_not
    )
    VALUES (
        p_makine_id, p_kullanici_id, p_sablon_id, CURRENT_DATE, p_genel_not
    )
    RETURNING form_id INTO v_form_id;

    FOR v_cevap IN SELECT * FROM jsonb_to_recordset(p_cevaplar) 
        AS x(res_id INT, s_durum VARCHAR, s_deger VARCHAR, s_not TEXT)
    LOOP
        INSERT INTO public.form_madde_cevap (
            form_id, soru_referans_id, 
            durum, girilen_deger, aciklama
        )
        VALUES (
            v_form_id, v_cevap.res_id, 
            v_cevap.s_durum, v_cevap.s_deger, v_cevap.s_not
        );
    END LOOP;
END;
$$;


--
-- TOC entry 301 (class 1255 OID 90116)
-- Name: pr_makine_operator(integer, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.pr_makine_operator(IN p_operator_id integer, IN p_makine_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- operatörün kapanmamış önceki oturumlarını kapattık
    UPDATE public.makine_kullanim 
    SET bitis_zamani = CURRENT_TIMESTAMP 
    WHERE kullanici_id = p_operator_id AND bitis_zamani IS NULL;

    -- yeni oturum için kayıt açtık
    INSERT INTO public.makine_kullanim(kullanici_id, makine_id, baslangic_zamani, bitis_zamani)
    VALUES(p_operator_id, p_makine_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
END;
$$;


--
-- TOC entry 321 (class 1255 OID 97760)
-- Name: sp_bakim_ekle(character varying, character varying, character varying, numeric, text, character varying, numeric, character varying, jsonb); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_bakim_ekle(IN p_makine_adi character varying, IN p_bakim_yapan_telefon character varying, IN p_servis_firma_adi character varying, IN p_bakim_maliyet numeric, IN p_aciklama text, IN p_bakim_turu_adi character varying, IN p_durus_suresi numeric, IN p_firma_telefon character varying, IN p_parca_verisi jsonb DEFAULT '[]'::jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_makine_id integer;
    v_ic_personel_id integer;   -- Kullanıcı Tablosu İçin
    v_dis_servis_id integer;    -- Servis Sorumlusu Tablosu İçin
    v_servis_firma_id integer;  
    v_ariza_id integer;         
    v_bakim_tur_id integer;     
    v_yeni_bakim_id integer;
    v_parca_id integer;
    v_kayit record;
BEGIN
    -- 1. Makine Bul
    SELECT makine_id INTO v_makine_id FROM public.makine WHERE UPPER(TRIM(makine_adi)) = UPPER(TRIM(p_makine_adi));
    IF v_makine_id IS NULL THEN RAISE EXCEPTION 'Makine bulunamadı!'; END IF;

	--arıza bul
	  SELECT ariza_id INTO v_ariza_id FROM public.ariza_kaydi WHERE makine_id=v_makine_id;
    IF v_ariza_id IS NULL THEN RAISE EXCEPTION 'Arıza bulunamadı!'; END IF;
	
   -- firma bul
	SELECT firma_id INTO  v_servis_firma_id FROM public.firma WHERE UPPER(TRIM(firma_adi)) = UPPER(TRIM( p_servis_firma_adi));
    IF  v_servis_firma_id IS NULL THEN RAISE EXCEPTION 'Firma bulunamadı!'; END IF;

    -- 2. Personel Tespit Et (Hibrit Kontrol)
    -- Önce kullanıcı tablosuna bak
    SELECT kullanici_id INTO v_ic_personel_id FROM public.kullanici WHERE TRIM(telefon) = TRIM(p_bakim_yapan_telefon);

    IF v_ic_personel_id IS NULL THEN
        -- Kullanıcı değilse servis sorumlusu tablosuna bak
        SELECT sorumlu_id INTO v_dis_servis_id FROM public.servis_sorumlusu WHERE TRIM(telefon) = TRIM(p_bakim_yapan_telefon);
        
        IF v_dis_servis_id IS NULL THEN
            RAISE EXCEPTION 'Bu telefona ait personel bulunamadı!';
        END IF;
    END IF;

    -- 3. Bakım Türü
    SELECT bakim_tur_id INTO v_bakim_tur_id FROM public.bakim_turu WHERE UPPER(TRIM(bakim_tur_adi)) = UPPER(TRIM(p_bakim_turu_adi));
    IF v_bakim_tur_id IS NULL THEN
        INSERT INTO public.bakim_turu (bakim_tur_adi) VALUES (UPPER(TRIM(p_bakim_turu_adi))) RETURNING bakim_tur_id INTO v_bakim_tur_id;
    END IF;

    -- 4. KRİTİK INSERT (Yeni Sütun Yapısı)
    INSERT INTO public.bakim_kaydi (
        makine_id, 
        kullanici_id,     -- Yeni sütun (Kullanıcıysa burası dolar)
        sorumlu_id,       -- Eski sütun (Servisçiyse burası dolar)
        servis_firma_id, 
        bakim_tarihi,
        bakim_maliyet, 
        aciklama,
		ariza_id,
        bakim_tur_id, 
        durus_suresi
    ) VALUES (
        v_makine_id, 
        v_ic_personel_id, -- Kullanıcı ID (4 numara buraya gelecek)
        v_dis_servis_id,  -- Dış servis ID (Kullanıcıysa NULL gidecek)
        v_servis_firma_id,             -- Firma ID (İç bakımda NULL olabilir)
        CURRENT_TIMESTAMP, 
        p_bakim_maliyet, 
        p_aciklama, 
        v_bakim_tur_id, 
        p_durus_suresi
    ) RETURNING bakim_id INTO v_yeni_bakim_id;

    -- 5. Parça Değişimi
    IF p_parca_verisi IS NOT NULL AND jsonb_array_length(p_parca_verisi) > 0 THEN
        FOR v_kayit IN SELECT * FROM jsonb_to_recordset(p_parca_verisi) AS x(parca text, adet integer)
        LOOP
            SELECT parca_id INTO v_parca_id FROM public.parca WHERE UPPER(TRIM(parca_adi)) = UPPER(TRIM(v_kayit.parca)) LIMIT 1;
            IF v_parca_id IS NOT NULL THEN
                INSERT INTO public.parca_degisim (bakim_id, parca_id, adet, bakim_kaydi_id)
                VALUES (v_yeni_bakim_id, v_parca_id, COALESCE(v_kayit.adet, 1), v_yeni_bakim_id);
            END IF;
        END LOOP;
    END IF;
END;
$$;


--
-- TOC entry 318 (class 1255 OID 90173)
-- Name: sp_garanti_firmasi_kaydet(character varying, character varying, character varying, character varying, character varying, character varying, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_garanti_firmasi_kaydet(IN p_garanti_firma_adi character varying, IN p_telefon character varying, IN p_email character varying, IN p_il character varying, IN p_ilce character varying, IN p_acik_adres character varying, INOUT p_out_garanti_firma_id integer DEFAULT NULL::integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_iletisim_id INTEGER;
    v_clean_g_firma VARCHAR := UPPER(TRIM(p_garanti_firma_adi));
BEGIN
    SELECT iletisim_id INTO v_iletisim_id 
    FROM iletisim 
    WHERE telefon = p_telefon;

    IF v_iletisim_id IS NULL THEN
        INSERT INTO iletisim (telefon, mail, il, ilce, acik_adres) 
        VALUES (p_telefon, p_email, p_il, p_ilce, p_acik_adres) 
        RETURNING iletisim_id INTO v_iletisim_id;
    END IF;

    SELECT garanti_firma_id INTO p_out_garanti_firma_id 
    FROM garanti_firma 
    WHERE UPPER(TRIM(firma_adi)) = v_clean_g_firma;

    IF p_out_garanti_firma_id IS NULL THEN
        INSERT INTO garanti_firma (firma_adi, iletisim_id) 
        VALUES (v_clean_g_firma, v_iletisim_id) 
        RETURNING garanti_firma_id INTO p_out_garanti_firma_id;
    END IF;

    COMMIT;
END;
$$;


--
-- TOC entry 319 (class 1255 OID 90174)
-- Name: sp_makine_temel_kaydet(character varying, character varying, character varying, character varying, character varying, date, numeric, integer, integer, numeric, integer, jsonb, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_makine_temel_kaydet(IN p_firma_adi character varying, IN p_makine_tur_adi character varying, IN p_makine_ad character varying, IN p_makine_qr character varying, IN p_seri_no character varying, IN p_satin_alma_tarihi date, IN p_satin_alma_maliyeti numeric, IN p_garanti_suresi integer, IN p_toplam_calisma_saati integer, IN p_risk_katsayisi numeric, IN p_servis_pin integer, IN p_teknik_ozellikler jsonb, IN p_telefon character varying DEFAULT NULL::character varying, IN p_email character varying DEFAULT NULL::character varying, IN p_il character varying DEFAULT NULL::character varying, IN p_ilce character varying DEFAULT NULL::character varying, IN p_acik_adres character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_firma_id INTEGER;
    v_m_tur_id INTEGER;
    v_makine_id INTEGER;
    v_garanti_firma_id INTEGER := NULL;
    v_garanti_suresi INTEGER := p_garanti_suresi;
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

    -- 3. ANA MAKİNE TABLOSUNA KAYIT
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

    -- 4. MAKİNE ÖZELLİKLERİ TABLOSUNA KAYIT
    INSERT INTO makine_ozellikleri (makine_id, teknik_ozellikler, guncelleme_tarihi)
    VALUES (v_makine_id, p_teknik_ozellikler, CURRENT_TIMESTAMP);

    COMMIT;
    RAISE NOTICE 'İşlem Başarılı: Makine % kaydedildi.', p_makine_ad;
END;
$$;


--
-- TOC entry 322 (class 1255 OID 97761)
-- Name: sp_parca_ekle(text, numeric, integer, integer, integer, integer, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_parca_ekle(IN p_parca_adi text, IN p_tahmini_omur_saati numeric, IN p_parca_maliyeti integer, IN p_stok_miktari integer, IN p_min_stok_seviyesi integer, IN p_tedarik_gun_suresi integer, IN p_kategori_adi character varying, IN p_tedarikci_firma_adi character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_clean_parca_adi text := UPPER(TRIM(p_parca_adi));
    v_clean_kategori_adi varchar := UPPER(TRIM(p_kategori_adi));
    v_clean_tedarikci_adi varchar := UPPER(TRIM(p_tedarikci_firma_adi));
    v_kategori_id integer;
    v_tedarikci_id integer;
    v_mevcut_parca_id integer;
BEGIN
    -- 1. Kategori Kontrolü (Yoksa oluştur)
    SELECT kategori_id INTO v_kategori_id FROM public.parca_kategori 
    WHERE UPPER(TRIM(kategori_adi)) = v_clean_kategori_adi;
    
    IF v_kategori_id IS NULL THEN
        INSERT INTO public.parca_kategori (kategori_adi) VALUES (v_clean_kategori_adi)
        RETURNING kategori_id INTO v_kategori_id;
    END IF;

    -- 2. Tedarikçi Kontrolü (Yoksa hata ver)
    SELECT tedarikci_id INTO v_tedarikci_id FROM public.tedarikci 
    WHERE UPPER(TRIM(firma_adi)) = v_clean_tedarikci_adi;
    
    IF v_tedarikci_id IS NULL THEN
        RAISE EXCEPTION 'HATA: "%" isimli tedarikçi sistemde kayıtlı değil!', v_clean_tedarikci_adi;
    END IF;

    -- 3. Parça Kontrolü (Varmı?)
    SELECT parca_id INTO v_mevcut_parca_id FROM public.parca 
    WHERE UPPER(TRIM(parca_adi)) = v_clean_parca_adi;

    IF v_mevcut_parca_id IS NOT NULL THEN
        -- EĞER PARÇA VARSA: Sadece stok miktarını güncelliyoruz
        UPDATE public.parca 
        SET stok_miktari = stok_miktari + p_stok_miktari
        WHERE parca_id = v_mevcut_parca_id;
        
        RAISE NOTICE 'Parça zaten mevcut. Stok % adet artırıldı. Güncel ID: %', p_stok_miktari, v_mevcut_parca_id;
    ELSE
        -- EĞER PARÇA YOKSA: Yeni kayıt oluşturuyoruz
        INSERT INTO public.parca (
            parca_adi, tahmini_omur_saati, parca_maliyeti, 
            tedarik_gun_suresi, kategori_id, tedarikci_id, stok_miktari, min_stok_seviyesi
        )
        VALUES (
            v_clean_parca_adi, p_tahmini_omur_saati, p_parca_maliyeti, 
            p_tedarik_gun_suresi, v_kategori_id, v_tedarikci_id, p_stok_miktari, p_min_stok_seviyesi
        ) RETURNING parca_id INTO v_mevcut_parca_id;

        RAISE NOTICE 'Yeni parça başarıyla eklendi. ID: %', v_mevcut_parca_id;
    END IF;

END;
$$;


--
-- TOC entry 320 (class 1255 OID 90176)
-- Name: sp_tedarikci_ekle(character varying, character varying, character varying, character varying, character varying, text, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_tedarikci_ekle(IN p_firma_adi character varying, IN p_telefon character varying, IN p_mail character varying, IN p_il character varying, IN p_ilce character varying, IN p_acik_adres text, IN p_vergi_no character varying, IN p_yetkili_kisi character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_iletisim_id integer;
    v_tedarikci_id integer;
    v_clean_firma text := UPPER(TRIM(p_firma_adi));
BEGIN
    SELECT iletisim_id INTO v_iletisim_id FROM public.iletisim WHERE telefon = p_telefon;

    IF v_iletisim_id IS NULL THEN
        INSERT INTO public.iletisim (telefon, mail, il, ilce, acik_adres)
        VALUES (p_telefon, p_mail, p_il, p_ilce, p_acik_adres)
        RETURNING iletisim_id INTO v_iletisim_id;
    END IF;

    INSERT INTO public.tedarikci (firma_adi, aktiflik, iletisim_id, vergi_no, yetkili_kisi, kayit_tarihi)
    VALUES (v_clean_firma, true, v_iletisim_id, p_vergi_no, p_yetkili_kisi, CURRENT_DATE)
    RETURNING tedarikci_id INTO v_tedarikci_id;

    RAISE NOTICE 'Yeni tedarikçi eklendi: % (ID: %)', v_clean_firma, v_tedarikci_id;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 215 (class 1259 OID 89528)
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


--
-- TOC entry 271 (class 1259 OID 89763)
-- Name: abonelik_tipi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.abonelik_tipi (
    abonelik_tip_id integer NOT NULL,
    abonelik_adi character varying(50) NOT NULL
);


--
-- TOC entry 270 (class 1259 OID 89762)
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
-- TOC entry 3980 (class 0 OID 0)
-- Dependencies: 270
-- Name: abonelik_tipi_abonelik_tip_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.abonelik_tipi_abonelik_tip_id_seq OWNED BY public.abonelik_tipi.abonelik_tip_id;


--
-- TOC entry 219 (class 1259 OID 89555)
-- Name: ai_ariza_tespit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_ariza_tespit (
    tespit_id integer NOT NULL,
    makine_id integer NOT NULL,
    form_id integer NOT NULL,
    madde_id integer NOT NULL,
    tahmin_edilen_ariza character varying(200),
    risk_skoru numeric(3,2),
    tespit_tarihi timestamp(6) with time zone,
    model_versiyon character varying(100),
    tahmini_durus_suresi numeric(6,2),
    tahmini_maliyet numeric(12,2)
);


--
-- TOC entry 218 (class 1259 OID 89554)
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
-- TOC entry 3981 (class 0 OID 0)
-- Dependencies: 218
-- Name: ai_ariza_tespit_tespit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_ariza_tespit_tespit_id_seq OWNED BY public.ai_ariza_tespit.tespit_id;


--
-- TOC entry 221 (class 1259 OID 89562)
-- Name: ai_model_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_model_log (
    log_id integer NOT NULL,
    makine_id integer NOT NULL,
    model_versiyon character varying(100),
    kullanilan_veri_sayisi integer,
    tahmin_risk numeric(5,2),
    tahmin_tarihi timestamp(6) with time zone,
    kullanici_id integer NOT NULL,
    form_id integer
);


--
-- TOC entry 220 (class 1259 OID 89561)
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
-- TOC entry 3982 (class 0 OID 0)
-- Dependencies: 220
-- Name: ai_model_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_model_log_log_id_seq OWNED BY public.ai_model_log.log_id;


--
-- TOC entry 223 (class 1259 OID 89569)
-- Name: ariza_kaydi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ariza_kaydi (
    ariza_id integer NOT NULL,
    makine_id integer NOT NULL,
    ariza_tespit_kaynagi character varying(100) NOT NULL,
    ariza_aciklama text,
    baslangic_zamani timestamp(6) with time zone,
    bitis_zamani timestamp(6) with time zone,
    olusturma_tarihi timestamp(6) with time zone,
    ariza_tur_id integer NOT NULL,
    makine_adi character varying(50)
);


--
-- TOC entry 222 (class 1259 OID 89568)
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
-- TOC entry 3983 (class 0 OID 0)
-- Dependencies: 222
-- Name: ariza_kaydi_ariza_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ariza_kaydi_ariza_id_seq OWNED BY public.ariza_kaydi.ariza_id;


--
-- TOC entry 259 (class 1259 OID 89714)
-- Name: ariza_turu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ariza_turu (
    ariza_tur_id integer NOT NULL,
    ariza_tur character varying(150) NOT NULL
);


--
-- TOC entry 258 (class 1259 OID 89713)
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
-- TOC entry 3984 (class 0 OID 0)
-- Dependencies: 258
-- Name: ariza_turu_ariza_tur_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ariza_turu_ariza_tur_id_seq OWNED BY public.ariza_turu.ariza_tur_id;


--
-- TOC entry 225 (class 1259 OID 89578)
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
    tespit_tarihi timestamp(6) with time zone,
    aciklama text
);


--
-- TOC entry 224 (class 1259 OID 89577)
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
-- TOC entry 3985 (class 0 OID 0)
-- Dependencies: 224
-- Name: arizayi_tetikleyen_form_tetik_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.arizayi_tetikleyen_form_tetik_id_seq OWNED BY public.arizayi_tetikleyen_form.tetik_id;


--
-- TOC entry 227 (class 1259 OID 89587)
-- Name: bakim_kaydi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bakim_kaydi (
    bakim_id integer NOT NULL,
    makine_id integer NOT NULL,
    sorumlu_id integer,
    servis_firma_id integer,
    bakim_tarihi timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP,
    bakim_maliyet numeric NOT NULL,
    aciklama text,
    ariza_id integer,
    bakim_tur_id integer,
    durus_suresi numeric(15,2),
    kullanici_id integer
);


--
-- TOC entry 226 (class 1259 OID 89586)
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
-- TOC entry 3986 (class 0 OID 0)
-- Dependencies: 226
-- Name: bakim_kaydi_bakim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bakim_kaydi_bakim_id_seq OWNED BY public.bakim_kaydi.bakim_id;


--
-- TOC entry 273 (class 1259 OID 89770)
-- Name: bakim_turu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bakim_turu (
    bakim_tur_id integer NOT NULL,
    bakim_tur_adi character varying(55) NOT NULL
);


--
-- TOC entry 272 (class 1259 OID 89769)
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
-- TOC entry 3987 (class 0 OID 0)
-- Dependencies: 272
-- Name: bakim_turu_bakim_tur_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bakim_turu_bakim_tur_id_seq OWNED BY public.bakim_turu.bakim_tur_id;


--
-- TOC entry 300 (class 1259 OID 105992)
-- Name: durus_kaydi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.durus_kaydi (
    durus_id integer NOT NULL,
    makine_id integer NOT NULL,
    vardiya_tarihi date NOT NULL,
    baslangic_saati timestamp(6) with time zone NOT NULL,
    bitis_saati timestamp(6) with time zone,
    durus_sure_dk integer,
    durus_nedeni character varying(255) NOT NULL,
    olusturma_tarihi timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP,
    kullanici_id integer
);


--
-- TOC entry 299 (class 1259 OID 105991)
-- Name: durus_kaydi_durus_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.durus_kaydi_durus_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3988 (class 0 OID 0)
-- Dependencies: 299
-- Name: durus_kaydi_durus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.durus_kaydi_durus_id_seq OWNED BY public.durus_kaydi.durus_id;


--
-- TOC entry 229 (class 1259 OID 89597)
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
-- TOC entry 228 (class 1259 OID 89596)
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
-- TOC entry 3989 (class 0 OID 0)
-- Dependencies: 228
-- Name: firma_firma_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.firma_firma_id_seq OWNED BY public.firma.firma_id;


--
-- TOC entry 231 (class 1259 OID 89604)
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


--
-- TOC entry 230 (class 1259 OID 89603)
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
-- TOC entry 3990 (class 0 OID 0)
-- Dependencies: 230
-- Name: form_madde_cevap_cevap_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.form_madde_cevap_cevap_id_seq OWNED BY public.form_madde_cevap.cevap_id;


--
-- TOC entry 261 (class 1259 OID 89721)
-- Name: garanti_firma; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.garanti_firma (
    garanti_firma_id integer NOT NULL,
    firma_adi character varying(150),
    iletisim_id integer
);


--
-- TOC entry 260 (class 1259 OID 89720)
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
-- TOC entry 3991 (class 0 OID 0)
-- Dependencies: 260
-- Name: garanti_firma_garanti_firma_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.garanti_firma_garanti_firma_id_seq OWNED BY public.garanti_firma.garanti_firma_id;


--
-- TOC entry 263 (class 1259 OID 89728)
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
-- TOC entry 262 (class 1259 OID 89727)
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
-- TOC entry 3992 (class 0 OID 0)
-- Dependencies: 262
-- Name: genel_sorular_genel_soru_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.genel_sorular_genel_soru_id_seq OWNED BY public.genel_sorular.genel_soru_id;


--
-- TOC entry 233 (class 1259 OID 89613)
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
-- TOC entry 232 (class 1259 OID 89612)
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
-- TOC entry 3993 (class 0 OID 0)
-- Dependencies: 232
-- Name: gunluk_kontrol_formu_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gunluk_kontrol_formu_form_id_seq OWNED BY public.gunluk_kontrol_formu.form_id;


--
-- TOC entry 275 (class 1259 OID 89777)
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
-- TOC entry 274 (class 1259 OID 89776)
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
-- TOC entry 3994 (class 0 OID 0)
-- Dependencies: 274
-- Name: iletisim_iletisim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iletisim_iletisim_id_seq OWNED BY public.iletisim.iletisim_id;


--
-- TOC entry 235 (class 1259 OID 89622)
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
-- TOC entry 234 (class 1259 OID 89621)
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
-- TOC entry 3995 (class 0 OID 0)
-- Dependencies: 234
-- Name: kontrol_maddesi_madde_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.kontrol_maddesi_madde_id_seq OWNED BY public.kontrol_maddesi.madde_id;


--
-- TOC entry 237 (class 1259 OID 89629)
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
-- TOC entry 236 (class 1259 OID 89628)
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
-- TOC entry 3996 (class 0 OID 0)
-- Dependencies: 236
-- Name: kontrol_sablonu_sablon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.kontrol_sablonu_sablon_id_seq OWNED BY public.kontrol_sablonu.sablon_id;


--
-- TOC entry 217 (class 1259 OID 89546)
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
-- TOC entry 216 (class 1259 OID 89545)
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
-- TOC entry 3997 (class 0 OID 0)
-- Dependencies: 216
-- Name: kullanici_kullanici_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.kullanici_kullanici_id_seq OWNED BY public.kullanici.kullanici_id;


--
-- TOC entry 239 (class 1259 OID 89638)
-- Name: lokasyon; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lokasyon (
    lokasyon_id integer NOT NULL,
    fabrika_alani character varying(150) NOT NULL,
    kat character varying(5) NOT NULL,
    x_koor numeric NOT NULL,
    y_koor numeric NOT NULL,
    guncelleme_tarihi timestamp(6) with time zone,
    firma_id integer,
    makine_id integer
);


--
-- TOC entry 238 (class 1259 OID 89637)
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
-- TOC entry 3998 (class 0 OID 0)
-- Dependencies: 238
-- Name: lokasyon_lokasyon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lokasyon_lokasyon_id_seq OWNED BY public.lokasyon.lokasyon_id;


--
-- TOC entry 241 (class 1259 OID 89647)
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
-- TOC entry 243 (class 1259 OID 89655)
-- Name: makine_kullanim; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.makine_kullanim (
    kullanim_id integer NOT NULL,
    kullanici_id integer NOT NULL,
    makine_id integer NOT NULL,
    baslangic_zamani timestamp(6) with time zone NOT NULL,
    bitis_zamani timestamp(6) with time zone NOT NULL,
    gunluk_top_calisma_saati bigint DEFAULT 0 NOT NULL
);


--
-- TOC entry 242 (class 1259 OID 89654)
-- Name: makine_kullanim_kullanim_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.makine_kullanim_kullanim_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3999 (class 0 OID 0)
-- Dependencies: 242
-- Name: makine_kullanim_kullanim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.makine_kullanim_kullanim_id_seq OWNED BY public.makine_kullanim.kullanim_id;


--
-- TOC entry 240 (class 1259 OID 89646)
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
-- TOC entry 4000 (class 0 OID 0)
-- Dependencies: 240
-- Name: makine_makine_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.makine_makine_id_seq OWNED BY public.makine.makine_id;


--
-- TOC entry 265 (class 1259 OID 89735)
-- Name: makine_ozellikleri; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.makine_ozellikleri (
    ozellik_id integer NOT NULL,
    makine_id integer NOT NULL,
    teknik_ozellikler jsonb,
    guncelleme_tarihi timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- TOC entry 264 (class 1259 OID 89734)
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
-- TOC entry 4001 (class 0 OID 0)
-- Dependencies: 264
-- Name: makine_ozellikleri_ozellik_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.makine_ozellikleri_ozellik_id_seq OWNED BY public.makine_ozellikleri.ozellik_id;


--
-- TOC entry 245 (class 1259 OID 89663)
-- Name: makine_turu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.makine_turu (
    makine_tur_id integer NOT NULL,
    makine_tur_adi character varying(50) NOT NULL,
    risk_katsayisi numeric(5,2)
);


--
-- TOC entry 244 (class 1259 OID 89662)
-- Name: makine_turu_makine_tur_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.makine_turu_makine_tur_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4002 (class 0 OID 0)
-- Dependencies: 244
-- Name: makine_turu_makine_tur_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.makine_turu_makine_tur_id_seq OWNED BY public.makine_turu.makine_tur_id;


--
-- TOC entry 296 (class 1259 OID 105954)
-- Name: oee_raporlari; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oee_raporlari (
    rapor_id integer NOT NULL,
    makine_id integer,
    tarih date DEFAULT CURRENT_DATE,
    kullanilabilirlik_orani double precision,
    performans_orani double precision,
    kalite_orani double precision,
    oee_skoru double precision
);


--
-- TOC entry 295 (class 1259 OID 105953)
-- Name: oee_raporlari_rapor_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oee_raporlari_rapor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4003 (class 0 OID 0)
-- Dependencies: 295
-- Name: oee_raporlari_rapor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oee_raporlari_rapor_id_seq OWNED BY public.oee_raporlari.rapor_id;


--
-- TOC entry 247 (class 1259 OID 89670)
-- Name: parca; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parca (
    parca_id integer NOT NULL,
    parca_adi character varying(100) NOT NULL,
    tahmini_omur_saati numeric(8,2) NOT NULL,
    parca_maliyeti integer NOT NULL,
    tedarik_gun_suresi integer NOT NULL,
    kategori_id integer,
    tedarikci_id integer NOT NULL,
    stok_miktari integer,
    min_stok_seviyesi integer
);


--
-- TOC entry 249 (class 1259 OID 89677)
-- Name: parca_degisim; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parca_degisim (
    parca_degisim_id integer NOT NULL,
    bakim_id integer NOT NULL,
    parca_id integer,
    adet integer,
    bakim_kaydi_id integer
);


--
-- TOC entry 248 (class 1259 OID 89676)
-- Name: parca_degisim_parca_degisim_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parca_degisim_parca_degisim_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4004 (class 0 OID 0)
-- Dependencies: 248
-- Name: parca_degisim_parca_degisim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parca_degisim_parca_degisim_id_seq OWNED BY public.parca_degisim.parca_degisim_id;


--
-- TOC entry 277 (class 1259 OID 89786)
-- Name: parca_kategori; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parca_kategori (
    kategori_id integer NOT NULL,
    kategori_adi character varying(155)
);


--
-- TOC entry 276 (class 1259 OID 89785)
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
-- TOC entry 4005 (class 0 OID 0)
-- Dependencies: 276
-- Name: parca_kategori_kategori_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parca_kategori_kategori_id_seq OWNED BY public.parca_kategori.kategori_id;


--
-- TOC entry 246 (class 1259 OID 89669)
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
-- TOC entry 4006 (class 0 OID 0)
-- Dependencies: 246
-- Name: parca_parca_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parca_parca_id_seq OWNED BY public.parca.parca_id;


--
-- TOC entry 251 (class 1259 OID 89684)
-- Name: risk_skoru; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.risk_skoru (
    risk_id integer NOT NULL,
    makine_id integer NOT NULL,
    risk_skoru numeric(5,2),
    risk_seviyesi public.du_ort_yuk NOT NULL,
    hesaplama_tarihi timestamp(6) with time zone
);


--
-- TOC entry 250 (class 1259 OID 89683)
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
-- TOC entry 4007 (class 0 OID 0)
-- Dependencies: 250
-- Name: risk_skoru_risk_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.risk_skoru_risk_id_seq OWNED BY public.risk_skoru.risk_id;


--
-- TOC entry 253 (class 1259 OID 89691)
-- Name: rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rol (
    rol_id integer NOT NULL,
    rol_adi character varying NOT NULL
);


--
-- TOC entry 252 (class 1259 OID 89690)
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
-- TOC entry 4008 (class 0 OID 0)
-- Dependencies: 252
-- Name: rol_rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rol_rol_id_seq OWNED BY public.rol.rol_id;


--
-- TOC entry 279 (class 1259 OID 89793)
-- Name: sektor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sektor (
    sektor_id integer NOT NULL,
    sektor_adi character varying(150) NOT NULL
);


--
-- TOC entry 278 (class 1259 OID 89792)
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
-- TOC entry 4009 (class 0 OID 0)
-- Dependencies: 278
-- Name: sektor_sektor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sektor_sektor_id_seq OWNED BY public.sektor.sektor_id;


--
-- TOC entry 255 (class 1259 OID 89700)
-- Name: servis_firma; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.servis_firma (
    servis_firma_id integer NOT NULL,
    firma_adi character varying(100) NOT NULL,
    aktiflik boolean NOT NULL,
    iletisim_id integer
);


--
-- TOC entry 254 (class 1259 OID 89699)
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
-- TOC entry 4010 (class 0 OID 0)
-- Dependencies: 254
-- Name: servis_firma_servis_firma_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.servis_firma_servis_firma_id_seq OWNED BY public.servis_firma.servis_firma_id;


--
-- TOC entry 280 (class 1259 OID 89799)
-- Name: servis_firma_uzmanlik; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.servis_firma_uzmanlik (
    servis_firma_id integer NOT NULL,
    uzmanlik_adi character varying NOT NULL
);


--
-- TOC entry 267 (class 1259 OID 89745)
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
-- TOC entry 266 (class 1259 OID 89744)
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
-- TOC entry 4011 (class 0 OID 0)
-- Dependencies: 266
-- Name: servis_puan_puan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.servis_puan_puan_id_seq OWNED BY public.servis_puan.puan_id;


--
-- TOC entry 269 (class 1259 OID 89754)
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
-- TOC entry 268 (class 1259 OID 89753)
-- Name: servis_sorumlusu_sorumlu_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.servis_sorumlusu_sorumlu_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4012 (class 0 OID 0)
-- Dependencies: 268
-- Name: servis_sorumlusu_sorumlu_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.servis_sorumlusu_sorumlu_id_seq OWNED BY public.servis_sorumlusu.sorumlu_id;


--
-- TOC entry 257 (class 1259 OID 89707)
-- Name: tedarikci; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tedarikci (
    tedarikci_id integer NOT NULL,
    firma_adi character varying(200) NOT NULL,
    aktiflik boolean NOT NULL,
    guvenilirlik_skoru numeric(5,2),
    vergi_no character varying(155),
    yetkili_kisi character varying(100),
    kayit_tarihi timestamp(6) with time zone,
    iletisim_id integer
);


--
-- TOC entry 282 (class 1259 OID 89807)
-- Name: tedarikci_parca; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tedarikci_parca (
    tedarikci_parca_id integer NOT NULL,
    tedarik_id integer NOT NULL,
    parca_id integer NOT NULL,
    tedarik_maliyeti numeric(15,3) NOT NULL
);


--
-- TOC entry 281 (class 1259 OID 89806)
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
-- TOC entry 4013 (class 0 OID 0)
-- Dependencies: 281
-- Name: tedarikci_parca_tedarikci_parca_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tedarikci_parca_tedarikci_parca_id_seq OWNED BY public.tedarikci_parca.tedarikci_parca_id;


--
-- TOC entry 284 (class 1259 OID 89814)
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
-- TOC entry 283 (class 1259 OID 89813)
-- Name: tedarikci_puan_puan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tedarikci_puan_puan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4014 (class 0 OID 0)
-- Dependencies: 283
-- Name: tedarikci_puan_puan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tedarikci_puan_puan_id_seq OWNED BY public.tedarikci_puan.puan_id;


--
-- TOC entry 256 (class 1259 OID 89706)
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
-- TOC entry 4015 (class 0 OID 0)
-- Dependencies: 256
-- Name: tedarikci_tedarikci_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tedarikci_tedarikci_id_seq OWNED BY public.tedarikci.tedarikci_id;


--
-- TOC entry 298 (class 1259 OID 105969)
-- Name: uretim_kaydi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uretim_kaydi (
    uretim_id integer NOT NULL,
    makine_id integer NOT NULL,
    vardiya_tarihi date NOT NULL,
    vardiya_turu character varying(20),
    planlanan_sure_dk integer NOT NULL,
    fiili_sure_dk integer NOT NULL,
    durus_sure_dk integer DEFAULT 0,
    teorik_uretim integer NOT NULL,
    gercek_uretim integer NOT NULL,
    hatali_uretim integer DEFAULT 0,
    olusturma_tarihi timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP,
    kullanici_id integer
);


--
-- TOC entry 297 (class 1259 OID 105968)
-- Name: uretim_kaydi_uretim_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.uretim_kaydi_uretim_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4016 (class 0 OID 0)
-- Dependencies: 297
-- Name: uretim_kaydi_uretim_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.uretim_kaydi_uretim_id_seq OWNED BY public.uretim_kaydi.uretim_id;


--
-- TOC entry 285 (class 1259 OID 90118)
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
-- TOC entry 294 (class 1259 OID 97737)
-- Name: v_parca_detay_listesi; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_parca_detay_listesi AS
 SELECT p.parca_adi AS "PARÇA ADI",
    p.stok_miktari AS "PARÇA ADETİ",
    p.min_stok_seviyesi AS "MİN PARÇA SEVİYESİ",
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
-- TOC entry 286 (class 1259 OID 90128)
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
     JOIN public.ariza_turu att ON ((ak.ariza_tur_id = att.ariza_tur_id)))
     JOIN public.risk_skoru rs ON ((m.makine_id = rs.makine_id)))
     LEFT JOIN public.lokasyon l ON ((m.makine_id = l.makine_id)))
  WHERE (ak.bitis_zamani IS NULL)
  ORDER BY rs.risk_skoru DESC;


--
-- TOC entry 287 (class 1259 OID 90133)
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
-- TOC entry 288 (class 1259 OID 90138)
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
     LEFT JOIN public.bakim_turu bt ON ((bk.bakim_tur_id = bt.bakim_tur_id)))
     LEFT JOIN public.parca_degisim pd ON ((bk.bakim_id = pd.bakim_id)))
     LEFT JOIN public.parca p ON ((pd.parca_id = p.parca_id)))
  ORDER BY m.makine_id, 'detay'::text DESC, bk.bakim_id, pd.parca_degisim_id;


--
-- TOC entry 289 (class 1259 OID 90143)
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
             JOIN public.parca_degisim pd ON ((p.parca_id = pd.parca_id)))
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
-- TOC entry 290 (class 1259 OID 90148)
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
-- TOC entry 291 (class 1259 OID 90152)
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
-- TOC entry 292 (class 1259 OID 90157)
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
-- TOC entry 293 (class 1259 OID 90162)
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
     JOIN public.bakim_turu bt ON ((bk.bakim_tur_id = bt.bakim_tur_id)))
     JOIN public.makine m ON ((bk.makine_id = m.makine_id)))
  WHERE (t.aktiflik = true);


--
-- TOC entry 3539 (class 2604 OID 89766)
-- Name: abonelik_tipi abonelik_tip_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonelik_tipi ALTER COLUMN abonelik_tip_id SET DEFAULT nextval('public.abonelik_tipi_abonelik_tip_id_seq'::regclass);


--
-- TOC entry 3509 (class 2604 OID 89558)
-- Name: ai_ariza_tespit tespit_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit ALTER COLUMN tespit_id SET DEFAULT nextval('public.ai_ariza_tespit_tespit_id_seq'::regclass);


--
-- TOC entry 3510 (class 2604 OID 89565)
-- Name: ai_model_log log_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log ALTER COLUMN log_id SET DEFAULT nextval('public.ai_model_log_log_id_seq'::regclass);


--
-- TOC entry 3511 (class 2604 OID 89572)
-- Name: ariza_kaydi ariza_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi ALTER COLUMN ariza_id SET DEFAULT nextval('public.ariza_kaydi_ariza_id_seq'::regclass);


--
-- TOC entry 3532 (class 2604 OID 89717)
-- Name: ariza_turu ariza_tur_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_turu ALTER COLUMN ariza_tur_id SET DEFAULT nextval('public.ariza_turu_ariza_tur_id_seq'::regclass);


--
-- TOC entry 3512 (class 2604 OID 89581)
-- Name: arizayi_tetikleyen_form tetik_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form ALTER COLUMN tetik_id SET DEFAULT nextval('public.arizayi_tetikleyen_form_tetik_id_seq'::regclass);


--
-- TOC entry 3513 (class 2604 OID 89590)
-- Name: bakim_kaydi bakim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi ALTER COLUMN bakim_id SET DEFAULT nextval('public.bakim_kaydi_bakim_id_seq'::regclass);


--
-- TOC entry 3540 (class 2604 OID 89773)
-- Name: bakim_turu bakim_tur_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_turu ALTER COLUMN bakim_tur_id SET DEFAULT nextval('public.bakim_turu_bakim_tur_id_seq'::regclass);


--
-- TOC entry 3552 (class 2604 OID 105995)
-- Name: durus_kaydi durus_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.durus_kaydi ALTER COLUMN durus_id SET DEFAULT nextval('public.durus_kaydi_durus_id_seq'::regclass);


--
-- TOC entry 3515 (class 2604 OID 89600)
-- Name: firma firma_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma ALTER COLUMN firma_id SET DEFAULT nextval('public.firma_firma_id_seq'::regclass);


--
-- TOC entry 3516 (class 2604 OID 89607)
-- Name: form_madde_cevap cevap_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap ALTER COLUMN cevap_id SET DEFAULT nextval('public.form_madde_cevap_cevap_id_seq'::regclass);


--
-- TOC entry 3533 (class 2604 OID 89724)
-- Name: garanti_firma garanti_firma_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.garanti_firma ALTER COLUMN garanti_firma_id SET DEFAULT nextval('public.garanti_firma_garanti_firma_id_seq'::regclass);


--
-- TOC entry 3534 (class 2604 OID 89731)
-- Name: genel_sorular genel_soru_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genel_sorular ALTER COLUMN genel_soru_id SET DEFAULT nextval('public.genel_sorular_genel_soru_id_seq'::regclass);


--
-- TOC entry 3517 (class 2604 OID 89616)
-- Name: gunluk_kontrol_formu form_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu ALTER COLUMN form_id SET DEFAULT nextval('public.gunluk_kontrol_formu_form_id_seq'::regclass);


--
-- TOC entry 3541 (class 2604 OID 89780)
-- Name: iletisim iletisim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iletisim ALTER COLUMN iletisim_id SET DEFAULT nextval('public.iletisim_iletisim_id_seq'::regclass);


--
-- TOC entry 3518 (class 2604 OID 89625)
-- Name: kontrol_maddesi madde_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_maddesi ALTER COLUMN madde_id SET DEFAULT nextval('public.kontrol_maddesi_madde_id_seq'::regclass);


--
-- TOC entry 3519 (class 2604 OID 89632)
-- Name: kontrol_sablonu sablon_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_sablonu ALTER COLUMN sablon_id SET DEFAULT nextval('public.kontrol_sablonu_sablon_id_seq'::regclass);


--
-- TOC entry 3508 (class 2604 OID 89549)
-- Name: kullanici kullanici_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici ALTER COLUMN kullanici_id SET DEFAULT nextval('public.kullanici_kullanici_id_seq'::regclass);


--
-- TOC entry 3520 (class 2604 OID 89641)
-- Name: lokasyon lokasyon_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon ALTER COLUMN lokasyon_id SET DEFAULT nextval('public.lokasyon_lokasyon_id_seq'::regclass);


--
-- TOC entry 3521 (class 2604 OID 89650)
-- Name: makine makine_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine ALTER COLUMN makine_id SET DEFAULT nextval('public.makine_makine_id_seq'::regclass);


--
-- TOC entry 3523 (class 2604 OID 89658)
-- Name: makine_kullanim kullanim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim ALTER COLUMN kullanim_id SET DEFAULT nextval('public.makine_kullanim_kullanim_id_seq'::regclass);


--
-- TOC entry 3535 (class 2604 OID 89738)
-- Name: makine_ozellikleri ozellik_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_ozellikleri ALTER COLUMN ozellik_id SET DEFAULT nextval('public.makine_ozellikleri_ozellik_id_seq'::regclass);


--
-- TOC entry 3525 (class 2604 OID 89666)
-- Name: makine_turu makine_tur_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_turu ALTER COLUMN makine_tur_id SET DEFAULT nextval('public.makine_turu_makine_tur_id_seq'::regclass);


--
-- TOC entry 3546 (class 2604 OID 105957)
-- Name: oee_raporlari rapor_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oee_raporlari ALTER COLUMN rapor_id SET DEFAULT nextval('public.oee_raporlari_rapor_id_seq'::regclass);


--
-- TOC entry 3526 (class 2604 OID 89673)
-- Name: parca parca_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca ALTER COLUMN parca_id SET DEFAULT nextval('public.parca_parca_id_seq'::regclass);


--
-- TOC entry 3527 (class 2604 OID 89680)
-- Name: parca_degisim parca_degisim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim ALTER COLUMN parca_degisim_id SET DEFAULT nextval('public.parca_degisim_parca_degisim_id_seq'::regclass);


--
-- TOC entry 3542 (class 2604 OID 89789)
-- Name: parca_kategori kategori_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_kategori ALTER COLUMN kategori_id SET DEFAULT nextval('public.parca_kategori_kategori_id_seq'::regclass);


--
-- TOC entry 3528 (class 2604 OID 89687)
-- Name: risk_skoru risk_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_skoru ALTER COLUMN risk_id SET DEFAULT nextval('public.risk_skoru_risk_id_seq'::regclass);


--
-- TOC entry 3529 (class 2604 OID 89694)
-- Name: rol rol_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol ALTER COLUMN rol_id SET DEFAULT nextval('public.rol_rol_id_seq'::regclass);


--
-- TOC entry 3543 (class 2604 OID 89796)
-- Name: sektor sektor_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sektor ALTER COLUMN sektor_id SET DEFAULT nextval('public.sektor_sektor_id_seq'::regclass);


--
-- TOC entry 3530 (class 2604 OID 89703)
-- Name: servis_firma servis_firma_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma ALTER COLUMN servis_firma_id SET DEFAULT nextval('public.servis_firma_servis_firma_id_seq'::regclass);


--
-- TOC entry 3537 (class 2604 OID 89748)
-- Name: servis_puan puan_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan ALTER COLUMN puan_id SET DEFAULT nextval('public.servis_puan_puan_id_seq'::regclass);


--
-- TOC entry 3538 (class 2604 OID 89757)
-- Name: servis_sorumlusu sorumlu_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_sorumlusu ALTER COLUMN sorumlu_id SET DEFAULT nextval('public.servis_sorumlusu_sorumlu_id_seq'::regclass);


--
-- TOC entry 3531 (class 2604 OID 89710)
-- Name: tedarikci tedarikci_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci ALTER COLUMN tedarikci_id SET DEFAULT nextval('public.tedarikci_tedarikci_id_seq'::regclass);


--
-- TOC entry 3544 (class 2604 OID 89810)
-- Name: tedarikci_parca tedarikci_parca_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca ALTER COLUMN tedarikci_parca_id SET DEFAULT nextval('public.tedarikci_parca_tedarikci_parca_id_seq'::regclass);


--
-- TOC entry 3545 (class 2604 OID 89817)
-- Name: tedarikci_puan puan_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan ALTER COLUMN puan_id SET DEFAULT nextval('public.tedarikci_puan_puan_id_seq'::regclass);


--
-- TOC entry 3548 (class 2604 OID 105972)
-- Name: uretim_kaydi uretim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uretim_kaydi ALTER COLUMN uretim_id SET DEFAULT nextval('public.uretim_kaydi_uretim_id_seq'::regclass);


--
-- TOC entry 3898 (class 0 OID 89528)
-- Dependencies: 215
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
1fb9a010-be97-4260-9782-65ce218b858a	a32ff71c4b29238ae4a58b1482d2db7df6f42ffc95029daabbe7f587efe0a0f7	2026-04-20 21:05:10.996067+00	20260416164838_init_schema	\N	\N	2026-04-20 21:05:08.447867+00	1
800af273-0dcd-453f-abc5-41d619307bf8	c88554b74443e0b806977c390852beb50ebfef26090eac0db0e9c1463e2f63fa	2026-04-20 21:05:11.130035+00	20260416174827_missing_views_and_procedures	\N	\N	2026-04-20 21:05:11.000983+00	1
51ba0b80-5e36-4689-a41f-030560fa22a3	b4b442121959a6f47ae8d60861aff1e214d2c7eb181b83f15ec45ec7e83f2505	2026-04-20 21:05:11.170172+00	20260416201600_custom_sql_objects	\N	\N	2026-04-20 21:05:11.135409+00	1
\.


--
-- TOC entry 3954 (class 0 OID 89763)
-- Dependencies: 271
-- Data for Name: abonelik_tipi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.abonelik_tipi (abonelik_tip_id, abonelik_adi) FROM stdin;
\.


--
-- TOC entry 3902 (class 0 OID 89555)
-- Dependencies: 219
-- Data for Name: ai_ariza_tespit; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ai_ariza_tespit (tespit_id, makine_id, form_id, madde_id, tahmin_edilen_ariza, risk_skoru, tespit_tarihi, model_versiyon, tahmini_durus_suresi, tahmini_maliyet) FROM stdin;
\.


--
-- TOC entry 3904 (class 0 OID 89562)
-- Dependencies: 221
-- Data for Name: ai_model_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ai_model_log (log_id, makine_id, model_versiyon, kullanilan_veri_sayisi, tahmin_risk, tahmin_tarihi, kullanici_id, form_id) FROM stdin;
\.


--
-- TOC entry 3906 (class 0 OID 89569)
-- Dependencies: 223
-- Data for Name: ariza_kaydi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ariza_kaydi (ariza_id, makine_id, ariza_tespit_kaynagi, ariza_aciklama, baslangic_zamani, bitis_zamani, olusturma_tarihi, ariza_tur_id, makine_adi) FROM stdin;
1	1	OPERATÖR	Makine çalışırken ana milden aşırı ses geliyor, sürtünme tespit edildi.	2026-04-22 00:00:00+00	\N	2026-04-22 19:02:39.384229+00	1	Picanol OmniPlus-01
\.


--
-- TOC entry 3942 (class 0 OID 89714)
-- Dependencies: 259
-- Data for Name: ariza_turu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ariza_turu (ariza_tur_id, ariza_tur) FROM stdin;
1	MEKANİK ARIZA
\.


--
-- TOC entry 3908 (class 0 OID 89578)
-- Dependencies: 225
-- Data for Name: arizayi_tetikleyen_form; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.arizayi_tetikleyen_form (tetik_id, ariza_id, form_id, madde_id, tetikleyici_deger, sapma_orani, ai_tespit_mi, tespit_tarihi, aciklama) FROM stdin;
\.


--
-- TOC entry 3910 (class 0 OID 89587)
-- Dependencies: 227
-- Data for Name: bakim_kaydi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bakim_kaydi (bakim_id, makine_id, sorumlu_id, servis_firma_id, bakim_tarihi, bakim_maliyet, aciklama, ariza_id, bakim_tur_id, durus_suresi, kullanici_id) FROM stdin;
18	1	\N	\N	2026-04-22 18:44:34.836954+00	1500	Mock test kaydı yapılıyor.	\N	11	60.00	4
\.


--
-- TOC entry 3956 (class 0 OID 89770)
-- Dependencies: 273
-- Data for Name: bakim_turu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bakim_turu (bakim_tur_id, bakim_tur_adi) FROM stdin;
11	GENEL BAKIM
\.


--
-- TOC entry 3973 (class 0 OID 105992)
-- Dependencies: 300
-- Data for Name: durus_kaydi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.durus_kaydi (durus_id, makine_id, vardiya_tarihi, baslangic_saati, bitis_saati, durus_sure_dk, durus_nedeni, olusturma_tarihi, kullanici_id) FROM stdin;
\.


--
-- TOC entry 3912 (class 0 OID 89597)
-- Dependencies: 229
-- Data for Name: firma; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.firma (firma_id, firma_adi, vergi_no, aktif_mi, abonelik_tip_id, iletisim_id, sektor_id) FROM stdin;
1	AKTEKS TEKSTİL A.Ş.	\N	\N	\N	\N	\N
\.


--
-- TOC entry 3914 (class 0 OID 89604)
-- Dependencies: 231
-- Data for Name: form_madde_cevap; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.form_madde_cevap (cevap_id, form_id, soru_referans_id, durum, aciklama, girilen_deger) FROM stdin;
\.


--
-- TOC entry 3944 (class 0 OID 89721)
-- Dependencies: 261
-- Data for Name: garanti_firma; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.garanti_firma (garanti_firma_id, firma_adi, iletisim_id) FROM stdin;
\.


--
-- TOC entry 3946 (class 0 OID 89728)
-- Dependencies: 263
-- Data for Name: genel_sorular; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.genel_sorular (genel_soru_id, madde_adi, teknik_parametre, aktiflik, kritiklik_durumu) FROM stdin;
\.


--
-- TOC entry 3916 (class 0 OID 89613)
-- Dependencies: 233
-- Data for Name: gunluk_kontrol_formu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.gunluk_kontrol_formu (form_id, makine_id, kullanici_id, sablon_id, kontrol_tarihi, genel_not, ai_on_risk_durumu) FROM stdin;
\.


--
-- TOC entry 3958 (class 0 OID 89777)
-- Dependencies: 275
-- Data for Name: iletisim; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.iletisim (iletisim_id, telefon, mail, il, ilce, acik_adres) FROM stdin;
1	02125551020	info@abcotomotiv.com	İSTANBUL	İkitelli	İkitelli Organize Sanayi Bölgesi, Metal İş Sanayi Sitesi, 12. Blok No: 45
\.


--
-- TOC entry 3918 (class 0 OID 89622)
-- Dependencies: 235
-- Data for Name: kontrol_maddesi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.kontrol_maddesi (madde_id, sablon_id, madde_adi, teknik_parametre, kritiklik_durumu) FROM stdin;
\.


--
-- TOC entry 3920 (class 0 OID 89629)
-- Dependencies: 237
-- Data for Name: kontrol_sablonu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.kontrol_sablonu (sablon_id, makine_tur_id, sablon_adi, aciklama, aktiflik) FROM stdin;
\.


--
-- TOC entry 3900 (class 0 OID 89546)
-- Dependencies: 217
-- Data for Name: kullanici; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.kullanici (kullanici_id, firma_id, rol_id, ad, soyad, telefon, eposta, sifre, aktiflik, baslama_tarihi, kullanici_adi) FROM stdin;
4	1	2	Zeynep	Yılmaz	05551112233	zeynep.yilmaz@endux.com	pbkdf2_password_hash_1	t	2025-01-10	zeynep_admin
\.


--
-- TOC entry 3922 (class 0 OID 89638)
-- Dependencies: 239
-- Data for Name: lokasyon; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lokasyon (lokasyon_id, fabrika_alani, kat, x_koor, y_koor, guncelleme_tarihi, firma_id, makine_id) FROM stdin;
\.


--
-- TOC entry 3924 (class 0 OID 89647)
-- Dependencies: 241
-- Data for Name: makine; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine (makine_id, firma_id, makine_tur_id, makine_qr, makine_adi, satin_alma_tarihi, satin_alma_maliyeti, aktiflik_durumu, seri_no, garanti_suresi, garanti_firma_id, servis_pin, toplam_calisma_saati) FROM stdin;
1	1	1	QR-TEX-2026-001	Picanol OmniPlus-01	2026-01-15	850000.0000	t	SERI-99887766	24	\N	1234	0.00
4	1	1	QR-TEX-2026-002	Picanol OmniPlus-01	2026-01-15	850000.0000	t	SERI-9988776	24	\N	1234	0.00
\.


--
-- TOC entry 3926 (class 0 OID 89655)
-- Dependencies: 243
-- Data for Name: makine_kullanim; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine_kullanim (kullanim_id, kullanici_id, makine_id, baslangic_zamani, bitis_zamani, gunluk_top_calisma_saati) FROM stdin;
\.


--
-- TOC entry 3948 (class 0 OID 89735)
-- Dependencies: 265
-- Data for Name: makine_ozellikleri; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine_ozellikleri (ozellik_id, makine_id, teknik_ozellikler, guncelleme_tarihi) FROM stdin;
1	1	{"en": "340 cm", "hiz": "1200 rpm", "motor": "Siemens 5kW", "yag_tipi": "ISO VG 150"}	2026-04-22 16:46:10.157747
2	4	{"en": "340 cm", "hiz": "1200 rpm", "motor": "Siemens 5kW", "yag_tipi": "ISO VG 150"}	2026-04-22 16:56:03.69592
\.


--
-- TOC entry 3928 (class 0 OID 89663)
-- Dependencies: 245
-- Data for Name: makine_turu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine_turu (makine_tur_id, makine_tur_adi, risk_katsayisi) FROM stdin;
1	DOKUMA MAKİNESİ	1.50
\.


--
-- TOC entry 3969 (class 0 OID 105954)
-- Dependencies: 296
-- Data for Name: oee_raporlari; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.oee_raporlari (rapor_id, makine_id, tarih, kullanilabilirlik_orani, performans_orani, kalite_orani, oee_skoru) FROM stdin;
\.


--
-- TOC entry 3930 (class 0 OID 89670)
-- Dependencies: 247
-- Data for Name: parca; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parca (parca_id, parca_adi, tahmini_omur_saati, parca_maliyeti, tedarik_gun_suresi, kategori_id, tedarikci_id, stok_miktari, min_stok_seviyesi) FROM stdin;
1	HAVA FILTRESI X10	2500.50	450	3	2	1	100	10
\.


--
-- TOC entry 3932 (class 0 OID 89677)
-- Dependencies: 249
-- Data for Name: parca_degisim; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parca_degisim (parca_degisim_id, bakim_id, parca_id, adet, bakim_kaydi_id) FROM stdin;
\.


--
-- TOC entry 3960 (class 0 OID 89786)
-- Dependencies: 277
-- Data for Name: parca_kategori; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parca_kategori (kategori_id, kategori_adi) FROM stdin;
2	FILTRE GRUBU
\.


--
-- TOC entry 3934 (class 0 OID 89684)
-- Dependencies: 251
-- Data for Name: risk_skoru; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.risk_skoru (risk_id, makine_id, risk_skoru, risk_seviyesi, hesaplama_tarihi) FROM stdin;
\.


--
-- TOC entry 3936 (class 0 OID 89691)
-- Dependencies: 253
-- Data for Name: rol; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rol (rol_id, rol_adi) FROM stdin;
1	YONETICI
2	TEKNISYEN
3	OPERATOR
4	SERVİS
\.


--
-- TOC entry 3962 (class 0 OID 89793)
-- Dependencies: 279
-- Data for Name: sektor; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sektor (sektor_id, sektor_adi) FROM stdin;
\.


--
-- TOC entry 3938 (class 0 OID 89700)
-- Dependencies: 255
-- Data for Name: servis_firma; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_firma (servis_firma_id, firma_adi, aktiflik, iletisim_id) FROM stdin;
\.


--
-- TOC entry 3963 (class 0 OID 89799)
-- Dependencies: 280
-- Data for Name: servis_firma_uzmanlik; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_firma_uzmanlik (servis_firma_id, uzmanlik_adi) FROM stdin;
\.


--
-- TOC entry 3950 (class 0 OID 89745)
-- Dependencies: 267
-- Data for Name: servis_puan; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_puan (puan_id, servis_firma_id, puanlayan_kullanici_id, puan, yorum, tarih) FROM stdin;
\.


--
-- TOC entry 3952 (class 0 OID 89754)
-- Dependencies: 269
-- Data for Name: servis_sorumlusu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_sorumlusu (sorumlu_id, servis_firma_id, ad, soyad, telefon, aktiflik, unvan, sorumlu_adi) FROM stdin;
\.


--
-- TOC entry 3940 (class 0 OID 89707)
-- Dependencies: 257
-- Data for Name: tedarikci; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tedarikci (tedarikci_id, firma_adi, aktiflik, guvenilirlik_skoru, vergi_no, yetkili_kisi, kayit_tarihi, iletisim_id) FROM stdin;
1	SANAYI COZUMLERI LTD	t	45.20	4561237890	Mehmet Can	2026-03-27 00:00:00+00	1
\.


--
-- TOC entry 3965 (class 0 OID 89807)
-- Dependencies: 282
-- Data for Name: tedarikci_parca; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tedarikci_parca (tedarikci_parca_id, tedarik_id, parca_id, tedarik_maliyeti) FROM stdin;
\.


--
-- TOC entry 3967 (class 0 OID 89814)
-- Dependencies: 284
-- Data for Name: tedarikci_puan; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tedarikci_puan (puan_id, tedarikci_id, puanlayan_kullanici_id, puan, yorum, tarih) FROM stdin;
\.


--
-- TOC entry 3971 (class 0 OID 105969)
-- Dependencies: 298
-- Data for Name: uretim_kaydi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.uretim_kaydi (uretim_id, makine_id, vardiya_tarihi, vardiya_turu, planlanan_sure_dk, fiili_sure_dk, durus_sure_dk, teorik_uretim, gercek_uretim, hatali_uretim, olusturma_tarihi, kullanici_id) FROM stdin;
\.


--
-- TOC entry 4017 (class 0 OID 0)
-- Dependencies: 270
-- Name: abonelik_tipi_abonelik_tip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.abonelik_tipi_abonelik_tip_id_seq', 1, false);


--
-- TOC entry 4018 (class 0 OID 0)
-- Dependencies: 218
-- Name: ai_ariza_tespit_tespit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ai_ariza_tespit_tespit_id_seq', 1, false);


--
-- TOC entry 4019 (class 0 OID 0)
-- Dependencies: 220
-- Name: ai_model_log_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ai_model_log_log_id_seq', 1, false);


--
-- TOC entry 4020 (class 0 OID 0)
-- Dependencies: 222
-- Name: ariza_kaydi_ariza_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ariza_kaydi_ariza_id_seq', 1, true);


--
-- TOC entry 4021 (class 0 OID 0)
-- Dependencies: 258
-- Name: ariza_turu_ariza_tur_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ariza_turu_ariza_tur_id_seq', 1, true);


--
-- TOC entry 4022 (class 0 OID 0)
-- Dependencies: 224
-- Name: arizayi_tetikleyen_form_tetik_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.arizayi_tetikleyen_form_tetik_id_seq', 1, false);


--
-- TOC entry 4023 (class 0 OID 0)
-- Dependencies: 226
-- Name: bakim_kaydi_bakim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bakim_kaydi_bakim_id_seq', 18, true);


--
-- TOC entry 4024 (class 0 OID 0)
-- Dependencies: 272
-- Name: bakim_turu_bakim_tur_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bakim_turu_bakim_tur_id_seq', 13, true);


--
-- TOC entry 4025 (class 0 OID 0)
-- Dependencies: 299
-- Name: durus_kaydi_durus_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.durus_kaydi_durus_id_seq', 1, false);


--
-- TOC entry 4026 (class 0 OID 0)
-- Dependencies: 228
-- Name: firma_firma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.firma_firma_id_seq', 1, true);


--
-- TOC entry 4027 (class 0 OID 0)
-- Dependencies: 230
-- Name: form_madde_cevap_cevap_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.form_madde_cevap_cevap_id_seq', 1, false);


--
-- TOC entry 4028 (class 0 OID 0)
-- Dependencies: 260
-- Name: garanti_firma_garanti_firma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.garanti_firma_garanti_firma_id_seq', 1, false);


--
-- TOC entry 4029 (class 0 OID 0)
-- Dependencies: 262
-- Name: genel_sorular_genel_soru_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.genel_sorular_genel_soru_id_seq', 1, false);


--
-- TOC entry 4030 (class 0 OID 0)
-- Dependencies: 232
-- Name: gunluk_kontrol_formu_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.gunluk_kontrol_formu_form_id_seq', 1, false);


--
-- TOC entry 4031 (class 0 OID 0)
-- Dependencies: 274
-- Name: iletisim_iletisim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.iletisim_iletisim_id_seq', 1, false);


--
-- TOC entry 4032 (class 0 OID 0)
-- Dependencies: 234
-- Name: kontrol_maddesi_madde_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.kontrol_maddesi_madde_id_seq', 1, false);


--
-- TOC entry 4033 (class 0 OID 0)
-- Dependencies: 236
-- Name: kontrol_sablonu_sablon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.kontrol_sablonu_sablon_id_seq', 1, false);


--
-- TOC entry 4034 (class 0 OID 0)
-- Dependencies: 216
-- Name: kullanici_kullanici_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.kullanici_kullanici_id_seq', 4, true);


--
-- TOC entry 4035 (class 0 OID 0)
-- Dependencies: 238
-- Name: lokasyon_lokasyon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lokasyon_lokasyon_id_seq', 1, false);


--
-- TOC entry 4036 (class 0 OID 0)
-- Dependencies: 242
-- Name: makine_kullanim_kullanim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_kullanim_kullanim_id_seq', 1, false);


--
-- TOC entry 4037 (class 0 OID 0)
-- Dependencies: 240
-- Name: makine_makine_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_makine_id_seq', 4, true);


--
-- TOC entry 4038 (class 0 OID 0)
-- Dependencies: 264
-- Name: makine_ozellikleri_ozellik_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_ozellikleri_ozellik_id_seq', 2, true);


--
-- TOC entry 4039 (class 0 OID 0)
-- Dependencies: 244
-- Name: makine_turu_makine_tur_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_turu_makine_tur_id_seq', 1, true);


--
-- TOC entry 4040 (class 0 OID 0)
-- Dependencies: 295
-- Name: oee_raporlari_rapor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.oee_raporlari_rapor_id_seq', 1, false);


--
-- TOC entry 4041 (class 0 OID 0)
-- Dependencies: 248
-- Name: parca_degisim_parca_degisim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parca_degisim_parca_degisim_id_seq', 1, false);


--
-- TOC entry 4042 (class 0 OID 0)
-- Dependencies: 276
-- Name: parca_kategori_kategori_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parca_kategori_kategori_id_seq', 2, true);


--
-- TOC entry 4043 (class 0 OID 0)
-- Dependencies: 246
-- Name: parca_parca_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parca_parca_id_seq', 1, true);


--
-- TOC entry 4044 (class 0 OID 0)
-- Dependencies: 250
-- Name: risk_skoru_risk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.risk_skoru_risk_id_seq', 1, false);


--
-- TOC entry 4045 (class 0 OID 0)
-- Dependencies: 252
-- Name: rol_rol_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.rol_rol_id_seq', 1, false);


--
-- TOC entry 4046 (class 0 OID 0)
-- Dependencies: 278
-- Name: sektor_sektor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.sektor_sektor_id_seq', 1, false);


--
-- TOC entry 4047 (class 0 OID 0)
-- Dependencies: 254
-- Name: servis_firma_servis_firma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.servis_firma_servis_firma_id_seq', 7, true);


--
-- TOC entry 4048 (class 0 OID 0)
-- Dependencies: 266
-- Name: servis_puan_puan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.servis_puan_puan_id_seq', 1, false);


--
-- TOC entry 4049 (class 0 OID 0)
-- Dependencies: 268
-- Name: servis_sorumlusu_sorumlu_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.servis_sorumlusu_sorumlu_id_seq', 1, false);


--
-- TOC entry 4050 (class 0 OID 0)
-- Dependencies: 281
-- Name: tedarikci_parca_tedarikci_parca_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tedarikci_parca_tedarikci_parca_id_seq', 1, false);


--
-- TOC entry 4051 (class 0 OID 0)
-- Dependencies: 283
-- Name: tedarikci_puan_puan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tedarikci_puan_puan_id_seq', 1, false);


--
-- TOC entry 4052 (class 0 OID 0)
-- Dependencies: 256
-- Name: tedarikci_tedarikci_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tedarikci_tedarikci_id_seq', 1, true);


--
-- TOC entry 4053 (class 0 OID 0)
-- Dependencies: 297
-- Name: uretim_kaydi_uretim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.uretim_kaydi_uretim_id_seq', 1, false);


--
-- TOC entry 3555 (class 2606 OID 89536)
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- TOC entry 3654 (class 2606 OID 89768)
-- Name: abonelik_tipi abonelik_tipi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonelik_tipi
    ADD CONSTRAINT abonelik_tipi_pkey PRIMARY KEY (abonelik_tip_id);


--
-- TOC entry 3566 (class 2606 OID 89560)
-- Name: ai_ariza_tespit ai_ariza_tespit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT ai_ariza_tespit_pkey PRIMARY KEY (tespit_id);


--
-- TOC entry 3571 (class 2606 OID 89567)
-- Name: ai_model_log ai_model_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT ai_model_log_pkey PRIMARY KEY (log_id);


--
-- TOC entry 3573 (class 2606 OID 89576)
-- Name: ariza_kaydi ariza_kaydi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi
    ADD CONSTRAINT ariza_kaydi_pkey PRIMARY KEY (ariza_id);


--
-- TOC entry 3639 (class 2606 OID 89719)
-- Name: ariza_turu ariza_turu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_turu
    ADD CONSTRAINT ariza_turu_pkey PRIMARY KEY (ariza_tur_id);


--
-- TOC entry 3577 (class 2606 OID 89585)
-- Name: arizayi_tetikleyen_form arizayi_tetikleyen_form_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT arizayi_tetikleyen_form_pkey PRIMARY KEY (tetik_id);


--
-- TOC entry 3582 (class 2606 OID 89595)
-- Name: bakim_kaydi bakim_kaydi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT bakim_kaydi_pkey PRIMARY KEY (bakim_id);


--
-- TOC entry 3656 (class 2606 OID 89775)
-- Name: bakim_turu bakim_turu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_turu
    ADD CONSTRAINT bakim_turu_pkey PRIMARY KEY (bakim_tur_id);


--
-- TOC entry 3682 (class 2606 OID 105998)
-- Name: durus_kaydi durus_kaydi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.durus_kaydi
    ADD CONSTRAINT durus_kaydi_pkey PRIMARY KEY (durus_id);


--
-- TOC entry 3587 (class 2606 OID 89602)
-- Name: firma firma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT firma_pkey PRIMARY KEY (firma_id);


--
-- TOC entry 3590 (class 2606 OID 89611)
-- Name: form_madde_cevap form_madde_cevap_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap
    ADD CONSTRAINT form_madde_cevap_pkey PRIMARY KEY (cevap_id);


--
-- TOC entry 3641 (class 2606 OID 89726)
-- Name: garanti_firma garanti_firma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.garanti_firma
    ADD CONSTRAINT garanti_firma_pkey PRIMARY KEY (garanti_firma_id);


--
-- TOC entry 3643 (class 2606 OID 89733)
-- Name: genel_sorular genel_sorular_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genel_sorular
    ADD CONSTRAINT genel_sorular_pkey PRIMARY KEY (genel_soru_id);


--
-- TOC entry 3594 (class 2606 OID 89620)
-- Name: gunluk_kontrol_formu gunluk_kontrol_formu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT gunluk_kontrol_formu_pkey PRIMARY KEY (form_id);


--
-- TOC entry 3658 (class 2606 OID 89784)
-- Name: iletisim iletisim_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iletisim
    ADD CONSTRAINT iletisim_pkey PRIMARY KEY (iletisim_id);


--
-- TOC entry 3602 (class 2606 OID 89627)
-- Name: kontrol_maddesi kontrol_maddesi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_maddesi
    ADD CONSTRAINT kontrol_maddesi_pkey PRIMARY KEY (madde_id);


--
-- TOC entry 3605 (class 2606 OID 89636)
-- Name: kontrol_sablonu kontrol_sablonu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_sablonu
    ADD CONSTRAINT kontrol_sablonu_pkey PRIMARY KEY (sablon_id);


--
-- TOC entry 3561 (class 2606 OID 97763)
-- Name: kullanici kullanici_adi; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT kullanici_adi UNIQUE (kullanici_adi);


--
-- TOC entry 3563 (class 2606 OID 89553)
-- Name: kullanici kullanici_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT kullanici_pkey PRIMARY KEY (kullanici_id);


--
-- TOC entry 3607 (class 2606 OID 89645)
-- Name: lokasyon lokasyon_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon
    ADD CONSTRAINT lokasyon_pkey PRIMARY KEY (lokasyon_id);


--
-- TOC entry 3646 (class 2606 OID 89743)
-- Name: makine_ozellikleri makine_ozellikleri_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_ozellikleri
    ADD CONSTRAINT makine_ozellikleri_pkey PRIMARY KEY (ozellik_id);


--
-- TOC entry 3612 (class 2606 OID 89653)
-- Name: makine makine_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT makine_pkey PRIMARY KEY (makine_id);


--
-- TOC entry 3621 (class 2606 OID 89668)
-- Name: makine_turu makine_turu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_turu
    ADD CONSTRAINT makine_turu_pkey PRIMARY KEY (makine_tur_id);


--
-- TOC entry 3673 (class 2606 OID 105962)
-- Name: oee_raporlari oee_raporlari_makine_id_tarih_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oee_raporlari
    ADD CONSTRAINT oee_raporlari_makine_id_tarih_key UNIQUE (makine_id, tarih);


--
-- TOC entry 3675 (class 2606 OID 105960)
-- Name: oee_raporlari oee_raporlari_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oee_raporlari
    ADD CONSTRAINT oee_raporlari_pkey PRIMARY KEY (rapor_id);


--
-- TOC entry 3619 (class 2606 OID 89661)
-- Name: makine_kullanim operator_makine_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim
    ADD CONSTRAINT operator_makine_pkey PRIMARY KEY (kullanim_id);


--
-- TOC entry 3627 (class 2606 OID 89682)
-- Name: parca_degisim parca_degisim_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT parca_degisim_pkey PRIMARY KEY (parca_degisim_id);


--
-- TOC entry 3661 (class 2606 OID 89791)
-- Name: parca_kategori parca_kategori_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_kategori
    ADD CONSTRAINT parca_kategori_pkey PRIMARY KEY (kategori_id);


--
-- TOC entry 3624 (class 2606 OID 89675)
-- Name: parca parca_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT parca_pkey PRIMARY KEY (parca_id);


--
-- TOC entry 3631 (class 2606 OID 89689)
-- Name: risk_skoru risk_skoru_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_skoru
    ADD CONSTRAINT risk_skoru_pkey PRIMARY KEY (risk_id);


--
-- TOC entry 3633 (class 2606 OID 89698)
-- Name: rol rol_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (rol_id);


--
-- TOC entry 3664 (class 2606 OID 89798)
-- Name: sektor sektor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sektor
    ADD CONSTRAINT sektor_pkey PRIMARY KEY (sektor_id);


--
-- TOC entry 3635 (class 2606 OID 89705)
-- Name: servis_firma servis_firma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma
    ADD CONSTRAINT servis_firma_pkey PRIMARY KEY (servis_firma_id);


--
-- TOC entry 3666 (class 2606 OID 89805)
-- Name: servis_firma_uzmanlik servis_firma_uzmanlik_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma_uzmanlik
    ADD CONSTRAINT servis_firma_uzmanlik_pkey PRIMARY KEY (servis_firma_id);


--
-- TOC entry 3650 (class 2606 OID 89752)
-- Name: servis_puan servis_puan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan
    ADD CONSTRAINT servis_puan_pkey PRIMARY KEY (puan_id);


--
-- TOC entry 3652 (class 2606 OID 89761)
-- Name: servis_sorumlusu servis_sorumlusu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_sorumlusu
    ADD CONSTRAINT servis_sorumlusu_pkey PRIMARY KEY (sorumlu_id);


--
-- TOC entry 3671 (class 2606 OID 89821)
-- Name: tedarikci_puan tedarakci_puan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan
    ADD CONSTRAINT tedarakci_puan_pkey PRIMARY KEY (puan_id);


--
-- TOC entry 3668 (class 2606 OID 89812)
-- Name: tedarikci_parca tedarikci_parca_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca
    ADD CONSTRAINT tedarikci_parca_pkey PRIMARY KEY (tedarikci_parca_id);


--
-- TOC entry 3637 (class 2606 OID 89712)
-- Name: tedarikci tedarikci_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci
    ADD CONSTRAINT tedarikci_pkey PRIMARY KEY (tedarikci_id);


--
-- TOC entry 3680 (class 2606 OID 105977)
-- Name: uretim_kaydi uretim_kaydi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uretim_kaydi
    ADD CONSTRAINT uretim_kaydi_pkey PRIMARY KEY (uretim_id);


--
-- TOC entry 3574 (class 1259 OID 89831)
-- Name: idx_ariza_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ariza_tarih ON public.ariza_kaydi USING btree (baslangic_zamani);


--
-- TOC entry 3583 (class 1259 OID 89835)
-- Name: idx_bakim_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bakim_makine ON public.bakim_kaydi USING btree (makine_id);


--
-- TOC entry 3584 (class 1259 OID 89836)
-- Name: idx_bakim_servis; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bakim_servis ON public.bakim_kaydi USING btree (servis_firma_id);


--
-- TOC entry 3585 (class 1259 OID 89837)
-- Name: idx_bakim_teknisyen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bakim_teknisyen ON public.bakim_kaydi USING btree (sorumlu_id);


--
-- TOC entry 3591 (class 1259 OID 89839)
-- Name: idx_cevap_form; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cevap_form ON public.form_madde_cevap USING btree (form_id);


--
-- TOC entry 3592 (class 1259 OID 89840)
-- Name: idx_cevap_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cevap_madde ON public.form_madde_cevap USING btree (soru_referans_id);


--
-- TOC entry 3625 (class 1259 OID 89857)
-- Name: idx_degisim_bakim; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_degisim_bakim ON public.parca_degisim USING btree (bakim_id);


--
-- TOC entry 3683 (class 1259 OID 106009)
-- Name: idx_durus_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_durus_makine ON public.durus_kaydi USING btree (makine_id);


--
-- TOC entry 3684 (class 1259 OID 106011)
-- Name: idx_durus_makine_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_durus_makine_tarih ON public.durus_kaydi USING btree (makine_id, vardiya_tarihi);


--
-- TOC entry 3685 (class 1259 OID 106010)
-- Name: idx_durus_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_durus_tarih ON public.durus_kaydi USING btree (vardiya_tarihi);


--
-- TOC entry 3599 (class 1259 OID 89846)
-- Name: idx_kontrol_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kontrol_madde ON public.kontrol_maddesi USING btree (madde_id);


--
-- TOC entry 3600 (class 1259 OID 89845)
-- Name: idx_kontrol_sablon; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kontrol_sablon ON public.kontrol_maddesi USING btree (sablon_id);


--
-- TOC entry 3556 (class 1259 OID 89826)
-- Name: idx_kullanici_adi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kullanici_adi ON public.kullanici USING btree (kullanici_adi);


--
-- TOC entry 3557 (class 1259 OID 89822)
-- Name: idx_kullanici_eposta; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_kullanici_eposta ON public.kullanici USING btree (eposta);


--
-- TOC entry 3558 (class 1259 OID 89824)
-- Name: idx_kullanici_firma_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kullanici_firma_id ON public.kullanici USING btree (firma_id);


--
-- TOC entry 3559 (class 1259 OID 89825)
-- Name: idx_kullanici_rol_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kullanici_rol_id ON public.kullanici USING btree (rol_id);


--
-- TOC entry 3575 (class 1259 OID 89830)
-- Name: idx_m_ariza; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_m_ariza ON public.ariza_kaydi USING btree (makine_id);


--
-- TOC entry 3608 (class 1259 OID 89852)
-- Name: idx_m_qr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_m_qr ON public.makine USING btree (makine_qr);


--
-- TOC entry 3609 (class 1259 OID 89850)
-- Name: idx_makine_firma; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_firma ON public.makine USING btree (firma_id);


--
-- TOC entry 3595 (class 1259 OID 89841)
-- Name: idx_makine_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_id ON public.gunluk_kontrol_formu USING btree (makine_id);


--
-- TOC entry 3615 (class 1259 OID 89854)
-- Name: idx_makine_kullanim_baslangic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_kullanim_baslangic ON public.makine_kullanim USING btree (baslangic_zamani);


--
-- TOC entry 3616 (class 1259 OID 89853)
-- Name: idx_makine_kullanim_kullanici_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_kullanim_kullanici_id ON public.makine_kullanim USING btree (kullanici_id);


--
-- TOC entry 3610 (class 1259 OID 89851)
-- Name: idx_makine_turu; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_turu ON public.makine USING btree (makine_tur_id);


--
-- TOC entry 3617 (class 1259 OID 89855)
-- Name: idx_mkullanim_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mkullanim_makine ON public.makine_kullanim USING btree (makine_id);


--
-- TOC entry 3596 (class 1259 OID 89842)
-- Name: idx_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_id ON public.gunluk_kontrol_formu USING btree (kullanici_id);


--
-- TOC entry 3628 (class 1259 OID 89858)
-- Name: idx_risk_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_risk_makine ON public.risk_skoru USING btree (makine_id);


--
-- TOC entry 3629 (class 1259 OID 89859)
-- Name: idx_risk_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_risk_tarih ON public.risk_skoru USING btree (hesaplama_tarihi);


--
-- TOC entry 3597 (class 1259 OID 89843)
-- Name: idx_sablon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sablon_id ON public.gunluk_kontrol_formu USING btree (sablon_id);


--
-- TOC entry 3603 (class 1259 OID 89847)
-- Name: idx_sablon_m_turu; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sablon_m_turu ON public.kontrol_sablonu USING btree (makine_tur_id);


--
-- TOC entry 3647 (class 1259 OID 89861)
-- Name: idx_spuan_firma; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_spuan_firma ON public.servis_puan USING btree (servis_firma_id);


--
-- TOC entry 3648 (class 1259 OID 89862)
-- Name: idx_spuan_kullanici; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_spuan_kullanici ON public.servis_puan USING btree (puanlayan_kullanici_id);


--
-- TOC entry 3598 (class 1259 OID 89844)
-- Name: idx_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tarih ON public.gunluk_kontrol_formu USING btree (kontrol_tarihi);


--
-- TOC entry 3567 (class 1259 OID 89827)
-- Name: idx_tespit_form; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tespit_form ON public.ai_ariza_tespit USING btree (form_id);


--
-- TOC entry 3568 (class 1259 OID 89828)
-- Name: idx_tespit_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tespit_madde ON public.ai_ariza_tespit USING btree (madde_id);


--
-- TOC entry 3569 (class 1259 OID 89829)
-- Name: idx_tespit_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tespit_makine ON public.ai_ariza_tespit USING btree (makine_id);


--
-- TOC entry 3578 (class 1259 OID 89832)
-- Name: idx_tetik_form; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tetik_form ON public.arizayi_tetikleyen_form USING btree (form_id);


--
-- TOC entry 3579 (class 1259 OID 89833)
-- Name: idx_tetik_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tetik_madde ON public.arizayi_tetikleyen_form USING btree (madde_id);


--
-- TOC entry 3580 (class 1259 OID 89834)
-- Name: idx_tetik_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tetik_tarih ON public.arizayi_tetikleyen_form USING btree (tespit_tarihi);


--
-- TOC entry 3669 (class 1259 OID 89865)
-- Name: idx_tpuan_tedarikci; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tpuan_tedarikci ON public.tedarikci_puan USING btree (tedarikci_id);


--
-- TOC entry 3676 (class 1259 OID 105988)
-- Name: idx_uretim_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_uretim_makine ON public.uretim_kaydi USING btree (makine_id);


--
-- TOC entry 3677 (class 1259 OID 105990)
-- Name: idx_uretim_makine_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_uretim_makine_tarih ON public.uretim_kaydi USING btree (makine_id, vardiya_tarihi);


--
-- TOC entry 3678 (class 1259 OID 105989)
-- Name: idx_uretim_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_uretim_tarih ON public.uretim_kaydi USING btree (vardiya_tarihi);


--
-- TOC entry 3644 (class 1259 OID 89860)
-- Name: makine_ozellikleri_makine_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX makine_ozellikleri_makine_id_key ON public.makine_ozellikleri USING btree (makine_id);


--
-- TOC entry 3622 (class 1259 OID 89856)
-- Name: parca_adi; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX parca_adi ON public.parca USING btree (parca_adi);


--
-- TOC entry 3662 (class 1259 OID 89864)
-- Name: unique_kategori_adi; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_kategori_adi ON public.parca_kategori USING btree (kategori_adi);


--
-- TOC entry 3564 (class 1259 OID 89823)
-- Name: unique_kullanici; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_kullanici ON public.kullanici USING btree (kullanici_adi);


--
-- TOC entry 3659 (class 1259 OID 89863)
-- Name: unique_telefon; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_telefon ON public.iletisim USING btree (telefon);


--
-- TOC entry 3613 (class 1259 OID 89848)
-- Name: uq_makine_qr; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_makine_qr ON public.makine USING btree (makine_qr);


--
-- TOC entry 3614 (class 1259 OID 89849)
-- Name: uq_seri_no; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_seri_no ON public.makine USING btree (seri_no);


--
-- TOC entry 3588 (class 1259 OID 89838)
-- Name: uq_vergi_no; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_vergi_no ON public.firma USING btree (vergi_no);


--
-- TOC entry 3744 (class 2620 OID 90177)
-- Name: bakim_kaydi trg_bakim_ariza_kapat; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_bakim_ariza_kapat AFTER INSERT ON public.bakim_kaydi FOR EACH ROW WHEN ((new.ariza_id IS NOT NULL)) EXECUTE FUNCTION public.fn_bakim_girince_arizayi_kapat();


--
-- TOC entry 3731 (class 2606 OID 90076)
-- Name: servis_puan firma_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan
    ADD CONSTRAINT firma_fk FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3705 (class 2606 OID 89951)
-- Name: firma fk_abonelik; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT fk_abonelik FOREIGN KEY (abonelik_tip_id) REFERENCES public.abonelik_tipi(abonelik_tip_id);


--
-- TOC entry 3691 (class 2606 OID 89891)
-- Name: ai_model_log fk_ai_log; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT fk_ai_log FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3696 (class 2606 OID 89916)
-- Name: arizayi_tetikleyen_form fk_ariza; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT fk_ariza FOREIGN KEY (ariza_id) REFERENCES public.ariza_kaydi(ariza_id);


--
-- TOC entry 3699 (class 2606 OID 89931)
-- Name: bakim_kaydi fk_ariza; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_ariza FOREIGN KEY (ariza_id) REFERENCES public.ariza_kaydi(ariza_id);


--
-- TOC entry 3694 (class 2606 OID 89906)
-- Name: ariza_kaydi fk_ariza_tur; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi
    ADD CONSTRAINT fk_ariza_tur FOREIGN KEY (ariza_tur_id) REFERENCES public.ariza_turu(ariza_tur_id);


--
-- TOC entry 3700 (class 2606 OID 89936)
-- Name: bakim_kaydi fk_bakim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_bakim FOREIGN KEY (bakim_tur_id) REFERENCES public.bakim_turu(bakim_tur_id);


--
-- TOC entry 3723 (class 2606 OID 90041)
-- Name: parca_degisim fk_bakim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT fk_bakim FOREIGN KEY (bakim_id) REFERENCES public.bakim_kaydi(bakim_id);


--
-- TOC entry 3724 (class 2606 OID 97719)
-- Name: parca_degisim fk_bakim_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT fk_bakim_id FOREIGN KEY (bakim_kaydi_id) REFERENCES public.bakim_kaydi(bakim_id) NOT VALID;


--
-- TOC entry 3742 (class 2606 OID 106004)
-- Name: durus_kaydi fk_durus_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.durus_kaydi
    ADD CONSTRAINT fk_durus_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3743 (class 2606 OID 105999)
-- Name: durus_kaydi fk_durus_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.durus_kaydi
    ADD CONSTRAINT fk_durus_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3686 (class 2606 OID 89866)
-- Name: kullanici fk_firma; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT fk_firma FOREIGN KEY (firma_id) REFERENCES public.firma(firma_id);


--
-- TOC entry 3716 (class 2606 OID 90006)
-- Name: makine fk_firma; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT fk_firma FOREIGN KEY (firma_id) REFERENCES public.firma(firma_id);


--
-- TOC entry 3688 (class 2606 OID 89876)
-- Name: ai_ariza_tespit fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3692 (class 2606 OID 89896)
-- Name: ai_model_log fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3697 (class 2606 OID 89921)
-- Name: arizayi_tetikleyen_form fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3708 (class 2606 OID 89966)
-- Name: form_madde_cevap fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3717 (class 2606 OID 90011)
-- Name: makine fk_garanti_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT fk_garanti_id FOREIGN KEY (garanti_firma_id) REFERENCES public.garanti_firma(garanti_firma_id);


--
-- TOC entry 3706 (class 2606 OID 89956)
-- Name: firma fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id);


--
-- TOC entry 3729 (class 2606 OID 90066)
-- Name: garanti_firma fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.garanti_firma
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id);


--
-- TOC entry 3727 (class 2606 OID 90056)
-- Name: servis_firma fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id);


--
-- TOC entry 3728 (class 2606 OID 90061)
-- Name: tedarikci fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id);


--
-- TOC entry 3721 (class 2606 OID 90031)
-- Name: parca fk_kategori; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT fk_kategori FOREIGN KEY (kategori_id) REFERENCES public.parca_kategori(kategori_id);


--
-- TOC entry 3693 (class 2606 OID 89901)
-- Name: ai_model_log fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3701 (class 2606 OID 97747)
-- Name: bakim_kaydi fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id) NOT VALID;


--
-- TOC entry 3710 (class 2606 OID 89976)
-- Name: gunluk_kontrol_formu fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3719 (class 2606 OID 90021)
-- Name: makine_kullanim fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3737 (class 2606 OID 90106)
-- Name: tedarikci_puan fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (puanlayan_kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3689 (class 2606 OID 89881)
-- Name: ai_ariza_tespit fk_madde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT fk_madde FOREIGN KEY (madde_id) REFERENCES public.kontrol_maddesi(madde_id);


--
-- TOC entry 3698 (class 2606 OID 89926)
-- Name: arizayi_tetikleyen_form fk_madde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT fk_madde FOREIGN KEY (madde_id) REFERENCES public.kontrol_maddesi(madde_id);


--
-- TOC entry 3709 (class 2606 OID 89971)
-- Name: form_madde_cevap fk_madde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap
    ADD CONSTRAINT fk_madde FOREIGN KEY (soru_referans_id) REFERENCES public.kontrol_maddesi(madde_id);


--
-- TOC entry 3690 (class 2606 OID 89886)
-- Name: ai_ariza_tespit fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3695 (class 2606 OID 89911)
-- Name: ariza_kaydi fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3702 (class 2606 OID 89941)
-- Name: bakim_kaydi fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3711 (class 2606 OID 89981)
-- Name: gunluk_kontrol_formu fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3714 (class 2606 OID 89996)
-- Name: lokasyon fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3720 (class 2606 OID 90026)
-- Name: makine_kullanim fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3730 (class 2606 OID 90071)
-- Name: makine_ozellikleri fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_ozellikleri
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id) ON DELETE CASCADE;


--
-- TOC entry 3726 (class 2606 OID 90051)
-- Name: risk_skoru fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_skoru
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3718 (class 2606 OID 90016)
-- Name: makine fk_makine_turu; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT fk_makine_turu FOREIGN KEY (makine_tur_id) REFERENCES public.makine_turu(makine_tur_id);


--
-- TOC entry 3725 (class 2606 OID 90046)
-- Name: parca_degisim fk_parca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT fk_parca FOREIGN KEY (parca_id) REFERENCES public.parca(parca_id);


--
-- TOC entry 3735 (class 2606 OID 90096)
-- Name: tedarikci_parca fk_parca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca
    ADD CONSTRAINT fk_parca FOREIGN KEY (parca_id) REFERENCES public.parca(parca_id);


--
-- TOC entry 3687 (class 2606 OID 89871)
-- Name: kullanici fk_rol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT fk_rol FOREIGN KEY (rol_id) REFERENCES public.rol(rol_id);


--
-- TOC entry 3712 (class 2606 OID 89986)
-- Name: gunluk_kontrol_formu fk_sablon; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT fk_sablon FOREIGN KEY (sablon_id) REFERENCES public.kontrol_sablonu(sablon_id);


--
-- TOC entry 3713 (class 2606 OID 89991)
-- Name: kontrol_sablonu fk_sablon_kontrol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_sablonu
    ADD CONSTRAINT fk_sablon_kontrol FOREIGN KEY (makine_tur_id) REFERENCES public.makine_turu(makine_tur_id);


--
-- TOC entry 3707 (class 2606 OID 89961)
-- Name: firma fk_sektor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT fk_sektor FOREIGN KEY (sektor_id) REFERENCES public.sektor(sektor_id);


--
-- TOC entry 3703 (class 2606 OID 89946)
-- Name: bakim_kaydi fk_servis; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_servis FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3704 (class 2606 OID 90179)
-- Name: bakim_kaydi fk_servis_sorumlu; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_servis_sorumlu FOREIGN KEY (sorumlu_id) REFERENCES public.servis_sorumlusu(sorumlu_id);


--
-- TOC entry 3733 (class 2606 OID 90086)
-- Name: servis_sorumlusu fk_sorumlusu; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_sorumlusu
    ADD CONSTRAINT fk_sorumlusu FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3722 (class 2606 OID 90036)
-- Name: parca fk_tedarikci; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT fk_tedarikci FOREIGN KEY (tedarikci_id) REFERENCES public.tedarikci(tedarikci_id);


--
-- TOC entry 3736 (class 2606 OID 90101)
-- Name: tedarikci_parca fk_tedarikci; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca
    ADD CONSTRAINT fk_tedarikci FOREIGN KEY (tedarik_id) REFERENCES public.tedarikci(tedarikci_id);


--
-- TOC entry 3740 (class 2606 OID 105983)
-- Name: uretim_kaydi fk_uretim_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uretim_kaydi
    ADD CONSTRAINT fk_uretim_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3741 (class 2606 OID 105978)
-- Name: uretim_kaydi fk_uretim_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uretim_kaydi
    ADD CONSTRAINT fk_uretim_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3732 (class 2606 OID 90081)
-- Name: servis_puan kullanici_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan
    ADD CONSTRAINT kullanici_fk FOREIGN KEY (puanlayan_kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3715 (class 2606 OID 90001)
-- Name: lokasyon lokasyon_firma_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon
    ADD CONSTRAINT lokasyon_firma_id_fkey FOREIGN KEY (firma_id) REFERENCES public.firma(firma_id);


--
-- TOC entry 3739 (class 2606 OID 105963)
-- Name: oee_raporlari oee_raporlari_makine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oee_raporlari
    ADD CONSTRAINT oee_raporlari_makine_id_fkey FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id) ON DELETE CASCADE;


--
-- TOC entry 3734 (class 2606 OID 90091)
-- Name: servis_firma_uzmanlik servis_firma_uzmanlik_servis_firma_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma_uzmanlik
    ADD CONSTRAINT servis_firma_uzmanlik_servis_firma_id_fkey FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3738 (class 2606 OID 90111)
-- Name: tedarikci_puan tk_tedarikci; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan
    ADD CONSTRAINT tk_tedarikci FOREIGN KEY (tedarikci_id) REFERENCES public.tedarikci(tedarikci_id);


--
-- TOC entry 3979 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


-- Completed on 2026-04-27 16:02:43

--
-- PostgreSQL database dump complete
--

\unrestrict dan7cXjsjdQiC2KHIfCjYCEOeAviTWRTwoLwivGRJa7qcYcIJYE5LWQ1TQfaCzY

