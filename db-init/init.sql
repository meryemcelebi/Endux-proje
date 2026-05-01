--
-- PostgreSQL database dump
--

\restrict 95Q7seZddgXjUnEphSaDEljTYym7FqErcoS9os4wAAc4xSpXknX37YxJCnAdrvr

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

-- Started on 2026-05-01 15:15:48

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
-- TOC entry 961 (class 1247 OID 89538)
-- Name: du_ort_yuk; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.du_ort_yuk AS ENUM (
    'DUSUK',
    'ORTA',
    'YUKSEK'
);


--
-- TOC entry 316 (class 1255 OID 90167)
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
-- TOC entry 318 (class 1255 OID 114156)
-- Name: fnk_stok_hareket_kaydet(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fnk_stok_hareket_kaydet() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Eğer yeni bir parca ekleniyorsa (INSERT)
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.parca_stok_hareketleri (parca_id, eklenen_miktar)
        VALUES (NEW.parca_id, NEW.stok_miktari);
        
    -- Eğer var olan parçanın stoğu güncelleniyorsa (UPDATE)
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Sadece stok miktarı değiştiyse kayıt at
        IF (OLD.stok_miktari IS DISTINCT FROM NEW.stok_miktari) THEN
            INSERT INTO public.parca_stok_hareketleri (parca_id, eklenen_miktar)
            VALUES (NEW.parca_id, (NEW.stok_miktari - OLD.stok_miktari));
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 317 (class 1255 OID 90117)
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
-- TOC entry 319 (class 1255 OID 90168)
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
-- TOC entry 320 (class 1255 OID 90169)
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
-- TOC entry 321 (class 1255 OID 90170)
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
-- TOC entry 304 (class 1255 OID 90116)
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
-- TOC entry 325 (class 1255 OID 97760)
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
-- TOC entry 322 (class 1255 OID 90173)
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
-- TOC entry 323 (class 1255 OID 90174)
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
-- TOC entry 326 (class 1255 OID 97761)
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
-- TOC entry 324 (class 1255 OID 90176)
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
-- TOC entry 3999 (class 0 OID 0)
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
-- TOC entry 4000 (class 0 OID 0)
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
-- TOC entry 4001 (class 0 OID 0)
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
-- TOC entry 4002 (class 0 OID 0)
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
-- TOC entry 4003 (class 0 OID 0)
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
-- TOC entry 4004 (class 0 OID 0)
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
    kullanici_id integer,
    durum character varying(50) DEFAULT 'BEKLEYEN'::character varying
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
-- TOC entry 4005 (class 0 OID 0)
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
-- TOC entry 4006 (class 0 OID 0)
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
-- TOC entry 4007 (class 0 OID 0)
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
-- TOC entry 4008 (class 0 OID 0)
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
-- TOC entry 4009 (class 0 OID 0)
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
-- TOC entry 4010 (class 0 OID 0)
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
-- TOC entry 4011 (class 0 OID 0)
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
-- TOC entry 4012 (class 0 OID 0)
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
-- TOC entry 4013 (class 0 OID 0)
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
-- TOC entry 4014 (class 0 OID 0)
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
-- TOC entry 4015 (class 0 OID 0)
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
-- TOC entry 4016 (class 0 OID 0)
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
-- TOC entry 4017 (class 0 OID 0)
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
-- TOC entry 4018 (class 0 OID 0)
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
-- TOC entry 4019 (class 0 OID 0)
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
-- TOC entry 4020 (class 0 OID 0)
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
-- TOC entry 4021 (class 0 OID 0)
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
-- TOC entry 4022 (class 0 OID 0)
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
-- TOC entry 4023 (class 0 OID 0)
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
-- TOC entry 4024 (class 0 OID 0)
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
-- TOC entry 4025 (class 0 OID 0)
-- Dependencies: 246
-- Name: parca_parca_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parca_parca_id_seq OWNED BY public.parca.parca_id;


--
-- TOC entry 302 (class 1259 OID 114149)
-- Name: parca_stok_hareketleri; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parca_stok_hareketleri (
    hareket_id integer NOT NULL,
    parca_id integer,
    eklenen_miktar integer,
    islem_tarihi timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- TOC entry 301 (class 1259 OID 114148)
-- Name: parca_stok_hareketleri_hareket_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parca_stok_hareketleri_hareket_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4026 (class 0 OID 0)
-- Dependencies: 301
-- Name: parca_stok_hareketleri_hareket_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parca_stok_hareketleri_hareket_id_seq OWNED BY public.parca_stok_hareketleri.hareket_id;


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
-- TOC entry 4027 (class 0 OID 0)
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
-- TOC entry 4028 (class 0 OID 0)
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
-- TOC entry 4029 (class 0 OID 0)
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
-- TOC entry 4030 (class 0 OID 0)
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
-- TOC entry 4031 (class 0 OID 0)
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
-- TOC entry 4032 (class 0 OID 0)
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
-- TOC entry 4033 (class 0 OID 0)
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
-- TOC entry 4034 (class 0 OID 0)
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
-- TOC entry 4035 (class 0 OID 0)
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
-- TOC entry 4036 (class 0 OID 0)
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
-- TOC entry 303 (class 1259 OID 114158)
-- Name: vw_parca_alim_gecmisi; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_parca_alim_gecmisi AS
 SELECT p.parca_adi,
    k.kategori_adi,
    sh.islem_tarihi AS stok_giris_tarihi,
    sh.eklenen_miktar AS girilen_adet
   FROM ((public.parca_stok_hareketleri sh
     JOIN public.parca p ON ((sh.parca_id = p.parca_id)))
     JOIN public.parca_kategori k ON ((p.kategori_id = k.kategori_id)))
  ORDER BY sh.islem_tarihi DESC;


--
-- TOC entry 3550 (class 2604 OID 89766)
-- Name: abonelik_tipi abonelik_tip_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonelik_tipi ALTER COLUMN abonelik_tip_id SET DEFAULT nextval('public.abonelik_tipi_abonelik_tip_id_seq'::regclass);


--
-- TOC entry 3519 (class 2604 OID 89558)
-- Name: ai_ariza_tespit tespit_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit ALTER COLUMN tespit_id SET DEFAULT nextval('public.ai_ariza_tespit_tespit_id_seq'::regclass);


--
-- TOC entry 3520 (class 2604 OID 89565)
-- Name: ai_model_log log_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log ALTER COLUMN log_id SET DEFAULT nextval('public.ai_model_log_log_id_seq'::regclass);


--
-- TOC entry 3521 (class 2604 OID 89572)
-- Name: ariza_kaydi ariza_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi ALTER COLUMN ariza_id SET DEFAULT nextval('public.ariza_kaydi_ariza_id_seq'::regclass);


--
-- TOC entry 3543 (class 2604 OID 89717)
-- Name: ariza_turu ariza_tur_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_turu ALTER COLUMN ariza_tur_id SET DEFAULT nextval('public.ariza_turu_ariza_tur_id_seq'::regclass);


--
-- TOC entry 3522 (class 2604 OID 89581)
-- Name: arizayi_tetikleyen_form tetik_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form ALTER COLUMN tetik_id SET DEFAULT nextval('public.arizayi_tetikleyen_form_tetik_id_seq'::regclass);


--
-- TOC entry 3523 (class 2604 OID 89590)
-- Name: bakim_kaydi bakim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi ALTER COLUMN bakim_id SET DEFAULT nextval('public.bakim_kaydi_bakim_id_seq'::regclass);


--
-- TOC entry 3551 (class 2604 OID 89773)
-- Name: bakim_turu bakim_tur_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_turu ALTER COLUMN bakim_tur_id SET DEFAULT nextval('public.bakim_turu_bakim_tur_id_seq'::regclass);


--
-- TOC entry 3563 (class 2604 OID 105995)
-- Name: durus_kaydi durus_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.durus_kaydi ALTER COLUMN durus_id SET DEFAULT nextval('public.durus_kaydi_durus_id_seq'::regclass);


--
-- TOC entry 3526 (class 2604 OID 89600)
-- Name: firma firma_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma ALTER COLUMN firma_id SET DEFAULT nextval('public.firma_firma_id_seq'::regclass);


--
-- TOC entry 3527 (class 2604 OID 89607)
-- Name: form_madde_cevap cevap_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap ALTER COLUMN cevap_id SET DEFAULT nextval('public.form_madde_cevap_cevap_id_seq'::regclass);


--
-- TOC entry 3544 (class 2604 OID 89724)
-- Name: garanti_firma garanti_firma_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.garanti_firma ALTER COLUMN garanti_firma_id SET DEFAULT nextval('public.garanti_firma_garanti_firma_id_seq'::regclass);


--
-- TOC entry 3545 (class 2604 OID 89731)
-- Name: genel_sorular genel_soru_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genel_sorular ALTER COLUMN genel_soru_id SET DEFAULT nextval('public.genel_sorular_genel_soru_id_seq'::regclass);


--
-- TOC entry 3528 (class 2604 OID 89616)
-- Name: gunluk_kontrol_formu form_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu ALTER COLUMN form_id SET DEFAULT nextval('public.gunluk_kontrol_formu_form_id_seq'::regclass);


--
-- TOC entry 3552 (class 2604 OID 89780)
-- Name: iletisim iletisim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iletisim ALTER COLUMN iletisim_id SET DEFAULT nextval('public.iletisim_iletisim_id_seq'::regclass);


--
-- TOC entry 3529 (class 2604 OID 89625)
-- Name: kontrol_maddesi madde_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_maddesi ALTER COLUMN madde_id SET DEFAULT nextval('public.kontrol_maddesi_madde_id_seq'::regclass);


--
-- TOC entry 3530 (class 2604 OID 89632)
-- Name: kontrol_sablonu sablon_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_sablonu ALTER COLUMN sablon_id SET DEFAULT nextval('public.kontrol_sablonu_sablon_id_seq'::regclass);


--
-- TOC entry 3518 (class 2604 OID 89549)
-- Name: kullanici kullanici_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici ALTER COLUMN kullanici_id SET DEFAULT nextval('public.kullanici_kullanici_id_seq'::regclass);


--
-- TOC entry 3531 (class 2604 OID 89641)
-- Name: lokasyon lokasyon_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon ALTER COLUMN lokasyon_id SET DEFAULT nextval('public.lokasyon_lokasyon_id_seq'::regclass);


--
-- TOC entry 3532 (class 2604 OID 89650)
-- Name: makine makine_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine ALTER COLUMN makine_id SET DEFAULT nextval('public.makine_makine_id_seq'::regclass);


--
-- TOC entry 3534 (class 2604 OID 89658)
-- Name: makine_kullanim kullanim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim ALTER COLUMN kullanim_id SET DEFAULT nextval('public.makine_kullanim_kullanim_id_seq'::regclass);


--
-- TOC entry 3546 (class 2604 OID 89738)
-- Name: makine_ozellikleri ozellik_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_ozellikleri ALTER COLUMN ozellik_id SET DEFAULT nextval('public.makine_ozellikleri_ozellik_id_seq'::regclass);


--
-- TOC entry 3536 (class 2604 OID 89666)
-- Name: makine_turu makine_tur_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_turu ALTER COLUMN makine_tur_id SET DEFAULT nextval('public.makine_turu_makine_tur_id_seq'::regclass);


--
-- TOC entry 3557 (class 2604 OID 105957)
-- Name: oee_raporlari rapor_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oee_raporlari ALTER COLUMN rapor_id SET DEFAULT nextval('public.oee_raporlari_rapor_id_seq'::regclass);


--
-- TOC entry 3537 (class 2604 OID 89673)
-- Name: parca parca_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca ALTER COLUMN parca_id SET DEFAULT nextval('public.parca_parca_id_seq'::regclass);


--
-- TOC entry 3538 (class 2604 OID 89680)
-- Name: parca_degisim parca_degisim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim ALTER COLUMN parca_degisim_id SET DEFAULT nextval('public.parca_degisim_parca_degisim_id_seq'::regclass);


--
-- TOC entry 3553 (class 2604 OID 89789)
-- Name: parca_kategori kategori_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_kategori ALTER COLUMN kategori_id SET DEFAULT nextval('public.parca_kategori_kategori_id_seq'::regclass);


--
-- TOC entry 3565 (class 2604 OID 114152)
-- Name: parca_stok_hareketleri hareket_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_stok_hareketleri ALTER COLUMN hareket_id SET DEFAULT nextval('public.parca_stok_hareketleri_hareket_id_seq'::regclass);


--
-- TOC entry 3539 (class 2604 OID 89687)
-- Name: risk_skoru risk_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_skoru ALTER COLUMN risk_id SET DEFAULT nextval('public.risk_skoru_risk_id_seq'::regclass);


--
-- TOC entry 3540 (class 2604 OID 89694)
-- Name: rol rol_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol ALTER COLUMN rol_id SET DEFAULT nextval('public.rol_rol_id_seq'::regclass);


--
-- TOC entry 3554 (class 2604 OID 89796)
-- Name: sektor sektor_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sektor ALTER COLUMN sektor_id SET DEFAULT nextval('public.sektor_sektor_id_seq'::regclass);


--
-- TOC entry 3541 (class 2604 OID 89703)
-- Name: servis_firma servis_firma_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma ALTER COLUMN servis_firma_id SET DEFAULT nextval('public.servis_firma_servis_firma_id_seq'::regclass);


--
-- TOC entry 3548 (class 2604 OID 89748)
-- Name: servis_puan puan_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan ALTER COLUMN puan_id SET DEFAULT nextval('public.servis_puan_puan_id_seq'::regclass);


--
-- TOC entry 3549 (class 2604 OID 89757)
-- Name: servis_sorumlusu sorumlu_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_sorumlusu ALTER COLUMN sorumlu_id SET DEFAULT nextval('public.servis_sorumlusu_sorumlu_id_seq'::regclass);


--
-- TOC entry 3542 (class 2604 OID 89710)
-- Name: tedarikci tedarikci_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci ALTER COLUMN tedarikci_id SET DEFAULT nextval('public.tedarikci_tedarikci_id_seq'::regclass);


--
-- TOC entry 3555 (class 2604 OID 89810)
-- Name: tedarikci_parca tedarikci_parca_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca ALTER COLUMN tedarikci_parca_id SET DEFAULT nextval('public.tedarikci_parca_tedarikci_parca_id_seq'::regclass);


--
-- TOC entry 3556 (class 2604 OID 89817)
-- Name: tedarikci_puan puan_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan ALTER COLUMN puan_id SET DEFAULT nextval('public.tedarikci_puan_puan_id_seq'::regclass);


--
-- TOC entry 3559 (class 2604 OID 105972)
-- Name: uretim_kaydi uretim_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uretim_kaydi ALTER COLUMN uretim_id SET DEFAULT nextval('public.uretim_kaydi_uretim_id_seq'::regclass);


--
-- TOC entry 3915 (class 0 OID 89528)
-- Dependencies: 215
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
1fb9a010-be97-4260-9782-65ce218b858a	a32ff71c4b29238ae4a58b1482d2db7df6f42ffc95029daabbe7f587efe0a0f7	2026-04-20 21:05:10.996067+00	20260416164838_init_schema	\N	\N	2026-04-20 21:05:08.447867+00	1
800af273-0dcd-453f-abc5-41d619307bf8	c88554b74443e0b806977c390852beb50ebfef26090eac0db0e9c1463e2f63fa	2026-04-20 21:05:11.130035+00	20260416174827_missing_views_and_procedures	\N	\N	2026-04-20 21:05:11.000983+00	1
51ba0b80-5e36-4689-a41f-030560fa22a3	b4b442121959a6f47ae8d60861aff1e214d2c7eb181b83f15ec45ec7e83f2505	2026-04-20 21:05:11.170172+00	20260416201600_custom_sql_objects	\N	\N	2026-04-20 21:05:11.135409+00	1
\.


--
-- TOC entry 3971 (class 0 OID 89763)
-- Dependencies: 271
-- Data for Name: abonelik_tipi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.abonelik_tipi (abonelik_tip_id, abonelik_adi) FROM stdin;
\.


--
-- TOC entry 3919 (class 0 OID 89555)
-- Dependencies: 219
-- Data for Name: ai_ariza_tespit; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ai_ariza_tespit (tespit_id, makine_id, form_id, madde_id, tahmin_edilen_ariza, risk_skoru, tespit_tarihi, model_versiyon, tahmini_durus_suresi, tahmini_maliyet) FROM stdin;
\.


--
-- TOC entry 3921 (class 0 OID 89562)
-- Dependencies: 221
-- Data for Name: ai_model_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ai_model_log (log_id, makine_id, model_versiyon, kullanilan_veri_sayisi, tahmin_risk, tahmin_tarihi, kullanici_id, form_id) FROM stdin;
\.


--
-- TOC entry 3923 (class 0 OID 89569)
-- Dependencies: 223
-- Data for Name: ariza_kaydi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ariza_kaydi (ariza_id, makine_id, ariza_tespit_kaynagi, ariza_aciklama, baslangic_zamani, bitis_zamani, olusturma_tarihi, ariza_tur_id, makine_adi) FROM stdin;
\.


--
-- TOC entry 3959 (class 0 OID 89714)
-- Dependencies: 259
-- Data for Name: ariza_turu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ariza_turu (ariza_tur_id, ariza_tur) FROM stdin;
1	MEKANİK ARIZA
\.


--
-- TOC entry 3925 (class 0 OID 89578)
-- Dependencies: 225
-- Data for Name: arizayi_tetikleyen_form; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.arizayi_tetikleyen_form (tetik_id, ariza_id, form_id, madde_id, tetikleyici_deger, sapma_orani, ai_tespit_mi, tespit_tarihi, aciklama) FROM stdin;
\.


--
-- TOC entry 3927 (class 0 OID 89587)
-- Dependencies: 227
-- Data for Name: bakim_kaydi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bakim_kaydi (bakim_id, makine_id, sorumlu_id, servis_firma_id, bakim_tarihi, bakim_maliyet, aciklama, ariza_id, bakim_tur_id, durus_suresi, kullanici_id, durum) FROM stdin;
\.


--
-- TOC entry 3973 (class 0 OID 89770)
-- Dependencies: 273
-- Data for Name: bakim_turu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bakim_turu (bakim_tur_id, bakim_tur_adi) FROM stdin;
11	GENEL BAKIM
\.


--
-- TOC entry 3990 (class 0 OID 105992)
-- Dependencies: 300
-- Data for Name: durus_kaydi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.durus_kaydi (durus_id, makine_id, vardiya_tarihi, baslangic_saati, bitis_saati, durus_sure_dk, durus_nedeni, olusturma_tarihi, kullanici_id) FROM stdin;
1	6	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:47:00+00	47	Ayar	2026-04-29 13:06:28.788+00	\N
2	6	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:28.824+00	\N
3	6	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:28.838+00	\N
4	6	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:28.851+00	\N
5	6	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:28.865+00	\N
6	6	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:28.879+00	\N
7	6	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:28.894+00	\N
8	6	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:32:00+00	32	Parça Bekleme	2026-04-29 13:06:28.909+00	\N
9	6	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:28.92+00	\N
10	6	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:06:28.93+00	\N
11	6	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:45:00+00	45	Ayar	2026-04-29 13:06:28.939+00	\N
12	6	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:49:00+00	49	Ayar	2026-04-29 13:06:28.95+00	\N
13	6	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:59:00+00	59	Ayar	2026-04-29 13:06:28.974+00	\N
14	6	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:28.987+00	\N
15	6	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:36:00+00	36	Ayar	2026-04-29 13:06:29+00	\N
16	6	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:06:29.012+00	\N
17	6	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:50:00+00	50	Ayar	2026-04-29 13:06:29.028+00	\N
18	6	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:06:29.04+00	\N
19	6	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:59:00+00	59	Parça Bekleme	2026-04-29 13:06:29.051+00	\N
20	6	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:16:00+00	16	Ayar	2026-04-29 13:06:29.063+00	\N
21	6	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:22:00+00	22	Parça Bekleme	2026-04-29 13:06:29.075+00	\N
22	6	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:02:00+00	2	Mekanik Arıza	2026-04-29 13:06:29.089+00	\N
23	6	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:06:29.103+00	\N
24	6	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:29:00+00	29	Ayar	2026-04-29 13:06:29.123+00	\N
25	6	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:29.144+00	\N
26	6	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:29.158+00	\N
27	6	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:29.174+00	\N
28	6	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:46:00+00	46	Ayar	2026-04-29 13:06:29.188+00	\N
29	6	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:34:00+00	34	Ayar	2026-04-29 13:06:29.201+00	\N
30	6	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:49:00+00	49	Ayar	2026-04-29 13:06:29.22+00	\N
31	7	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:29.24+00	\N
32	7	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:29.253+00	\N
33	7	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:29.266+00	\N
34	7	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:46:00+00	46	Ayar	2026-04-29 13:06:29.279+00	\N
35	7	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:29.293+00	\N
36	7	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:29.305+00	\N
37	7	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:29.318+00	\N
38	7	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:10:00+00	10	Ayar	2026-04-29 13:06:29.332+00	\N
39	7	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:32:00+00	32	Ayar	2026-04-29 13:06:29.346+00	\N
40	7	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:29.36+00	\N
41	7	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:29.373+00	\N
42	7	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:29.386+00	\N
43	7	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:27:00+00	27	Ayar	2026-04-29 13:06:29.398+00	\N
44	7	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:29.411+00	\N
45	7	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:48:00+00	48	Ayar	2026-04-29 13:06:29.424+00	\N
46	7	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:15:00+00	15	Ayar	2026-04-29 13:06:29.438+00	\N
47	7	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:29.451+00	\N
48	7	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:29.463+00	\N
49	7	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:29.476+00	\N
50	7	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:29.491+00	\N
51	7	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:19:00+00	19	Mekanik Arıza	2026-04-29 13:06:29.508+00	\N
52	7	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:29.524+00	\N
53	7	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:29.541+00	\N
54	7	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:07:00+00	7	Ayar	2026-04-29 13:06:29.555+00	\N
55	7	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:26:00+00	26	Ayar	2026-04-29 13:06:29.567+00	\N
56	7	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:29.588+00	\N
57	7	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:29.608+00	\N
58	7	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:06:00+00	6	Ayar	2026-04-29 13:06:29.626+00	\N
59	7	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:29.642+00	\N
60	7	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:29.657+00	\N
61	8	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:29.669+00	\N
62	8	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:29.684+00	\N
63	8	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:29.7+00	\N
64	8	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:29.714+00	\N
65	8	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:29.728+00	\N
66	8	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:29.743+00	\N
67	8	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:29.757+00	\N
68	8	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:29.775+00	\N
69	8	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:29.791+00	\N
70	8	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:29.806+00	\N
71	8	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:29.821+00	\N
72	8	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:36:00+00	36	Ayar	2026-04-29 13:06:29.839+00	\N
73	8	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:29.853+00	\N
74	8	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:29.874+00	\N
75	8	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:29.895+00	\N
76	8	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:29.916+00	\N
77	8	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:29.939+00	\N
78	8	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 06:00:00+00	60	Parça Bekleme	2026-04-29 13:06:29.96+00	\N
79	8	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:32:00+00	32	Ayar	2026-04-29 13:06:29.978+00	\N
80	8	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:29.998+00	\N
81	8	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:34:00+00	34	Parça Bekleme	2026-04-29 13:06:30.016+00	\N
82	8	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:30.033+00	\N
83	8	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:30.05+00	\N
84	8	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:03:00+00	3	Ayar	2026-04-29 13:06:30.068+00	\N
85	8	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:30.098+00	\N
86	8	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:30.113+00	\N
87	8	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:30.131+00	\N
88	8	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:30.149+00	\N
89	8	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:49:00+00	49	Ayar	2026-04-29 13:06:30.178+00	\N
90	8	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:30.194+00	\N
91	9	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:30.21+00	\N
92	9	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:30.229+00	\N
93	9	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:02:00+00	2	Mekanik Arıza	2026-04-29 13:06:30.248+00	\N
94	9	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:57:00+00	57	Ayar	2026-04-29 13:06:30.265+00	\N
95	9	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:30.277+00	\N
96	9	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:30.293+00	\N
97	9	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:02:00+00	2	Ayar	2026-04-29 13:06:30.313+00	\N
98	9	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:30.335+00	\N
99	9	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:30.356+00	\N
100	9	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:19:00+00	19	Parça Bekleme	2026-04-29 13:06:30.377+00	\N
101	9	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:30.397+00	\N
102	9	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:30.417+00	\N
103	9	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:30.436+00	\N
104	9	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:30.467+00	\N
105	9	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:30.485+00	\N
106	9	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:30.502+00	\N
107	9	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:30.52+00	\N
108	9	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:30:00+00	30	Ayar	2026-04-29 13:06:30.545+00	\N
109	9	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:25:00+00	25	Parça Bekleme	2026-04-29 13:06:30.563+00	\N
110	9	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:30.579+00	\N
111	9	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:30.595+00	\N
112	9	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:30.612+00	\N
113	9	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:30.63+00	\N
114	9	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:44:00+00	44	Ayar	2026-04-29 13:06:30.647+00	\N
115	9	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:30.665+00	\N
116	9	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:20:00+00	20	Ayar	2026-04-29 13:06:30.682+00	\N
117	9	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:30.699+00	\N
118	9	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:23:00+00	23	Ayar	2026-04-29 13:06:30.717+00	\N
119	9	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:15:00+00	15	Ayar	2026-04-29 13:06:30.735+00	\N
120	10	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:30.753+00	\N
121	10	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:30.769+00	\N
122	10	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:30.784+00	\N
123	10	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:30.799+00	\N
124	10	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:24:00+00	24	Ayar	2026-04-29 13:06:30.816+00	\N
125	10	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:35:00+00	35	Ayar	2026-04-29 13:06:30.831+00	\N
126	10	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:47:00+00	47	Ayar	2026-04-29 13:06:30.847+00	\N
127	10	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:30.862+00	\N
128	10	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:40:00+00	40	Parça Bekleme	2026-04-29 13:06:30.88+00	\N
129	10	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 06:00:00+00	60	Ayar	2026-04-29 13:06:30.895+00	\N
130	10	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:04:00+00	4	Ayar	2026-04-29 13:06:30.912+00	\N
131	10	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:30.929+00	\N
132	10	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:30.945+00	\N
133	10	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:52:00+00	52	Parça Bekleme	2026-04-29 13:06:30.96+00	\N
134	10	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:30.976+00	\N
135	10	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:19:00+00	19	Ayar	2026-04-29 13:06:30.993+00	\N
136	10	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:31.009+00	\N
137	10	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:31.024+00	\N
138	10	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:06:31.039+00	\N
139	10	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:09:00+00	9	Ayar	2026-04-29 13:06:31.054+00	\N
140	10	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:31.073+00	\N
141	10	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:31.09+00	\N
142	10	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:11:00+00	11	Mekanik Arıza	2026-04-29 13:06:31.107+00	\N
143	10	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:19:00+00	19	Parça Bekleme	2026-04-29 13:06:31.124+00	\N
144	10	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:54:00+00	54	Ayar	2026-04-29 13:06:31.14+00	\N
145	10	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:08:00+00	8	Ayar	2026-04-29 13:06:31.158+00	\N
146	10	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:09:00+00	9	Ayar	2026-04-29 13:06:31.176+00	\N
147	10	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:31.191+00	\N
148	10	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:31.207+00	\N
149	10	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:31.224+00	\N
150	11	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:31.242+00	\N
151	11	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:31.258+00	\N
152	11	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:31.273+00	\N
153	11	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:31.289+00	\N
154	11	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:31.312+00	\N
155	11	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:31.325+00	\N
156	11	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:31.341+00	\N
157	11	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:31.355+00	\N
158	11	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:24:00+00	24	Ayar	2026-04-29 13:06:31.379+00	\N
159	11	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:15:00+00	15	Ayar	2026-04-29 13:06:31.394+00	\N
160	11	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:31.41+00	\N
161	11	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:31.428+00	\N
162	11	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:06:31.444+00	\N
163	11	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:28:00+00	28	Ayar	2026-04-29 13:06:31.46+00	\N
164	11	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:50:00+00	50	Ayar	2026-04-29 13:06:31.477+00	\N
165	11	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:51:00+00	51	Ayar	2026-04-29 13:06:31.494+00	\N
166	11	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:46:00+00	46	Ayar	2026-04-29 13:06:31.509+00	\N
167	11	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:24:00+00	24	Ayar	2026-04-29 13:06:31.526+00	\N
168	11	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:12:00+00	12	Ayar	2026-04-29 13:06:31.544+00	\N
169	11	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:31.562+00	\N
170	11	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:31.577+00	\N
171	11	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:31.594+00	\N
172	11	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:15:00+00	15	Parça Bekleme	2026-04-29 13:06:31.612+00	\N
173	11	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:31.628+00	\N
174	11	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:31.642+00	\N
175	11	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:25:00+00	25	Ayar	2026-04-29 13:06:31.658+00	\N
176	11	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:30:00+00	30	Ayar	2026-04-29 13:06:31.673+00	\N
177	11	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:32:00+00	32	Parça Bekleme	2026-04-29 13:06:31.688+00	\N
178	11	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:04:00+00	4	Ayar	2026-04-29 13:06:31.703+00	\N
179	11	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:31.716+00	\N
180	12	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:55:00+00	55	Ayar	2026-04-29 13:06:31.73+00	\N
181	12	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:31.746+00	\N
182	12	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:31.76+00	\N
183	12	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:26:00+00	26	Ayar	2026-04-29 13:06:31.773+00	\N
184	12	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:31.786+00	\N
185	12	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:31.799+00	\N
186	12	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:31.813+00	\N
187	12	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:06:31.825+00	\N
188	12	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:28:00+00	28	Ayar	2026-04-29 13:06:31.838+00	\N
189	12	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:06:00+00	6	Ayar	2026-04-29 13:06:31.852+00	\N
190	12	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:31.865+00	\N
191	12	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:31.878+00	\N
192	12	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:31.89+00	\N
193	12	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:31.904+00	\N
194	12	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:31.918+00	\N
195	12	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:47:00+00	47	Ayar	2026-04-29 13:06:31.932+00	\N
196	12	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:27:00+00	27	Ayar	2026-04-29 13:06:31.947+00	\N
197	12	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:06:31.963+00	\N
198	12	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:31:00+00	31	Ayar	2026-04-29 13:06:31.976+00	\N
199	12	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:31.991+00	\N
200	12	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:32.007+00	\N
201	12	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:07:00+00	7	Ayar	2026-04-29 13:06:32.022+00	\N
202	12	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:32.039+00	\N
203	12	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:32.056+00	\N
204	12	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:32.071+00	\N
205	12	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:13:00+00	13	Ayar	2026-04-29 13:06:32.086+00	\N
206	12	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:32.1+00	\N
207	12	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:06:32.114+00	\N
208	12	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:11:00+00	11	Ayar	2026-04-29 13:06:32.127+00	\N
209	12	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:32.141+00	\N
210	13	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:32.154+00	\N
211	13	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:29:00+00	29	Ayar	2026-04-29 13:06:32.166+00	\N
212	13	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:13:00+00	13	Parça Bekleme	2026-04-29 13:06:32.179+00	\N
213	13	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:06:00+00	6	Ayar	2026-04-29 13:06:32.192+00	\N
214	13	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:32.204+00	\N
215	13	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:28:00+00	28	Ayar	2026-04-29 13:06:32.217+00	\N
216	13	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:35:00+00	35	Ayar	2026-04-29 13:06:32.23+00	\N
217	13	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:32.242+00	\N
218	13	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:44:00+00	44	Ayar	2026-04-29 13:06:32.255+00	\N
219	13	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:32.267+00	\N
220	13	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:38:00+00	38	Parça Bekleme	2026-04-29 13:06:32.278+00	\N
221	13	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:36:00+00	36	Ayar	2026-04-29 13:06:32.291+00	\N
222	13	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:32.304+00	\N
223	13	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:25:00+00	25	Ayar	2026-04-29 13:06:32.318+00	\N
224	13	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:15:00+00	15	Parça Bekleme	2026-04-29 13:06:32.332+00	\N
225	13	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:32.345+00	\N
226	13	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:32.357+00	\N
227	13	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:11:00+00	11	Ayar	2026-04-29 13:06:32.373+00	\N
228	13	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:56:00+00	56	Ayar	2026-04-29 13:06:32.387+00	\N
229	13	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:17:00+00	17	Ayar	2026-04-29 13:06:32.402+00	\N
230	13	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:32.418+00	\N
231	13	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:34:00+00	34	Ayar	2026-04-29 13:06:32.434+00	\N
232	13	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:32.45+00	\N
233	13	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:32.465+00	\N
234	13	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:44:00+00	44	Ayar	2026-04-29 13:06:32.482+00	\N
235	13	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:06:32.498+00	\N
236	13	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:32.525+00	\N
237	13	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:13:00+00	13	Ayar	2026-04-29 13:06:32.541+00	\N
238	13	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:46:00+00	46	Ayar	2026-04-29 13:06:32.557+00	\N
239	14	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:47:00+00	47	Ayar	2026-04-29 13:06:32.571+00	\N
240	14	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:32.581+00	\N
241	14	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:44:00+00	44	Ayar	2026-04-29 13:06:32.593+00	\N
242	14	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:31:00+00	31	Ayar	2026-04-29 13:06:32.608+00	\N
243	14	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:32.624+00	\N
244	14	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:32.64+00	\N
245	14	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:15:00+00	15	Ayar	2026-04-29 13:06:32.656+00	\N
246	14	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:32.672+00	\N
247	14	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:52:00+00	52	Parça Bekleme	2026-04-29 13:06:32.688+00	\N
248	14	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:36:00+00	36	Ayar	2026-04-29 13:06:32.7+00	\N
249	14	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:08:00+00	8	Ayar	2026-04-29 13:06:32.711+00	\N
250	14	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:17:00+00	17	Ayar	2026-04-29 13:06:32.725+00	\N
251	14	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:32.739+00	\N
252	14	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:06:00+00	6	Ayar	2026-04-29 13:06:32.753+00	\N
253	14	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:32.769+00	\N
254	14	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:57:00+00	57	Ayar	2026-04-29 13:06:32.783+00	\N
255	14	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:19:00+00	19	Mekanik Arıza	2026-04-29 13:06:32.796+00	\N
256	14	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:32.81+00	\N
257	14	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:41:00+00	41	Ayar	2026-04-29 13:06:32.824+00	\N
258	14	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:06:32.838+00	\N
259	14	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:50:00+00	50	Ayar	2026-04-29 13:06:32.854+00	\N
260	14	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:32.87+00	\N
261	14	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:32.887+00	\N
262	14	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:41:00+00	41	Ayar	2026-04-29 13:06:32.907+00	\N
263	14	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:32.923+00	\N
264	14	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:38:00+00	38	Parça Bekleme	2026-04-29 13:06:32.937+00	\N
265	14	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:32.952+00	\N
266	14	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:36:00+00	36	Ayar	2026-04-29 13:06:32.969+00	\N
267	14	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:32.984+00	\N
268	14	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:33+00	\N
269	15	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:33.021+00	\N
270	15	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:59:00+00	59	Ayar	2026-04-29 13:06:33.036+00	\N
271	15	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:33.053+00	\N
272	15	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:33.07+00	\N
273	15	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:01:00+00	1	Ayar	2026-04-29 13:06:33.088+00	\N
274	15	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:33.108+00	\N
275	15	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:33.125+00	\N
276	15	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:33.143+00	\N
277	15	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:56:00+00	56	Mekanik Arıza	2026-04-29 13:06:33.16+00	\N
278	15	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:06:33.186+00	\N
279	15	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:33.202+00	\N
280	15	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:33.218+00	\N
281	15	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:55:00+00	55	Ayar	2026-04-29 13:06:33.232+00	\N
282	15	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:17:00+00	17	Ayar	2026-04-29 13:06:33.247+00	\N
283	15	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:33.261+00	\N
284	15	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:26:00+00	26	Ayar	2026-04-29 13:06:33.274+00	\N
285	15	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:33.288+00	\N
286	15	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:33.301+00	\N
287	15	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:17:00+00	17	Ayar	2026-04-29 13:06:33.314+00	\N
288	15	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:04:00+00	4	Ayar	2026-04-29 13:06:33.327+00	\N
289	15	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:33.34+00	\N
290	15	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:33.352+00	\N
291	15	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:33.364+00	\N
292	15	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:33.375+00	\N
293	15	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:06:33.387+00	\N
294	15	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:33.399+00	\N
295	15	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:06:33.41+00	\N
296	15	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 06:00:00+00	60	Ayar	2026-04-29 13:06:33.423+00	\N
297	15	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:33.434+00	\N
298	16	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:19:00+00	19	Ayar	2026-04-29 13:06:33.448+00	\N
299	16	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:33.469+00	\N
300	16	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:06:00+00	6	Ayar	2026-04-29 13:06:33.484+00	\N
301	16	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:33.499+00	\N
302	16	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:58:00+00	58	Ayar	2026-04-29 13:06:33.512+00	\N
303	16	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 06:00:00+00	60	Parça Bekleme	2026-04-29 13:06:33.526+00	\N
304	16	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:33.539+00	\N
305	16	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:33.552+00	\N
306	16	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:31:00+00	31	Ayar	2026-04-29 13:06:33.566+00	\N
307	16	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:33.58+00	\N
308	16	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:29:00+00	29	Ayar	2026-04-29 13:06:33.596+00	\N
309	16	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:27:00+00	27	Ayar	2026-04-29 13:06:33.611+00	\N
310	16	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:33.626+00	\N
311	16	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:33.64+00	\N
312	16	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:33.657+00	\N
313	16	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:59:00+00	59	Ayar	2026-04-29 13:06:33.719+00	\N
314	16	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:44:00+00	44	Ayar	2026-04-29 13:06:33.737+00	\N
315	16	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:33.748+00	\N
316	16	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:33.761+00	\N
317	16	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:33.773+00	\N
318	16	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:19:00+00	19	Ayar	2026-04-29 13:06:33.788+00	\N
319	16	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:33:00+00	33	Ayar	2026-04-29 13:06:33.803+00	\N
320	16	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:23:00+00	23	Ayar	2026-04-29 13:06:33.817+00	\N
321	16	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:31:00+00	31	Ayar	2026-04-29 13:06:33.831+00	\N
322	16	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:33.847+00	\N
323	16	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:33.861+00	\N
324	16	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:33.875+00	\N
325	16	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:33.891+00	\N
326	17	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:50:00+00	50	Ayar	2026-04-29 13:06:33.915+00	\N
327	17	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:33.928+00	\N
328	17	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:50:00+00	50	Ayar	2026-04-29 13:06:33.941+00	\N
329	17	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:33.957+00	\N
330	17	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:33.973+00	\N
331	17	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:11:00+00	11	Ayar	2026-04-29 13:06:33.988+00	\N
332	17	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:28:00+00	28	Ayar	2026-04-29 13:06:34.004+00	\N
333	17	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:12:00+00	12	Ayar	2026-04-29 13:06:34.02+00	\N
334	17	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:33:00+00	33	Ayar	2026-04-29 13:06:34.035+00	\N
335	17	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:34.049+00	\N
336	17	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:34.064+00	\N
337	17	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:15:00+00	15	Parça Bekleme	2026-04-29 13:06:34.08+00	\N
338	17	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:34.097+00	\N
339	17	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:18:00+00	18	Ayar	2026-04-29 13:06:34.112+00	\N
340	17	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:49:00+00	49	Ayar	2026-04-29 13:06:34.127+00	\N
341	17	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:40:00+00	40	Parça Bekleme	2026-04-29 13:06:34.141+00	\N
342	17	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:35:00+00	35	Ayar	2026-04-29 13:06:34.154+00	\N
343	17	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:40:00+00	40	Ayar	2026-04-29 13:06:34.168+00	\N
344	17	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:34.182+00	\N
345	17	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:34.204+00	\N
346	17	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:26:00+00	26	Ayar	2026-04-29 13:06:34.218+00	\N
347	17	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:34.229+00	\N
348	17	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:34.242+00	\N
349	17	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:34.256+00	\N
350	17	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:34.271+00	\N
351	17	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:34.286+00	\N
352	17	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:34.301+00	\N
353	17	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:06:34.316+00	\N
354	17	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:06:00+00	6	Ayar	2026-04-29 13:06:34.331+00	\N
355	18	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:50:00+00	50	Ayar	2026-04-29 13:06:34.346+00	\N
356	18	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:34.368+00	\N
357	18	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:27:00+00	27	Ayar	2026-04-29 13:06:34.383+00	\N
358	18	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:34.397+00	\N
359	18	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:06:34.413+00	\N
360	18	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:34.428+00	\N
361	18	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:31:00+00	31	Parça Bekleme	2026-04-29 13:06:34.444+00	\N
362	18	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:56:00+00	56	Mekanik Arıza	2026-04-29 13:06:34.458+00	\N
363	18	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:22:00+00	22	Parça Bekleme	2026-04-29 13:06:34.472+00	\N
364	18	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:34.485+00	\N
365	18	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:34:00+00	34	Parça Bekleme	2026-04-29 13:06:34.498+00	\N
366	18	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:34.515+00	\N
367	18	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:34.527+00	\N
368	18	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:41:00+00	41	Ayar	2026-04-29 13:06:34.54+00	\N
369	18	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:40:00+00	40	Parça Bekleme	2026-04-29 13:06:34.549+00	\N
370	18	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:34.56+00	\N
371	18	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:24:00+00	24	Ayar	2026-04-29 13:06:34.569+00	\N
372	18	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:22:00+00	22	Parça Bekleme	2026-04-29 13:06:34.579+00	\N
373	18	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:34.589+00	\N
374	18	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:59:00+00	59	Parça Bekleme	2026-04-29 13:06:34.599+00	\N
375	18	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:13:00+00	13	Parça Bekleme	2026-04-29 13:06:34.621+00	\N
376	18	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:15:00+00	15	Ayar	2026-04-29 13:06:34.636+00	\N
377	18	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:11:00+00	11	Ayar	2026-04-29 13:06:34.652+00	\N
378	18	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:34.667+00	\N
379	18	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:34.681+00	\N
380	18	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:34.694+00	\N
381	18	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:45:00+00	45	Ayar	2026-04-29 13:06:34.711+00	\N
382	18	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:01:00+00	1	Parça Bekleme	2026-04-29 13:06:34.727+00	\N
383	19	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:06:34.742+00	\N
384	19	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:29:00+00	29	Ayar	2026-04-29 13:06:34.76+00	\N
385	19	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:34.777+00	\N
386	19	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:23:00+00	23	Ayar	2026-04-29 13:06:34.791+00	\N
387	19	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:34.804+00	\N
388	19	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:20:00+00	20	Parça Bekleme	2026-04-29 13:06:34.813+00	\N
389	19	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:34.823+00	\N
390	19	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:56:00+00	56	Mekanik Arıza	2026-04-29 13:06:34.833+00	\N
391	19	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:30:00+00	30	Ayar	2026-04-29 13:06:34.846+00	\N
392	19	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:34.869+00	\N
393	19	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:34.887+00	\N
394	19	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:21:00+00	21	Ayar	2026-04-29 13:06:34.905+00	\N
395	19	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:34.922+00	\N
396	19	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:34.937+00	\N
397	19	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:20:00+00	20	Ayar	2026-04-29 13:06:34.95+00	\N
398	19	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:34.959+00	\N
399	19	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:34.971+00	\N
400	19	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:53:00+00	53	Ayar	2026-04-29 13:06:34.983+00	\N
401	19	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:31:00+00	31	Ayar	2026-04-29 13:06:34.996+00	\N
402	19	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:38:00+00	38	Mekanik Arıza	2026-04-29 13:06:35.009+00	\N
403	19	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:35.025+00	\N
404	19	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:35.042+00	\N
405	19	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:23:00+00	23	Ayar	2026-04-29 13:06:35.058+00	\N
406	19	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:35.087+00	\N
407	19	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:35.106+00	\N
408	19	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:31:00+00	31	Ayar	2026-04-29 13:06:35.12+00	\N
409	19	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:34:00+00	34	Parça Bekleme	2026-04-29 13:06:35.135+00	\N
410	19	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:35.152+00	\N
411	20	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:35.17+00	\N
412	20	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:15:00+00	15	Ayar	2026-04-29 13:06:35.187+00	\N
413	20	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:35.204+00	\N
414	20	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:40:00+00	40	Ayar	2026-04-29 13:06:35.218+00	\N
415	20	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:35.236+00	\N
416	20	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:12:00+00	12	Ayar	2026-04-29 13:06:35.255+00	\N
417	20	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:35.273+00	\N
418	20	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:35.289+00	\N
419	20	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:35.307+00	\N
420	20	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:23:00+00	23	Ayar	2026-04-29 13:06:35.325+00	\N
421	20	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:35.338+00	\N
422	20	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:13:00+00	13	Ayar	2026-04-29 13:06:35.348+00	\N
423	20	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:35.362+00	\N
424	20	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:06:35.377+00	\N
425	20	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:35.392+00	\N
426	20	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:35.407+00	\N
427	20	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:54:00+00	54	Ayar	2026-04-29 13:06:35.421+00	\N
428	20	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:06:35.437+00	\N
429	20	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:06:35.45+00	\N
430	20	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:35.46+00	\N
431	20	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:02:00+00	2	Ayar	2026-04-29 13:06:35.469+00	\N
432	20	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:35.479+00	\N
433	20	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:35.492+00	\N
434	20	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:09:00+00	9	Ayar	2026-04-29 13:06:35.504+00	\N
435	20	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:35.516+00	\N
436	20	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:31:00+00	31	Ayar	2026-04-29 13:06:35.53+00	\N
437	20	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:58:00+00	58	Ayar	2026-04-29 13:06:35.545+00	\N
438	20	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 06:00:00+00	60	Parça Bekleme	2026-04-29 13:06:35.559+00	\N
439	20	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:35.573+00	\N
440	20	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:35.585+00	\N
441	21	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:54:00+00	54	Ayar	2026-04-29 13:06:35.597+00	\N
442	21	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:35.612+00	\N
443	21	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:35.627+00	\N
444	21	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:22:00+00	22	Parça Bekleme	2026-04-29 13:06:35.653+00	\N
445	21	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:35.669+00	\N
446	21	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:01:00+00	1	Parça Bekleme	2026-04-29 13:06:35.683+00	\N
447	21	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:35.696+00	\N
448	21	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:09:00+00	9	Ayar	2026-04-29 13:06:35.709+00	\N
449	21	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:35.717+00	\N
450	21	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:35.726+00	\N
451	21	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:35.734+00	\N
452	21	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:47:00+00	47	Ayar	2026-04-29 13:06:35.744+00	\N
453	21	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:19:00+00	19	Mekanik Arıza	2026-04-29 13:06:35.755+00	\N
454	21	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:35.768+00	\N
455	21	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:53:00+00	53	Ayar	2026-04-29 13:06:35.784+00	\N
456	21	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:36:00+00	36	Ayar	2026-04-29 13:06:35.81+00	\N
457	21	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:34:00+00	34	Ayar	2026-04-29 13:06:35.826+00	\N
458	21	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:35.843+00	\N
459	21	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:48:00+00	48	Ayar	2026-04-29 13:06:35.861+00	\N
460	21	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:35.881+00	\N
461	21	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:35.897+00	\N
462	21	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:14:00+00	14	Ayar	2026-04-29 13:06:35.908+00	\N
463	21	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:06:35.916+00	\N
464	21	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:06:35.925+00	\N
465	21	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:06:35.934+00	\N
466	21	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:35.943+00	\N
467	21	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:35.954+00	\N
468	21	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:35.967+00	\N
469	22	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:35:00+00	35	Ayar	2026-04-29 13:06:35.984+00	\N
470	22	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:06:36+00	\N
471	22	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:36.016+00	\N
472	22	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:43:00+00	43	Ayar	2026-04-29 13:06:36.033+00	\N
473	22	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:47:00+00	47	Ayar	2026-04-29 13:06:36.05+00	\N
474	22	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:36.063+00	\N
475	22	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:38:00+00	38	Ayar	2026-04-29 13:06:36.073+00	\N
476	22	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:36.082+00	\N
477	22	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:36.091+00	\N
478	22	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:36.102+00	\N
479	22	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:39:00+00	39	Ayar	2026-04-29 13:06:36.116+00	\N
480	22	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:25:00+00	25	Ayar	2026-04-29 13:06:36.133+00	\N
481	22	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:07:00+00	7	Ayar	2026-04-29 13:06:36.15+00	\N
482	22	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:36.169+00	\N
483	22	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:56:00+00	56	Mekanik Arıza	2026-04-29 13:06:36.189+00	\N
484	22	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:30:00+00	30	Ayar	2026-04-29 13:06:36.202+00	\N
485	22	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:44:00+00	44	Ayar	2026-04-29 13:06:36.215+00	\N
486	22	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:36.224+00	\N
487	22	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:36.233+00	\N
488	22	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:32:00+00	32	Ayar	2026-04-29 13:06:36.243+00	\N
489	22	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:43:00+00	43	Ayar	2026-04-29 13:06:36.254+00	\N
490	22	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:23:00+00	23	Ayar	2026-04-29 13:06:36.266+00	\N
491	22	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:36.282+00	\N
492	22	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:06:36.298+00	\N
493	22	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:23:00+00	23	Ayar	2026-04-29 13:06:36.315+00	\N
494	22	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:52:00+00	52	Parça Bekleme	2026-04-29 13:06:36.331+00	\N
495	22	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:49:00+00	49	Parça Bekleme	2026-04-29 13:06:36.344+00	\N
496	22	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:10:00+00	10	Ayar	2026-04-29 13:06:36.358+00	\N
497	22	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:36.373+00	\N
498	22	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:36.388+00	\N
499	23	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:36.403+00	\N
500	23	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:36.416+00	\N
501	23	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:59:00+00	59	Parça Bekleme	2026-04-29 13:06:36.428+00	\N
502	23	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:44:00+00	44	Ayar	2026-04-29 13:06:36.441+00	\N
503	23	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:31:00+00	31	Ayar	2026-04-29 13:06:36.455+00	\N
504	23	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:36.468+00	\N
505	23	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:36.481+00	\N
506	23	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:31:00+00	31	Mekanik Arıza	2026-04-29 13:06:36.5+00	\N
507	23	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:17:00+00	17	Ayar	2026-04-29 13:06:36.517+00	\N
508	23	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:36.531+00	\N
509	23	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:36.543+00	\N
510	23	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:36.556+00	\N
511	23	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:36.57+00	\N
512	23	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:09:00+00	9	Ayar	2026-04-29 13:06:36.587+00	\N
513	23	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:36.603+00	\N
514	23	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:36.618+00	\N
515	23	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:36.633+00	\N
516	23	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:43:00+00	43	Ayar	2026-04-29 13:06:36.649+00	\N
517	23	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:18:00+00	18	Ayar	2026-04-29 13:06:36.66+00	\N
518	23	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:36.67+00	\N
519	23	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:53:00+00	53	Ayar	2026-04-29 13:06:36.684+00	\N
520	23	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:36.698+00	\N
521	23	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:36.713+00	\N
522	23	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:36.78+00	\N
523	23	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:36.792+00	\N
524	23	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:24:00+00	24	Ayar	2026-04-29 13:06:36.803+00	\N
525	23	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:36.816+00	\N
526	23	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:36.827+00	\N
527	23	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:36.839+00	\N
528	23	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:06:36.852+00	\N
529	24	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:36.866+00	\N
530	24	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:52:00+00	52	Ayar	2026-04-29 13:06:36.882+00	\N
531	24	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:36.901+00	\N
532	24	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:36.922+00	\N
533	24	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:36.942+00	\N
534	24	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:36.962+00	\N
535	24	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:36.98+00	\N
536	24	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:30:00+00	30	Ayar	2026-04-29 13:06:36.997+00	\N
537	24	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:37.016+00	\N
538	24	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:37.034+00	\N
539	24	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:37.054+00	\N
540	24	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:37.074+00	\N
541	24	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:36:00+00	36	Ayar	2026-04-29 13:06:37.092+00	\N
542	24	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:57:00+00	57	Ayar	2026-04-29 13:06:37.109+00	\N
543	24	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:25:00+00	25	Parça Bekleme	2026-04-29 13:06:37.128+00	\N
544	24	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:45:00+00	45	Ayar	2026-04-29 13:06:37.147+00	\N
545	24	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:37.167+00	\N
546	24	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:37.184+00	\N
547	24	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:37.198+00	\N
548	24	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:37.209+00	\N
549	24	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:59:00+00	59	Ayar	2026-04-29 13:06:37.228+00	\N
550	24	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:20:00+00	20	Ayar	2026-04-29 13:06:37.247+00	\N
551	24	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:06:37.266+00	\N
552	24	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:37.285+00	\N
553	24	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:07:00+00	7	Ayar	2026-04-29 13:06:37.302+00	\N
554	24	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:37.332+00	\N
555	24	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:31:00+00	31	Ayar	2026-04-29 13:06:37.341+00	\N
556	24	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:37.35+00	\N
557	24	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:37.371+00	\N
558	25	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:37.389+00	\N
559	25	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:17:00+00	17	Ayar	2026-04-29 13:06:37.407+00	\N
560	25	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:37.426+00	\N
561	25	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 06:00:00+00	60	Ayar	2026-04-29 13:06:37.445+00	\N
562	25	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:37.458+00	\N
563	25	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:37.47+00	\N
564	25	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:37.48+00	\N
565	25	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:19:00+00	19	Mekanik Arıza	2026-04-29 13:06:37.494+00	\N
566	25	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:37.502+00	\N
567	25	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:37.515+00	\N
568	25	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:31:00+00	31	Mekanik Arıza	2026-04-29 13:06:37.531+00	\N
569	25	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:37.547+00	\N
570	25	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:43:00+00	43	Ayar	2026-04-29 13:06:37.564+00	\N
571	25	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:37.582+00	\N
572	25	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:37.6+00	\N
573	25	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:38:00+00	38	Ayar	2026-04-29 13:06:37.615+00	\N
574	25	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:37.629+00	\N
575	25	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:06:37.641+00	\N
576	25	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:02:00+00	2	Mekanik Arıza	2026-04-29 13:06:37.652+00	\N
577	25	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:06:37.665+00	\N
578	25	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:37.68+00	\N
579	25	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:37.695+00	\N
580	25	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:56:00+00	56	Mekanik Arıza	2026-04-29 13:06:37.71+00	\N
581	25	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:04:00+00	4	Ayar	2026-04-29 13:06:37.724+00	\N
582	25	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:06:37.736+00	\N
583	25	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:50:00+00	50	Ayar	2026-04-29 13:06:37.748+00	\N
584	25	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:23:00+00	23	Ayar	2026-04-29 13:06:37.76+00	\N
585	25	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:37.774+00	\N
586	25	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:37.789+00	\N
587	26	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:37.801+00	\N
588	26	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:37.813+00	\N
589	26	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:37.825+00	\N
590	26	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:38:00+00	38	Ayar	2026-04-29 13:06:37.837+00	\N
591	26	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:37.849+00	\N
592	26	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:37.865+00	\N
593	26	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:51:00+00	51	Ayar	2026-04-29 13:06:37.878+00	\N
594	26	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:37.891+00	\N
595	26	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:17:00+00	17	Ayar	2026-04-29 13:06:37.907+00	\N
596	26	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:37.923+00	\N
597	26	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:50:00+00	50	Ayar	2026-04-29 13:06:37.939+00	\N
598	26	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:37.953+00	\N
599	26	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:06:37.972+00	\N
600	26	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:37.99+00	\N
601	26	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:38.008+00	\N
602	26	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:33:00+00	33	Ayar	2026-04-29 13:06:38.028+00	\N
603	26	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:38.046+00	\N
604	26	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:38.06+00	\N
605	26	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:22:00+00	22	Parça Bekleme	2026-04-29 13:06:38.072+00	\N
606	26	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:17:00+00	17	Ayar	2026-04-29 13:06:38.081+00	\N
607	26	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:06:38.09+00	\N
608	26	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:38.099+00	\N
609	26	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:38.11+00	\N
610	26	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:38.122+00	\N
611	26	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:38.135+00	\N
612	26	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:58:00+00	58	Ayar	2026-04-29 13:06:38.148+00	\N
613	26	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:38.161+00	\N
614	26	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:38.173+00	\N
615	26	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:39:00+00	39	Ayar	2026-04-29 13:06:38.187+00	\N
616	26	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:38.199+00	\N
617	27	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:38.211+00	\N
618	27	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:53:00+00	53	Ayar	2026-04-29 13:06:38.223+00	\N
619	27	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:11:00+00	11	Ayar	2026-04-29 13:06:38.235+00	\N
620	27	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:06:38.245+00	\N
621	27	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:48:00+00	48	Ayar	2026-04-29 13:06:38.255+00	\N
622	27	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:38.267+00	\N
623	27	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:38.279+00	\N
624	27	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:38.291+00	\N
625	27	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:47:00+00	47	Ayar	2026-04-29 13:06:38.302+00	\N
626	27	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:38.314+00	\N
627	27	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:58:00+00	58	Ayar	2026-04-29 13:06:38.326+00	\N
628	27	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:38.338+00	\N
629	27	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:06:38.351+00	\N
630	27	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:38:00+00	38	Mekanik Arıza	2026-04-29 13:06:38.361+00	\N
631	27	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:38.37+00	\N
632	27	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:34:00+00	34	Parça Bekleme	2026-04-29 13:06:38.379+00	\N
633	27	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:17:00+00	17	Ayar	2026-04-29 13:06:38.39+00	\N
634	27	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:53:00+00	53	Ayar	2026-04-29 13:06:38.4+00	\N
635	27	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:38.411+00	\N
636	27	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:38.421+00	\N
637	27	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:38.43+00	\N
638	27	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:42:00+00	42	Ayar	2026-04-29 13:06:38.44+00	\N
639	27	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:38.45+00	\N
640	27	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:38.461+00	\N
641	27	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:06:38.472+00	\N
642	27	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:05:00+00	5	Ayar	2026-04-29 13:06:38.481+00	\N
643	27	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:38.489+00	\N
644	27	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:38.498+00	\N
645	27	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:49:00+00	49	Ayar	2026-04-29 13:06:38.509+00	\N
646	27	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:38.519+00	\N
647	28	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:38.53+00	\N
648	28	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:38.544+00	\N
649	28	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:38.556+00	\N
650	28	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 06:00:00+00	60	Ayar	2026-04-29 13:06:38.565+00	\N
651	28	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:38.575+00	\N
652	28	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:38.589+00	\N
653	28	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:59:00+00	59	Ayar	2026-04-29 13:06:38.602+00	\N
654	28	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:06:38.615+00	\N
655	28	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:49:00+00	49	Ayar	2026-04-29 13:06:38.625+00	\N
656	28	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:38.635+00	\N
657	28	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:38.644+00	\N
658	28	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:38.655+00	\N
659	28	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:38.668+00	\N
660	28	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:05:00+00	5	Ayar	2026-04-29 13:06:38.683+00	\N
661	28	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:59:00+00	59	Parça Bekleme	2026-04-29 13:06:38.696+00	\N
662	28	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:28:00+00	28	Ayar	2026-04-29 13:06:38.709+00	\N
663	28	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:38.723+00	\N
664	28	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:38.739+00	\N
665	28	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:06:38.755+00	\N
666	28	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:41:00+00	41	Ayar	2026-04-29 13:06:38.766+00	\N
667	28	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:38.781+00	\N
668	28	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:06:38.801+00	\N
669	28	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:38.813+00	\N
670	28	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:38.826+00	\N
671	28	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 06:00:00+00	60	Parça Bekleme	2026-04-29 13:06:38.838+00	\N
672	28	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:39:00+00	39	Ayar	2026-04-29 13:06:38.848+00	\N
673	28	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:38.859+00	\N
674	28	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:06:00+00	6	Ayar	2026-04-29 13:06:38.87+00	\N
675	28	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:38.883+00	\N
676	28	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:38.896+00	\N
677	29	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:38.909+00	\N
678	29	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:38.924+00	\N
679	29	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:27:00+00	27	Ayar	2026-04-29 13:06:38.941+00	\N
680	29	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:59:00+00	59	Parça Bekleme	2026-04-29 13:06:38.952+00	\N
681	29	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:54:00+00	54	Ayar	2026-04-29 13:06:38.963+00	\N
682	29	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:16:00+00	16	Ayar	2026-04-29 13:06:38.975+00	\N
683	29	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:55:00+00	55	Ayar	2026-04-29 13:06:38.987+00	\N
684	29	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:42:00+00	42	Ayar	2026-04-29 13:06:38.999+00	\N
685	29	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:19:00+00	19	Mekanik Arıza	2026-04-29 13:06:39.01+00	\N
686	29	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:39.023+00	\N
687	29	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:46:00+00	46	Ayar	2026-04-29 13:06:39.037+00	\N
688	29	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:39.051+00	\N
689	29	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:39.064+00	\N
690	29	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:10:00+00	10	Ayar	2026-04-29 13:06:39.078+00	\N
691	29	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:05:00+00	5	Ayar	2026-04-29 13:06:39.093+00	\N
692	29	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:06:39.108+00	\N
693	29	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:01:00+00	1	Parça Bekleme	2026-04-29 13:06:39.122+00	\N
694	29	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:13:00+00	13	Parça Bekleme	2026-04-29 13:06:39.135+00	\N
695	29	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:22:00+00	22	Ayar	2026-04-29 13:06:39.147+00	\N
696	29	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:39.159+00	\N
697	29	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:38:00+00	38	Parça Bekleme	2026-04-29 13:06:39.169+00	\N
698	29	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:39.179+00	\N
699	29	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:04:00+00	4	Ayar	2026-04-29 13:06:39.189+00	\N
700	29	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:39.199+00	\N
701	29	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:53:00+00	53	Ayar	2026-04-29 13:06:39.209+00	\N
702	29	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:39.217+00	\N
703	29	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:55:00+00	55	Ayar	2026-04-29 13:06:39.227+00	\N
704	29	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:39.238+00	\N
705	29	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:39.249+00	\N
706	29	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:28:00+00	28	Ayar	2026-04-29 13:06:39.261+00	\N
707	30	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:39.274+00	\N
708	30	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:59:00+00	59	Parça Bekleme	2026-04-29 13:06:39.287+00	\N
709	30	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:52:00+00	52	Parça Bekleme	2026-04-29 13:06:39.299+00	\N
710	30	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:50:00+00	50	Ayar	2026-04-29 13:06:39.311+00	\N
711	30	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:39.324+00	\N
712	30	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:49:00+00	49	Ayar	2026-04-29 13:06:39.338+00	\N
713	30	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:39.348+00	\N
714	30	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:04:00+00	4	Ayar	2026-04-29 13:06:39.359+00	\N
715	30	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:39.371+00	\N
716	30	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:39.381+00	\N
717	30	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:39.392+00	\N
718	30	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:06:00+00	6	Ayar	2026-04-29 13:06:39.402+00	\N
719	30	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:39.412+00	\N
720	30	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:40:00+00	40	Ayar	2026-04-29 13:06:39.422+00	\N
721	30	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:39.435+00	\N
722	30	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:39.448+00	\N
723	30	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:40:00+00	40	Ayar	2026-04-29 13:06:39.461+00	\N
724	30	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:15:00+00	15	Ayar	2026-04-29 13:06:39.474+00	\N
725	30	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:39.488+00	\N
726	30	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:52:00+00	52	Ayar	2026-04-29 13:06:39.502+00	\N
727	30	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:56:00+00	56	Ayar	2026-04-29 13:06:39.517+00	\N
728	30	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:39.53+00	\N
729	30	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:38:00+00	38	Mekanik Arıza	2026-04-29 13:06:39.544+00	\N
730	30	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:39.556+00	\N
731	30	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:24:00+00	24	Ayar	2026-04-29 13:06:39.57+00	\N
732	30	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:39.583+00	\N
733	30	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:39.596+00	\N
734	30	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:39.61+00	\N
735	30	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:42:00+00	42	Ayar	2026-04-29 13:06:39.625+00	\N
736	30	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:38:00+00	38	Ayar	2026-04-29 13:06:39.639+00	\N
737	31	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:29:00+00	29	Ayar	2026-04-29 13:06:39.668+00	\N
738	31	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:06:39.684+00	\N
739	31	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:39.7+00	\N
740	31	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:39.715+00	\N
741	31	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:28:00+00	28	Ayar	2026-04-29 13:06:39.731+00	\N
742	31	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:12:00+00	12	Ayar	2026-04-29 13:06:39.745+00	\N
743	31	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:34:00+00	34	Ayar	2026-04-29 13:06:39.759+00	\N
744	31	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:39.771+00	\N
745	31	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:55:00+00	55	Ayar	2026-04-29 13:06:39.784+00	\N
746	31	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:39.797+00	\N
747	31	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:15:00+00	15	Parça Bekleme	2026-04-29 13:06:39.809+00	\N
748	31	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:41:00+00	41	Ayar	2026-04-29 13:06:39.822+00	\N
749	31	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:39.832+00	\N
750	31	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:03:00+00	3	Ayar	2026-04-29 13:06:39.841+00	\N
751	31	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:06:39.849+00	\N
752	31	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:51:00+00	51	Ayar	2026-04-29 13:06:39.857+00	\N
753	31	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:01:00+00	1	Parça Bekleme	2026-04-29 13:06:39.868+00	\N
754	31	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:02:00+00	2	Ayar	2026-04-29 13:06:39.879+00	\N
755	31	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:36:00+00	36	Ayar	2026-04-29 13:06:39.889+00	\N
756	31	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:38:00+00	38	Parça Bekleme	2026-04-29 13:06:39.899+00	\N
757	31	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:06:39.91+00	\N
758	31	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:39:00+00	39	Parça Bekleme	2026-04-29 13:06:39.921+00	\N
759	31	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:06:39.935+00	\N
760	31	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:39.946+00	\N
761	31	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:39.958+00	\N
762	31	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:38:00+00	38	Ayar	2026-04-29 13:06:39.973+00	\N
763	31	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:38:00+00	38	Parça Bekleme	2026-04-29 13:06:39.984+00	\N
764	31	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:15:00+00	15	Ayar	2026-04-29 13:06:39.995+00	\N
765	31	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:40.006+00	\N
766	32	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:36:00+00	36	Ayar	2026-04-29 13:06:40.016+00	\N
767	32	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:56:00+00	56	Mekanik Arıza	2026-04-29 13:06:40.027+00	\N
768	32	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:15:00+00	15	Ayar	2026-04-29 13:06:40.037+00	\N
769	32	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:40.047+00	\N
770	32	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:40.058+00	\N
771	32	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:52:00+00	52	Parça Bekleme	2026-04-29 13:06:40.069+00	\N
772	32	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:40.081+00	\N
773	32	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:40.091+00	\N
774	32	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:40.101+00	\N
775	32	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:40.116+00	\N
776	32	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:57:00+00	57	Ayar	2026-04-29 13:06:40.131+00	\N
777	32	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:40.144+00	\N
778	32	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:33:00+00	33	Ayar	2026-04-29 13:06:40.156+00	\N
779	32	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:40.167+00	\N
780	32	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:16:00+00	16	Ayar	2026-04-29 13:06:40.178+00	\N
781	32	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:13:00+00	13	Ayar	2026-04-29 13:06:40.189+00	\N
782	32	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:06:00+00	6	Ayar	2026-04-29 13:06:40.2+00	\N
783	32	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:40.211+00	\N
784	32	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:40.221+00	\N
785	32	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:29:00+00	29	Ayar	2026-04-29 13:06:40.233+00	\N
786	32	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:40.246+00	\N
787	32	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:40.258+00	\N
788	32	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:40.27+00	\N
789	32	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:43:00+00	43	Ayar	2026-04-29 13:06:40.282+00	\N
790	32	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:04:00+00	4	Ayar	2026-04-29 13:06:40.295+00	\N
791	32	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:30:00+00	30	Ayar	2026-04-29 13:06:40.309+00	\N
792	32	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:40.325+00	\N
793	32	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:05:00+00	5	Ayar	2026-04-29 13:06:40.336+00	\N
794	32	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:40.345+00	\N
795	32	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:25:00+00	25	Parça Bekleme	2026-04-29 13:06:40.354+00	\N
796	33	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:40.364+00	\N
797	33	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:59:00+00	59	Ayar	2026-04-29 13:06:40.373+00	\N
798	33	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:06:00+00	6	Ayar	2026-04-29 13:06:40.384+00	\N
799	33	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:40.394+00	\N
800	33	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:40.404+00	\N
801	33	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:03:00+00	3	Ayar	2026-04-29 13:06:40.413+00	\N
802	33	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:40.424+00	\N
803	33	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:40.434+00	\N
804	33	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:43:00+00	43	Parça Bekleme	2026-04-29 13:06:40.444+00	\N
805	33	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:24:00+00	24	Ayar	2026-04-29 13:06:40.456+00	\N
806	33	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:09:00+00	9	Ayar	2026-04-29 13:06:40.467+00	\N
807	33	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:40.477+00	\N
808	33	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:40.488+00	\N
809	33	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:40.498+00	\N
810	33	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:32:00+00	32	Ayar	2026-04-29 13:06:40.507+00	\N
811	33	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:39:00+00	39	Ayar	2026-04-29 13:06:40.517+00	\N
812	33	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:55:00+00	55	Ayar	2026-04-29 13:06:40.527+00	\N
813	33	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:42:00+00	42	Ayar	2026-04-29 13:06:40.536+00	\N
814	33	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:10:00+00	10	Ayar	2026-04-29 13:06:40.547+00	\N
815	33	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:06:40.559+00	\N
816	33	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:43:00+00	43	Parça Bekleme	2026-04-29 13:06:40.57+00	\N
817	33	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:40.582+00	\N
818	33	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:40.595+00	\N
819	33	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:40.607+00	\N
820	33	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:40.618+00	\N
821	33	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:06:00+00	6	Mekanik Arıza	2026-04-29 13:06:40.631+00	\N
822	33	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:40.643+00	\N
823	33	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:40.664+00	\N
824	33	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:40.676+00	\N
825	34	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:13:00+00	13	Parça Bekleme	2026-04-29 13:06:40.688+00	\N
826	34	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 06:00:00+00	60	Parça Bekleme	2026-04-29 13:06:40.699+00	\N
827	34	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:40.711+00	\N
828	34	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:40.732+00	\N
829	34	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:06:40.746+00	\N
830	34	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:23:00+00	23	Ayar	2026-04-29 13:06:40.759+00	\N
831	34	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:40.773+00	\N
832	34	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:40.788+00	\N
833	34	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:40.8+00	\N
834	34	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:40.814+00	\N
835	34	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:40.83+00	\N
836	34	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:34:00+00	34	Ayar	2026-04-29 13:06:40.843+00	\N
837	34	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:40.853+00	\N
838	34	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:19:00+00	19	Ayar	2026-04-29 13:06:40.863+00	\N
839	34	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:22:00+00	22	Parça Bekleme	2026-04-29 13:06:40.873+00	\N
840	34	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:40.884+00	\N
841	34	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:40.897+00	\N
842	34	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:26:00+00	26	Ayar	2026-04-29 13:06:40.909+00	\N
843	34	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:31:00+00	31	Ayar	2026-04-29 13:06:40.921+00	\N
844	34	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:40.933+00	\N
845	34	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:49:00+00	49	Parça Bekleme	2026-04-29 13:06:40.945+00	\N
846	34	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:40.957+00	\N
847	34	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:04:00+00	4	Ayar	2026-04-29 13:06:40.967+00	\N
848	34	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:40.979+00	\N
849	34	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:49:00+00	49	Ayar	2026-04-29 13:06:40.988+00	\N
850	34	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:40.998+00	\N
851	34	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:41.007+00	\N
852	34	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:35:00+00	35	Ayar	2026-04-29 13:06:41.026+00	\N
853	35	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:41.036+00	\N
854	35	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:06:41.049+00	\N
855	35	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:41.062+00	\N
856	35	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:41.077+00	\N
857	35	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:37:00+00	37	Ayar	2026-04-29 13:06:41.092+00	\N
858	35	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:41.109+00	\N
859	35	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:41.125+00	\N
860	35	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:04:00+00	4	Ayar	2026-04-29 13:06:41.142+00	\N
861	35	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:41.156+00	\N
862	35	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:41.169+00	\N
863	35	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:41.182+00	\N
864	35	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:41.195+00	\N
865	35	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:41.211+00	\N
866	35	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:03:00+00	3	Ayar	2026-04-29 13:06:41.226+00	\N
867	35	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:17:00+00	17	Ayar	2026-04-29 13:06:41.243+00	\N
868	35	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:41.26+00	\N
869	35	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:41.275+00	\N
870	35	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:21:00+00	21	Ayar	2026-04-29 13:06:41.292+00	\N
871	35	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:22:00+00	22	Ayar	2026-04-29 13:06:41.306+00	\N
872	35	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:41.321+00	\N
873	35	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:41.342+00	\N
874	35	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:41.356+00	\N
875	35	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:41.37+00	\N
876	35	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:41.385+00	\N
877	35	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:41.401+00	\N
878	35	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:38:00+00	38	Ayar	2026-04-29 13:06:41.416+00	\N
879	35	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:41.433+00	\N
880	35	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:41.45+00	\N
881	35	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:41.467+00	\N
882	35	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:41.486+00	\N
883	36	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:05:00+00	5	Ayar	2026-04-29 13:06:41.502+00	\N
884	36	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:02:00+00	2	Ayar	2026-04-29 13:06:41.518+00	\N
885	36	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:57:00+00	57	Ayar	2026-04-29 13:06:41.533+00	\N
886	36	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:41.548+00	\N
887	36	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:45:00+00	45	Ayar	2026-04-29 13:06:41.564+00	\N
888	36	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:57:00+00	57	Ayar	2026-04-29 13:06:41.579+00	\N
889	36	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:41.594+00	\N
890	36	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:41.611+00	\N
891	36	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:41.625+00	\N
892	36	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:41.639+00	\N
893	36	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:41.652+00	\N
894	36	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:01:00+00	1	Ayar	2026-04-29 13:06:41.663+00	\N
895	36	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:41.677+00	\N
896	36	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:13:00+00	13	Parça Bekleme	2026-04-29 13:06:41.693+00	\N
897	36	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:04:00+00	4	Ayar	2026-04-29 13:06:41.709+00	\N
898	36	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:41.725+00	\N
899	36	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:41.74+00	\N
900	36	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:01:00+00	1	Ayar	2026-04-29 13:06:41.755+00	\N
901	36	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:46:00+00	46	Ayar	2026-04-29 13:06:41.77+00	\N
902	36	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:41.784+00	\N
903	36	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:06:41.797+00	\N
904	36	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:41:00+00	41	Ayar	2026-04-29 13:06:41.809+00	\N
905	36	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:41.821+00	\N
906	36	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:23:00+00	23	Ayar	2026-04-29 13:06:41.838+00	\N
907	36	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:15:00+00	15	Parça Bekleme	2026-04-29 13:06:41.848+00	\N
908	36	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:40:00+00	40	Parça Bekleme	2026-04-29 13:06:41.858+00	\N
909	36	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:41.869+00	\N
910	36	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:41.882+00	\N
911	36	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:41.896+00	\N
912	36	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:41.908+00	\N
913	37	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:06:41.921+00	\N
914	37	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:41.934+00	\N
915	37	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:19:00+00	19	Mekanik Arıza	2026-04-29 13:06:41.948+00	\N
916	37	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:41.963+00	\N
917	37	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:41.978+00	\N
918	37	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:41.993+00	\N
919	37	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:42.007+00	\N
920	37	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:56:00+00	56	Ayar	2026-04-29 13:06:42.023+00	\N
921	37	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:42.037+00	\N
922	37	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:58:00+00	58	Ayar	2026-04-29 13:06:42.051+00	\N
923	37	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:20:00+00	20	Ayar	2026-04-29 13:06:42.065+00	\N
924	37	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:42.079+00	\N
925	37	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:42.093+00	\N
926	37	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:58:00+00	58	Ayar	2026-04-29 13:06:42.107+00	\N
927	37	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:09:00+00	9	Ayar	2026-04-29 13:06:42.12+00	\N
928	37	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:42.134+00	\N
929	37	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:42.15+00	\N
930	37	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:15:00+00	15	Parça Bekleme	2026-04-29 13:06:42.164+00	\N
931	37	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:42.178+00	\N
932	37	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:42.191+00	\N
933	37	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:42.204+00	\N
934	37	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:42.218+00	\N
935	37	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:42.231+00	\N
936	37	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:42.245+00	\N
937	37	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:42.258+00	\N
938	37	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:42.271+00	\N
939	37	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:07:00+00	7	Ayar	2026-04-29 13:06:42.284+00	\N
940	37	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:42.297+00	\N
941	37	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:42.312+00	\N
942	37	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:48:00+00	48	Ayar	2026-04-29 13:06:42.329+00	\N
943	38	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 06:00:00+00	60	Ayar	2026-04-29 13:06:42.345+00	\N
944	38	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:42.359+00	\N
945	38	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:11:00+00	11	Ayar	2026-04-29 13:06:42.374+00	\N
946	38	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:17:00+00	17	Ayar	2026-04-29 13:06:42.388+00	\N
947	38	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:19:00+00	19	Mekanik Arıza	2026-04-29 13:06:42.404+00	\N
948	38	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:42.421+00	\N
949	38	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:05:00+00	5	Ayar	2026-04-29 13:06:42.439+00	\N
950	38	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:49:00+00	49	Ayar	2026-04-29 13:06:42.454+00	\N
951	38	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:42.471+00	\N
952	38	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:06:00+00	6	Mekanik Arıza	2026-04-29 13:06:42.488+00	\N
953	38	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:51:00+00	51	Ayar	2026-04-29 13:06:42.504+00	\N
954	38	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:01:00+00	1	Ayar	2026-04-29 13:06:42.52+00	\N
955	38	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:59:00+00	59	Ayar	2026-04-29 13:06:42.537+00	\N
956	38	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:07:00+00	7	Ayar	2026-04-29 13:06:42.553+00	\N
957	38	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:45:00+00	45	Ayar	2026-04-29 13:06:42.568+00	\N
958	38	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:01:00+00	1	Parça Bekleme	2026-04-29 13:06:42.584+00	\N
959	38	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:23:00+00	23	Ayar	2026-04-29 13:06:42.6+00	\N
960	38	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:42.615+00	\N
961	38	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:42.63+00	\N
962	38	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:42.645+00	\N
963	38	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:42.668+00	\N
964	38	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:42.682+00	\N
965	38	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:20:00+00	20	Ayar	2026-04-29 13:06:42.696+00	\N
966	38	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:42.709+00	\N
967	38	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:42.723+00	\N
968	38	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:06:42.736+00	\N
969	38	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:38:00+00	38	Parça Bekleme	2026-04-29 13:06:42.748+00	\N
970	38	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:06:42.762+00	\N
971	38	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:42.779+00	\N
972	39	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:20:00+00	20	Ayar	2026-04-29 13:06:42.795+00	\N
973	39	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:56:00+00	56	Mekanik Arıza	2026-04-29 13:06:42.811+00	\N
974	39	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:42.827+00	\N
975	39	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:38:00+00	38	Mekanik Arıza	2026-04-29 13:06:42.844+00	\N
976	39	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:42.856+00	\N
977	39	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:42.866+00	\N
978	39	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:54:00+00	54	Ayar	2026-04-29 13:06:42.877+00	\N
979	39	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:42.888+00	\N
980	39	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:09:00+00	9	Ayar	2026-04-29 13:06:42.899+00	\N
981	39	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:42.911+00	\N
982	39	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:42.925+00	\N
983	39	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:42.938+00	\N
984	39	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:06:42.951+00	\N
985	39	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:42.963+00	\N
986	39	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:34:00+00	34	Ayar	2026-04-29 13:06:42.972+00	\N
987	39	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:42.981+00	\N
988	39	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:04:00+00	4	Ayar	2026-04-29 13:06:42.99+00	\N
989	39	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:42.999+00	\N
990	39	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:43.01+00	\N
991	39	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:43.02+00	\N
992	39	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:43.03+00	\N
993	39	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:43.039+00	\N
994	39	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:43.049+00	\N
995	39	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:25:00+00	25	Parça Bekleme	2026-04-29 13:06:43.06+00	\N
996	39	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:43.071+00	\N
997	39	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:43.082+00	\N
998	39	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:43.094+00	\N
999	39	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:43.105+00	\N
1000	39	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:43.117+00	\N
1001	39	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:43.128+00	\N
1002	40	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:32:00+00	32	Ayar	2026-04-29 13:06:43.141+00	\N
1003	40	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:59:00+00	59	Ayar	2026-04-29 13:06:43.156+00	\N
1004	40	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:43.168+00	\N
1005	40	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:43.184+00	\N
1006	40	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:10:00+00	10	Ayar	2026-04-29 13:06:43.195+00	\N
1007	40	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:48:00+00	48	Ayar	2026-04-29 13:06:43.207+00	\N
1008	40	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:31:00+00	31	Parça Bekleme	2026-04-29 13:06:43.218+00	\N
1009	40	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:19:00+00	19	Parça Bekleme	2026-04-29 13:06:43.23+00	\N
1010	40	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:46:00+00	46	Ayar	2026-04-29 13:06:43.243+00	\N
1011	40	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:06:43.255+00	\N
1012	40	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:43.266+00	\N
1013	40	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:43.278+00	\N
1014	40	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:56:00+00	56	Mekanik Arıza	2026-04-29 13:06:43.29+00	\N
1015	40	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:59:00+00	59	Parça Bekleme	2026-04-29 13:06:43.3+00	\N
1016	40	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:43.311+00	\N
1017	40	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:48:00+00	48	Ayar	2026-04-29 13:06:43.326+00	\N
1018	40	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:50:00+00	50	Ayar	2026-04-29 13:06:43.337+00	\N
1019	40	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:38:00+00	38	Ayar	2026-04-29 13:06:43.347+00	\N
1020	40	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:43.358+00	\N
1021	40	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:43.37+00	\N
1022	40	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:26:00+00	26	Ayar	2026-04-29 13:06:43.383+00	\N
1023	40	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:42:00+00	42	Ayar	2026-04-29 13:06:43.396+00	\N
1024	40	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:24:00+00	24	Ayar	2026-04-29 13:06:43.41+00	\N
1025	40	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:06:43.424+00	\N
1026	40	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:43.437+00	\N
1027	40	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:25:00+00	25	Parça Bekleme	2026-04-29 13:06:43.451+00	\N
1028	40	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:51:00+00	51	Ayar	2026-04-29 13:06:43.464+00	\N
1029	40	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:49:00+00	49	Ayar	2026-04-29 13:06:43.479+00	\N
1030	40	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:46:00+00	46	Ayar	2026-04-29 13:06:43.493+00	\N
1031	40	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:39:00+00	39	Parça Bekleme	2026-04-29 13:06:43.506+00	\N
1032	41	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:43.52+00	\N
1033	41	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:26:00+00	26	Ayar	2026-04-29 13:06:43.534+00	\N
1034	41	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:43.547+00	\N
1035	41	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:43.56+00	\N
1036	41	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:31:00+00	31	Mekanik Arıza	2026-04-29 13:06:43.574+00	\N
1037	41	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:22:00+00	22	Ayar	2026-04-29 13:06:43.588+00	\N
1038	41	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:43.602+00	\N
1039	41	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:43:00+00	43	Parça Bekleme	2026-04-29 13:06:43.621+00	\N
1040	41	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:43.633+00	\N
1041	41	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:43.645+00	\N
1042	41	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:16:00+00	16	Ayar	2026-04-29 13:06:43.656+00	\N
1043	41	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:06:43.668+00	\N
1044	41	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:43.68+00	\N
1045	41	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:43.691+00	\N
1046	41	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:43.71+00	\N
1047	41	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:43.72+00	\N
1048	41	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:57:00+00	57	Ayar	2026-04-29 13:06:43.73+00	\N
1049	41	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:32:00+00	32	Parça Bekleme	2026-04-29 13:06:43.74+00	\N
1050	41	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:43.75+00	\N
1051	41	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:43.761+00	\N
1052	41	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:02:00+00	2	Ayar	2026-04-29 13:06:43.772+00	\N
1053	41	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 06:00:00+00	60	Parça Bekleme	2026-04-29 13:06:43.785+00	\N
1054	41	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:20:00+00	20	Parça Bekleme	2026-04-29 13:06:43.802+00	\N
1055	41	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:43.817+00	\N
1056	41	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:52:00+00	52	Ayar	2026-04-29 13:06:43.833+00	\N
1057	41	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:06:43.845+00	\N
1058	41	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:43.857+00	\N
1059	41	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:30:00+00	30	Ayar	2026-04-29 13:06:43.87+00	\N
1060	42	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:43.882+00	\N
1061	42	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:32:00+00	32	Ayar	2026-04-29 13:06:43.894+00	\N
1062	42	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:43.906+00	\N
1063	42	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:35:00+00	35	Ayar	2026-04-29 13:06:43.917+00	\N
1064	42	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:43.929+00	\N
1065	42	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:43.942+00	\N
1066	42	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:43.954+00	\N
1067	42	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:20:00+00	20	Ayar	2026-04-29 13:06:43.966+00	\N
1068	42	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:04:00+00	4	Ayar	2026-04-29 13:06:43.977+00	\N
1069	42	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:03:00+00	3	Ayar	2026-04-29 13:06:43.998+00	\N
1070	42	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:32:00+00	32	Ayar	2026-04-29 13:06:44.01+00	\N
1071	42	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:51:00+00	51	Ayar	2026-04-29 13:06:44.024+00	\N
1072	42	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:43:00+00	43	Ayar	2026-04-29 13:06:44.039+00	\N
1073	42	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:49:00+00	49	Ayar	2026-04-29 13:06:44.052+00	\N
1074	42	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:44.064+00	\N
1075	42	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:01:00+00	1	Ayar	2026-04-29 13:06:44.08+00	\N
1076	42	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:57:00+00	57	Ayar	2026-04-29 13:06:44.093+00	\N
1077	42	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:22:00+00	22	Ayar	2026-04-29 13:06:44.105+00	\N
1078	42	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:44.117+00	\N
1079	42	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:43:00+00	43	Ayar	2026-04-29 13:06:44.129+00	\N
1080	42	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:32:00+00	32	Ayar	2026-04-29 13:06:44.14+00	\N
1081	42	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:03:00+00	3	Ayar	2026-04-29 13:06:44.151+00	\N
1082	42	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:37:00+00	37	Ayar	2026-04-29 13:06:44.161+00	\N
1083	42	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:58:00+00	58	Ayar	2026-04-29 13:06:44.171+00	\N
1084	42	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:44.181+00	\N
1085	42	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:58:00+00	58	Ayar	2026-04-29 13:06:44.193+00	\N
1086	42	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:06:00+00	6	Ayar	2026-04-29 13:06:44.205+00	\N
1087	42	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:44.218+00	\N
1088	42	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:44.233+00	\N
1089	43	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:06:44.246+00	\N
1090	43	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 06:00:00+00	60	Ayar	2026-04-29 13:06:44.26+00	\N
1091	43	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:36:00+00	36	Ayar	2026-04-29 13:06:44.273+00	\N
1092	43	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:06:44.285+00	\N
1093	43	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:30:00+00	30	Ayar	2026-04-29 13:06:44.298+00	\N
1094	43	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:41:00+00	41	Ayar	2026-04-29 13:06:44.31+00	\N
1095	43	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:44.322+00	\N
1096	43	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:44.339+00	\N
1097	43	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:34:00+00	34	Ayar	2026-04-29 13:06:44.349+00	\N
1098	43	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:44.36+00	\N
1099	43	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:44.375+00	\N
1100	43	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:59:00+00	59	Ayar	2026-04-29 13:06:44.39+00	\N
1101	43	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:44.405+00	\N
1102	43	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:44.422+00	\N
1103	43	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:13:00+00	13	Ayar	2026-04-29 13:06:44.439+00	\N
1104	43	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:31:00+00	31	Parça Bekleme	2026-04-29 13:06:44.453+00	\N
1105	43	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:57:00+00	57	Ayar	2026-04-29 13:06:44.467+00	\N
1106	43	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:28:00+00	28	Ayar	2026-04-29 13:06:44.483+00	\N
1107	43	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:44.499+00	\N
1108	43	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:53:00+00	53	Ayar	2026-04-29 13:06:44.512+00	\N
1109	43	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:52:00+00	52	Ayar	2026-04-29 13:06:44.525+00	\N
1110	43	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:44.538+00	\N
1111	43	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:44.549+00	\N
1112	43	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:44.558+00	\N
1113	43	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:11:00+00	11	Ayar	2026-04-29 13:06:44.568+00	\N
1114	43	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:13:00+00	13	Ayar	2026-04-29 13:06:44.578+00	\N
1115	43	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:07:00+00	7	Ayar	2026-04-29 13:06:44.589+00	\N
1116	43	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:44.598+00	\N
1117	43	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:27:00+00	27	Ayar	2026-04-29 13:06:44.609+00	\N
1118	43	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:44.621+00	\N
1119	44	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:21:00+00	21	Ayar	2026-04-29 13:06:44.634+00	\N
1120	44	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:44.644+00	\N
1121	44	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:30:00+00	30	Ayar	2026-04-29 13:06:44.654+00	\N
1122	44	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:06:44.666+00	\N
1123	44	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:44.68+00	\N
1124	44	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:27:00+00	27	Ayar	2026-04-29 13:06:44.693+00	\N
1125	44	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:43:00+00	43	Parça Bekleme	2026-04-29 13:06:44.705+00	\N
1126	44	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:44.715+00	\N
1127	44	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:44.725+00	\N
1128	44	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:44.733+00	\N
1129	44	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:08:00+00	8	Ayar	2026-04-29 13:06:44.742+00	\N
1130	44	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:44.75+00	\N
1131	44	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:44.761+00	\N
1132	44	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:44.77+00	\N
1133	44	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:44.779+00	\N
1134	44	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:44.791+00	\N
1135	44	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:24:00+00	24	Ayar	2026-04-29 13:06:44.804+00	\N
1136	44	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:44.818+00	\N
1137	44	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:44.832+00	\N
1138	44	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:44.844+00	\N
1139	44	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:08:00+00	8	Ayar	2026-04-29 13:06:44.856+00	\N
1140	44	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:44.868+00	\N
1141	44	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:16:00+00	16	Ayar	2026-04-29 13:06:44.883+00	\N
1142	44	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:06:44.897+00	\N
1143	44	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:44.912+00	\N
1144	44	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:44.926+00	\N
1145	44	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:44.941+00	\N
1146	44	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:44.957+00	\N
1147	44	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 06:00:00+00	60	Ayar	2026-04-29 13:06:44.973+00	\N
1148	44	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:44.988+00	\N
1149	45	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:43:00+00	43	Ayar	2026-04-29 13:06:45.004+00	\N
1150	45	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:45.021+00	\N
1151	45	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:45.037+00	\N
1152	45	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:45.052+00	\N
1153	45	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:45.068+00	\N
1154	45	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:45.083+00	\N
1155	45	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:45:00+00	45	Ayar	2026-04-29 13:06:45.099+00	\N
1156	45	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:47:00+00	47	Ayar	2026-04-29 13:06:45.115+00	\N
1157	45	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:49:00+00	49	Parça Bekleme	2026-04-29 13:06:45.131+00	\N
1158	45	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:45.145+00	\N
1159	45	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:45.16+00	\N
1160	45	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:39:00+00	39	Parça Bekleme	2026-04-29 13:06:45.183+00	\N
1161	45	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:49:00+00	49	Ayar	2026-04-29 13:06:45.198+00	\N
1162	45	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:56:00+00	56	Ayar	2026-04-29 13:06:45.212+00	\N
1163	45	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:43:00+00	43	Parça Bekleme	2026-04-29 13:06:45.226+00	\N
1164	45	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:41:00+00	41	Ayar	2026-04-29 13:06:45.239+00	\N
1165	45	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:45.253+00	\N
1166	45	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:45.266+00	\N
1167	45	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:52:00+00	52	Ayar	2026-04-29 13:06:45.28+00	\N
1168	45	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:45.297+00	\N
1169	45	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:06:45.313+00	\N
1170	45	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:45.329+00	\N
1171	45	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:45.342+00	\N
1172	45	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:45.354+00	\N
1173	45	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:34:00+00	34	Parça Bekleme	2026-04-29 13:06:45.369+00	\N
1174	45	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:45.387+00	\N
1175	45	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:45.401+00	\N
1176	45	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:45.415+00	\N
1177	45	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:45.43+00	\N
1178	46	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:45.446+00	\N
1179	46	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:58:00+00	58	Ayar	2026-04-29 13:06:45.462+00	\N
1180	46	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:45.477+00	\N
1181	46	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:45.493+00	\N
1182	46	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:49:00+00	49	Ayar	2026-04-29 13:06:45.506+00	\N
1183	46	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:45.519+00	\N
1184	46	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:45.532+00	\N
1185	46	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:39:00+00	39	Parça Bekleme	2026-04-29 13:06:45.542+00	\N
1186	46	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:44:00+00	44	Ayar	2026-04-29 13:06:45.553+00	\N
1187	46	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:50:00+00	50	Ayar	2026-04-29 13:06:45.563+00	\N
1188	46	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 06:00:00+00	60	Parça Bekleme	2026-04-29 13:06:45.574+00	\N
1189	46	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:45.587+00	\N
1190	46	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:45.596+00	\N
1191	46	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:45.604+00	\N
1192	46	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:49:00+00	49	Parça Bekleme	2026-04-29 13:06:45.615+00	\N
1193	46	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:06:45.628+00	\N
1194	46	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:45.642+00	\N
1195	46	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:45.656+00	\N
1196	46	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:45.671+00	\N
1197	46	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:45.685+00	\N
1198	46	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:50:00+00	50	Ayar	2026-04-29 13:06:45.7+00	\N
1199	46	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:45.714+00	\N
1200	46	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:45.727+00	\N
1201	46	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:45.74+00	\N
1202	46	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:45.753+00	\N
1203	46	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:45.764+00	\N
1204	46	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:45.776+00	\N
1205	46	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:45.788+00	\N
1206	46	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:45.798+00	\N
1207	46	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:30:00+00	30	Ayar	2026-04-29 13:06:45.807+00	\N
1208	47	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:54:00+00	54	Ayar	2026-04-29 13:06:45.816+00	\N
1209	47	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:45.825+00	\N
1210	47	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:39:00+00	39	Ayar	2026-04-29 13:06:45.841+00	\N
1211	47	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:45.853+00	\N
1212	47	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:45.864+00	\N
1213	47	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:45.874+00	\N
1214	47	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:45.883+00	\N
1215	47	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:59:00+00	59	Ayar	2026-04-29 13:06:45.894+00	\N
1216	47	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:40:00+00	40	Parça Bekleme	2026-04-29 13:06:45.904+00	\N
1217	47	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:16:00+00	16	Ayar	2026-04-29 13:06:45.915+00	\N
1218	47	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:45.927+00	\N
1219	47	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:41:00+00	41	Ayar	2026-04-29 13:06:45.939+00	\N
1220	47	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 06:00:00+00	60	Ayar	2026-04-29 13:06:45.955+00	\N
1221	47	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:27:00+00	27	Ayar	2026-04-29 13:06:45.969+00	\N
1222	47	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:09:00+00	9	Ayar	2026-04-29 13:06:45.99+00	\N
1223	47	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:46.003+00	\N
1224	47	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:23:00+00	23	Ayar	2026-04-29 13:06:46.023+00	\N
1225	47	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:38:00+00	38	Ayar	2026-04-29 13:06:46.035+00	\N
1226	47	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:54:00+00	54	Ayar	2026-04-29 13:06:46.046+00	\N
1227	47	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:56:00+00	56	Ayar	2026-04-29 13:06:46.056+00	\N
1228	47	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:46.066+00	\N
1229	47	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:46.078+00	\N
1230	47	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:06:46.09+00	\N
1231	47	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:46.103+00	\N
1232	47	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:13:00+00	13	Ayar	2026-04-29 13:06:46.117+00	\N
1233	47	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:46.127+00	\N
1234	47	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:48:00+00	48	Ayar	2026-04-29 13:06:46.139+00	\N
1235	47	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:47:00+00	47	Ayar	2026-04-29 13:06:46.151+00	\N
1236	48	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:46.17+00	\N
1237	48	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:16:00+00	16	Ayar	2026-04-29 13:06:46.18+00	\N
1238	48	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:49:00+00	49	Parça Bekleme	2026-04-29 13:06:46.191+00	\N
1239	48	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:19:00+00	19	Parça Bekleme	2026-04-29 13:06:46.202+00	\N
1240	48	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:59:00+00	59	Ayar	2026-04-29 13:06:46.211+00	\N
1241	48	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:46.222+00	\N
1242	48	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:46.232+00	\N
1243	48	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:46.244+00	\N
1244	48	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:46.255+00	\N
1245	48	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:46.266+00	\N
1246	48	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:46.284+00	\N
1247	48	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:46.294+00	\N
1248	48	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:46.307+00	\N
1249	48	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:46.321+00	\N
1250	48	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:46.336+00	\N
1251	48	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:46.347+00	\N
1252	48	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:02:00+00	2	Mekanik Arıza	2026-04-29 13:06:46.357+00	\N
1253	48	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:46.368+00	\N
1254	48	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:46.378+00	\N
1255	48	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:06:46.39+00	\N
1256	48	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:37:00+00	37	Ayar	2026-04-29 13:06:46.401+00	\N
1257	48	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:46.413+00	\N
1258	48	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:59:00+00	59	Ayar	2026-04-29 13:06:46.426+00	\N
1259	48	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:46.437+00	\N
1260	48	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:34:00+00	34	Parça Bekleme	2026-04-29 13:06:46.45+00	\N
1261	48	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:46.463+00	\N
1262	48	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:21:00+00	21	Ayar	2026-04-29 13:06:46.475+00	\N
1263	48	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:14:00+00	14	Ayar	2026-04-29 13:06:46.489+00	\N
1264	49	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:38:00+00	38	Ayar	2026-04-29 13:06:46.502+00	\N
1265	49	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:35:00+00	35	Ayar	2026-04-29 13:06:46.514+00	\N
1266	49	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:46.535+00	\N
1267	49	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:46.547+00	\N
1268	49	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:49:00+00	49	Parça Bekleme	2026-04-29 13:06:46.56+00	\N
1269	49	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:46.573+00	\N
1270	49	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:46.587+00	\N
1271	49	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:11:00+00	11	Ayar	2026-04-29 13:06:46.6+00	\N
1272	49	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:06:46.613+00	\N
1273	49	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:46.626+00	\N
1274	49	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:46.638+00	\N
1275	49	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:06:46.653+00	\N
1276	49	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:46.666+00	\N
1277	49	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:36:00+00	36	Ayar	2026-04-29 13:06:46.679+00	\N
1278	49	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:46.691+00	\N
1279	49	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:49:00+00	49	Ayar	2026-04-29 13:06:46.704+00	\N
1280	49	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:14:00+00	14	Ayar	2026-04-29 13:06:46.716+00	\N
1281	49	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:46.728+00	\N
1282	49	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:43:00+00	43	Parça Bekleme	2026-04-29 13:06:46.742+00	\N
1283	49	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:46.755+00	\N
1284	49	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:09:00+00	9	Ayar	2026-04-29 13:06:46.771+00	\N
1285	49	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:46.786+00	\N
1286	49	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:11:00+00	11	Mekanik Arıza	2026-04-29 13:06:46.8+00	\N
1287	49	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:46.816+00	\N
1288	49	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:46.835+00	\N
1289	49	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:06:46.853+00	\N
1290	49	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:46.865+00	\N
1291	49	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:59:00+00	59	Ayar	2026-04-29 13:06:46.877+00	\N
1292	50	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:46.89+00	\N
1293	50	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:46.902+00	\N
1294	50	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:15:00+00	15	Ayar	2026-04-29 13:06:46.913+00	\N
1295	50	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:58:00+00	58	Ayar	2026-04-29 13:06:46.924+00	\N
1296	50	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:46.932+00	\N
1297	50	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:32:00+00	32	Parça Bekleme	2026-04-29 13:06:46.942+00	\N
1298	50	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:06:46.952+00	\N
1299	50	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:34:00+00	34	Ayar	2026-04-29 13:06:46.968+00	\N
1300	50	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:46.98+00	\N
1301	50	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:46.994+00	\N
1302	50	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:22:00+00	22	Ayar	2026-04-29 13:06:47.01+00	\N
1303	50	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:47.027+00	\N
1304	50	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:02:00+00	2	Ayar	2026-04-29 13:06:47.046+00	\N
1305	50	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:47.061+00	\N
1306	50	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:47.075+00	\N
1307	50	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:43:00+00	43	Parça Bekleme	2026-04-29 13:06:47.089+00	\N
1308	50	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:02:00+00	2	Mekanik Arıza	2026-04-29 13:06:47.103+00	\N
1309	50	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:47.117+00	\N
1310	50	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:35:00+00	35	Ayar	2026-04-29 13:06:47.131+00	\N
1311	50	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:13:00+00	13	Ayar	2026-04-29 13:06:47.145+00	\N
1312	50	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:47.157+00	\N
1313	50	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:18:00+00	18	Ayar	2026-04-29 13:06:47.168+00	\N
1314	50	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:34:00+00	34	Ayar	2026-04-29 13:06:47.179+00	\N
1315	50	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:49:00+00	49	Parça Bekleme	2026-04-29 13:06:47.191+00	\N
1316	50	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:29:00+00	29	Ayar	2026-04-29 13:06:47.203+00	\N
1317	50	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:06:47.217+00	\N
1318	50	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:47.23+00	\N
1319	50	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:47.244+00	\N
1320	50	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:03:00+00	3	Ayar	2026-04-29 13:06:47.259+00	\N
1321	50	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:06:47.274+00	\N
1322	51	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:47.289+00	\N
1323	51	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:47.329+00	\N
1324	51	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:19:00+00	19	Mekanik Arıza	2026-04-29 13:06:47.345+00	\N
1325	51	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:47.357+00	\N
1326	51	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:48:00+00	48	Ayar	2026-04-29 13:06:47.372+00	\N
1327	51	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:28:00+00	28	Ayar	2026-04-29 13:06:47.383+00	\N
1328	51	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:02:00+00	2	Ayar	2026-04-29 13:06:47.396+00	\N
1329	51	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:57:00+00	57	Ayar	2026-04-29 13:06:47.408+00	\N
1330	51	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:39:00+00	39	Parça Bekleme	2026-04-29 13:06:47.42+00	\N
1331	51	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:47.432+00	\N
1332	51	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:28:00+00	28	Ayar	2026-04-29 13:06:47.444+00	\N
1333	51	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:47.454+00	\N
1334	51	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:41:00+00	41	Ayar	2026-04-29 13:06:47.465+00	\N
1335	51	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 06:00:00+00	60	Ayar	2026-04-29 13:06:47.476+00	\N
1336	51	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:47.486+00	\N
1337	51	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:47.497+00	\N
1338	51	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:06:47.508+00	\N
1339	51	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:44:00+00	44	Ayar	2026-04-29 13:06:47.52+00	\N
1340	51	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:50:00+00	50	Ayar	2026-04-29 13:06:47.532+00	\N
1341	51	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:39:00+00	39	Ayar	2026-04-29 13:06:47.545+00	\N
1342	51	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:53:00+00	53	Ayar	2026-04-29 13:06:47.559+00	\N
1343	51	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:47.572+00	\N
1344	51	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:58:00+00	58	Ayar	2026-04-29 13:06:47.584+00	\N
1345	51	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:47.596+00	\N
1346	51	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:17:00+00	17	Ayar	2026-04-29 13:06:47.609+00	\N
1347	51	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:47.622+00	\N
1348	51	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:47.636+00	\N
1349	51	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:47.648+00	\N
1350	51	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:47.66+00	\N
1351	51	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:47.673+00	\N
1352	52	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:47.687+00	\N
1353	52	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:34:00+00	34	Ayar	2026-04-29 13:06:47.702+00	\N
1354	52	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:47.718+00	\N
1355	52	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:02:00+00	2	Ayar	2026-04-29 13:06:47.735+00	\N
1356	52	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:43:00+00	43	Ayar	2026-04-29 13:06:47.751+00	\N
1357	52	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:22:00+00	22	Ayar	2026-04-29 13:06:47.772+00	\N
1358	52	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:47.79+00	\N
1359	52	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:50:00+00	50	Ayar	2026-04-29 13:06:47.804+00	\N
1360	52	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:47.816+00	\N
1361	52	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:44:00+00	44	Ayar	2026-04-29 13:06:47.832+00	\N
1362	52	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 06:00:00+00	60	Ayar	2026-04-29 13:06:47.844+00	\N
1363	52	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:47.858+00	\N
1364	52	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:47.871+00	\N
1365	52	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:07:00+00	7	Ayar	2026-04-29 13:06:47.893+00	\N
1366	52	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:47.905+00	\N
1367	52	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:12:00+00	12	Ayar	2026-04-29 13:06:47.917+00	\N
1368	52	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:02:00+00	2	Ayar	2026-04-29 13:06:47.93+00	\N
1369	52	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:47.944+00	\N
1370	52	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:06:00+00	6	Ayar	2026-04-29 13:06:47.955+00	\N
1371	52	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:47.967+00	\N
1372	52	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:38:00+00	38	Parça Bekleme	2026-04-29 13:06:47.977+00	\N
1373	52	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:35:00+00	35	Ayar	2026-04-29 13:06:47.989+00	\N
1374	52	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:48.003+00	\N
1375	52	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:26:00+00	26	Ayar	2026-04-29 13:06:48.016+00	\N
1376	52	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:48.028+00	\N
1377	52	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:52:00+00	52	Ayar	2026-04-29 13:06:48.04+00	\N
1378	52	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:32:00+00	32	Ayar	2026-04-29 13:06:48.052+00	\N
1379	52	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:48.068+00	\N
1380	52	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:48.084+00	\N
1381	53	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:48.102+00	\N
1382	53	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:48.122+00	\N
1383	53	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:48.137+00	\N
1384	53	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:49:00+00	49	Ayar	2026-04-29 13:06:48.15+00	\N
1385	53	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:48.167+00	\N
1386	53	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:48.178+00	\N
1387	53	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:28:00+00	28	Ayar	2026-04-29 13:06:48.196+00	\N
1388	53	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:46:00+00	46	Ayar	2026-04-29 13:06:48.207+00	\N
1389	53	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:59:00+00	59	Parça Bekleme	2026-04-29 13:06:48.216+00	\N
1390	53	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:35:00+00	35	Ayar	2026-04-29 13:06:48.225+00	\N
1391	53	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:37:00+00	37	Ayar	2026-04-29 13:06:48.237+00	\N
1392	53	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:48.25+00	\N
1393	53	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:59:00+00	59	Ayar	2026-04-29 13:06:48.262+00	\N
1394	53	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:10:00+00	10	Ayar	2026-04-29 13:06:48.273+00	\N
1395	53	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:48.284+00	\N
1396	53	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:48.294+00	\N
1397	53	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:59:00+00	59	Ayar	2026-04-29 13:06:48.305+00	\N
1398	53	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:48.315+00	\N
1399	53	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:19:00+00	19	Ayar	2026-04-29 13:06:48.377+00	\N
1400	53	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:48.389+00	\N
1401	53	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:48.409+00	\N
1402	53	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:06:48.423+00	\N
1403	53	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:25:00+00	25	Parça Bekleme	2026-04-29 13:06:48.44+00	\N
1404	53	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:48.451+00	\N
1405	53	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:06:48.461+00	\N
1406	53	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:06:48.47+00	\N
1407	53	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:06:48.48+00	\N
1408	53	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:53:00+00	53	Ayar	2026-04-29 13:06:48.49+00	\N
1409	53	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:31:00+00	31	Parça Bekleme	2026-04-29 13:06:48.5+00	\N
1410	53	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:59:00+00	59	Ayar	2026-04-29 13:06:48.512+00	\N
1411	54	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:48.524+00	\N
1412	54	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:48.537+00	\N
1413	54	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:48.55+00	\N
1414	54	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:48.565+00	\N
1415	54	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:48.581+00	\N
1416	54	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:48.596+00	\N
1417	54	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:48.616+00	\N
1418	54	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:26:00+00	26	Ayar	2026-04-29 13:06:48.632+00	\N
1419	54	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:12:00+00	12	Ayar	2026-04-29 13:06:48.647+00	\N
1420	54	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:48.66+00	\N
1421	54	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:36:00+00	36	Ayar	2026-04-29 13:06:48.676+00	\N
1422	54	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:38:00+00	38	Ayar	2026-04-29 13:06:48.69+00	\N
1423	54	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:48.704+00	\N
1424	54	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:48.72+00	\N
1425	54	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:48.737+00	\N
1426	54	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:48.751+00	\N
1427	54	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:48.77+00	\N
1428	54	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:18:00+00	18	Ayar	2026-04-29 13:06:48.794+00	\N
1429	54	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:48.814+00	\N
1430	54	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:25:00+00	25	Parça Bekleme	2026-04-29 13:06:48.827+00	\N
1431	54	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:48.84+00	\N
1432	54	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:06:48.852+00	\N
1433	54	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:48.865+00	\N
1434	54	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:06:48.878+00	\N
1435	54	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:41:00+00	41	Ayar	2026-04-29 13:06:48.89+00	\N
1436	54	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:48.902+00	\N
1437	54	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:48.919+00	\N
1438	54	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:16:00+00	16	Ayar	2026-04-29 13:06:48.937+00	\N
1439	54	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:12:00+00	12	Ayar	2026-04-29 13:06:48.946+00	\N
1440	55	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:11:00+00	11	Mekanik Arıza	2026-04-29 13:06:48.957+00	\N
1441	55	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:48.969+00	\N
1442	55	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:57:00+00	57	Ayar	2026-04-29 13:06:48.98+00	\N
1443	55	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:48.992+00	\N
1444	55	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:49.003+00	\N
1445	55	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:49.013+00	\N
1446	55	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:06:49.026+00	\N
1447	55	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:04:00+00	4	Ayar	2026-04-29 13:06:49.041+00	\N
1448	55	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:49.055+00	\N
1449	55	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:49.067+00	\N
1450	55	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:49.079+00	\N
1451	55	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:06:49.094+00	\N
1452	55	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:49.108+00	\N
1453	55	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:19:00+00	19	Ayar	2026-04-29 13:06:49.125+00	\N
1454	55	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:49.14+00	\N
1455	55	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:49:00+00	49	Ayar	2026-04-29 13:06:49.153+00	\N
1456	55	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:49.169+00	\N
1457	55	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:39:00+00	39	Parça Bekleme	2026-04-29 13:06:49.186+00	\N
1458	55	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:49.204+00	\N
1459	55	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:49.222+00	\N
1460	55	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:24:00+00	24	Ayar	2026-04-29 13:06:49.237+00	\N
1461	55	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:49.252+00	\N
1462	55	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:49.268+00	\N
1463	55	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:06:49.283+00	\N
1464	55	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:21:00+00	21	Ayar	2026-04-29 13:06:49.3+00	\N
1465	55	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:09:00+00	9	Ayar	2026-04-29 13:06:49.315+00	\N
1466	55	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:19:00+00	19	Parça Bekleme	2026-04-29 13:06:49.328+00	\N
1467	55	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:25:00+00	25	Parça Bekleme	2026-04-29 13:06:49.338+00	\N
1468	55	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:49.35+00	\N
1469	55	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:49.362+00	\N
1470	56	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:51:00+00	51	Ayar	2026-04-29 13:06:49.374+00	\N
1471	56	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:49.388+00	\N
1472	56	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:49.401+00	\N
1473	56	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:01:00+00	1	Ayar	2026-04-29 13:06:49.414+00	\N
1474	56	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:49.425+00	\N
1475	56	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:49.438+00	\N
1476	56	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:49.451+00	\N
1477	56	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:54:00+00	54	Ayar	2026-04-29 13:06:49.465+00	\N
1478	56	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:49.479+00	\N
1479	56	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:49.491+00	\N
1480	56	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:49.502+00	\N
1481	56	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:59:00+00	59	Parça Bekleme	2026-04-29 13:06:49.521+00	\N
1482	56	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:49.532+00	\N
1483	56	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:49.543+00	\N
1484	56	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:41:00+00	41	Ayar	2026-04-29 13:06:49.555+00	\N
1485	56	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:49.568+00	\N
1486	56	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:49.581+00	\N
1487	56	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:11:00+00	11	Mekanik Arıza	2026-04-29 13:06:49.594+00	\N
1488	56	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:49.61+00	\N
1489	56	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:49.623+00	\N
1490	56	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:34:00+00	34	Parça Bekleme	2026-04-29 13:06:49.634+00	\N
1491	56	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:49.646+00	\N
1492	56	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:49.657+00	\N
1493	56	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:08:00+00	8	Ayar	2026-04-29 13:06:49.669+00	\N
1494	56	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:06:00+00	6	Ayar	2026-04-29 13:06:49.68+00	\N
1495	56	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:49.691+00	\N
1496	56	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:11:00+00	11	Mekanik Arıza	2026-04-29 13:06:49.702+00	\N
1497	56	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:53:00+00	53	Ayar	2026-04-29 13:06:49.714+00	\N
1498	56	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:20:00+00	20	Ayar	2026-04-29 13:06:49.724+00	\N
1499	57	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:55:00+00	55	Ayar	2026-04-29 13:06:49.734+00	\N
1500	57	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:49.744+00	\N
1501	57	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:39:00+00	39	Ayar	2026-04-29 13:06:49.755+00	\N
1502	57	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:49.766+00	\N
1503	57	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:49.778+00	\N
1504	57	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:06:49.788+00	\N
1505	57	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:49.796+00	\N
1506	57	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:53:00+00	53	Ayar	2026-04-29 13:06:49.806+00	\N
1507	57	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:04:00+00	4	Ayar	2026-04-29 13:06:49.819+00	\N
1508	57	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:49.831+00	\N
1509	57	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:49.844+00	\N
1510	57	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:49.859+00	\N
1511	57	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:49.876+00	\N
1512	57	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:49.895+00	\N
1513	57	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:03:00+00	3	Ayar	2026-04-29 13:06:49.908+00	\N
1514	57	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:49.923+00	\N
1515	57	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:49.935+00	\N
1516	57	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:49.955+00	\N
1517	57	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:27:00+00	27	Ayar	2026-04-29 13:06:49.972+00	\N
1518	57	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:46:00+00	46	Ayar	2026-04-29 13:06:49.987+00	\N
1519	57	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:49.998+00	\N
1520	57	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:50.009+00	\N
1521	57	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:50.02+00	\N
1522	57	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:50.032+00	\N
1523	57	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:37:00+00	37	Ayar	2026-04-29 13:06:50.041+00	\N
1524	57	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:50.05+00	\N
1525	57	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:49:00+00	49	Parça Bekleme	2026-04-29 13:06:50.06+00	\N
1526	57	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:50.07+00	\N
1527	57	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:50.08+00	\N
1528	58	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:50.089+00	\N
1529	58	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:06:50.099+00	\N
1530	58	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:52:00+00	52	Parça Bekleme	2026-04-29 13:06:50.108+00	\N
1531	58	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:57:00+00	57	Ayar	2026-04-29 13:06:50.118+00	\N
1532	58	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:50.127+00	\N
1533	58	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:07:00+00	7	Ayar	2026-04-29 13:06:50.138+00	\N
1534	58	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:38:00+00	38	Ayar	2026-04-29 13:06:50.149+00	\N
1535	58	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:54:00+00	54	Ayar	2026-04-29 13:06:50.159+00	\N
1536	58	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:50.169+00	\N
1537	58	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:42:00+00	42	Ayar	2026-04-29 13:06:50.181+00	\N
1538	58	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:19:00+00	19	Parça Bekleme	2026-04-29 13:06:50.195+00	\N
1539	58	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:50.22+00	\N
1540	58	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:50.233+00	\N
1541	58	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:50.244+00	\N
1542	58	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:50.257+00	\N
1543	58	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:50.268+00	\N
1544	58	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:50.279+00	\N
1545	58	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:06:50.29+00	\N
1546	58	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:01:00+00	1	Ayar	2026-04-29 13:06:50.302+00	\N
1547	58	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:50.314+00	\N
1548	58	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:50.332+00	\N
1549	58	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:38:00+00	38	Mekanik Arıza	2026-04-29 13:06:50.348+00	\N
1550	58	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:50.36+00	\N
1551	58	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:26:00+00	26	Ayar	2026-04-29 13:06:50.375+00	\N
1552	58	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:50.388+00	\N
1553	58	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:50.401+00	\N
1554	58	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:45:00+00	45	Ayar	2026-04-29 13:06:50.417+00	\N
1555	58	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:02:00+00	2	Ayar	2026-04-29 13:06:50.434+00	\N
1556	58	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:50.45+00	\N
1557	59	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:50.467+00	\N
1558	59	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 06:00:00+00	60	Ayar	2026-04-29 13:06:50.484+00	\N
1559	59	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:24:00+00	24	Ayar	2026-04-29 13:06:50.502+00	\N
1560	59	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:50.519+00	\N
1561	59	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:02:00+00	2	Ayar	2026-04-29 13:06:50.537+00	\N
1562	59	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:30:00+00	30	Ayar	2026-04-29 13:06:50.554+00	\N
1563	59	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:50.568+00	\N
1564	59	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:50.581+00	\N
1565	59	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:50.592+00	\N
1566	59	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:50.605+00	\N
1567	59	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:50.618+00	\N
1568	59	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:50.631+00	\N
1569	59	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:06:50.646+00	\N
1570	59	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:06:50.66+00	\N
1571	59	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:55:00+00	55	Ayar	2026-04-29 13:06:50.674+00	\N
1572	59	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:50.688+00	\N
1573	59	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:50.702+00	\N
1574	59	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:15:00+00	15	Parça Bekleme	2026-04-29 13:06:50.715+00	\N
1575	59	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:06:50.728+00	\N
1576	59	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:50.744+00	\N
1577	59	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:50.761+00	\N
1578	59	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:50.776+00	\N
1579	59	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:50.79+00	\N
1580	59	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:54:00+00	54	Ayar	2026-04-29 13:06:50.804+00	\N
1581	59	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:58:00+00	58	Ayar	2026-04-29 13:06:50.818+00	\N
1582	59	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:50.833+00	\N
1583	59	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:50.846+00	\N
1584	59	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:11:00+00	11	Ayar	2026-04-29 13:06:50.859+00	\N
1585	59	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:50.874+00	\N
1586	59	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:50.888+00	\N
1587	60	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:50.906+00	\N
1588	60	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:31:00+00	31	Mekanik Arıza	2026-04-29 13:06:50.923+00	\N
1589	60	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:41:00+00	41	Ayar	2026-04-29 13:06:50.939+00	\N
1590	60	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:26:00+00	26	Ayar	2026-04-29 13:06:50.956+00	\N
1591	60	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:06:50.973+00	\N
1592	60	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:50.985+00	\N
1593	60	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:50.995+00	\N
1594	60	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:51.005+00	\N
1595	60	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:56:00+00	56	Ayar	2026-04-29 13:06:51.017+00	\N
1596	60	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:09:00+00	9	Ayar	2026-04-29 13:06:51.03+00	\N
1597	60	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:51.042+00	\N
1598	60	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:51.055+00	\N
1599	60	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:51.071+00	\N
1600	60	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:36:00+00	36	Ayar	2026-04-29 13:06:51.088+00	\N
1601	60	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:51.104+00	\N
1602	60	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:31:00+00	31	Ayar	2026-04-29 13:06:51.121+00	\N
1603	60	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:35:00+00	35	Ayar	2026-04-29 13:06:51.139+00	\N
1604	60	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:51.157+00	\N
1605	60	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:40:00+00	40	Ayar	2026-04-29 13:06:51.174+00	\N
1606	60	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:51.191+00	\N
1607	60	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:51.207+00	\N
1608	60	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:27:00+00	27	Ayar	2026-04-29 13:06:51.222+00	\N
1609	60	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:51.239+00	\N
1610	60	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:57:00+00	57	Ayar	2026-04-29 13:06:51.254+00	\N
1611	60	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 06:00:00+00	60	Ayar	2026-04-29 13:06:51.268+00	\N
1612	60	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:51.282+00	\N
1613	60	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:51.297+00	\N
1614	60	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:51.312+00	\N
1615	60	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:51.332+00	\N
1616	61	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:57:00+00	57	Ayar	2026-04-29 13:06:51.343+00	\N
1617	61	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:27:00+00	27	Ayar	2026-04-29 13:06:51.356+00	\N
1618	61	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:06:51.369+00	\N
1619	61	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:51.384+00	\N
1620	61	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:51.398+00	\N
1621	61	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:51.411+00	\N
1622	61	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:51.423+00	\N
1623	61	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:51.439+00	\N
1624	61	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:21:00+00	21	Ayar	2026-04-29 13:06:51.454+00	\N
1625	61	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:51.473+00	\N
1626	61	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:15:00+00	15	Ayar	2026-04-29 13:06:51.494+00	\N
1627	61	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:51.514+00	\N
1628	61	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:51.535+00	\N
1629	61	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:17:00+00	17	Ayar	2026-04-29 13:06:51.553+00	\N
1630	61	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:33:00+00	33	Ayar	2026-04-29 13:06:51.571+00	\N
1631	61	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:51.588+00	\N
1632	61	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:51.608+00	\N
1633	61	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:47:00+00	47	Ayar	2026-04-29 13:06:51.629+00	\N
1634	61	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:38:00+00	38	Ayar	2026-04-29 13:06:51.648+00	\N
1635	61	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:06:51.667+00	\N
1636	61	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:51.685+00	\N
1637	61	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:51.703+00	\N
1638	61	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:51.722+00	\N
1639	61	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:18:00+00	18	Ayar	2026-04-29 13:06:51.739+00	\N
1640	61	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:51.755+00	\N
1641	61	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:51.772+00	\N
1642	61	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:24:00+00	24	Ayar	2026-04-29 13:06:51.787+00	\N
1643	61	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:51.804+00	\N
1644	61	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:31:00+00	31	Mekanik Arıza	2026-04-29 13:06:51.816+00	\N
1645	61	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:22:00+00	22	Ayar	2026-04-29 13:06:51.829+00	\N
1646	62	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:51.839+00	\N
1647	62	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:51.851+00	\N
1648	62	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:06:51.862+00	\N
1649	62	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:51.871+00	\N
1650	62	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:56:00+00	56	Ayar	2026-04-29 13:06:51.88+00	\N
1651	62	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:51.895+00	\N
1652	62	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:06:51.904+00	\N
1653	62	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:51.913+00	\N
1654	62	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:51.923+00	\N
1655	62	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:59:00+00	59	Ayar	2026-04-29 13:06:51.933+00	\N
1656	62	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:26:00+00	26	Ayar	2026-04-29 13:06:51.944+00	\N
1657	62	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:22:00+00	22	Parça Bekleme	2026-04-29 13:06:51.957+00	\N
1658	62	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:51.97+00	\N
1659	62	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:51.984+00	\N
1660	62	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:04:00+00	4	Ayar	2026-04-29 13:06:51.999+00	\N
1661	62	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:01:00+00	1	Ayar	2026-04-29 13:06:52.014+00	\N
1662	62	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:16:00+00	16	Ayar	2026-04-29 13:06:52.029+00	\N
1663	62	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:52.045+00	\N
1664	62	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:52.06+00	\N
1665	62	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:52.083+00	\N
1666	62	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:52.097+00	\N
1667	62	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:50:00+00	50	Ayar	2026-04-29 13:06:52.11+00	\N
1668	62	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:46:00+00	46	Ayar	2026-04-29 13:06:52.123+00	\N
1669	62	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:52.135+00	\N
1670	62	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:52.147+00	\N
1671	62	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:52.159+00	\N
1672	62	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:50:00+00	50	Ayar	2026-04-29 13:06:52.171+00	\N
1673	62	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:34:00+00	34	Ayar	2026-04-29 13:06:52.182+00	\N
1674	63	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:52.194+00	\N
1675	63	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:38:00+00	38	Ayar	2026-04-29 13:06:52.207+00	\N
1676	63	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:52.219+00	\N
1677	63	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:52.232+00	\N
1678	63	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:52.246+00	\N
1679	63	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:13:00+00	13	Ayar	2026-04-29 13:06:52.261+00	\N
1680	63	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:24:00+00	24	Ayar	2026-04-29 13:06:52.274+00	\N
1681	63	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:52.287+00	\N
1682	63	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:52:00+00	52	Parça Bekleme	2026-04-29 13:06:52.299+00	\N
1683	63	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:52.31+00	\N
1684	63	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:58:00+00	58	Ayar	2026-04-29 13:06:52.323+00	\N
1685	63	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:06:52.333+00	\N
1686	63	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:09:00+00	9	Ayar	2026-04-29 13:06:52.343+00	\N
1687	63	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:39:00+00	39	Ayar	2026-04-29 13:06:52.353+00	\N
1688	63	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:52.364+00	\N
1689	63	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:52.374+00	\N
1690	63	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:52.384+00	\N
1691	63	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:52.395+00	\N
1692	63	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:52.405+00	\N
1693	63	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:52.419+00	\N
1694	63	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:10:00+00	10	Ayar	2026-04-29 13:06:52.43+00	\N
1695	63	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:06:52.44+00	\N
1696	63	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:06:52.45+00	\N
1697	63	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:20:00+00	20	Parça Bekleme	2026-04-29 13:06:52.461+00	\N
1698	63	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:52.475+00	\N
1699	63	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:52.486+00	\N
1700	63	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:52.498+00	\N
1701	63	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:27:00+00	27	Ayar	2026-04-29 13:06:52.51+00	\N
1702	63	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:52.522+00	\N
1703	63	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:52.533+00	\N
1704	64	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:59:00+00	59	Parça Bekleme	2026-04-29 13:06:52.544+00	\N
1705	64	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:02:00+00	2	Mekanik Arıza	2026-04-29 13:06:52.554+00	\N
1706	64	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:52.564+00	\N
1707	64	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:49:00+00	49	Ayar	2026-04-29 13:06:52.575+00	\N
1708	64	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:52.585+00	\N
1709	64	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:24:00+00	24	Ayar	2026-04-29 13:06:52.594+00	\N
1710	64	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:53:00+00	53	Ayar	2026-04-29 13:06:52.605+00	\N
1711	64	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:10:00+00	10	Ayar	2026-04-29 13:06:52.621+00	\N
1712	64	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:52.631+00	\N
1713	64	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:06:52.643+00	\N
1714	64	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:52.654+00	\N
1715	64	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:52.666+00	\N
1716	64	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:51:00+00	51	Ayar	2026-04-29 13:06:52.676+00	\N
1717	64	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:06:52.686+00	\N
1718	64	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:52.696+00	\N
1719	64	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:52.708+00	\N
1720	64	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:06:52.72+00	\N
1721	64	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:31:00+00	31	Parça Bekleme	2026-04-29 13:06:52.733+00	\N
1722	64	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:53:00+00	53	Ayar	2026-04-29 13:06:52.745+00	\N
1723	64	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:51:00+00	51	Ayar	2026-04-29 13:06:52.758+00	\N
1724	64	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:52.771+00	\N
1725	64	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:52.783+00	\N
1726	64	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:14:00+00	14	Ayar	2026-04-29 13:06:52.795+00	\N
1727	64	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:25:00+00	25	Ayar	2026-04-29 13:06:52.806+00	\N
1728	64	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:26:00+00	26	Ayar	2026-04-29 13:06:52.821+00	\N
1729	64	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:52.836+00	\N
1730	64	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:38:00+00	38	Ayar	2026-04-29 13:06:52.848+00	\N
1731	64	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:31:00+00	31	Mekanik Arıza	2026-04-29 13:06:52.862+00	\N
1732	64	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:21:00+00	21	Ayar	2026-04-29 13:06:52.877+00	\N
1733	65	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:52.891+00	\N
1734	65	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:52.904+00	\N
1735	65	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:52.914+00	\N
1736	65	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:52.925+00	\N
1737	65	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:17:00+00	17	Ayar	2026-04-29 13:06:52.936+00	\N
1738	65	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:06:52.946+00	\N
1739	65	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:52.955+00	\N
1740	65	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:52.965+00	\N
1741	65	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:12:00+00	12	Parça Bekleme	2026-04-29 13:06:52.974+00	\N
1742	65	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:31:00+00	31	Ayar	2026-04-29 13:06:52.983+00	\N
1743	65	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:29:00+00	29	Ayar	2026-04-29 13:06:52.994+00	\N
1744	65	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:23:00+00	23	Ayar	2026-04-29 13:06:53.003+00	\N
1745	65	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:53.013+00	\N
1746	65	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:48:00+00	48	Ayar	2026-04-29 13:06:53.021+00	\N
1747	65	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:14:00+00	14	Ayar	2026-04-29 13:06:53.03+00	\N
1748	65	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:53.039+00	\N
1749	65	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:53.047+00	\N
1750	65	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:38:00+00	38	Ayar	2026-04-29 13:06:53.057+00	\N
1751	65	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:06:53.071+00	\N
1752	65	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:53.081+00	\N
1753	65	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:53.089+00	\N
1754	65	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:41:00+00	41	Ayar	2026-04-29 13:06:53.099+00	\N
1755	65	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:41:00+00	41	Ayar	2026-04-29 13:06:53.108+00	\N
1756	65	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:53.116+00	\N
1757	65	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:53.125+00	\N
1758	65	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:47:00+00	47	Ayar	2026-04-29 13:06:53.133+00	\N
1759	65	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:39:00+00	39	Ayar	2026-04-29 13:06:53.142+00	\N
1760	65	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:22:00+00	22	Parça Bekleme	2026-04-29 13:06:53.152+00	\N
1761	65	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:56:00+00	56	Ayar	2026-04-29 13:06:53.163+00	\N
1762	66	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:53.174+00	\N
1763	66	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:53.186+00	\N
1764	66	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:22:00+00	22	Ayar	2026-04-29 13:06:53.197+00	\N
1765	66	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:06:53.209+00	\N
1766	66	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:53.222+00	\N
1767	66	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:53.233+00	\N
1768	66	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:17:00+00	17	Parça Bekleme	2026-04-29 13:06:53.248+00	\N
1769	66	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:12:00+00	12	Ayar	2026-04-29 13:06:53.259+00	\N
1770	66	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:06:53.269+00	\N
1771	66	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:23:00+00	23	Ayar	2026-04-29 13:06:53.28+00	\N
1772	66	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:18:00+00	18	Ayar	2026-04-29 13:06:53.293+00	\N
1773	66	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:06:53.304+00	\N
1774	66	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:53.315+00	\N
1775	66	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:12:00+00	12	Ayar	2026-04-29 13:06:53.327+00	\N
1776	66	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:25:00+00	25	Ayar	2026-04-29 13:06:53.338+00	\N
1777	66	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:53.35+00	\N
1778	66	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:53.362+00	\N
1779	66	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:53.372+00	\N
1780	66	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:53.384+00	\N
1781	66	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:54:00+00	54	Ayar	2026-04-29 13:06:53.395+00	\N
1782	66	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:53.408+00	\N
1783	66	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:34:00+00	34	Ayar	2026-04-29 13:06:53.422+00	\N
1784	66	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:26:00+00	26	Ayar	2026-04-29 13:06:53.438+00	\N
1785	66	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:33:00+00	33	Ayar	2026-04-29 13:06:53.453+00	\N
1786	66	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:16:00+00	16	Ayar	2026-04-29 13:06:53.467+00	\N
1787	66	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:18:00+00	18	Ayar	2026-04-29 13:06:53.481+00	\N
1788	66	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:06:53.496+00	\N
1789	66	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:08:00+00	8	Ayar	2026-04-29 13:06:53.51+00	\N
1790	66	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:05:00+00	5	Ayar	2026-04-29 13:06:53.524+00	\N
1791	66	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:06:53.54+00	\N
1792	67	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:53.551+00	\N
1793	67	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:53.561+00	\N
1794	67	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:16:00+00	16	Ayar	2026-04-29 13:06:53.572+00	\N
1795	67	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:53.582+00	\N
1796	67	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:53.591+00	\N
1797	67	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:53.6+00	\N
1798	67	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:26:00+00	26	Ayar	2026-04-29 13:06:53.609+00	\N
1799	67	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:29:00+00	29	Ayar	2026-04-29 13:06:53.621+00	\N
1800	67	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:53.635+00	\N
1801	67	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:39:00+00	39	Ayar	2026-04-29 13:06:53.646+00	\N
1802	67	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:58:00+00	58	Ayar	2026-04-29 13:06:53.66+00	\N
1803	67	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:07:00+00	7	Ayar	2026-04-29 13:06:53.671+00	\N
1804	67	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:53.683+00	\N
1805	67	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:53.694+00	\N
1806	67	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:53.705+00	\N
1807	67	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:06:53.717+00	\N
1808	67	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:53.729+00	\N
1809	67	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:53.743+00	\N
1810	67	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:53.756+00	\N
1811	67	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:19:00+00	19	Mekanik Arıza	2026-04-29 13:06:53.775+00	\N
1812	67	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:53.787+00	\N
1813	67	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:10:00+00	10	Ayar	2026-04-29 13:06:53.802+00	\N
1814	67	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:41:00+00	41	Ayar	2026-04-29 13:06:53.818+00	\N
1815	67	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:43:00+00	43	Ayar	2026-04-29 13:06:53.836+00	\N
1816	67	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:53.85+00	\N
1817	67	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:45:00+00	45	Ayar	2026-04-29 13:06:53.862+00	\N
1818	67	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:38:00+00	38	Parça Bekleme	2026-04-29 13:06:53.873+00	\N
1819	67	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:11:00+00	11	Ayar	2026-04-29 13:06:53.884+00	\N
1820	67	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:54:00+00	54	Ayar	2026-04-29 13:06:53.895+00	\N
1821	68	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:01:00+00	1	Parça Bekleme	2026-04-29 13:06:53.908+00	\N
1822	68	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:06:53.922+00	\N
1823	68	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 06:00:00+00	60	Ayar	2026-04-29 13:06:53.934+00	\N
1824	68	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:53.947+00	\N
1825	68	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:53.958+00	\N
1826	68	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:55:00+00	55	Parça Bekleme	2026-04-29 13:06:53.969+00	\N
1827	68	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:53.98+00	\N
1828	68	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:53.991+00	\N
1829	68	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:21:00+00	21	Ayar	2026-04-29 13:06:54.004+00	\N
1830	68	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:06:54.016+00	\N
1831	68	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:54.028+00	\N
1832	68	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:54.04+00	\N
1833	68	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:09:00+00	9	Ayar	2026-04-29 13:06:54.054+00	\N
1834	68	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:54.068+00	\N
1835	68	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:10:00+00	10	Parça Bekleme	2026-04-29 13:06:54.082+00	\N
1836	68	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:38:00+00	38	Parça Bekleme	2026-04-29 13:06:54.095+00	\N
1837	68	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:06:54.108+00	\N
1838	68	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:35:00+00	35	Ayar	2026-04-29 13:06:54.119+00	\N
1839	68	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:54.13+00	\N
1840	68	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:43:00+00	43	Ayar	2026-04-29 13:06:54.141+00	\N
1841	68	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:07:00+00	7	Ayar	2026-04-29 13:06:54.152+00	\N
1842	68	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:54.171+00	\N
1843	68	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:54.187+00	\N
1844	68	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:54.199+00	\N
1845	68	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:36:00+00	36	Ayar	2026-04-29 13:06:54.212+00	\N
1846	68	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:06:00+00	6	Parça Bekleme	2026-04-29 13:06:54.224+00	\N
1847	68	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:41:00+00	41	Ayar	2026-04-29 13:06:54.237+00	\N
1848	68	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:56:00+00	56	Ayar	2026-04-29 13:06:54.249+00	\N
1849	68	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:54.263+00	\N
1850	69	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:54.275+00	\N
1851	69	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:11:00+00	11	Ayar	2026-04-29 13:06:54.287+00	\N
1852	69	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:24:00+00	24	Ayar	2026-04-29 13:06:54.299+00	\N
1853	69	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:54.311+00	\N
1854	69	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:17:00+00	17	Ayar	2026-04-29 13:06:54.324+00	\N
1855	69	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:54.336+00	\N
1856	69	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:06:54.349+00	\N
1857	69	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:33:00+00	33	Ayar	2026-04-29 13:06:54.36+00	\N
1858	69	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:54.374+00	\N
1859	69	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:54.385+00	\N
1860	69	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:54.397+00	\N
1861	69	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:20:00+00	20	Ayar	2026-04-29 13:06:54.408+00	\N
1862	69	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:59:00+00	59	Ayar	2026-04-29 13:06:54.423+00	\N
1863	69	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:54.435+00	\N
1864	69	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:54.455+00	\N
1865	69	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:54.466+00	\N
1866	69	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:54.479+00	\N
1867	69	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:50:00+00	50	Ayar	2026-04-29 13:06:54.558+00	\N
1868	69	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:54.578+00	\N
1869	69	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:07:00+00	7	Ayar	2026-04-29 13:06:54.594+00	\N
1870	69	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:55:00+00	55	Ayar	2026-04-29 13:06:54.606+00	\N
1871	69	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:25:00+00	25	Parça Bekleme	2026-04-29 13:06:54.617+00	\N
1872	69	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:06:54.629+00	\N
1873	69	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:29:00+00	29	Ayar	2026-04-29 13:06:54.642+00	\N
1874	69	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:27:00+00	27	Ayar	2026-04-29 13:06:54.655+00	\N
1875	69	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:54.672+00	\N
1876	69	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:59:00+00	59	Ayar	2026-04-29 13:06:54.693+00	\N
1877	69	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:54.714+00	\N
1878	69	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:14:00+00	14	Ayar	2026-04-29 13:06:54.734+00	\N
1879	70	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:43:00+00	43	Ayar	2026-04-29 13:06:54.751+00	\N
1880	70	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:20:00+00	20	Parça Bekleme	2026-04-29 13:06:54.777+00	\N
1881	70	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:21:00+00	21	Ayar	2026-04-29 13:06:54.8+00	\N
1882	70	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:19:00+00	19	Parça Bekleme	2026-04-29 13:06:54.816+00	\N
1883	70	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:29:00+00	29	Ayar	2026-04-29 13:06:54.833+00	\N
1884	70	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:22:00+00	22	Ayar	2026-04-29 13:06:54.845+00	\N
1885	70	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:54.859+00	\N
1886	70	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:38:00+00	38	Ayar	2026-04-29 13:06:54.87+00	\N
1887	70	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:54.881+00	\N
1888	70	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:54.895+00	\N
1889	70	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:52:00+00	52	Parça Bekleme	2026-04-29 13:06:54.912+00	\N
1890	70	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:11:00+00	11	Ayar	2026-04-29 13:06:54.928+00	\N
1891	70	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:54.955+00	\N
1892	70	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:11:00+00	11	Mekanik Arıza	2026-04-29 13:06:54.971+00	\N
1893	70	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:54.994+00	\N
1894	70	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:55.011+00	\N
1895	70	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:34:00+00	34	Ayar	2026-04-29 13:06:55.028+00	\N
1896	70	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:01:00+00	1	Parça Bekleme	2026-04-29 13:06:55.044+00	\N
1897	70	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:55.061+00	\N
1898	70	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:31:00+00	31	Mekanik Arıza	2026-04-29 13:06:55.077+00	\N
1899	70	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:55.096+00	\N
1900	70	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:06:55.114+00	\N
1901	70	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:53:00+00	53	Ayar	2026-04-29 13:06:55.132+00	\N
1902	70	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:09:00+00	9	Ayar	2026-04-29 13:06:55.149+00	\N
1903	70	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:53:00+00	53	Ayar	2026-04-29 13:06:55.166+00	\N
1904	70	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:55.184+00	\N
1905	70	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:14:00+00	14	Ayar	2026-04-29 13:06:55.204+00	\N
1906	70	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:55.225+00	\N
1907	70	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:55.245+00	\N
1908	71	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:13:00+00	13	Parça Bekleme	2026-04-29 13:06:55.264+00	\N
1909	71	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:52:00+00	52	Ayar	2026-04-29 13:06:55.281+00	\N
1910	71	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:55.298+00	\N
1911	71	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:24:00+00	24	Ayar	2026-04-29 13:06:55.315+00	\N
1912	71	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:22:00+00	22	Ayar	2026-04-29 13:06:55.332+00	\N
1913	71	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:55.35+00	\N
1914	71	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:34:00+00	34	Parça Bekleme	2026-04-29 13:06:55.369+00	\N
1915	71	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:55.387+00	\N
1916	71	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:55.405+00	\N
1917	71	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:43:00+00	43	Parça Bekleme	2026-04-29 13:06:55.422+00	\N
1918	71	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:55.44+00	\N
1919	71	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:55.457+00	\N
1920	71	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:22:00+00	22	Parça Bekleme	2026-04-29 13:06:55.477+00	\N
1921	71	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:29:00+00	29	Ayar	2026-04-29 13:06:55.499+00	\N
1922	71	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:55.52+00	\N
1923	71	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:58:00+00	58	Ayar	2026-04-29 13:06:55.543+00	\N
1924	71	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:55.565+00	\N
1925	71	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:34:00+00	34	Ayar	2026-04-29 13:06:55.587+00	\N
1926	71	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:23:00+00	23	Ayar	2026-04-29 13:06:55.608+00	\N
1927	71	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:15:00+00	15	Ayar	2026-04-29 13:06:55.628+00	\N
1928	71	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:55.645+00	\N
1929	71	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:55.662+00	\N
1930	71	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 06:00:00+00	60	Parça Bekleme	2026-04-29 13:06:55.684+00	\N
1931	71	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:25:00+00	25	Parça Bekleme	2026-04-29 13:06:55.706+00	\N
1932	71	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:06:00+00	6	Ayar	2026-04-29 13:06:55.725+00	\N
1933	71	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:45:00+00	45	Parça Bekleme	2026-04-29 13:06:55.741+00	\N
1934	71	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:55.752+00	\N
1935	71	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:11:00+00	11	Ayar	2026-04-29 13:06:55.765+00	\N
1936	71	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:40:00+00	40	Parça Bekleme	2026-04-29 13:06:55.775+00	\N
1937	71	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:55.788+00	\N
1938	72	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:55.802+00	\N
1939	72	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:55.816+00	\N
1940	72	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:48:00+00	48	Ayar	2026-04-29 13:06:55.834+00	\N
1941	72	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:55.849+00	\N
1942	72	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:06:55.868+00	\N
1943	72	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:55.885+00	\N
1944	72	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:55.901+00	\N
1945	72	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:34:00+00	34	Parça Bekleme	2026-04-29 13:06:55.915+00	\N
1946	72	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:06:55.931+00	\N
1947	72	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:55.949+00	\N
1948	72	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:06:55.966+00	\N
1949	72	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:53:00+00	53	Ayar	2026-04-29 13:06:55.983+00	\N
1950	72	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:45:00+00	45	Ayar	2026-04-29 13:06:56.001+00	\N
1951	72	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:36:00+00	36	Ayar	2026-04-29 13:06:56.017+00	\N
1952	72	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:06:56.04+00	\N
1953	72	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:56.056+00	\N
1954	72	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:52:00+00	52	Ayar	2026-04-29 13:06:56.073+00	\N
1955	72	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:56.088+00	\N
1956	72	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:34:00+00	34	Ayar	2026-04-29 13:06:56.103+00	\N
1957	72	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:50:00+00	50	Ayar	2026-04-29 13:06:56.119+00	\N
1958	72	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:56.135+00	\N
1959	72	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:47:00+00	47	Parça Bekleme	2026-04-29 13:06:56.154+00	\N
1960	72	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:20:00+00	20	Ayar	2026-04-29 13:06:56.17+00	\N
1961	72	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:56.185+00	\N
1962	72	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:56.202+00	\N
1963	72	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:56.22+00	\N
1964	72	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:56:00+00	56	Ayar	2026-04-29 13:06:56.235+00	\N
1965	72	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:56.249+00	\N
1966	72	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:56.262+00	\N
1967	73	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:56.287+00	\N
1968	73	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:21:00+00	21	Parça Bekleme	2026-04-29 13:06:56.302+00	\N
1969	73	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:47:00+00	47	Ayar	2026-04-29 13:06:56.317+00	\N
1970	73	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:56.333+00	\N
1971	73	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:56.348+00	\N
1972	73	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:56.362+00	\N
1973	73	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:06:56.378+00	\N
1974	73	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:06:56.392+00	\N
1975	73	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:56.407+00	\N
1976	73	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:56.421+00	\N
1977	73	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:28:00+00	28	Ayar	2026-04-29 13:06:56.435+00	\N
1978	73	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:56.449+00	\N
1979	73	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:06:56.463+00	\N
1980	73	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:56.476+00	\N
1981	73	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:42:00+00	42	Ayar	2026-04-29 13:06:56.49+00	\N
1982	73	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:13:00+00	13	Ayar	2026-04-29 13:06:56.503+00	\N
1983	73	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:08:00+00	8	Ayar	2026-04-29 13:06:56.525+00	\N
1984	73	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:39:00+00	39	Parça Bekleme	2026-04-29 13:06:56.54+00	\N
1985	73	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:56.555+00	\N
1986	73	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:56:00+00	56	Ayar	2026-04-29 13:06:56.572+00	\N
1987	73	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:31:00+00	31	Ayar	2026-04-29 13:06:56.587+00	\N
1988	73	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:16:00+00	16	Parça Bekleme	2026-04-29 13:06:56.613+00	\N
1989	73	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:54:00+00	54	Ayar	2026-04-29 13:06:56.628+00	\N
1990	73	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:56.641+00	\N
1991	73	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:56.656+00	\N
1992	73	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:06:56.669+00	\N
1993	73	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:56.681+00	\N
1994	73	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:56.693+00	\N
1995	74	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:56.705+00	\N
1996	74	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:10:00+00	10	Ayar	2026-04-29 13:06:56.718+00	\N
1997	74	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:56.728+00	\N
1998	74	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:33:00+00	33	Ayar	2026-04-29 13:06:56.738+00	\N
1999	74	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:56.746+00	\N
2000	74	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:56.755+00	\N
2001	74	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:06:56.766+00	\N
2002	74	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:50:00+00	50	Ayar	2026-04-29 13:06:56.78+00	\N
2003	74	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:58:00+00	58	Ayar	2026-04-29 13:06:56.795+00	\N
2004	74	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:06:56.809+00	\N
2005	74	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:56.825+00	\N
2006	74	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:56.841+00	\N
2007	74	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:56.854+00	\N
2008	74	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:56.868+00	\N
2009	74	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:56.882+00	\N
2010	74	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:39:00+00	39	Ayar	2026-04-29 13:06:56.898+00	\N
2011	74	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:56.913+00	\N
2012	74	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:56.93+00	\N
2013	74	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:01:00+00	1	Parça Bekleme	2026-04-29 13:06:56.943+00	\N
2014	74	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:06:56.956+00	\N
2015	74	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:33:00+00	33	Ayar	2026-04-29 13:06:56.971+00	\N
2016	74	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:56:00+00	56	Parça Bekleme	2026-04-29 13:06:56.986+00	\N
2017	74	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:06:57.001+00	\N
2018	74	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:58:00+00	58	Parça Bekleme	2026-04-29 13:06:57.015+00	\N
2019	74	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:57.028+00	\N
2020	74	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:54:00+00	54	Ayar	2026-04-29 13:06:57.041+00	\N
2021	74	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:57.054+00	\N
2022	74	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:57.066+00	\N
2023	74	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:01:00+00	1	Parça Bekleme	2026-04-29 13:06:57.079+00	\N
2024	74	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:57.091+00	\N
2025	75	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:57.101+00	\N
2026	75	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:06:57.113+00	\N
2027	75	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:06:57.124+00	\N
2028	75	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:43:00+00	43	Ayar	2026-04-29 13:06:57.137+00	\N
2029	75	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:33:00+00	33	Ayar	2026-04-29 13:06:57.15+00	\N
2030	75	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:06:57.161+00	\N
2031	75	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:46:00+00	46	Ayar	2026-04-29 13:06:57.17+00	\N
2032	75	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:06:57.18+00	\N
2033	75	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:50:00+00	50	Parça Bekleme	2026-04-29 13:06:57.191+00	\N
2034	75	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:57.203+00	\N
2035	75	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:06:57.215+00	\N
2036	75	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:58:00+00	58	Ayar	2026-04-29 13:06:57.225+00	\N
2037	75	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:06:57.234+00	\N
2038	75	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:55:00+00	55	Ayar	2026-04-29 13:06:57.244+00	\N
2039	75	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:15:00+00	15	Ayar	2026-04-29 13:06:57.255+00	\N
2040	75	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:57.266+00	\N
2041	75	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:32:00+00	32	Ayar	2026-04-29 13:06:57.281+00	\N
2042	75	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:31:00+00	31	Parça Bekleme	2026-04-29 13:06:57.315+00	\N
2043	75	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:57.329+00	\N
2044	75	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:06:57.344+00	\N
2045	75	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:02:00+00	2	Mekanik Arıza	2026-04-29 13:06:57.357+00	\N
2046	75	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:43:00+00	43	Parça Bekleme	2026-04-29 13:06:57.372+00	\N
2047	75	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:06:57.385+00	\N
2048	75	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:42:00+00	42	Ayar	2026-04-29 13:06:57.397+00	\N
2049	75	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:37:00+00	37	Ayar	2026-04-29 13:06:57.408+00	\N
2050	75	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:04:00+00	4	Parça Bekleme	2026-04-29 13:06:57.421+00	\N
2051	75	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:57.436+00	\N
2052	75	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:42:00+00	42	Ayar	2026-04-29 13:06:57.452+00	\N
2053	75	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:06:00+00	6	Ayar	2026-04-29 13:06:57.465+00	\N
2054	75	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:57.478+00	\N
2055	76	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:57.493+00	\N
2056	76	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:57.508+00	\N
2057	76	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:57.519+00	\N
2058	76	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:57.529+00	\N
2059	76	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:57.539+00	\N
2060	76	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:24:00+00	24	Ayar	2026-04-29 13:06:57.55+00	\N
2061	76	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:01:00+00	1	Ayar	2026-04-29 13:06:57.563+00	\N
2062	76	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:57.577+00	\N
2063	76	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:59:00+00	59	Ayar	2026-04-29 13:06:57.59+00	\N
2064	76	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:57.605+00	\N
2065	76	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:57.622+00	\N
2066	76	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:12:00+00	12	Ayar	2026-04-29 13:06:57.64+00	\N
2067	76	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:40:00+00	40	Parça Bekleme	2026-04-29 13:06:57.657+00	\N
2068	76	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:57.671+00	\N
2069	76	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:06:57.689+00	\N
2070	76	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:57.705+00	\N
2071	76	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:57.719+00	\N
2072	76	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:57:00+00	57	Parça Bekleme	2026-04-29 13:06:57.732+00	\N
2073	76	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:30:00+00	30	Ayar	2026-04-29 13:06:57.743+00	\N
2074	76	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:56:00+00	56	Ayar	2026-04-29 13:06:57.754+00	\N
2075	76	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:47:00+00	47	Ayar	2026-04-29 13:06:57.766+00	\N
2076	76	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:57.778+00	\N
2077	76	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:21:00+00	21	Ayar	2026-04-29 13:06:57.79+00	\N
2078	76	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:39:00+00	39	Ayar	2026-04-29 13:06:57.801+00	\N
2079	76	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:57.811+00	\N
2080	76	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:16:00+00	16	Ayar	2026-04-29 13:06:57.823+00	\N
2081	76	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:57.837+00	\N
2082	76	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:46:00+00	46	Parça Bekleme	2026-04-29 13:06:57.85+00	\N
2083	76	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:15:00+00	15	Ayar	2026-04-29 13:06:57.864+00	\N
2084	76	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:57.878+00	\N
2085	77	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:57.891+00	\N
2086	77	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:06:57.905+00	\N
2087	77	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:37:00+00	37	Parça Bekleme	2026-04-29 13:06:57.919+00	\N
2088	77	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:32:00+00	32	Ayar	2026-04-29 13:06:57.935+00	\N
2089	77	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:57.95+00	\N
2090	77	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:06:57.961+00	\N
2091	77	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:29:00+00	29	Parça Bekleme	2026-04-29 13:06:57.97+00	\N
2092	77	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:55:00+00	55	Ayar	2026-04-29 13:06:57.981+00	\N
2093	77	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:57.991+00	\N
2094	77	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:58+00	\N
2095	77	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:47:00+00	47	Ayar	2026-04-29 13:06:58.01+00	\N
2096	77	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:20:00+00	20	Parça Bekleme	2026-04-29 13:06:58.02+00	\N
2097	77	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:58:00+00	58	Ayar	2026-04-29 13:06:58.03+00	\N
2098	77	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:21:00+00	21	Ayar	2026-04-29 13:06:58.04+00	\N
2099	77	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:07:00+00	7	Parça Bekleme	2026-04-29 13:06:58.052+00	\N
2100	77	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:11:00+00	11	Parça Bekleme	2026-04-29 13:06:58.065+00	\N
2101	77	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:58.08+00	\N
2102	77	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:58.093+00	\N
2103	77	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:58.105+00	\N
2104	77	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:58.115+00	\N
2105	77	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:49:00+00	49	Parça Bekleme	2026-04-29 13:06:58.127+00	\N
2106	77	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:19:00+00	19	Parça Bekleme	2026-04-29 13:06:58.137+00	\N
2107	77	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:06:58.151+00	\N
2108	77	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:54:00+00	54	Ayar	2026-04-29 13:06:58.163+00	\N
2109	77	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:53:00+00	53	Parça Bekleme	2026-04-29 13:06:58.176+00	\N
2110	77	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:58.189+00	\N
2111	77	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 06:00:00+00	60	Ayar	2026-04-29 13:06:58.201+00	\N
2112	77	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:26:00+00	26	Ayar	2026-04-29 13:06:58.212+00	\N
2113	77	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:58.223+00	\N
2114	77	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:48:00+00	48	Ayar	2026-04-29 13:06:58.234+00	\N
2115	78	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:58.247+00	\N
2116	78	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:42:00+00	42	Ayar	2026-04-29 13:06:58.258+00	\N
2117	78	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:06:58.269+00	\N
2118	78	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:40:00+00	40	Parça Bekleme	2026-04-29 13:06:58.281+00	\N
2119	78	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:58.292+00	\N
2120	78	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:06:58.304+00	\N
2121	78	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:06:58.317+00	\N
2122	78	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:41:00+00	41	Ayar	2026-04-29 13:06:58.329+00	\N
2123	78	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:06:58.341+00	\N
2124	78	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:05:00+00	5	Parça Bekleme	2026-04-29 13:06:58.354+00	\N
2125	78	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:16:00+00	16	Ayar	2026-04-29 13:06:58.366+00	\N
2126	78	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:19:00+00	19	Ayar	2026-04-29 13:06:58.378+00	\N
2127	78	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:58.39+00	\N
2128	78	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:58.405+00	\N
2129	78	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:58.419+00	\N
2130	78	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:51:00+00	51	Parça Bekleme	2026-04-29 13:06:58.431+00	\N
2131	78	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:06:58.444+00	\N
2132	78	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:04:00+00	4	Ayar	2026-04-29 13:06:58.456+00	\N
2133	78	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:35:00+00	35	Ayar	2026-04-29 13:06:58.469+00	\N
2134	78	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:13:00+00	13	Parça Bekleme	2026-04-29 13:06:58.482+00	\N
2135	78	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:48:00+00	48	Parça Bekleme	2026-04-29 13:06:58.496+00	\N
2136	78	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:49:00+00	49	Ayar	2026-04-29 13:06:58.508+00	\N
2137	78	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:47:00+00	47	Ayar	2026-04-29 13:06:58.519+00	\N
2138	78	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:58.53+00	\N
2139	78	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:26:00+00	26	Ayar	2026-04-29 13:06:58.542+00	\N
2140	78	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:03:00+00	3	Parça Bekleme	2026-04-29 13:06:58.553+00	\N
2141	78	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:06:58.566+00	\N
2142	78	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:06:58.577+00	\N
2143	78	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:02:00+00	2	Parça Bekleme	2026-04-29 13:06:58.589+00	\N
2144	78	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:58.601+00	\N
2145	79	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:23:00+00	23	Parça Bekleme	2026-04-29 13:06:58.613+00	\N
2146	79	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:58.63+00	\N
2147	79	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:26:00+00	26	Parça Bekleme	2026-04-29 13:06:58.643+00	\N
2148	79	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:06:58.655+00	\N
2149	79	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:58.669+00	\N
2150	79	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:01:00+00	1	Ayar	2026-04-29 13:06:58.682+00	\N
2151	79	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:03:00+00	3	Ayar	2026-04-29 13:06:58.693+00	\N
2152	79	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:58.706+00	\N
2153	79	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:55:00+00	55	Ayar	2026-04-29 13:06:58.72+00	\N
2154	79	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:15:00+00	15	Parça Bekleme	2026-04-29 13:06:58.733+00	\N
2155	79	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:50:00+00	50	Ayar	2026-04-29 13:06:58.744+00	\N
2156	79	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:24:00+00	24	Ayar	2026-04-29 13:06:58.754+00	\N
2157	79	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:27:00+00	27	Parça Bekleme	2026-04-29 13:06:58.771+00	\N
2158	79	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:58.783+00	\N
2159	79	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:06:58.801+00	\N
2160	79	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:58:00+00	58	Ayar	2026-04-29 13:06:58.821+00	\N
2161	79	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:58.837+00	\N
2162	79	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:06:58.851+00	\N
2163	79	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:43:00+00	43	Parça Bekleme	2026-04-29 13:06:58.866+00	\N
2164	79	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:58.884+00	\N
2165	79	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:58.902+00	\N
2166	79	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:11:00+00	11	Mekanik Arıza	2026-04-29 13:06:58.923+00	\N
2167	79	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:44:00+00	44	Ayar	2026-04-29 13:06:58.945+00	\N
2168	79	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:09:00+00	9	Parça Bekleme	2026-04-29 13:06:58.962+00	\N
2169	79	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:58.975+00	\N
2170	79	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:24:00+00	24	Ayar	2026-04-29 13:06:58.989+00	\N
2171	79	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:34:00+00	34	Ayar	2026-04-29 13:06:59.002+00	\N
2172	79	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:41:00+00	41	Parça Bekleme	2026-04-29 13:06:59.016+00	\N
2173	79	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:24:00+00	24	Parça Bekleme	2026-04-29 13:06:59.03+00	\N
2174	79	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:57:00+00	57	Ayar	2026-04-29 13:06:59.042+00	\N
2175	80	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:38:00+00	38	Ayar	2026-04-29 13:06:59.053+00	\N
2176	80	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:55:00+00	55	Ayar	2026-04-29 13:06:59.064+00	\N
2177	80	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:22:00+00	22	Ayar	2026-04-29 13:06:59.075+00	\N
2178	80	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:13:00+00	13	Parça Bekleme	2026-04-29 13:06:59.088+00	\N
2179	80	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:08:00+00	8	Parça Bekleme	2026-04-29 13:06:59.104+00	\N
2180	80	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:39:00+00	39	Parça Bekleme	2026-04-29 13:06:59.124+00	\N
2181	80	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:06:59.142+00	\N
2182	80	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:06:59.161+00	\N
2183	80	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:06:59.179+00	\N
2184	80	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:18:00+00	18	Ayar	2026-04-29 13:06:59.196+00	\N
2185	80	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:35:00+00	35	Ayar	2026-04-29 13:06:59.214+00	\N
2186	80	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:42:00+00	42	Ayar	2026-04-29 13:06:59.236+00	\N
2187	80	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:59.255+00	\N
2188	80	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:06:59.274+00	\N
2189	80	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:06:59.294+00	\N
2190	80	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:06:59.313+00	\N
2191	80	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:44:00+00	44	Ayar	2026-04-29 13:06:59.331+00	\N
2192	80	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:59.35+00	\N
2193	80	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:59.364+00	\N
2194	80	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:08:00+00	8	Ayar	2026-04-29 13:06:59.376+00	\N
2195	80	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:41:00+00	41	Ayar	2026-04-29 13:06:59.39+00	\N
2196	80	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:14:00+00	14	Ayar	2026-04-29 13:06:59.406+00	\N
2197	80	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:35:00+00	35	Parça Bekleme	2026-04-29 13:06:59.421+00	\N
2198	80	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:57:00+00	57	Ayar	2026-04-29 13:06:59.437+00	\N
2199	80	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:57:00+00	57	Ayar	2026-04-29 13:06:59.454+00	\N
2200	80	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:36:00+00	36	Parça Bekleme	2026-04-29 13:06:59.474+00	\N
2201	80	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:06:59.49+00	\N
2202	80	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:13:00+00	13	Ayar	2026-04-29 13:06:59.508+00	\N
2203	80	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:43:00+00	43	Ayar	2026-04-29 13:06:59.528+00	\N
2204	80	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:07:00+00	7	Ayar	2026-04-29 13:06:59.548+00	\N
2205	81	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:06:59.579+00	\N
2206	81	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:14:00+00	14	Parça Bekleme	2026-04-29 13:06:59.597+00	\N
2207	81	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:44:00+00	44	Parça Bekleme	2026-04-29 13:06:59.616+00	\N
2208	81	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:30:00+00	30	Parça Bekleme	2026-04-29 13:06:59.634+00	\N
2209	81	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:18:00+00	18	Parça Bekleme	2026-04-29 13:06:59.652+00	\N
2210	81	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:39:00+00	39	Ayar	2026-04-29 13:06:59.67+00	\N
2211	81	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:33:00+00	33	Parça Bekleme	2026-04-29 13:06:59.688+00	\N
2212	81	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:19:00+00	19	Ayar	2026-04-29 13:06:59.706+00	\N
2213	81	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:28:00+00	28	Parça Bekleme	2026-04-29 13:06:59.724+00	\N
2214	81	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:06:59.744+00	\N
2215	81	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:18:00+00	18	Ayar	2026-04-29 13:06:59.763+00	\N
2216	81	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 06:00:00+00	60	Parça Bekleme	2026-04-29 13:06:59.781+00	\N
2217	81	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:54:00+00	54	Parça Bekleme	2026-04-29 13:06:59.797+00	\N
2218	81	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:06:59.812+00	\N
2219	81	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:06:59.83+00	\N
2220	81	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:34:00+00	34	Parça Bekleme	2026-04-29 13:06:59.846+00	\N
2221	81	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:08:00+00	8	Ayar	2026-04-29 13:06:59.859+00	\N
2222	81	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:06:59.874+00	\N
2223	81	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:06:59.889+00	\N
2224	81	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:06:59.905+00	\N
2225	81	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:53:00+00	53	Ayar	2026-04-29 13:06:59.921+00	\N
2226	81	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:01:00+00	1	Ayar	2026-04-29 13:06:59.937+00	\N
2227	81	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:42:00+00	42	Parça Bekleme	2026-04-29 13:06:59.953+00	\N
2228	81	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:06:59.968+00	\N
2229	81	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:06:59.984+00	\N
2230	81	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:27:00+00	27	Parça Bekleme	2026-04-29 13:07:00.003+00	\N
2231	81	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:38:00+00	38	Mekanik Arıza	2026-04-29 13:07:00.025+00	\N
2232	81	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:07:00.036+00	\N
2233	81	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:39:00+00	39	Parça Bekleme	2026-04-29 13:07:00.053+00	\N
2234	82	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:29:00+00	29	Ayar	2026-04-29 13:07:00.068+00	\N
2235	82	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:46:00+00	46	Parça Bekleme	2026-04-29 13:07:00.084+00	\N
2236	82	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:07:00.099+00	\N
2237	82	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:53:00+00	53	Ayar	2026-04-29 13:07:00.114+00	\N
2238	82	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:27:00+00	27	Ayar	2026-04-29 13:07:00.13+00	\N
2239	82	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:20:00+00	20	Ayar	2026-04-29 13:07:00.145+00	\N
2240	82	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:07:00.16+00	\N
2241	82	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:07:00.175+00	\N
2242	82	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 06:00:00+00	60	Ayar	2026-04-29 13:07:00.189+00	\N
2243	82	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:52:00+00	52	Ayar	2026-04-29 13:07:00.201+00	\N
2244	82	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:07:00.211+00	\N
2245	82	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:43:00+00	43	Ayar	2026-04-29 13:07:00.225+00	\N
2246	82	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:03:00+00	3	Ayar	2026-04-29 13:07:00.251+00	\N
2247	82	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:07:00.261+00	\N
2248	82	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:45:00+00	45	Ayar	2026-04-29 13:07:00.273+00	\N
2249	82	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:41:00+00	41	Parça Bekleme	2026-04-29 13:07:00.284+00	\N
2250	82	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:05:00+00	5	Ayar	2026-04-29 13:07:00.297+00	\N
2251	82	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:03:00+00	3	Ayar	2026-04-29 13:07:00.314+00	\N
2252	82	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:07:00.334+00	\N
2253	82	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:23:00+00	23	Parça Bekleme	2026-04-29 13:07:00.354+00	\N
2254	82	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:39:00+00	39	Parça Bekleme	2026-04-29 13:07:00.372+00	\N
2255	82	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:30:00+00	30	Parça Bekleme	2026-04-29 13:07:00.389+00	\N
2256	82	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:41:00+00	41	Parça Bekleme	2026-04-29 13:07:00.407+00	\N
2257	82	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:50:00+00	50	Ayar	2026-04-29 13:07:00.425+00	\N
2258	82	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:27:00+00	27	Ayar	2026-04-29 13:07:00.444+00	\N
2259	82	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:14:00+00	14	Parça Bekleme	2026-04-29 13:07:00.463+00	\N
2260	82	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:43:00+00	43	Ayar	2026-04-29 13:07:00.48+00	\N
2261	82	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:19:00+00	19	Parça Bekleme	2026-04-29 13:07:00.498+00	\N
2262	82	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:29:00+00	29	Ayar	2026-04-29 13:07:00.516+00	\N
2263	82	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 06:00:00+00	60	Parça Bekleme	2026-04-29 13:07:00.533+00	\N
2264	83	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:36:00+00	36	Parça Bekleme	2026-04-29 13:07:00.55+00	\N
2265	83	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:21:00+00	21	Parça Bekleme	2026-04-29 13:07:00.567+00	\N
2266	83	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:32:00+00	32	Parça Bekleme	2026-04-29 13:07:00.581+00	\N
2267	83	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:07:00.594+00	\N
2268	83	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:35:00+00	35	Parça Bekleme	2026-04-29 13:07:00.609+00	\N
2269	83	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:51:00+00	51	Parça Bekleme	2026-04-29 13:07:00.623+00	\N
2270	83	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:07:00.636+00	\N
2271	83	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:22:00+00	22	Ayar	2026-04-29 13:07:00.648+00	\N
2272	83	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:17:00+00	17	Ayar	2026-04-29 13:07:00.659+00	\N
2273	83	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:07:00.67+00	\N
2274	83	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:07:00.683+00	\N
2275	83	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:36:00+00	36	Ayar	2026-04-29 13:07:00.696+00	\N
2276	83	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:59:00+00	59	Parça Bekleme	2026-04-29 13:07:00.71+00	\N
2277	83	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:07:00.724+00	\N
2278	83	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:06:00+00	6	Parça Bekleme	2026-04-29 13:07:00.737+00	\N
2279	83	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:07:00.751+00	\N
2280	83	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:07:00.765+00	\N
2281	83	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:07:00.778+00	\N
2282	83	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:49:00+00	49	Ayar	2026-04-29 13:07:00.791+00	\N
2283	83	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:07:00.805+00	\N
2284	83	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:04:00+00	4	Ayar	2026-04-29 13:07:00.821+00	\N
2285	83	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:03:00+00	3	Parça Bekleme	2026-04-29 13:07:00.836+00	\N
2286	83	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:22:00+00	22	Ayar	2026-04-29 13:07:00.85+00	\N
2287	83	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:32:00+00	32	Ayar	2026-04-29 13:07:00.864+00	\N
2288	83	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:21:00+00	21	Ayar	2026-04-29 13:07:00.878+00	\N
2289	83	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:39:00+00	39	Parça Bekleme	2026-04-29 13:07:00.891+00	\N
2290	83	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:52:00+00	52	Parça Bekleme	2026-04-29 13:07:00.905+00	\N
2291	83	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:36:00+00	36	Parça Bekleme	2026-04-29 13:07:00.92+00	\N
2292	83	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:25:00+00	25	Parça Bekleme	2026-04-29 13:07:00.933+00	\N
2293	83	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:07:00.946+00	\N
2294	84	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:11:00+00	11	Ayar	2026-04-29 13:07:00.959+00	\N
2295	84	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:07:00.973+00	\N
2296	84	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:06:00+00	6	Ayar	2026-04-29 13:07:00.988+00	\N
2297	84	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:43:00+00	43	Parça Bekleme	2026-04-29 13:07:01.002+00	\N
2298	84	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:21:00+00	21	Ayar	2026-04-29 13:07:01.02+00	\N
2299	84	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:54:00+00	54	Parça Bekleme	2026-04-29 13:07:01.041+00	\N
2300	84	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:07:01.064+00	\N
2301	84	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:45:00+00	45	Parça Bekleme	2026-04-29 13:07:01.084+00	\N
2302	84	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 06:00:00+00	60	Parça Bekleme	2026-04-29 13:07:01.097+00	\N
2303	84	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:54:00+00	54	Ayar	2026-04-29 13:07:01.109+00	\N
2304	84	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:16:00+00	16	Parça Bekleme	2026-04-29 13:07:01.125+00	\N
2305	84	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:16:00+00	16	Ayar	2026-04-29 13:07:01.139+00	\N
2306	84	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:56:00+00	56	Mekanik Arıza	2026-04-29 13:07:01.155+00	\N
2307	84	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:59:00+00	59	Ayar	2026-04-29 13:07:01.172+00	\N
2308	84	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:07:01.189+00	\N
2309	84	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:07:00+00	7	Parça Bekleme	2026-04-29 13:07:01.206+00	\N
2310	84	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:36:00+00	36	Ayar	2026-04-29 13:07:01.223+00	\N
2311	84	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:36:00+00	36	Parça Bekleme	2026-04-29 13:07:01.239+00	\N
2312	84	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:07:01.251+00	\N
2313	84	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:26:00+00	26	Ayar	2026-04-29 13:07:01.266+00	\N
2314	84	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:07:01.281+00	\N
2315	84	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:31:00+00	31	Ayar	2026-04-29 13:07:01.296+00	\N
2316	84	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:07:01.311+00	\N
2317	84	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:33:00+00	33	Parça Bekleme	2026-04-29 13:07:01.328+00	\N
2318	84	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:07:01.344+00	\N
2319	84	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:23:00+00	23	Parça Bekleme	2026-04-29 13:07:01.359+00	\N
2320	84	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:07:01.374+00	\N
2321	84	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:07:01.388+00	\N
2322	84	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:27:00+00	27	Parça Bekleme	2026-04-29 13:07:01.403+00	\N
2323	84	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:14:00+00	14	Ayar	2026-04-29 13:07:01.418+00	\N
2324	85	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:07:01.435+00	\N
2325	85	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:07:01.452+00	\N
2326	85	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:59:00+00	59	Ayar	2026-04-29 13:07:01.471+00	\N
2327	85	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:35:00+00	35	Parça Bekleme	2026-04-29 13:07:01.487+00	\N
2328	85	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:01:00+00	1	Ayar	2026-04-29 13:07:01.502+00	\N
2329	85	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:20:00+00	20	Parça Bekleme	2026-04-29 13:07:01.519+00	\N
2330	85	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:38:00+00	38	Parça Bekleme	2026-04-29 13:07:01.535+00	\N
2331	85	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:07:01.551+00	\N
2332	85	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:27:00+00	27	Ayar	2026-04-29 13:07:01.567+00	\N
2333	85	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:07:01.584+00	\N
2334	85	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:30:00+00	30	Parça Bekleme	2026-04-29 13:07:01.602+00	\N
2335	85	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:24:00+00	24	Ayar	2026-04-29 13:07:01.619+00	\N
2336	85	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:22:00+00	22	Parça Bekleme	2026-04-29 13:07:01.646+00	\N
2337	85	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:37:00+00	37	Ayar	2026-04-29 13:07:01.662+00	\N
2338	85	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:07:01.679+00	\N
2339	85	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:01.697+00	\N
2340	85	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:10:00+00	10	Parça Bekleme	2026-04-29 13:07:01.714+00	\N
2341	85	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:41:00+00	41	Parça Bekleme	2026-04-29 13:07:01.727+00	\N
2342	85	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:57:00+00	57	Ayar	2026-04-29 13:07:01.741+00	\N
2343	85	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:07:01.754+00	\N
2344	85	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:14:00+00	14	Parça Bekleme	2026-04-29 13:07:01.768+00	\N
2345	85	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:07:01.782+00	\N
2346	85	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:07:00+00	7	Ayar	2026-04-29 13:07:01.798+00	\N
2347	85	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:07:01.812+00	\N
2348	85	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:07:01.828+00	\N
2349	85	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:06:00+00	6	Mekanik Arıza	2026-04-29 13:07:01.844+00	\N
2350	85	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:14:00+00	14	Parça Bekleme	2026-04-29 13:07:01.86+00	\N
2351	85	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:35:00+00	35	Ayar	2026-04-29 13:07:01.874+00	\N
2352	85	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:54:00+00	54	Ayar	2026-04-29 13:07:01.888+00	\N
2353	86	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:07:01.901+00	\N
2354	86	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:58:00+00	58	Parça Bekleme	2026-04-29 13:07:01.916+00	\N
2355	86	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:41:00+00	41	Ayar	2026-04-29 13:07:01.931+00	\N
2356	86	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:07:01.946+00	\N
2357	86	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:07:01.961+00	\N
2358	86	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:47:00+00	47	Ayar	2026-04-29 13:07:01.991+00	\N
2359	86	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:46:00+00	46	Ayar	2026-04-29 13:07:02.006+00	\N
2360	86	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:51:00+00	51	Parça Bekleme	2026-04-29 13:07:02.02+00	\N
2361	86	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:41:00+00	41	Parça Bekleme	2026-04-29 13:07:02.033+00	\N
2362	86	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:21:00+00	21	Parça Bekleme	2026-04-29 13:07:02.049+00	\N
2363	86	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:07:02.074+00	\N
2364	86	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:38:00+00	38	Mekanik Arıza	2026-04-29 13:07:02.089+00	\N
2365	86	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:07:02.107+00	\N
2366	86	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:07:02.127+00	\N
2367	86	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:07:02.148+00	\N
2368	86	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:53:00+00	53	Ayar	2026-04-29 13:07:02.169+00	\N
2369	86	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:03:00+00	3	Parça Bekleme	2026-04-29 13:07:02.19+00	\N
2370	86	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:24:00+00	24	Parça Bekleme	2026-04-29 13:07:02.21+00	\N
2371	86	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:53:00+00	53	Parça Bekleme	2026-04-29 13:07:02.228+00	\N
2372	86	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:22:00+00	22	Ayar	2026-04-29 13:07:02.243+00	\N
2373	86	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:59:00+00	59	Parça Bekleme	2026-04-29 13:07:02.26+00	\N
2374	86	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:11:00+00	11	Parça Bekleme	2026-04-29 13:07:02.279+00	\N
2375	86	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:02.298+00	\N
2376	86	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:26:00+00	26	Parça Bekleme	2026-04-29 13:07:02.319+00	\N
2377	86	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:07:00+00	7	Parça Bekleme	2026-04-29 13:07:02.337+00	\N
2378	86	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:11:00+00	11	Parça Bekleme	2026-04-29 13:07:02.352+00	\N
2379	86	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:12:00+00	12	Parça Bekleme	2026-04-29 13:07:02.367+00	\N
2380	86	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:19:00+00	19	Parça Bekleme	2026-04-29 13:07:02.384+00	\N
2381	86	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:06:00+00	6	Ayar	2026-04-29 13:07:02.403+00	\N
2382	86	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:49:00+00	49	Parça Bekleme	2026-04-29 13:07:02.418+00	\N
2383	87	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:17:00+00	17	Parça Bekleme	2026-04-29 13:07:02.433+00	\N
2384	87	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:37:00+00	37	Parça Bekleme	2026-04-29 13:07:02.449+00	\N
2385	87	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:24:00+00	24	Ayar	2026-04-29 13:07:02.465+00	\N
2386	87	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:21:00+00	21	Ayar	2026-04-29 13:07:02.482+00	\N
2387	87	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:07:02.5+00	\N
2388	87	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:55:00+00	55	Parça Bekleme	2026-04-29 13:07:02.519+00	\N
2389	87	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:07:02.537+00	\N
2390	87	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:07:02.555+00	\N
2391	87	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:10:00+00	10	Ayar	2026-04-29 13:07:02.573+00	\N
2392	87	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:07:02.591+00	\N
2393	87	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:57:00+00	57	Parça Bekleme	2026-04-29 13:07:02.608+00	\N
2394	87	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:43:00+00	43	Parça Bekleme	2026-04-29 13:07:02.624+00	\N
2395	87	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:31:00+00	31	Mekanik Arıza	2026-04-29 13:07:02.64+00	\N
2396	87	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:06:00+00	6	Mekanik Arıza	2026-04-29 13:07:02.655+00	\N
2397	87	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:07:02.667+00	\N
2398	87	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:07:02.68+00	\N
2399	87	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:02.692+00	\N
2400	87	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:07:00+00	7	Ayar	2026-04-29 13:07:02.708+00	\N
2401	87	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:01:00+00	1	Ayar	2026-04-29 13:07:02.723+00	\N
2402	87	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:01:00+00	1	Ayar	2026-04-29 13:07:02.734+00	\N
2403	87	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:15:00+00	15	Ayar	2026-04-29 13:07:02.746+00	\N
2404	87	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 06:00:00+00	60	Ayar	2026-04-29 13:07:02.756+00	\N
2405	87	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:05:00+00	5	Ayar	2026-04-29 13:07:02.768+00	\N
2406	87	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:11:00+00	11	Parça Bekleme	2026-04-29 13:07:02.781+00	\N
2407	87	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:51:00+00	51	Ayar	2026-04-29 13:07:02.794+00	\N
2408	87	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:02.809+00	\N
2409	87	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:07:02.824+00	\N
2410	87	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:56:00+00	56	Ayar	2026-04-29 13:07:02.84+00	\N
2411	87	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:23:00+00	23	Ayar	2026-04-29 13:07:02.856+00	\N
2412	87	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:48:00+00	48	Ayar	2026-04-29 13:07:02.869+00	\N
2413	88	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:03:00+00	3	Ayar	2026-04-29 13:07:02.884+00	\N
2414	88	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:11:00+00	11	Parça Bekleme	2026-04-29 13:07:02.898+00	\N
2415	88	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:07:02.914+00	\N
2416	88	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:34:00+00	34	Parça Bekleme	2026-04-29 13:07:02.928+00	\N
2417	88	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:13:00+00	13	Ayar	2026-04-29 13:07:02.945+00	\N
2418	88	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:59:00+00	59	Parça Bekleme	2026-04-29 13:07:02.959+00	\N
2419	88	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:07:02.972+00	\N
2420	88	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:36:00+00	36	Ayar	2026-04-29 13:07:02.984+00	\N
2421	88	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:31:00+00	31	Ayar	2026-04-29 13:07:02.997+00	\N
2422	88	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:07:03.012+00	\N
2423	88	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:07:03.026+00	\N
2424	88	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:05:00+00	5	Parça Bekleme	2026-04-29 13:07:03.039+00	\N
2425	88	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:38:00+00	38	Mekanik Arıza	2026-04-29 13:07:03.051+00	\N
2426	88	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:07:03.065+00	\N
2427	88	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:15:00+00	15	Ayar	2026-04-29 13:07:03.079+00	\N
2428	88	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:59:00+00	59	Parça Bekleme	2026-04-29 13:07:03.093+00	\N
2429	88	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:34:00+00	34	Ayar	2026-04-29 13:07:03.108+00	\N
2430	88	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:07:03.124+00	\N
2431	88	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:30:00+00	30	Mekanik Arıza	2026-04-29 13:07:03.139+00	\N
2432	88	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:07:03.154+00	\N
2433	88	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:28:00+00	28	Ayar	2026-04-29 13:07:03.169+00	\N
2434	88	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:36:00+00	36	Ayar	2026-04-29 13:07:03.183+00	\N
2435	88	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:02:00+00	2	Parça Bekleme	2026-04-29 13:07:03.199+00	\N
2436	88	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:49:00+00	49	Ayar	2026-04-29 13:07:03.215+00	\N
2437	88	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:40:00+00	40	Ayar	2026-04-29 13:07:03.226+00	\N
2438	88	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:34:00+00	34	Ayar	2026-04-29 13:07:03.238+00	\N
2439	88	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:13:00+00	13	Parça Bekleme	2026-04-29 13:07:03.248+00	\N
2440	88	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:07:03.258+00	\N
2441	88	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:07:03.27+00	\N
2442	88	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:38:00+00	38	Parça Bekleme	2026-04-29 13:07:03.283+00	\N
2443	89	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:52:00+00	52	Ayar	2026-04-29 13:07:03.297+00	\N
2444	89	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:58:00+00	58	Ayar	2026-04-29 13:07:03.311+00	\N
2445	89	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:07:00+00	7	Ayar	2026-04-29 13:07:03.324+00	\N
2446	89	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:09:00+00	9	Parça Bekleme	2026-04-29 13:07:03.339+00	\N
2447	89	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:19:00+00	19	Parça Bekleme	2026-04-29 13:07:03.353+00	\N
2448	89	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:03.368+00	\N
2449	89	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:07:03.382+00	\N
2450	89	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:07:03.395+00	\N
2451	89	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:48:00+00	48	Ayar	2026-04-29 13:07:03.408+00	\N
2452	89	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:45:00+00	45	Ayar	2026-04-29 13:07:03.421+00	\N
2453	89	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:51:00+00	51	Parça Bekleme	2026-04-29 13:07:03.434+00	\N
2454	89	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:07:03.447+00	\N
2455	89	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:07:03.461+00	\N
2456	89	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:23:00+00	23	Ayar	2026-04-29 13:07:03.476+00	\N
2457	89	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:14:00+00	14	Parça Bekleme	2026-04-29 13:07:03.49+00	\N
2458	89	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:52:00+00	52	Parça Bekleme	2026-04-29 13:07:03.503+00	\N
2459	89	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:35:00+00	35	Parça Bekleme	2026-04-29 13:07:03.518+00	\N
2460	89	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:07:03.534+00	\N
2461	89	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:13:00+00	13	Parça Bekleme	2026-04-29 13:07:03.55+00	\N
2462	89	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:51:00+00	51	Ayar	2026-04-29 13:07:03.563+00	\N
2463	89	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:45:00+00	45	Ayar	2026-04-29 13:07:03.574+00	\N
2464	89	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:03.585+00	\N
2465	89	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:54:00+00	54	Parça Bekleme	2026-04-29 13:07:03.594+00	\N
2466	89	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:07:03.604+00	\N
2467	89	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:52:00+00	52	Ayar	2026-04-29 13:07:03.614+00	\N
2468	89	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:57:00+00	57	Ayar	2026-04-29 13:07:03.623+00	\N
2469	89	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:03.634+00	\N
2470	89	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:33:00+00	33	Parça Bekleme	2026-04-29 13:07:03.646+00	\N
2471	89	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:28:00+00	28	Ayar	2026-04-29 13:07:03.658+00	\N
2472	89	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:21:00+00	21	Parça Bekleme	2026-04-29 13:07:03.672+00	\N
2473	90	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:07:03.687+00	\N
2474	90	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:07:03.711+00	\N
2475	90	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:07:03.727+00	\N
2476	90	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:29:00+00	29	Ayar	2026-04-29 13:07:03.744+00	\N
2477	90	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:07:03.759+00	\N
2478	90	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:07:03.77+00	\N
2479	90	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:03:00+00	3	Ayar	2026-04-29 13:07:03.781+00	\N
2480	90	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:19:00+00	19	Mekanik Arıza	2026-04-29 13:07:03.79+00	\N
2481	90	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:06:00+00	6	Ayar	2026-04-29 13:07:03.8+00	\N
2482	90	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:23:00+00	23	Parça Bekleme	2026-04-29 13:07:03.811+00	\N
2483	90	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:07:03.824+00	\N
2484	90	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:07:00+00	7	Ayar	2026-04-29 13:07:03.838+00	\N
2485	90	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:07:03.851+00	\N
2486	90	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:10:00+00	10	Ayar	2026-04-29 13:07:03.864+00	\N
2487	90	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:07:03.878+00	\N
2488	90	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:07:03.89+00	\N
2489	90	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:07:03.903+00	\N
2490	90	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:07:03.918+00	\N
2491	90	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:07:03.933+00	\N
2492	90	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:09:00+00	9	Ayar	2026-04-29 13:07:03.948+00	\N
2493	90	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:07:03.959+00	\N
2494	90	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:58:00+00	58	Parça Bekleme	2026-04-29 13:07:03.968+00	\N
2495	90	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:20:00+00	20	Ayar	2026-04-29 13:07:03.98+00	\N
2496	90	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:07:03.991+00	\N
2497	90	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:06:00+00	6	Ayar	2026-04-29 13:07:04.005+00	\N
2498	90	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:07:04.017+00	\N
2499	90	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:01:00+00	1	Ayar	2026-04-29 13:07:04.029+00	\N
2500	90	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:22:00+00	22	Mekanik Arıza	2026-04-29 13:07:04.042+00	\N
2501	90	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:41:00+00	41	Ayar	2026-04-29 13:07:04.054+00	\N
2502	91	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:09:00+00	9	Parça Bekleme	2026-04-29 13:07:04.066+00	\N
2503	91	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:07:04.079+00	\N
2504	91	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:07:04.092+00	\N
2505	91	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:04.105+00	\N
2506	91	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:56:00+00	56	Parça Bekleme	2026-04-29 13:07:04.118+00	\N
2507	91	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:47:00+00	47	Parça Bekleme	2026-04-29 13:07:04.13+00	\N
2508	91	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:02:00+00	2	Parça Bekleme	2026-04-29 13:07:04.142+00	\N
2509	91	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:07:04.156+00	\N
2510	91	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:07:04.169+00	\N
2511	91	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:04:00+00	4	Parça Bekleme	2026-04-29 13:07:04.183+00	\N
2512	91	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:40:00+00	40	Ayar	2026-04-29 13:07:04.197+00	\N
2513	91	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:36:00+00	36	Ayar	2026-04-29 13:07:04.212+00	\N
2514	91	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:26:00+00	26	Ayar	2026-04-29 13:07:04.229+00	\N
2515	91	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:15:00+00	15	Parça Bekleme	2026-04-29 13:07:04.244+00	\N
2516	91	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:07:04.256+00	\N
2517	91	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:05:00+00	5	Parça Bekleme	2026-04-29 13:07:04.27+00	\N
2518	91	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:53:00+00	53	Ayar	2026-04-29 13:07:04.284+00	\N
2519	91	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:08:00+00	8	Ayar	2026-04-29 13:07:04.301+00	\N
2520	91	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:17:00+00	17	Ayar	2026-04-29 13:07:04.317+00	\N
2521	91	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:07:04.332+00	\N
2522	91	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:09:00+00	9	Ayar	2026-04-29 13:07:04.347+00	\N
2523	91	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:07:04.362+00	\N
2524	91	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:21:00+00	21	Ayar	2026-04-29 13:07:04.38+00	\N
2525	91	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:07:04.395+00	\N
2526	91	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:22:00+00	22	Parça Bekleme	2026-04-29 13:07:04.41+00	\N
2527	91	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:07:04.425+00	\N
2528	91	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:22:00+00	22	Ayar	2026-04-29 13:07:04.439+00	\N
2529	91	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:07:04.454+00	\N
2530	91	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:43:00+00	43	Parça Bekleme	2026-04-29 13:07:04.47+00	\N
2531	91	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:42:00+00	42	Ayar	2026-04-29 13:07:04.486+00	\N
2532	92	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:52:00+00	52	Ayar	2026-04-29 13:07:04.501+00	\N
2533	92	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:40:00+00	40	Parça Bekleme	2026-04-29 13:07:04.515+00	\N
2534	92	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:50:00+00	50	Parça Bekleme	2026-04-29 13:07:04.529+00	\N
2535	92	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:18:00+00	18	Parça Bekleme	2026-04-29 13:07:04.545+00	\N
2536	92	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:20:00+00	20	Ayar	2026-04-29 13:07:04.559+00	\N
2537	92	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:21:00+00	21	Parça Bekleme	2026-04-29 13:07:04.574+00	\N
2538	92	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:25:00+00	25	Ayar	2026-04-29 13:07:04.589+00	\N
2539	92	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:07:04.604+00	\N
2540	92	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:36:00+00	36	Parça Bekleme	2026-04-29 13:07:04.62+00	\N
2541	92	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:29:00+00	29	Parça Bekleme	2026-04-29 13:07:04.635+00	\N
2542	92	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:36:00+00	36	Parça Bekleme	2026-04-29 13:07:04.651+00	\N
2543	92	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:08:00+00	8	Mekanik Arıza	2026-04-29 13:07:04.665+00	\N
2544	92	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:07:04.679+00	\N
2545	92	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:39:00+00	39	Parça Bekleme	2026-04-29 13:07:04.695+00	\N
2546	92	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:29:00+00	29	Ayar	2026-04-29 13:07:04.709+00	\N
2547	92	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:51:00+00	51	Parça Bekleme	2026-04-29 13:07:04.725+00	\N
2548	92	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:56:00+00	56	Ayar	2026-04-29 13:07:04.742+00	\N
2549	92	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:59:00+00	59	Parça Bekleme	2026-04-29 13:07:04.754+00	\N
2550	92	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:34:00+00	34	Parça Bekleme	2026-04-29 13:07:04.766+00	\N
2551	92	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:06:00+00	6	Mekanik Arıza	2026-04-29 13:07:04.781+00	\N
2552	92	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:41:00+00	41	Ayar	2026-04-29 13:07:04.795+00	\N
2553	92	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:34:00+00	34	Parça Bekleme	2026-04-29 13:07:04.812+00	\N
2554	92	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:15:00+00	15	Ayar	2026-04-29 13:07:04.827+00	\N
2555	92	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 06:00:00+00	60	Mekanik Arıza	2026-04-29 13:07:04.845+00	\N
2556	92	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:57:00+00	57	Parça Bekleme	2026-04-29 13:07:04.864+00	\N
2557	92	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:22:00+00	22	Ayar	2026-04-29 13:07:04.881+00	\N
2558	92	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:06:00+00	6	Mekanik Arıza	2026-04-29 13:07:04.897+00	\N
2559	92	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:07:04.913+00	\N
2560	92	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:07:00+00	7	Ayar	2026-04-29 13:07:04.928+00	\N
2561	92	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:12:00+00	12	Mekanik Arıza	2026-04-29 13:07:04.944+00	\N
2562	93	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:13:00+00	13	Parça Bekleme	2026-04-29 13:07:04.961+00	\N
2563	93	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:14:00+00	14	Ayar	2026-04-29 13:07:04.979+00	\N
2564	93	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:07:05.003+00	\N
2565	93	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:07:05.016+00	\N
2566	93	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:07:05.03+00	\N
2567	93	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:06:00+00	6	Mekanik Arıza	2026-04-29 13:07:05.045+00	\N
2568	93	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:07:05.058+00	\N
2569	93	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:08:00+00	8	Parça Bekleme	2026-04-29 13:07:05.072+00	\N
2570	93	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:07:05.083+00	\N
2571	93	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:22:00+00	22	Parça Bekleme	2026-04-29 13:07:05.096+00	\N
2572	93	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:20:00+00	20	Parça Bekleme	2026-04-29 13:07:05.11+00	\N
2573	93	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:36:00+00	36	Ayar	2026-04-29 13:07:05.121+00	\N
2574	93	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:29:00+00	29	Parça Bekleme	2026-04-29 13:07:05.132+00	\N
2575	93	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:38:00+00	38	Ayar	2026-04-29 13:07:05.144+00	\N
2576	93	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:46:00+00	46	Parça Bekleme	2026-04-29 13:07:05.154+00	\N
2577	93	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:05:00+00	5	Ayar	2026-04-29 13:07:05.175+00	\N
2578	93	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:59:00+00	59	Mekanik Arıza	2026-04-29 13:07:05.192+00	\N
2579	93	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:02:00+00	2	Mekanik Arıza	2026-04-29 13:07:05.206+00	\N
2580	93	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:08:00+00	8	Parça Bekleme	2026-04-29 13:07:05.239+00	\N
2581	93	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:01:00+00	1	Ayar	2026-04-29 13:07:05.252+00	\N
2582	93	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:46:00+00	46	Ayar	2026-04-29 13:07:05.265+00	\N
2583	93	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:07:05.278+00	\N
2584	93	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:29:00+00	29	Parça Bekleme	2026-04-29 13:07:05.294+00	\N
2585	93	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:40:00+00	40	Ayar	2026-04-29 13:07:05.31+00	\N
2586	93	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:56:00+00	56	Ayar	2026-04-29 13:07:05.328+00	\N
2587	93	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:07:05.345+00	\N
2588	93	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:07:05.362+00	\N
2589	93	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:07:05.38+00	\N
2590	93	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:07:05.396+00	\N
2591	93	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:44:00+00	44	Ayar	2026-04-29 13:07:05.415+00	\N
2592	94	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:59:00+00	59	Ayar	2026-04-29 13:07:05.432+00	\N
2593	94	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:23:00+00	23	Parça Bekleme	2026-04-29 13:07:05.45+00	\N
2594	94	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:07:05.467+00	\N
2595	94	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:55:00+00	55	Parça Bekleme	2026-04-29 13:07:05.483+00	\N
2596	94	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:24:00+00	24	Parça Bekleme	2026-04-29 13:07:05.501+00	\N
2597	94	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:07:05.519+00	\N
2598	94	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:37:00+00	37	Parça Bekleme	2026-04-29 13:07:05.534+00	\N
2599	94	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:07:05.551+00	\N
2600	94	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:03:00+00	3	Mekanik Arıza	2026-04-29 13:07:05.57+00	\N
2601	94	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:07:05.589+00	\N
2602	94	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:35:00+00	35	Parça Bekleme	2026-04-29 13:07:05.609+00	\N
2603	94	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:17:00+00	17	Ayar	2026-04-29 13:07:05.629+00	\N
2604	94	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:07:05.649+00	\N
2605	94	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:07:05.671+00	\N
2606	94	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:20:00+00	20	Ayar	2026-04-29 13:07:05.692+00	\N
2607	94	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:24:00+00	24	Parça Bekleme	2026-04-29 13:07:05.713+00	\N
2608	94	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:51:00+00	51	Mekanik Arıza	2026-04-29 13:07:05.733+00	\N
2609	94	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:14:00+00	14	Parça Bekleme	2026-04-29 13:07:05.75+00	\N
2610	94	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:41:00+00	41	Parça Bekleme	2026-04-29 13:07:05.768+00	\N
2611	94	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:34:00+00	34	Ayar	2026-04-29 13:07:05.785+00	\N
2612	94	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:13:00+00	13	Parça Bekleme	2026-04-29 13:07:05.804+00	\N
2613	94	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:16:00+00	16	Ayar	2026-04-29 13:07:05.824+00	\N
2614	94	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:23:00+00	23	Ayar	2026-04-29 13:07:05.843+00	\N
2615	94	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:22:00+00	22	Parça Bekleme	2026-04-29 13:07:05.862+00	\N
2616	94	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:32:00+00	32	Parça Bekleme	2026-04-29 13:07:05.881+00	\N
2617	94	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:20:00+00	20	Ayar	2026-04-29 13:07:05.901+00	\N
2618	94	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:17:00+00	17	Parça Bekleme	2026-04-29 13:07:05.921+00	\N
2619	94	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:08:00+00	8	Parça Bekleme	2026-04-29 13:07:05.941+00	\N
2620	94	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:25:00+00	25	Ayar	2026-04-29 13:07:05.96+00	\N
2621	94	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:43:00+00	43	Parça Bekleme	2026-04-29 13:07:05.98+00	\N
2622	95	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:14:00+00	14	Parça Bekleme	2026-04-29 13:07:06.012+00	\N
2623	95	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:55:00+00	55	Ayar	2026-04-29 13:07:06.032+00	\N
2624	95	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:23:00+00	23	Ayar	2026-04-29 13:07:06.052+00	\N
2625	95	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:19:00+00	19	Parça Bekleme	2026-04-29 13:07:06.071+00	\N
2626	95	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:59:00+00	59	Ayar	2026-04-29 13:07:06.091+00	\N
2627	95	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:51:00+00	51	Ayar	2026-04-29 13:07:06.112+00	\N
2628	95	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:55:00+00	55	Mekanik Arıza	2026-04-29 13:07:06.132+00	\N
2629	95	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:07:06.151+00	\N
2630	95	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:41:00+00	41	Parça Bekleme	2026-04-29 13:07:06.171+00	\N
2631	95	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:07:06.19+00	\N
2632	95	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:06:00+00	6	Ayar	2026-04-29 13:07:06.21+00	\N
2633	95	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:07:06.229+00	\N
2634	95	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:04:00+00	4	Ayar	2026-04-29 13:07:06.246+00	\N
2635	95	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:45:00+00	45	Parça Bekleme	2026-04-29 13:07:06.262+00	\N
2636	95	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:07:06.282+00	\N
2637	95	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:55:00+00	55	Ayar	2026-04-29 13:07:06.299+00	\N
2638	95	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:03:00+00	3	Parça Bekleme	2026-04-29 13:07:06.315+00	\N
2639	95	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:58:00+00	58	Parça Bekleme	2026-04-29 13:07:06.333+00	\N
2640	95	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:28:00+00	28	Mekanik Arıza	2026-04-29 13:07:06.366+00	\N
2641	95	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:54:00+00	54	Ayar	2026-04-29 13:07:06.385+00	\N
2642	95	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:21:00+00	21	Ayar	2026-04-29 13:07:06.405+00	\N
2643	95	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:20:00+00	20	Parça Bekleme	2026-04-29 13:07:06.424+00	\N
2644	95	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:31:00+00	31	Mekanik Arıza	2026-04-29 13:07:06.444+00	\N
2645	95	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:44:00+00	44	Ayar	2026-04-29 13:07:06.463+00	\N
2646	95	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:44:00+00	44	Ayar	2026-04-29 13:07:06.484+00	\N
2647	95	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:18:00+00	18	Ayar	2026-04-29 13:07:06.504+00	\N
2648	95	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:49:00+00	49	Mekanik Arıza	2026-04-29 13:07:06.525+00	\N
2649	95	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:09:00+00	9	Parça Bekleme	2026-04-29 13:07:06.545+00	\N
2650	96	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:38:00+00	38	Ayar	2026-04-29 13:07:06.564+00	\N
2651	96	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:29:00+00	29	Ayar	2026-04-29 13:07:06.584+00	\N
2652	96	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:02:00+00	2	Parça Bekleme	2026-04-29 13:07:06.604+00	\N
2653	96	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:29:00+00	29	Ayar	2026-04-29 13:07:06.629+00	\N
2654	96	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:57:00+00	57	Mekanik Arıza	2026-04-29 13:07:06.65+00	\N
2655	96	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:07:06.668+00	\N
2656	96	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:07:06.688+00	\N
2657	96	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:06:00+00	6	Parça Bekleme	2026-04-29 13:07:06.784+00	\N
2658	96	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:22:00+00	22	Ayar	2026-04-29 13:07:06.811+00	\N
2659	96	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:24:00+00	24	Parça Bekleme	2026-04-29 13:07:06.825+00	\N
2660	96	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:06:00+00	6	Parça Bekleme	2026-04-29 13:07:06.838+00	\N
2661	96	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:41:00+00	41	Parça Bekleme	2026-04-29 13:07:06.854+00	\N
2662	96	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:43:00+00	43	Parça Bekleme	2026-04-29 13:07:06.872+00	\N
2663	96	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:07:06.89+00	\N
2664	96	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:06:00+00	6	Ayar	2026-04-29 13:07:06.907+00	\N
2665	96	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:38:00+00	38	Mekanik Arıza	2026-04-29 13:07:06.925+00	\N
2666	96	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:07:06.943+00	\N
2667	96	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:24:00+00	24	Mekanik Arıza	2026-04-29 13:07:06.96+00	\N
2668	96	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:33:00+00	33	Parça Bekleme	2026-04-29 13:07:06.977+00	\N
2669	96	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:17:00+00	17	Mekanik Arıza	2026-04-29 13:07:06.993+00	\N
2670	96	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:29:00+00	29	Ayar	2026-04-29 13:07:07.01+00	\N
2671	96	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:35:00+00	35	Ayar	2026-04-29 13:07:07.026+00	\N
2672	96	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:44:00+00	44	Parça Bekleme	2026-04-29 13:07:07.042+00	\N
2673	96	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:42:00+00	42	Ayar	2026-04-29 13:07:07.058+00	\N
2674	96	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:30:00+00	30	Ayar	2026-04-29 13:07:07.072+00	\N
2675	96	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:02:00+00	2	Mekanik Arıza	2026-04-29 13:07:07.088+00	\N
2676	96	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:22:00+00	22	Parça Bekleme	2026-04-29 13:07:07.116+00	\N
2677	96	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:14:00+00	14	Mekanik Arıza	2026-04-29 13:07:07.134+00	\N
2678	96	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:07:00+00	7	Parça Bekleme	2026-04-29 13:07:07.15+00	\N
2679	97	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:25:00+00	25	Ayar	2026-04-29 13:07:07.165+00	\N
2680	97	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:07:00+00	7	Mekanik Arıza	2026-04-29 13:07:07.182+00	\N
2681	97	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:51:00+00	51	Ayar	2026-04-29 13:07:07.2+00	\N
2682	97	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:01:00+00	1	Parça Bekleme	2026-04-29 13:07:07.219+00	\N
2683	97	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:31:00+00	31	Parça Bekleme	2026-04-29 13:07:07.235+00	\N
2684	97	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:33:00+00	33	Parça Bekleme	2026-04-29 13:07:07.249+00	\N
2685	97	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:47:00+00	47	Parça Bekleme	2026-04-29 13:07:07.265+00	\N
2686	97	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:07:07.306+00	\N
2687	97	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:07:07.326+00	\N
2688	97	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:43:00+00	43	Ayar	2026-04-29 13:07:07.345+00	\N
2689	97	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:08:00+00	8	Parça Bekleme	2026-04-29 13:07:07.366+00	\N
2690	97	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:30:00+00	30	Ayar	2026-04-29 13:07:07.386+00	\N
2691	97	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:11:00+00	11	Parça Bekleme	2026-04-29 13:07:07.405+00	\N
2692	97	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:31:00+00	31	Parça Bekleme	2026-04-29 13:07:07.424+00	\N
2693	97	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:31:00+00	31	Ayar	2026-04-29 13:07:07.443+00	\N
2694	97	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:52:00+00	52	Parça Bekleme	2026-04-29 13:07:07.464+00	\N
2695	97	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:20:00+00	20	Parça Bekleme	2026-04-29 13:07:07.483+00	\N
2696	97	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:36:00+00	36	Ayar	2026-04-29 13:07:07.504+00	\N
2697	97	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:41:00+00	41	Ayar	2026-04-29 13:07:07.524+00	\N
2698	97	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:16:00+00	16	Parça Bekleme	2026-04-29 13:07:07.543+00	\N
2699	97	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:07.563+00	\N
2700	97	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:18:00+00	18	Mekanik Arıza	2026-04-29 13:07:07.581+00	\N
2701	97	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:46:00+00	46	Ayar	2026-04-29 13:07:07.601+00	\N
2702	97	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:15:00+00	15	Ayar	2026-04-29 13:07:07.623+00	\N
2703	97	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:13:00+00	13	Parça Bekleme	2026-04-29 13:07:07.644+00	\N
2704	97	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:07:07.664+00	\N
2705	97	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:20:00+00	20	Parça Bekleme	2026-04-29 13:07:07.685+00	\N
2706	97	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:25:00+00	25	Mekanik Arıza	2026-04-29 13:07:07.705+00	\N
2707	97	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 06:00:00+00	60	Parça Bekleme	2026-04-29 13:07:07.725+00	\N
2708	97	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:12:00+00	12	Ayar	2026-04-29 13:07:07.741+00	\N
2709	98	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:07:07.754+00	\N
2710	98	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:11:00+00	11	Parça Bekleme	2026-04-29 13:07:07.768+00	\N
2711	98	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:58:00+00	58	Mekanik Arıza	2026-04-29 13:07:07.785+00	\N
2712	98	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:54:00+00	54	Parça Bekleme	2026-04-29 13:07:07.802+00	\N
2713	98	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:06:00+00	6	Mekanik Arıza	2026-04-29 13:07:07.819+00	\N
2714	98	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:54:00+00	54	Mekanik Arıza	2026-04-29 13:07:07.835+00	\N
2715	98	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:07:07.851+00	\N
2716	98	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:37:00+00	37	Ayar	2026-04-29 13:07:07.862+00	\N
2717	98	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:13:00+00	13	Parça Bekleme	2026-04-29 13:07:07.874+00	\N
2718	98	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:11:00+00	11	Ayar	2026-04-29 13:07:07.888+00	\N
2719	98	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:07:07.904+00	\N
2720	98	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:07:07.92+00	\N
2721	98	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:51:00+00	51	Parça Bekleme	2026-04-29 13:07:07.937+00	\N
2722	98	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:38:00+00	38	Ayar	2026-04-29 13:07:07.951+00	\N
2723	98	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:03:00+00	3	Parça Bekleme	2026-04-29 13:07:07.963+00	\N
2724	98	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:07:07.982+00	\N
2725	98	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:24:00+00	24	Parça Bekleme	2026-04-29 13:07:07.994+00	\N
2726	98	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:07:08.004+00	\N
2727	98	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:03:00+00	3	Parça Bekleme	2026-04-29 13:07:08.016+00	\N
2728	98	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:28:00+00	28	Parça Bekleme	2026-04-29 13:07:08.029+00	\N
2729	98	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:43:00+00	43	Mekanik Arıza	2026-04-29 13:07:08.041+00	\N
2730	98	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:27:00+00	27	Ayar	2026-04-29 13:07:08.055+00	\N
2731	98	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:18:00+00	18	Ayar	2026-04-29 13:07:08.074+00	\N
2732	98	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:08.094+00	\N
2733	98	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:52:00+00	52	Parça Bekleme	2026-04-29 13:07:08.115+00	\N
2734	98	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:22:00+00	22	Parça Bekleme	2026-04-29 13:07:08.135+00	\N
2735	98	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:30:00+00	30	Ayar	2026-04-29 13:07:08.157+00	\N
2736	98	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:57:00+00	57	Parça Bekleme	2026-04-29 13:07:08.173+00	\N
2737	98	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:11:00+00	11	Mekanik Arıza	2026-04-29 13:07:08.186+00	\N
2738	99	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:07:08.2+00	\N
2739	99	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:07:08.212+00	\N
2740	99	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:16:00+00	16	Ayar	2026-04-29 13:07:08.225+00	\N
2741	99	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:45:00+00	45	Ayar	2026-04-29 13:07:08.239+00	\N
2742	99	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:34:00+00	34	Ayar	2026-04-29 13:07:08.25+00	\N
2743	99	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:33:00+00	33	Parça Bekleme	2026-04-29 13:07:08.26+00	\N
2744	99	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:12:00+00	12	Ayar	2026-04-29 13:07:08.273+00	\N
2745	99	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:07:08.283+00	\N
2746	99	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:02:00+00	2	Mekanik Arıza	2026-04-29 13:07:08.293+00	\N
2747	99	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:09:00+00	9	Ayar	2026-04-29 13:07:08.302+00	\N
2748	99	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:07:08.312+00	\N
2749	99	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:46:00+00	46	Ayar	2026-04-29 13:07:08.32+00	\N
2750	99	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:29:00+00	29	Ayar	2026-04-29 13:07:08.329+00	\N
2751	99	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:53:00+00	53	Parça Bekleme	2026-04-29 13:07:08.344+00	\N
2752	99	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:13:00+00	13	Parça Bekleme	2026-04-29 13:07:08.353+00	\N
2753	99	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:14:00+00	14	Ayar	2026-04-29 13:07:08.363+00	\N
2754	99	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:39:00+00	39	Mekanik Arıza	2026-04-29 13:07:08.372+00	\N
2755	99	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:07:08.381+00	\N
2756	99	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:41:00+00	41	Ayar	2026-04-29 13:07:08.39+00	\N
2757	99	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:05:00+00	5	Parça Bekleme	2026-04-29 13:07:08.399+00	\N
2758	99	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:07:08.409+00	\N
2759	99	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:39:00+00	39	Parça Bekleme	2026-04-29 13:07:08.418+00	\N
2760	99	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:14:00+00	14	Ayar	2026-04-29 13:07:08.427+00	\N
2761	99	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:09:00+00	9	Ayar	2026-04-29 13:07:08.436+00	\N
2762	99	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:46:00+00	46	Ayar	2026-04-29 13:07:08.445+00	\N
2763	99	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:39:00+00	39	Ayar	2026-04-29 13:07:08.455+00	\N
2764	99	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:08.464+00	\N
2765	99	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:20:00+00	20	Parça Bekleme	2026-04-29 13:07:08.473+00	\N
2766	99	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:04:00+00	4	Mekanik Arıza	2026-04-29 13:07:08.483+00	\N
2767	100	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:41:00+00	41	Parça Bekleme	2026-04-29 13:07:08.492+00	\N
2768	100	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:41:00+00	41	Ayar	2026-04-29 13:07:08.501+00	\N
2769	100	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:09:00+00	9	Parça Bekleme	2026-04-29 13:07:08.509+00	\N
2770	100	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:26:00+00	26	Parça Bekleme	2026-04-29 13:07:08.518+00	\N
2771	100	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:07:08.527+00	\N
2772	100	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:28:00+00	28	Parça Bekleme	2026-04-29 13:07:08.536+00	\N
2773	100	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:33:00+00	33	Parça Bekleme	2026-04-29 13:07:08.552+00	\N
2774	100	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:07:08.563+00	\N
2775	100	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:11:00+00	11	Mekanik Arıza	2026-04-29 13:07:08.576+00	\N
2776	100	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:45:00+00	45	Ayar	2026-04-29 13:07:08.589+00	\N
2777	100	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:39:00+00	39	Parça Bekleme	2026-04-29 13:07:08.601+00	\N
2778	100	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:17:00+00	17	Parça Bekleme	2026-04-29 13:07:08.614+00	\N
2779	100	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:41:00+00	41	Ayar	2026-04-29 13:07:08.626+00	\N
2780	100	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:47:00+00	47	Parça Bekleme	2026-04-29 13:07:08.642+00	\N
2781	100	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:01:00+00	1	Ayar	2026-04-29 13:07:08.656+00	\N
2782	100	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:10:00+00	10	Parça Bekleme	2026-04-29 13:07:08.668+00	\N
2783	100	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:07:08.681+00	\N
2784	100	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:34:00+00	34	Ayar	2026-04-29 13:07:08.694+00	\N
2785	100	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:10:00+00	10	Mekanik Arıza	2026-04-29 13:07:08.705+00	\N
2786	100	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:29:00+00	29	Parça Bekleme	2026-04-29 13:07:08.716+00	\N
2787	100	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:38:00+00	38	Ayar	2026-04-29 13:07:08.728+00	\N
2788	100	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:48:00+00	48	Ayar	2026-04-29 13:07:08.74+00	\N
2789	100	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:59:00+00	59	Ayar	2026-04-29 13:07:08.751+00	\N
2790	100	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:15:00+00	15	Mekanik Arıza	2026-04-29 13:07:08.764+00	\N
2791	100	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:07:08.782+00	\N
2792	100	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:07:08.796+00	\N
2793	100	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:45:00+00	45	Ayar	2026-04-29 13:07:08.808+00	\N
2794	100	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:16:00+00	16	Mekanik Arıza	2026-04-29 13:07:08.82+00	\N
2795	100	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:14:00+00	14	Parça Bekleme	2026-04-29 13:07:08.834+00	\N
2796	101	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:53:00+00	53	Parça Bekleme	2026-04-29 13:07:08.849+00	\N
2797	101	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:33:00+00	33	Mekanik Arıza	2026-04-29 13:07:08.864+00	\N
2798	101	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:07:08.877+00	\N
2799	101	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:07:08.89+00	\N
2800	101	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:30:00+00	30	Ayar	2026-04-29 13:07:08.902+00	\N
2801	101	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:53:00+00	53	Mekanik Arıza	2026-04-29 13:07:08.916+00	\N
2802	101	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:49:00+00	49	Parça Bekleme	2026-04-29 13:07:08.934+00	\N
2803	101	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:21:00+00	21	Ayar	2026-04-29 13:07:08.946+00	\N
2804	101	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:07:08.957+00	\N
2805	101	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:37:00+00	37	Mekanik Arıza	2026-04-29 13:07:08.969+00	\N
2806	101	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:59:00+00	59	Parça Bekleme	2026-04-29 13:07:08.98+00	\N
2807	101	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:07:08.99+00	\N
2808	101	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:37:00+00	37	Parça Bekleme	2026-04-29 13:07:09+00	\N
2809	101	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:07:09.012+00	\N
2810	101	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:07:09.024+00	\N
2811	101	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:52:00+00	52	Ayar	2026-04-29 13:07:09.039+00	\N
2812	101	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:48:00+00	48	Ayar	2026-04-29 13:07:09.056+00	\N
2813	101	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:45:00+00	45	Mekanik Arıza	2026-04-29 13:07:09.073+00	\N
2814	101	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:14:00+00	14	Parça Bekleme	2026-04-29 13:07:09.092+00	\N
2815	101	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:09.108+00	\N
2816	101	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:36:00+00	36	Mekanik Arıza	2026-04-29 13:07:09.126+00	\N
2817	101	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:44:00+00	44	Parça Bekleme	2026-04-29 13:07:09.143+00	\N
2818	101	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:23:00+00	23	Mekanik Arıza	2026-04-29 13:07:09.163+00	\N
2819	101	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:09:00+00	9	Mekanik Arıza	2026-04-29 13:07:09.18+00	\N
2820	101	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:56:00+00	56	Parça Bekleme	2026-04-29 13:07:09.196+00	\N
2821	101	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:14:00+00	14	Parça Bekleme	2026-04-29 13:07:09.209+00	\N
2822	101	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:59:00+00	59	Ayar	2026-04-29 13:07:09.22+00	\N
2823	101	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:49:00+00	49	Parça Bekleme	2026-04-29 13:07:09.23+00	\N
2824	101	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:35:00+00	35	Ayar	2026-04-29 13:07:09.241+00	\N
2825	102	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:02:00+00	2	Parça Bekleme	2026-04-29 13:07:09.256+00	\N
2826	102	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:58:00+00	58	Ayar	2026-04-29 13:07:09.265+00	\N
2827	102	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:15:00+00	15	Parça Bekleme	2026-04-29 13:07:09.274+00	\N
2828	102	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:49:00+00	49	Ayar	2026-04-29 13:07:09.284+00	\N
2829	102	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:31:00+00	31	Parça Bekleme	2026-04-29 13:07:09.293+00	\N
2830	102	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:52:00+00	52	Mekanik Arıza	2026-04-29 13:07:09.303+00	\N
2831	102	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:07:09.314+00	\N
2832	102	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:26:00+00	26	Ayar	2026-04-29 13:07:09.33+00	\N
2833	102	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:07:09.344+00	\N
2834	102	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:50:00+00	50	Mekanik Arıza	2026-04-29 13:07:09.361+00	\N
2835	102	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:23:00+00	23	Parça Bekleme	2026-04-29 13:07:09.382+00	\N
2836	102	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:07:00+00	7	Ayar	2026-04-29 13:07:09.401+00	\N
2837	102	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:09:00+00	9	Parça Bekleme	2026-04-29 13:07:09.42+00	\N
2838	102	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:33:00+00	33	Parça Bekleme	2026-04-29 13:07:09.441+00	\N
2839	102	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:27:00+00	27	Ayar	2026-04-29 13:07:09.473+00	\N
2840	102	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:21:00+00	21	Ayar	2026-04-29 13:07:09.492+00	\N
2841	102	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:35:00+00	35	Mekanik Arıza	2026-04-29 13:07:09.513+00	\N
2842	102	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:26:00+00	26	Mekanik Arıza	2026-04-29 13:07:09.531+00	\N
2843	102	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:58:00+00	58	Parça Bekleme	2026-04-29 13:07:09.552+00	\N
2844	102	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:51:00+00	51	Ayar	2026-04-29 13:07:09.573+00	\N
2845	102	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:41:00+00	41	Ayar	2026-04-29 13:07:09.594+00	\N
2846	102	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:44:00+00	44	Ayar	2026-04-29 13:07:09.614+00	\N
2847	102	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 06:00:00+00	60	Ayar	2026-04-29 13:07:09.633+00	\N
2848	102	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:11:00+00	11	Mekanik Arıza	2026-04-29 13:07:09.655+00	\N
2849	102	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:41:00+00	41	Parça Bekleme	2026-04-29 13:07:09.674+00	\N
2850	102	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:57:00+00	57	Ayar	2026-04-29 13:07:09.693+00	\N
2851	102	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:43:00+00	43	Parça Bekleme	2026-04-29 13:07:09.712+00	\N
2852	102	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:13:00+00	13	Ayar	2026-04-29 13:07:09.732+00	\N
2853	102	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:07:00+00	7	Parça Bekleme	2026-04-29 13:07:09.749+00	\N
2854	103	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:42:00+00	42	Parça Bekleme	2026-04-29 13:07:09.763+00	\N
2855	103	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:48:00+00	48	Ayar	2026-04-29 13:07:09.782+00	\N
2856	103	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:07:09.801+00	\N
2857	103	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:41:00+00	41	Ayar	2026-04-29 13:07:09.821+00	\N
2858	103	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:48:00+00	48	Mekanik Arıza	2026-04-29 13:07:09.839+00	\N
2859	103	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:29:00+00	29	Ayar	2026-04-29 13:07:09.857+00	\N
2860	103	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:44:00+00	44	Ayar	2026-04-29 13:07:09.877+00	\N
2861	103	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:30:00+00	30	Parça Bekleme	2026-04-29 13:07:09.894+00	\N
2862	103	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:45:00+00	45	Parça Bekleme	2026-04-29 13:07:09.913+00	\N
2863	103	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:07:09.933+00	\N
2864	103	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:29:00+00	29	Parça Bekleme	2026-04-29 13:07:09.951+00	\N
2865	103	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:26:00+00	26	Parça Bekleme	2026-04-29 13:07:09.979+00	\N
2866	103	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:07:09.993+00	\N
2867	103	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:05:00+00	5	Mekanik Arıza	2026-04-29 13:07:10.008+00	\N
2868	103	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:42:00+00	42	Ayar	2026-04-29 13:07:10.02+00	\N
2869	103	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:12:00+00	12	Parça Bekleme	2026-04-29 13:07:10.032+00	\N
2870	103	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:17:00+00	17	Parça Bekleme	2026-04-29 13:07:10.045+00	\N
2871	103	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:57:00+00	57	Ayar	2026-04-29 13:07:10.061+00	\N
2872	103	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:07:00+00	7	Ayar	2026-04-29 13:07:10.078+00	\N
2873	103	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:20:00+00	20	Ayar	2026-04-29 13:07:10.093+00	\N
2874	103	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:44:00+00	44	Mekanik Arıza	2026-04-29 13:07:10.108+00	\N
2875	103	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:07:10.123+00	\N
2876	103	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:18:00+00	18	Ayar	2026-04-29 13:07:10.138+00	\N
2877	103	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:08:00+00	8	Parça Bekleme	2026-04-29 13:07:10.154+00	\N
2878	103	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:23:00+00	23	Ayar	2026-04-29 13:07:10.17+00	\N
2879	103	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:26:00+00	26	Ayar	2026-04-29 13:07:10.184+00	\N
2880	103	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:27:00+00	27	Parça Bekleme	2026-04-29 13:07:10.201+00	\N
2881	103	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:11:00+00	11	Parça Bekleme	2026-04-29 13:07:10.219+00	\N
2882	103	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:41:00+00	41	Parça Bekleme	2026-04-29 13:07:10.238+00	\N
2883	103	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:07:10.252+00	\N
2884	104	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:16:00+00	16	Parça Bekleme	2026-04-29 13:07:10.268+00	\N
2885	104	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:42:00+00	42	Mekanik Arıza	2026-04-29 13:07:10.285+00	\N
2886	104	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:33:00+00	33	Ayar	2026-04-29 13:07:10.301+00	\N
2887	104	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:07:10.317+00	\N
2888	104	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:19:00+00	19	Ayar	2026-04-29 13:07:10.333+00	\N
2889	104	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:27:00+00	27	Parça Bekleme	2026-04-29 13:07:10.349+00	\N
2890	104	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:53:00+00	53	Parça Bekleme	2026-04-29 13:07:10.366+00	\N
2891	104	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:38:00+00	38	Parça Bekleme	2026-04-29 13:07:10.385+00	\N
2892	104	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:12:00+00	12	Parça Bekleme	2026-04-29 13:07:10.416+00	\N
2893	104	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:35:00+00	35	Ayar	2026-04-29 13:07:10.432+00	\N
2894	104	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:50:00+00	50	Ayar	2026-04-29 13:07:10.448+00	\N
2895	104	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:20:00+00	20	Ayar	2026-04-29 13:07:10.465+00	\N
2896	104	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:21:00+00	21	Mekanik Arıza	2026-04-29 13:07:10.493+00	\N
2897	104	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:32:00+00	32	Mekanik Arıza	2026-04-29 13:07:10.509+00	\N
2898	104	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:07:10.526+00	\N
2899	104	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:03:00+00	3	Parça Bekleme	2026-04-29 13:07:10.541+00	\N
2900	104	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:29:00+00	29	Ayar	2026-04-29 13:07:10.558+00	\N
2901	104	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:13:00+00	13	Parça Bekleme	2026-04-29 13:07:10.573+00	\N
2902	104	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:29:00+00	29	Mekanik Arıza	2026-04-29 13:07:10.592+00	\N
2903	104	2026-04-07	2026-04-08 05:00:00+00	2026-04-08 05:41:00+00	41	Mekanik Arıza	2026-04-29 13:07:10.609+00	\N
2904	104	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:02:00+00	2	Ayar	2026-04-29 13:07:10.625+00	\N
2905	104	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:46:00+00	46	Mekanik Arıza	2026-04-29 13:07:10.642+00	\N
2906	104	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:39:00+00	39	Parça Bekleme	2026-04-29 13:07:10.658+00	\N
2907	104	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:07:10.674+00	\N
2908	104	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:37:00+00	37	Parça Bekleme	2026-04-29 13:07:10.69+00	\N
2909	104	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:34:00+00	34	Mekanik Arıza	2026-04-29 13:07:10.706+00	\N
2910	104	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:05:00+00	5	Ayar	2026-04-29 13:07:10.726+00	\N
2911	104	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:59:00+00	59	Ayar	2026-04-29 13:07:10.744+00	\N
2912	105	2026-04-28	2026-04-29 05:00:00+00	2026-04-29 05:17:00+00	17	Parça Bekleme	2026-04-29 13:07:10.76+00	\N
2913	105	2026-04-27	2026-04-28 05:00:00+00	2026-04-28 05:40:00+00	40	Ayar	2026-04-29 13:07:10.774+00	\N
2914	105	2026-04-26	2026-04-27 05:00:00+00	2026-04-27 05:23:00+00	23	Parça Bekleme	2026-04-29 13:07:10.788+00	\N
2915	105	2026-04-25	2026-04-26 05:00:00+00	2026-04-26 05:27:00+00	27	Mekanik Arıza	2026-04-29 13:07:10.803+00	\N
2916	105	2026-04-24	2026-04-25 05:00:00+00	2026-04-25 05:40:00+00	40	Ayar	2026-04-29 13:07:10.818+00	\N
2917	105	2026-04-23	2026-04-24 05:00:00+00	2026-04-24 05:59:00+00	59	Parça Bekleme	2026-04-29 13:07:10.834+00	\N
2918	105	2026-04-22	2026-04-23 05:00:00+00	2026-04-23 05:04:00+00	4	Ayar	2026-04-29 13:07:10.85+00	\N
2919	105	2026-04-21	2026-04-22 05:00:00+00	2026-04-22 05:38:00+00	38	Parça Bekleme	2026-04-29 13:07:10.865+00	\N
2920	105	2026-04-20	2026-04-21 05:00:00+00	2026-04-21 05:02:00+00	2	Parça Bekleme	2026-04-29 13:07:10.881+00	\N
2921	105	2026-04-19	2026-04-20 05:00:00+00	2026-04-20 05:51:00+00	51	Parça Bekleme	2026-04-29 13:07:10.896+00	\N
2922	105	2026-04-18	2026-04-19 05:00:00+00	2026-04-19 05:30:00+00	30	Parça Bekleme	2026-04-29 13:07:10.912+00	\N
2923	105	2026-04-17	2026-04-18 05:00:00+00	2026-04-18 05:56:00+00	56	Mekanik Arıza	2026-04-29 13:07:10.927+00	\N
2924	105	2026-04-16	2026-04-17 05:00:00+00	2026-04-17 05:28:00+00	28	Ayar	2026-04-29 13:07:10.943+00	\N
2925	105	2026-04-15	2026-04-16 05:00:00+00	2026-04-16 05:48:00+00	48	Ayar	2026-04-29 13:07:10.958+00	\N
2926	105	2026-04-14	2026-04-15 05:00:00+00	2026-04-15 05:12:00+00	12	Parça Bekleme	2026-04-29 13:07:10.975+00	\N
2927	105	2026-04-13	2026-04-14 05:00:00+00	2026-04-14 05:46:00+00	46	Parça Bekleme	2026-04-29 13:07:10.991+00	\N
2928	105	2026-04-12	2026-04-13 05:00:00+00	2026-04-13 05:28:00+00	28	Ayar	2026-04-29 13:07:11.007+00	\N
2929	105	2026-04-11	2026-04-12 05:00:00+00	2026-04-12 05:15:00+00	15	Ayar	2026-04-29 13:07:11.024+00	\N
2930	105	2026-04-10	2026-04-11 05:00:00+00	2026-04-11 05:53:00+00	53	Ayar	2026-04-29 13:07:11.04+00	\N
2931	105	2026-04-09	2026-04-10 05:00:00+00	2026-04-10 05:34:00+00	34	Ayar	2026-04-29 13:07:11.057+00	\N
2932	105	2026-04-08	2026-04-09 05:00:00+00	2026-04-09 05:21:00+00	21	Parça Bekleme	2026-04-29 13:07:11.072+00	\N
2933	105	2026-04-06	2026-04-07 05:00:00+00	2026-04-07 05:40:00+00	40	Mekanik Arıza	2026-04-29 13:07:11.099+00	\N
2934	105	2026-04-05	2026-04-06 05:00:00+00	2026-04-06 05:47:00+00	47	Mekanik Arıza	2026-04-29 13:07:11.115+00	\N
2935	105	2026-04-04	2026-04-05 05:00:00+00	2026-04-05 05:15:00+00	15	Ayar	2026-04-29 13:07:11.129+00	\N
2936	105	2026-04-03	2026-04-04 05:00:00+00	2026-04-04 05:09:00+00	9	Ayar	2026-04-29 13:07:11.144+00	\N
2937	105	2026-04-02	2026-04-03 05:00:00+00	2026-04-03 05:20:00+00	20	Mekanik Arıza	2026-04-29 13:07:11.159+00	\N
2938	105	2026-04-01	2026-04-02 05:00:00+00	2026-04-02 05:01:00+00	1	Mekanik Arıza	2026-04-29 13:07:11.175+00	\N
2939	105	2026-03-31	2026-04-01 05:00:00+00	2026-04-01 05:28:00+00	28	Ayar	2026-04-29 13:07:11.188+00	\N
2940	105	2026-03-30	2026-03-31 05:00:00+00	2026-03-31 05:13:00+00	13	Mekanik Arıza	2026-04-29 13:07:11.204+00	\N
\.


--
-- TOC entry 3929 (class 0 OID 89597)
-- Dependencies: 229
-- Data for Name: firma; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.firma (firma_id, firma_adi, vergi_no, aktif_mi, abonelik_tip_id, iletisim_id, sektor_id) FROM stdin;
1	AKTEKS TEKSTİL A.Ş.	\N	\N	\N	\N	\N
\.


--
-- TOC entry 3931 (class 0 OID 89604)
-- Dependencies: 231
-- Data for Name: form_madde_cevap; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.form_madde_cevap (cevap_id, form_id, soru_referans_id, durum, aciklama, girilen_deger) FROM stdin;
\.


--
-- TOC entry 3961 (class 0 OID 89721)
-- Dependencies: 261
-- Data for Name: garanti_firma; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.garanti_firma (garanti_firma_id, firma_adi, iletisim_id) FROM stdin;
1	Genel Makine İthalat İhracat A.Ş.	2
\.


--
-- TOC entry 3963 (class 0 OID 89728)
-- Dependencies: 263
-- Data for Name: genel_sorular; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.genel_sorular (genel_soru_id, madde_adi, teknik_parametre, aktiflik, kritiklik_durumu) FROM stdin;
\.


--
-- TOC entry 3933 (class 0 OID 89613)
-- Dependencies: 233
-- Data for Name: gunluk_kontrol_formu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.gunluk_kontrol_formu (form_id, makine_id, kullanici_id, sablon_id, kontrol_tarihi, genel_not, ai_on_risk_durumu) FROM stdin;
\.


--
-- TOC entry 3975 (class 0 OID 89777)
-- Dependencies: 275
-- Data for Name: iletisim; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.iletisim (iletisim_id, telefon, mail, il, ilce, acik_adres) FROM stdin;
1	02125551020	info@abcotomotiv.com	İSTANBUL	İkitelli	İkitelli Organize Sanayi Bölgesi, Metal İş Sanayi Sitesi, 12. Blok No: 45
2	+90 555 123 4567	destek@genelyedekparca.com	\N	\N	Endüstri Sanayi Sitesi, 1. Blok No:4, İstanbul
\.


--
-- TOC entry 3935 (class 0 OID 89622)
-- Dependencies: 235
-- Data for Name: kontrol_maddesi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.kontrol_maddesi (madde_id, sablon_id, madde_adi, teknik_parametre, kritiklik_durumu) FROM stdin;
1	1	Sıcaklık Anomalisi	sicaklik	f
2	1	Titreşim Anomalisi	titresim	f
3	1	Ses Anomalisi	ses_anomalisi	f
4	1	Yağ Kaçağı/Durumu	yag_durumu	f
5	1	Form Doldurma Süresi (sn)	form_doldurma_suresi_sn	f
6	1	İş Mili Ses ve Titreşim	is_mili_ses_ve_titresim	f
7	1	Eksen Ölçü Sapması	eksen_olcu_sapmasi	f
8	1	Takım Zorlanma Durumu	takim_zorlanma_durumu	f
9	1	İşlenen Yüzey Kalitesi	islenen_yuzey_kalitesi	f
10	1	İş Mili Gövde Sıcaklığı	is_mili_govde_sicakligi	f
11	1	Bor Yağı ve Soğutma	bor_yagi_ve_sogutma	f
12	1	Pnömatik Hava Basıncı	pnomatik_hava_basinci	f
13	1	Kızak Yağ Seviyesi	kizak_yag_seviyesi	f
14	2	Sıcaklık Anomalisi	sicaklik	f
15	2	Titreşim Anomalisi	titresim	f
16	2	Ses Anomalisi	ses_anomalisi	f
17	2	Yağ Kaçağı/Durumu	yag_durumu	f
18	2	Form Doldurma Süresi (sn)	form_doldurma_suresi_sn	f
19	2	Hidrolik Basınç Seviyesi	hidrolik_basinc_seviyesi	f
20	2	Hidrolik Yağ Sıcaklığı	hidrolik_yag_sicakligi	f
21	2	Yağ Kaçak Durumu	yag_kacak_durumu	f
22	2	Koç Vuruntu Sesi	koc_vuruntu_sesi	f
23	2	Koç Kılavuz Boşluğu	koc_kilavuz_boslugu	f
24	2	Kavrama Fren Hava Basıncı	kavrama_fren_hava_basinci	f
25	2	Tonaj Sapması	tonaj_sapmasi	f
26	2	Basılan Parça Kalitesi	basilan_parca_kalitesi	f
27	3	Sıcaklık Anomalisi	sicaklik	f
28	3	Titreşim Anomalisi	titresim	f
29	3	Ses Anomalisi	ses_anomalisi	f
30	3	Yağ Kaçağı/Durumu	yag_durumu	f
31	3	Form Doldurma Süresi (sn)	form_doldurma_suresi_sn	f
32	3	Kovan Rezistans Sıcaklığı	kovan_rezistans_sicakligi	f
33	3	Eriyik Plastik Kokusu	eriyik_plastik_kokusu	f
34	3	Vida Dönüş Sesi	vida_donus_sesi	f
35	3	Enjeksiyon Baskı Basıncı	enjeksiyon_baski_basinci	f
36	3	Mengene Kapanma Basıncı	mengene_kapanma_basinci	f
37	3	Kalıp Soğutma Suyu Debisi	kalip_sogutma_suyu_debisi	f
38	3	Soğutma Suyu Sıcaklığı	sogutma_suyu_sicakligi	f
39	3	Eksik Baskı Durumu	eksik_baski_durumu	f
40	3	Çapaklı Baskı Durumu	capakli_baski_durumu	f
\.


--
-- TOC entry 3937 (class 0 OID 89629)
-- Dependencies: 237
-- Data for Name: kontrol_sablonu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.kontrol_sablonu (sablon_id, makine_tur_id, sablon_adi, aciklama, aktiflik) FROM stdin;
1	2	Günlük Operatör Kontrolü	CNC Makinesi için günlük operatör kontrol formu.	t
2	3	Günlük Operatör Kontrolü	Pres Makinesi için günlük operatör kontrol formu.	t
3	4	Günlük Operatör Kontrolü	Plastik Enjeksiyon Makinesi için günlük operatör kontrol formu.	t
\.


--
-- TOC entry 3917 (class 0 OID 89546)
-- Dependencies: 217
-- Data for Name: kullanici; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.kullanici (kullanici_id, firma_id, rol_id, ad, soyad, telefon, eposta, sifre, aktiflik, baslama_tarihi, kullanici_adi) FROM stdin;
4	1	2	Zeynep	Yılmaz	05551112233	zeynep.yilmaz@endux.com	pbkdf2_password_hash_1	t	2025-01-10	zeynep_admin
5	1	1	Canan	Yılmaz	5551112233	canan.yilmaz@deu.edu.tr	$2b$10$CxZf33nDiru6T2KvCI7eVuTD1wXuaOVm6Yps5Ji9.6xrRmbkMfdci	t	2026-04-29	Canan
6	1	1	Sistem	Yöneticisi	5550000000	admin@endux.com	$2b$10$cC4GHQEzL0f7CQvnBqmVY.dVP5rIRZCo6QEocGfSW9fo4Tb6nEKzi	t	2026-04-29	YON_admin
8	1	3	meryem	çelebi	555555555	meryem@gmail.com	$2b$10$MoHnF645HvZpuF9stb9U..yKRcCwFth.UCm1GtxdhsgGkngeHX0li	t	\N	OP_meryemcelebi
\.


--
-- TOC entry 3939 (class 0 OID 89638)
-- Dependencies: 239
-- Data for Name: lokasyon; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lokasyon (lokasyon_id, fabrika_alani, kat, x_koor, y_koor, guncelleme_tarihi, firma_id, makine_id) FROM stdin;
\.


--
-- TOC entry 3941 (class 0 OID 89647)
-- Dependencies: 241
-- Data for Name: makine; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine (makine_id, firma_id, makine_tur_id, makine_qr, makine_adi, satin_alma_tarihi, satin_alma_maliyeti, aktiflik_durumu, seri_no, garanti_suresi, garanti_firma_id, servis_pin, toplam_calisma_saati) FROM stdin;
6	1	4	7bd8d5cb-e9e8-4cf8-95e6-5202b0e26c95	Plastik Enjeksiyon Makinesi - Ünite 1 (2.El)	2020-04-16	443657.0000	t	SNO-203EE01C	0	1	1888	7565.00
11	1	3	260d7034-b893-458a-8c40-87d3e788ab11	Pres Makinesi - Ünite 6 (2.El)	2022-06-16	120289.0000	t	SNO-90D9F4F3	0	1	6142	9542.00
12	1	4	20882970-e800-4aed-8d3d-538982fca31e	Plastik Enjeksiyon Makinesi - Ünite 7 (Sıfır)	2026-04-29	576918.0000	t	SNO-3350B916	24	1	7524	0.00
13	1	2	7873a4b8-020f-455e-be4f-5ef2e0647de5	CNC Makinesi - Ünite 8 (2.El)	2025-04-21	420533.0000	t	SNO-45790A26	0	1	4395	10627.00
14	1	4	11192dd8-973c-4ea9-948d-8a51518e03a2	Plastik Enjeksiyon Makinesi - Ünite 9 (Sıfır)	2026-04-29	145677.0000	t	SNO-35051C5F	24	1	8972	0.00
15	1	2	64494825-6061-4fe0-982f-021baf9d2df3	CNC Makinesi - Ünite 10 (Sıfır)	2026-04-29	335422.0000	t	SNO-360A5BA7	24	1	9970	0.00
16	1	3	d8d59c2c-cff6-4cfc-8832-efbc520a4160	Pres Makinesi - Ünite 11 (2.El)	2025-08-04	380027.0000	f	SNO-2AEC3AD6	0	1	5471	3681.00
17	1	3	411ff152-365e-457c-a326-f3ea301d4a03	Pres Makinesi - Ünite 12 (Sıfır)	2026-04-29	149185.0000	t	SNO-9C74C436	24	1	5968	0.00
18	1	4	a2c64996-6bfd-4a23-a03b-99d3f864c6f9	Plastik Enjeksiyon Makinesi - Ünite 13 (Sıfır)	2026-04-29	510239.0000	t	SNO-8FEE9FEA	24	1	9946	0.00
19	1	3	bae305a9-34c3-449f-a5d0-b074a609ddaa	Pres Makinesi - Ünite 14 (2.El)	2023-03-06	554092.0000	t	SNO-2B9FCA63	0	1	4863	5929.00
20	1	3	a555cee2-79f7-4463-8c27-ff68239d388f	Pres Makinesi - Ünite 15 (2.El)	2023-08-16	497083.0000	f	SNO-F9C807DC	0	1	4525	7362.00
21	1	2	4b058daa-e095-4b6c-bae6-b4eead148c5b	CNC Makinesi - Ünite 16 (Sıfır)	2026-04-29	584556.0000	t	SNO-F7C1DF13	24	1	7306	0.00
22	1	2	3f993fe6-cef5-4bdf-86eb-bdaf4b9ab6ed	CNC Makinesi - Ünite 17 (2.El)	2026-03-11	163529.0000	t	SNO-4EEC1CB3	0	1	2379	4236.00
23	1	4	47113000-a38b-4091-8cb8-0fb25baf46ef	Plastik Enjeksiyon Makinesi - Ünite 18 (2.El)	2024-01-15	317540.0000	t	SNO-CFA6EDB3	0	1	6908	3389.00
24	1	4	f0eec8dc-69ad-481f-86c9-0403661f36ca	Plastik Enjeksiyon Makinesi - Ünite 19 (Sıfır)	2026-04-29	539204.0000	f	SNO-1A9C2B6F	24	1	5646	0.00
25	1	4	0c29106e-08de-41e7-8966-e170cef1719f	Plastik Enjeksiyon Makinesi - Ünite 20 (2.El)	2025-08-15	566715.0000	t	SNO-11C01C79	0	1	4679	2662.00
26	1	4	bbccef97-2160-4a00-8b61-1083c24d30a9	Plastik Enjeksiyon Makinesi - Ünite 21 (Sıfır)	2026-04-29	418897.0000	t	SNO-BA5C559B	24	1	7639	0.00
27	1	4	3c7809f8-ebb9-4c48-9c47-2ab549688f0c	Plastik Enjeksiyon Makinesi - Ünite 22 (2.El)	2026-02-13	360033.0000	t	SNO-CA314DE9	0	1	8010	9142.00
28	1	4	6772a207-43d7-4ef9-a2ba-d60ee5df05ba	Plastik Enjeksiyon Makinesi - Ünite 23 (2.El)	2026-03-12	478640.0000	t	SNO-5E7CB23E	0	1	9815	5292.00
29	1	3	e3c582e8-e4d0-4dfb-941d-b520234d718a	Pres Makinesi - Ünite 24 (Sıfır)	2026-04-29	540000.0000	f	SNO-8B5AED3E	24	1	7557	0.00
30	1	3	164e48da-0f64-4991-8ae0-bae0e2bea61a	Pres Makinesi - Ünite 25 (2.El)	2023-10-06	451086.0000	t	SNO-A5BD89CF	0	1	2224	1292.00
31	1	2	4e826700-7b97-4915-bda9-24ab3b986abb	CNC Makinesi - Ünite 26 (2.El)	2022-02-12	272190.0000	t	SNO-8A921F0A	0	1	3701	123.00
32	1	3	594f9beb-1c71-433f-9d8e-fa1e538befea	Pres Makinesi - Ünite 27 (Sıfır)	2026-04-29	123416.0000	t	SNO-627B54BA	24	1	5294	0.00
33	1	2	254916f1-4553-4008-b241-b41215b18382	CNC Makinesi - Ünite 28 (2.El)	2020-07-03	523323.0000	t	SNO-DF2D1709	0	1	1419	4596.00
34	1	3	59078745-f705-476b-ab92-e010ca4c7fe1	Pres Makinesi - Ünite 29 (Sıfır)	2026-04-29	461860.0000	t	SNO-731B807D	24	1	6086	0.00
35	1	2	2b7e2b02-9a7e-4323-92a3-7e18cd796fb4	CNC Makinesi - Ünite 30 (2.El)	2021-08-17	406371.0000	f	SNO-FA25327D	0	1	3352	5743.00
36	1	3	8b5886a3-b011-4bbd-81f1-a331a7cc85a6	Pres Makinesi - Ünite 31 (2.El)	2020-05-05	144951.0000	t	SNO-81B23769	0	1	5580	6413.00
37	1	3	5f8c4c87-6b68-4342-a075-4b397462d9ed	Pres Makinesi - Ünite 32 (Sıfır)	2026-04-29	581779.0000	t	SNO-A94057B5	24	1	4483	0.00
38	1	4	e3b66965-12a9-400f-b33a-e32191db0144	Plastik Enjeksiyon Makinesi - Ünite 33 (2.El)	2022-10-16	540336.0000	t	SNO-45825D40	0	1	4171	2966.00
39	1	2	92d7bcbc-0e47-44be-82f6-d8acfd981157	CNC Makinesi - Ünite 34 (Sıfır)	2026-04-29	460464.0000	t	SNO-B559B8A9	24	1	2369	0.00
40	1	3	18e053a2-fbe6-459d-87d8-f237d2bdad39	Pres Makinesi - Ünite 35 (2.El)	2025-04-18	231238.0000	t	SNO-CA845A8A	0	1	2222	11721.00
41	1	4	21828672-dffd-4571-abfc-165dae5e56e2	Plastik Enjeksiyon Makinesi - Ünite 36 (Sıfır)	2026-04-29	440282.0000	t	SNO-1A332FFE	24	1	1137	0.00
42	1	3	a746a5b2-a648-4b5f-9d93-99442dca69d7	Pres Makinesi - Ünite 37 (2.El)	2023-04-22	342760.0000	t	SNO-B3230974	0	1	9687	2079.00
43	1	4	2cc7b351-f9f9-40a1-9ade-35107f53efd5	Plastik Enjeksiyon Makinesi - Ünite 38 (Sıfır)	2026-04-29	225400.0000	t	SNO-67A3B004	24	1	8284	0.00
44	1	4	27434298-bf52-414a-a839-412410fc27d1	Plastik Enjeksiyon Makinesi - Ünite 39 (Sıfır)	2026-04-29	240696.0000	f	SNO-645956DD	24	1	1972	0.00
45	1	2	52a73725-958d-492d-bce1-507f335df59c	CNC Makinesi - Ünite 40 (Sıfır)	2026-04-29	561037.0000	t	SNO-5BD63880	24	1	8040	0.00
46	1	2	ddce8f37-6213-4aeb-a13f-bd2561be2742	CNC Makinesi - Ünite 41 (Sıfır)	2026-04-29	339629.0000	t	SNO-00FD67CA	24	1	7316	0.00
47	1	4	65be0ed2-1004-4429-969e-4059a47c9b05	Plastik Enjeksiyon Makinesi - Ünite 42 (2.El)	2020-09-04	528534.0000	f	SNO-28AA33C0	0	1	2827	7148.00
48	1	2	c5a20248-4fd3-40bf-88fa-590659b16582	CNC Makinesi - Ünite 43 (2.El)	2021-09-26	232278.0000	t	SNO-3649827C	0	1	8140	1645.00
49	1	3	f8140811-a4a3-4f20-8811-788da85275c2	Pres Makinesi - Ünite 44 (2.El)	2022-03-13	119157.0000	t	SNO-ABBCA13D	0	1	8193	4391.00
50	1	2	7165ebde-9da6-4f7e-b130-073cbccd2506	CNC Makinesi - Ünite 45 (2.El)	2020-03-28	406731.0000	t	SNO-0F8940E9	0	1	6159	2926.00
51	1	4	51640699-4b43-4d55-8608-acf688fed6fc	Plastik Enjeksiyon Makinesi - Ünite 46 (2.El)	2020-06-22	205652.0000	t	SNO-B4BC61AC	0	1	6245	10342.00
52	1	4	fdc48f80-77a4-4d59-b645-75ae2287d0fb	Plastik Enjeksiyon Makinesi - Ünite 47 (2.El)	2021-05-26	397369.0000	t	SNO-8F6E159D	0	1	4952	12500.00
53	1	4	2bf06eba-d15f-45c6-8c63-7cd61fc71942	Plastik Enjeksiyon Makinesi - Ünite 48 (Sıfır)	2026-04-29	520259.0000	f	SNO-5FF6A40A	24	1	3211	0.00
54	1	2	a06739e8-85ae-4920-9393-24d20dd949d0	CNC Makinesi - Ünite 49 (Sıfır)	2026-04-29	182379.0000	t	SNO-E445B6AB	24	1	9613	0.00
8	1	3	aa147b53-adbe-409b-8e3a-1679f7092d29	Pres Makinesi - Ünite 3 (Sıfır)	2026-04-29	192081.0000	f	SNO-85297733	24	1	8819	0.00
9	1	2	be3cf861-d594-477f-a73c-1dfe233d03cf	CNC Makinesi - Ünite 4 (2.El)	2023-09-12	459716.0000	f	SNO-D6F17F4B	0	1	3876	13958.00
10	1	4	1abc5c5a-f78e-4153-8c22-edba04c7c49a	Plastik Enjeksiyon Makinesi - Ünite 5 (Sıfır)	2026-04-29	232147.0000	f	SNO-C6466D41	24	1	9675	0.00
55	1	2	41c5a22e-d542-47ce-8a3d-9558743d53e3	CNC Makinesi - Ünite 50 (Sıfır)	2026-04-29	115051.0000	f	SNO-B65BEAB5	24	1	9578	0.00
56	1	3	2f868c26-7b43-4368-b1f4-c145c7cb3bda	Pres Makinesi - Ünite 51 (2.El)	2025-03-08	417896.0000	t	SNO-AC769244	0	1	9523	8326.00
57	1	2	1d5d1bdf-5582-4c33-9307-901d6d3106a1	CNC Makinesi - Ünite 52 (2.El)	2022-12-08	243057.0000	t	SNO-70BC7E04	0	1	5924	13636.00
58	1	3	a36774a1-19c4-4493-87cb-13c0047a161e	Pres Makinesi - Ünite 53 (2.El)	2020-04-13	427817.0000	t	SNO-091DC208	0	1	3603	1618.00
59	1	2	be5d7909-635d-4147-b707-8bc2a0e274c5	CNC Makinesi - Ünite 54 (2.El)	2023-10-30	324894.0000	t	SNO-1BE701ED	0	1	8965	14358.00
60	1	4	386aa011-9bda-48c5-a08e-4b6aad15e4e4	Plastik Enjeksiyon Makinesi - Ünite 55 (2.El)	2026-04-18	572387.0000	t	SNO-6C105E48	0	1	6036	5670.00
61	1	3	3076ea1f-ca8a-437b-b4c1-cfc724434a0b	Pres Makinesi - Ünite 56 (2.El)	2025-07-16	468312.0000	t	SNO-1054E2B0	0	1	8741	5974.00
62	1	2	da192709-2972-4510-898a-1351bf305b5b	CNC Makinesi - Ünite 57 (Sıfır)	2026-04-29	306344.0000	f	SNO-4D0018FA	24	1	2864	0.00
63	1	2	6837deab-7825-4e80-91d6-ba99de12350a	CNC Makinesi - Ünite 58 (Sıfır)	2026-04-29	501525.0000	t	SNO-4837A857	24	1	2270	0.00
64	1	3	f2ec1e15-010f-4fa5-9670-fbedc6f4ee7b	Pres Makinesi - Ünite 59 (2.El)	2021-06-17	368287.0000	t	SNO-0A270245	0	1	5499	11020.00
65	1	2	eaa99fa4-1d2c-4f30-92ac-79cc69392007	CNC Makinesi - Ünite 60 (Sıfır)	2026-04-29	208081.0000	t	SNO-CE10DDCA	24	1	9895	0.00
66	1	3	8872c8bf-103c-4495-858b-2f160da2f782	Pres Makinesi - Ünite 61 (2.El)	2020-08-23	166154.0000	t	SNO-26155C5C	0	1	6739	5308.00
67	1	4	fca0dff0-7394-4103-9ff8-b0e17ebbc621	Plastik Enjeksiyon Makinesi - Ünite 62 (Sıfır)	2026-04-29	238347.0000	t	SNO-81ED3756	24	1	9103	0.00
68	1	4	d7288a2d-7027-4ecf-b4fe-fbfa27653c46	Plastik Enjeksiyon Makinesi - Ünite 63 (2.El)	2026-02-08	151532.0000	f	SNO-48372A55	0	1	2449	4281.00
69	1	2	74d043f0-4766-4fef-a22f-eb3ecc5cb160	CNC Makinesi - Ünite 64 (Sıfır)	2026-04-29	570951.0000	t	SNO-9F2E4B34	24	1	2929	0.00
70	1	2	c9b387a8-866f-4091-8d30-9ed244886744	CNC Makinesi - Ünite 65 (Sıfır)	2026-04-29	417200.0000	f	SNO-82BE6CD1	24	1	9014	0.00
71	1	2	effb3f3a-3a44-485e-ad89-14ca8db0d335	CNC Makinesi - Ünite 66 (2.El)	2023-06-23	552297.0000	t	SNO-9B3D626D	0	1	8927	9540.00
72	1	3	a141a546-26df-4550-9ae1-a15f9fc0c8c4	Pres Makinesi - Ünite 67 (2.El)	2025-09-08	509310.0000	t	SNO-F4660151	0	1	2821	8945.00
73	1	3	e800b184-d513-4e42-8845-fa6ed3b65f0b	Pres Makinesi - Ünite 68 (2.El)	2023-07-22	531211.0000	f	SNO-6A05529D	0	1	5101	4888.00
74	1	2	350de925-1053-45cd-bc33-5ea3e1e42810	CNC Makinesi - Ünite 69 (2.El)	2021-01-05	536259.0000	t	SNO-218B09B1	0	1	3545	7878.00
75	1	4	3769a7da-4c45-49da-bd0f-ec640515b7ad	Plastik Enjeksiyon Makinesi - Ünite 70 (2.El)	2023-06-04	476291.0000	t	SNO-7EEF8C2F	0	1	4432	5108.00
76	1	4	540fe715-50e8-4edd-a72f-9543eca31288	Plastik Enjeksiyon Makinesi - Ünite 71 (2.El)	2023-06-05	487218.0000	t	SNO-8F124B0A	0	1	7847	13435.00
77	1	3	404d1dde-3338-401c-9788-2d9bffe27e11	Pres Makinesi - Ünite 72 (Sıfır)	2026-04-29	331523.0000	t	SNO-30641F6B	24	1	2044	0.00
78	1	4	93355f02-986c-49cd-b23b-ec09dee59f24	Plastik Enjeksiyon Makinesi - Ünite 73 (2.El)	2021-02-16	341033.0000	f	SNO-547FD1CE	0	1	6458	325.00
79	1	4	462f402b-0128-4967-8621-21e7ace58f0d	Plastik Enjeksiyon Makinesi - Ünite 74 (2.El)	2022-01-30	454153.0000	t	SNO-89255D0F	0	1	6450	4301.00
80	1	3	eaa409ae-6bff-417d-b0e1-f6bc686c482b	Pres Makinesi - Ünite 75 (2.El)	2021-07-20	130513.0000	f	SNO-DC1C3CC9	0	1	2899	11877.00
81	1	3	09bfed16-4845-49c8-a08e-be09110c82b7	Pres Makinesi - Ünite 76 (Sıfır)	2026-04-29	576858.0000	t	SNO-85E45183	24	1	3210	0.00
82	1	4	6d80bebe-7e97-45e9-b6bd-1dae30b0c9ca	Plastik Enjeksiyon Makinesi - Ünite 77 (2.El)	2025-10-12	314953.0000	f	SNO-A30CE4C9	0	1	2917	1953.00
83	1	3	612d6500-3adc-4d03-8f4c-922b43179b5b	Pres Makinesi - Ünite 78 (Sıfır)	2026-04-29	354054.0000	f	SNO-F86D2D55	24	1	1834	0.00
84	1	4	a3ffd672-ad09-4bd2-9c18-b84dea34ce30	Plastik Enjeksiyon Makinesi - Ünite 79 (Sıfır)	2026-04-29	534848.0000	t	SNO-27FD0684	24	1	4178	0.00
85	1	3	58e5e30b-3f91-4b4f-b4c0-4d1a609c9db6	Pres Makinesi - Ünite 80 (Sıfır)	2026-04-29	214158.0000	t	SNO-EBAAE9BE	24	1	5786	0.00
86	1	4	eb7404b9-592a-4ec7-9d91-d3c274fbe15b	Plastik Enjeksiyon Makinesi - Ünite 81 (Sıfır)	2026-04-29	420915.0000	t	SNO-EB67DD78	24	1	3327	0.00
87	1	3	223c0b84-8bc5-44e5-a123-3e2c10cb09bc	Pres Makinesi - Ünite 82 (Sıfır)	2026-04-29	599820.0000	t	SNO-66ACBD71	24	1	4586	0.00
88	1	3	b863f16b-37a9-4632-9f31-b0f0f37de04a	Pres Makinesi - Ünite 83 (2.El)	2020-06-07	447684.0000	t	SNO-43643A2A	0	1	4453	7019.00
89	1	4	7529921d-c772-45f6-adc0-ab54a6470fa2	Plastik Enjeksiyon Makinesi - Ünite 84 (2.El)	2021-07-20	441462.0000	t	SNO-9BD607F6	0	1	2807	11705.00
90	1	3	4609b20e-39c1-43ad-af2d-e32903cf3a9a	Pres Makinesi - Ünite 85 (2.El)	2024-04-09	558347.0000	t	SNO-ADC5E9E9	0	1	2326	10424.00
91	1	2	da4f7f5e-419d-42c9-9188-46c809858622	CNC Makinesi - Ünite 86 (2.El)	2020-05-26	133810.0000	t	SNO-BEA605A2	0	1	5448	13646.00
92	1	2	2b8bf538-2e01-4159-b67d-cf2c7fc6e12c	CNC Makinesi - Ünite 87 (Sıfır)	2026-04-29	223081.0000	f	SNO-A5357110	24	1	1919	0.00
93	1	4	06314fbf-ace0-4361-94af-03e9c265c432	Plastik Enjeksiyon Makinesi - Ünite 88 (Sıfır)	2026-04-29	119947.0000	t	SNO-F2FFC54A	24	1	2342	0.00
94	1	3	8347ed4e-4a0e-4f8d-9f04-fbc361702feb	Pres Makinesi - Ünite 89 (2.El)	2024-02-11	464476.0000	f	SNO-24AB2F44	0	1	2821	14247.00
95	1	3	50b5d83e-8b68-4178-8234-bc2e99cda94e	Pres Makinesi - Ünite 90 (2.El)	2025-01-15	336342.0000	t	SNO-C86AFBAA	0	1	9118	3896.00
96	1	4	bd7a5d20-73e6-4b3b-998c-c8554e7d5d4c	Plastik Enjeksiyon Makinesi - Ünite 91 (2.El)	2024-04-02	423225.0000	t	SNO-6F7323F6	0	1	9710	633.00
97	1	2	32ce1eeb-5bad-4471-95a5-1a9c0f42c651	CNC Makinesi - Ünite 92 (2.El)	2021-03-14	315630.0000	t	SNO-2613C64D	0	1	8384	7654.00
98	1	3	eb809400-2e23-43b4-bf03-1a17129defab	Pres Makinesi - Ünite 93 (2.El)	2021-05-21	100432.0000	t	SNO-F9DBCEF5	0	1	2869	12953.00
99	1	3	86b1bab6-5a39-4daf-89c6-dfa3a5e9dfcd	Pres Makinesi - Ünite 94 (2.El)	2025-10-02	425107.0000	t	SNO-D9461189	0	1	2423	4800.00
100	1	4	6ab42e8b-55f9-4b77-86cc-7e0d1d7168e3	Plastik Enjeksiyon Makinesi - Ünite 95 (Sıfır)	2026-04-29	565712.0000	t	SNO-CB365382	24	1	4458	0.00
101	1	4	fe868a99-4ea2-4661-a3fd-fd229f7655c7	Plastik Enjeksiyon Makinesi - Ünite 96 (2.El)	2024-04-27	415434.0000	f	SNO-9832E18E	0	1	4356	8355.00
102	1	2	8bf3d883-cb9a-4bfc-a8f3-e83e9bc386df	CNC Makinesi - Ünite 97 (Sıfır)	2026-04-29	289180.0000	t	SNO-CBB93E81	24	1	1935	0.00
103	1	3	a4f07726-0ccf-4bdf-978e-4f89f0f46db0	Pres Makinesi - Ünite 98 (Sıfır)	2026-04-29	515679.0000	t	SNO-736B3361	24	1	4488	0.00
104	1	3	75cccb9d-74f6-40a9-87b7-e595855a8d1f	Pres Makinesi - Ünite 99 (2.El)	2021-04-21	395115.0000	t	SNO-92618F4D	0	1	5036	14863.00
105	1	3	ca56a8aa-cd90-4395-9ad0-9447891673c3	Pres Makinesi - Ünite 100 (2.El)	2020-08-07	413697.0000	t	SNO-18774169	0	1	7257	3542.00
7	1	4	b58654b1-c934-4f8a-8fe6-c86c9c2756a0	Plastik Enjeksiyon Makinesi - Ünite 2 (2.El)	2021-04-13	408257.0000	f	SNO-83F272E2	0	1	6080	5366.00
\.


--
-- TOC entry 3943 (class 0 OID 89655)
-- Dependencies: 243
-- Data for Name: makine_kullanim; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine_kullanim (kullanim_id, kullanici_id, makine_id, baslangic_zamani, bitis_zamani, gunluk_top_calisma_saati) FROM stdin;
\.


--
-- TOC entry 3965 (class 0 OID 89735)
-- Dependencies: 265
-- Data for Name: makine_ozellikleri; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine_ozellikleri (ozellik_id, makine_id, teknik_ozellikler, guncelleme_tarihi) FROM stdin;
\.


--
-- TOC entry 3945 (class 0 OID 89663)
-- Dependencies: 245
-- Data for Name: makine_turu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.makine_turu (makine_tur_id, makine_tur_adi, risk_katsayisi) FROM stdin;
1	DOKUMA MAKİNESİ	1.50
2	CNC Makinesi	1.50
3	Pres Makinesi	2.00
4	Plastik Enjeksiyon Makinesi	1.80
\.


--
-- TOC entry 3986 (class 0 OID 105954)
-- Dependencies: 296
-- Data for Name: oee_raporlari; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.oee_raporlari (rapor_id, makine_id, tarih, kullanilabilirlik_orani, performans_orani, kalite_orani, oee_skoru) FROM stdin;
1	6	2026-04-28	90.21	96.4	96.27	83.71
2	6	2026-04-27	91.25	88.3	98.87	79.66
3	6	2026-04-26	89.38	84.8	98.47	74.63
4	6	2026-04-25	89.38	95	96.95	82.31
5	6	2026-04-24	92.71	81.7	98.78	74.82
6	6	2026-04-23	98.54	87.6	96	82.87
7	6	2026-04-22	90.42	88.5	97.06	77.67
8	6	2026-04-21	93.33	80.2	99	74.11
9	6	2026-04-20	88.75	94.8	98.1	82.54
10	6	2026-04-19	99.17	82	98.29	79.93
11	6	2026-04-18	90.63	83.2	98.92	74.58
12	6	2026-04-17	89.79	90.6	98.01	79.74
13	6	2026-04-16	87.71	95.7	97.39	81.74
14	6	2026-04-15	98.54	95.9	96.98	91.64
15	6	2026-04-14	92.5	93.3	96.89	83.62
16	6	2026-04-13	98.33	88.1	96.59	83.68
17	6	2026-04-12	89.58	93.4	97.32	81.43
18	6	2026-04-11	95	96	96.25	87.78
19	6	2026-04-10	87.71	80	98.13	68.85
20	6	2026-04-09	96.67	84.6	97.04	79.36
21	6	2026-04-08	95.42	82.6	96	75.67
22	6	2026-04-07	99.58	89.8	95.66	85.54
23	6	2026-04-06	91.67	95.9	97.71	85.89
24	6	2026-04-05	93.96	81.7	97.92	75.17
25	6	2026-04-04	91.46	93.1	96.13	81.86
26	6	2026-04-03	89.79	82.8	97.58	72.55
27	6	2026-04-02	99.38	86.9	96.32	83.18
28	6	2026-04-01	90.42	90.7	99.01	81.19
29	6	2026-03-31	92.92	85.5	96.14	76.38
30	6	2026-03-30	89.79	91.6	96.4	79.29
31	7	2026-04-28	94.38	91	95.27	81.82
32	7	2026-04-27	97.71	93.8	95.63	87.64
33	7	2026-04-26	88.13	93.5	95.29	78.52
34	7	2026-04-25	90.42	85.3	96.83	74.68
35	7	2026-04-24	88.75	91.5	97.27	78.99
36	7	2026-04-23	88.96	81.9	96.7	70.45
37	7	2026-04-22	91.25	91.8	95.64	80.12
38	7	2026-04-21	97.92	81.3	96.06	76.47
39	7	2026-04-20	93.33	95.3	96.22	85.59
40	7	2026-04-19	88.75	94.5	96.08	80.58
41	7	2026-04-18	98.33	85.9	95.23	80.44
42	7	2026-04-17	91.46	89.8	96.88	79.57
43	7	2026-04-16	94.38	88.9	96.18	80.69
44	7	2026-04-15	95.63	85.4	98.24	80.23
45	7	2026-04-14	90	97.8	97.24	85.59
46	7	2026-04-13	96.88	95	97.68	89.9
47	7	2026-04-12	96.67	86.2	97.56	81.3
48	7	2026-04-11	96.67	88.7	97.41	83.52
49	7	2026-04-10	87.92	87.3	97.59	74.91
50	7	2026-04-09	92.29	93.4	97.22	83.8
51	7	2026-04-08	96.04	88.2	96.83	82.02
52	7	2026-04-07	98.54	81.8	96.33	77.65
53	7	2026-04-06	94.17	85.4	95.78	77.03
54	7	2026-04-05	98.54	87.1	95.75	82.18
55	7	2026-04-04	94.58	90	98.78	84.08
56	7	2026-04-03	87.92	83.9	96.78	71.39
57	7	2026-04-02	91.46	95.2	95.69	83.32
58	7	2026-04-01	98.75	89.4	97.76	86.31
59	7	2026-03-31	88.75	90.8	96.26	77.57
60	7	2026-03-30	90.42	92.6	95.14	79.66
61	8	2026-04-28	92.29	83.3	98.56	75.77
62	8	2026-04-27	98.96	81.6	95.71	77.29
63	8	2026-04-26	96.88	82.8	97.71	78.37
64	8	2026-04-25	97.92	94.8	98.31	91.26
65	8	2026-04-24	91.25	92.4	97.62	82.31
66	8	2026-04-23	92.71	92.5	95.35	81.77
67	8	2026-04-22	94.17	88.7	97.97	81.83
68	8	2026-04-21	96.88	89.5	96.65	83.8
69	8	2026-04-20	97.29	94	95.85	87.66
70	8	2026-04-19	95.63	85.2	96.01	78.22
71	8	2026-04-18	96.25	88.8	97.97	83.74
72	8	2026-04-17	92.5	81.2	98.4	73.91
73	8	2026-04-16	99.38	90	95.22	85.16
74	8	2026-04-15	89.38	89.4	98.43	78.65
75	8	2026-04-14	93.13	91.5	95.74	81.58
76	8	2026-04-13	99.38	81.1	97.41	78.51
77	8	2026-04-12	87.5	82.7	95.65	69.21
78	8	2026-04-11	87.5	92.2	97.29	78.49
79	8	2026-04-10	93.33	97.1	96.91	87.83
80	8	2026-04-09	96.88	91.8	97.6	86.8
81	8	2026-04-08	92.92	85.7	97.67	77.77
82	8	2026-04-07	90.63	81.4	98.89	72.95
83	8	2026-04-06	90.21	95.2	97.58	83.8
84	8	2026-04-05	99.38	85.9	97.67	83.38
85	8	2026-04-04	97.29	93.2	95.49	86.59
86	8	2026-04-03	98.54	88.5	96.05	83.76
87	8	2026-04-02	89.79	93.9	95.31	80.36
88	8	2026-04-01	90.42	93.7	98.19	83.18
89	8	2026-03-31	89.79	87.8	98.86	77.94
90	8	2026-03-30	99.38	87.9	96.7	84.47
91	9	2026-04-28	94.17	86.1	95.24	77.22
92	9	2026-04-27	91.04	89.5	96.76	78.84
93	9	2026-04-26	99.58	96.4	95.85	92.01
94	9	2026-04-25	88.13	80.4	98.51	69.8
95	9	2026-04-24	97.08	81	95.43	75.05
96	9	2026-04-23	98.13	94.6	95.35	88.51
97	9	2026-04-22	99.58	86.3	95.25	81.86
98	9	2026-04-21	92.29	97.2	97.53	87.49
99	9	2026-04-20	88.75	82.9	97.95	72.06
100	9	2026-04-19	96.04	89.5	98.44	84.61
101	9	2026-04-18	89.79	92.4	98.16	81.44
102	9	2026-04-17	93.75	80.5	95.9	72.38
103	9	2026-04-16	97.08	97.4	98.25	92.91
104	9	2026-04-15	100	96.2	98.44	94.7
105	9	2026-04-14	88.33	83.1	96.27	70.67
106	9	2026-04-13	92.92	85	97.88	77.31
107	9	2026-04-12	91.25	86.2	98.26	77.29
108	9	2026-04-11	98.54	80.6	96.53	76.67
109	9	2026-04-10	93.75	92.4	97.84	84.75
110	9	2026-04-09	94.79	85.5	96.61	78.3
111	9	2026-04-08	90.42	97.5	97.23	85.72
112	9	2026-04-07	98.75	88.1	97.84	85.12
113	9	2026-04-06	88.96	80.7	98.64	70.81
114	9	2026-04-05	89.38	87.3	96.45	75.25
115	9	2026-04-04	90.83	83.7	96.77	73.58
116	9	2026-04-03	91.04	95.7	95.19	82.94
117	9	2026-04-02	95.83	92.4	96.1	85.1
118	9	2026-04-01	88.54	97	96.39	82.79
119	9	2026-03-31	95.21	82.1	98.9	77.31
120	9	2026-03-30	96.88	82.7	96.86	77.6
121	10	2026-04-28	98.75	94.9	97.05	90.95
122	10	2026-04-27	98.54	88.7	98.31	85.93
123	10	2026-04-26	97.92	88.5	97.85	84.8
124	10	2026-04-25	96.25	84.9	95.52	78.06
125	10	2026-04-24	95	93.5	98.18	87.21
126	10	2026-04-23	92.71	88.2	97.05	79.36
127	10	2026-04-22	90.21	90.8	96.7	79.2
128	10	2026-04-21	97.92	91.6	97.05	87.05
129	10	2026-04-20	91.67	88.2	97.05	78.47
130	10	2026-04-19	87.5	92.2	97.61	78.75
131	10	2026-04-18	99.17	84.7	95.75	80.42
132	10	2026-04-17	90	87.6	95.21	75.06
133	10	2026-04-16	89.17	90.1	97.67	78.47
134	10	2026-04-15	89.17	86.4	98.96	76.24
135	10	2026-04-14	92.92	96.6	95.76	85.95
136	10	2026-04-13	96.04	88.9	95.39	81.44
137	10	2026-04-12	93.33	87.1	95.18	77.37
138	10	2026-04-11	96.67	88.9	97.3	83.62
139	10	2026-04-10	99.17	88.6	95.15	83.6
140	10	2026-04-09	98.13	84.7	95.28	79.19
141	10	2026-04-08	90.21	84.6	95.39	72.8
142	10	2026-04-07	89.79	82.2	95.38	70.4
143	10	2026-04-06	97.71	93.5	95.94	87.64
144	10	2026-04-05	96.04	92.6	95.9	85.28
145	10	2026-04-04	88.75	85.6	96.03	72.95
146	10	2026-04-03	98.33	91.5	96.07	86.44
147	10	2026-04-02	98.13	94.6	97.99	90.96
148	10	2026-04-01	95.42	97.4	95.48	88.74
149	10	2026-03-31	98.54	83.4	95.56	78.54
150	10	2026-03-30	93.75	87.9	96.36	79.41
151	11	2026-04-28	96.46	87	97.36	81.7
152	11	2026-04-27	88.96	86.7	97.23	74.99
153	11	2026-04-26	93.96	83.5	95.33	74.79
154	11	2026-04-25	94.17	96.1	98.96	89.55
155	11	2026-04-24	98.33	86.3	99.07	84.07
156	11	2026-04-23	91.25	88.7	98.65	79.84
157	11	2026-04-22	95.63	85.6	98.01	80.23
158	11	2026-04-21	94.58	89.1	97.87	82.48
159	11	2026-04-20	95	94.7	98.84	88.92
160	11	2026-04-19	96.88	96.2	98.44	91.74
161	11	2026-04-18	89.79	82	97.68	71.92
162	11	2026-04-17	88.96	95.1	98.84	83.62
163	11	2026-04-16	93.96	96.9	98.56	89.73
164	11	2026-04-15	94.17	94.9	98.42	87.95
165	11	2026-04-14	89.58	97.1	96.6	84.03
166	11	2026-04-13	89.38	80.3	95.14	68.28
167	11	2026-04-12	90.42	97.5	95.59	84.27
168	11	2026-04-11	95	85.3	99.06	80.27
169	11	2026-04-10	97.5	94.2	96.92	89.02
170	11	2026-04-09	95.21	93.4	97.75	86.93
171	11	2026-04-08	96.88	96.3	95.53	89.13
172	11	2026-04-07	95.21	93.7	95.3	85.02
173	11	2026-04-06	96.88	81.5	98.53	77.79
174	11	2026-04-05	92.71	90.7	95.15	80.01
175	11	2026-04-04	88.96	85.2	95.66	72.5
176	11	2026-04-03	94.79	81.7	97.43	75.45
177	11	2026-04-02	93.75	94	98.83	87.09
178	11	2026-04-01	93.33	82	95.73	73.27
179	11	2026-03-31	99.17	88.7	95.49	83.99
180	11	2026-03-30	91.46	86.8	96.2	76.37
181	12	2026-04-28	88.54	96.7	95.97	82.17
182	12	2026-04-27	91.46	94	97.66	83.96
183	12	2026-04-26	89.38	87.6	98.97	77.49
184	12	2026-04-25	94.58	81.5	96.32	74.25
185	12	2026-04-24	91.88	80	95.38	70.1
186	12	2026-04-23	94.38	89.5	98.77	83.43
187	12	2026-04-22	91.46	86.5	96.76	76.55
188	12	2026-04-21	94.79	85.7	98.25	79.81
189	12	2026-04-20	94.17	84	97.26	76.93
190	12	2026-04-19	98.75	83.2	96.15	79
191	12	2026-04-18	96.67	93.3	97	87.48
192	12	2026-04-17	98.96	95.3	96.12	90.65
193	12	2026-04-16	89.58	82.9	97.95	72.74
194	12	2026-04-15	92.5	87.2	96.1	77.51
195	12	2026-04-14	97.5	88	97.27	83.46
196	12	2026-04-13	90.21	89.4	98.55	79.47
197	12	2026-04-12	94.38	84.6	96.69	77.2
198	12	2026-04-11	95	85.9	96.04	78.38
199	12	2026-04-10	93.54	82.5	97.7	75.39
200	12	2026-04-09	98.96	90.6	95.92	85.99
201	12	2026-04-08	91.88	81.7	95.84	71.94
202	12	2026-04-07	98.54	94.2	95.75	88.88
203	12	2026-04-06	87.92	86.7	96.54	73.59
204	12	2026-04-05	96.25	82.7	98.67	78.54
205	12	2026-04-04	97.29	94.9	98.74	91.16
206	12	2026-04-03	97.29	87.4	96.8	82.31
207	12	2026-04-02	95	96.1	98.54	89.96
208	12	2026-04-01	90.83	90.1	98.67	80.75
209	12	2026-03-31	97.71	85.8	98.6	82.66
210	12	2026-03-30	96.88	97.1	95.78	90.09
211	13	2026-04-28	92.29	83.7	95.94	74.11
212	13	2026-04-27	93.96	97.5	97.13	88.98
213	13	2026-04-26	97.29	97.2	98.66	93.3
214	13	2026-04-25	98.75	93.1	95.17	87.49
215	13	2026-04-24	99.38	95.1	98.84	93.41
216	13	2026-04-23	94.17	95.8	95.62	86.26
217	13	2026-04-22	92.71	94.7	95.35	83.72
218	13	2026-04-21	93.13	93.5	97.22	84.65
219	13	2026-04-20	90.83	86.8	98.85	77.94
220	13	2026-04-19	88.96	81.8	96.82	70.45
221	13	2026-04-18	92.08	94.8	98.1	85.64
222	13	2026-04-17	92.5	92.8	97.74	83.9
223	13	2026-04-16	92.29	80.4	98.63	73.19
224	13	2026-04-15	94.79	88.9	95.16	80.19
225	13	2026-04-14	96.88	95.1	95.16	87.67
226	13	2026-04-13	93.33	91.8	98.58	84.47
227	13	2026-04-12	97.5	91.9	98.8	88.53
228	13	2026-04-11	97.71	83.6	98.33	80.32
229	13	2026-04-10	88.33	93.8	96.59	80.03
230	13	2026-04-09	96.46	81.4	98.4	77.26
231	13	2026-04-08	97.29	93.4	97.64	88.73
232	13	2026-04-07	92.92	90.4	96.68	81.21
233	13	2026-04-06	95.21	87.2	96.22	79.88
234	13	2026-04-05	87.5	81.4	96.56	68.77
235	13	2026-04-04	90.83	95	98.32	84.84
236	13	2026-04-03	95	84.2	97.15	77.71
237	13	2026-04-02	100	87.1	95.98	83.6
238	13	2026-04-01	93.13	81.2	98.65	74.59
239	13	2026-03-31	97.29	95.9	97.5	90.97
240	13	2026-03-30	90.42	82.7	95.28	71.25
241	14	2026-04-28	90.21	93	95.48	80.11
242	14	2026-04-27	99.17	84.7	97.28	81.71
243	14	2026-04-26	90.83	89.5	96.42	78.39
244	14	2026-04-25	93.54	97	96.08	87.18
245	14	2026-04-24	99.17	83.8	96.06	79.83
246	14	2026-04-23	93.33	96	97.81	87.64
247	14	2026-04-22	96.88	86.5	95.95	80.41
248	14	2026-04-21	91.25	89.8	96.99	79.48
249	14	2026-04-20	89.17	86.6	97	74.9
250	14	2026-04-19	92.5	89.9	95.55	79.46
251	14	2026-04-18	98.33	88.5	95.82	83.39
252	14	2026-04-17	96.46	84.9	96.11	78.71
253	14	2026-04-16	97.08	96.5	96.17	90.09
254	14	2026-04-15	98.75	86.3	98.49	83.94
255	14	2026-04-14	92.71	93.4	96.15	83.25
256	14	2026-04-13	88.13	91.2	96.6	77.64
257	14	2026-04-12	96.04	93.6	95.09	85.48
258	14	2026-04-11	88.75	90.1	95.45	76.33
259	14	2026-04-10	91.46	93.3	96.46	82.31
260	14	2026-04-09	94.79	84.6	97.28	78.01
261	14	2026-04-08	89.58	97.9	98.16	86.09
262	14	2026-04-07	88.13	90.8	98.46	78.78
263	14	2026-04-06	98.96	95.8	98.64	93.52
264	14	2026-04-05	91.46	97.4	97.13	86.52
265	14	2026-04-04	92.71	81.9	95.24	72.31
266	14	2026-04-03	92.08	82.6	98.67	75.05
267	14	2026-04-02	90.63	94.2	96.07	82.02
268	14	2026-04-01	92.5	84.5	98.93	77.33
269	14	2026-03-31	88.96	90.1	98.45	78.91
270	14	2026-03-30	89.58	86.6	96.07	74.53
271	15	2026-04-28	91.88	94.7	98.42	85.63
272	15	2026-04-27	87.71	97.7	96.32	82.53
273	15	2026-04-26	91.88	80.1	95.13	70.01
274	15	2026-04-25	89.79	89.6	98.55	79.29
275	15	2026-04-24	99.79	86.3	95.02	81.83
276	15	2026-04-23	88.13	83.8	97.85	72.26
277	15	2026-04-22	97.92	85.9	98.6	82.94
278	15	2026-04-21	98.54	95.1	95.48	89.48
279	15	2026-04-20	88.33	86	97.67	74.2
280	15	2026-04-19	100	94	95.11	89.4
281	15	2026-04-18	98.13	81.6	98.16	78.6
282	15	2026-04-17	98.54	80.8	96.29	76.67
283	15	2026-04-16	91.46	94.3	96.71	83.41
284	15	2026-04-15	88.54	92.8	98.49	80.93
285	15	2026-04-14	96.46	95.1	98.95	90.77
286	15	2026-04-13	97.08	94.9	96.63	89.03
287	15	2026-04-12	94.58	97.2	95.99	88.25
288	15	2026-04-11	88.13	80.1	95.13	67.15
289	15	2026-04-10	95.42	92.7	98.06	86.73
290	15	2026-04-09	96.46	93.5	96.68	87.2
291	15	2026-04-08	99.17	88.3	98.64	86.37
292	15	2026-04-07	99.58	91.5	97.05	88.43
293	15	2026-04-06	88.75	80.2	97.13	69.14
294	15	2026-04-05	94.17	87.2	97.82	80.32
295	15	2026-04-04	98.75	81.7	97.06	78.31
296	15	2026-04-03	90	86.4	96.88	75.33
297	15	2026-04-02	92.71	90.9	98.24	82.79
298	15	2026-04-01	99.38	95.2	97.69	92.42
299	15	2026-03-31	87.5	91.2	97.81	78.05
300	15	2026-03-30	96.67	80.6	96.65	75.3
301	16	2026-04-28	96.04	96.2	97.61	90.18
302	16	2026-04-27	100	86.6	96.07	83.2
303	16	2026-04-26	89.58	97	96.29	83.67
304	16	2026-04-25	98.75	87.1	96.79	83.25
305	16	2026-04-24	96.25	97.4	96.71	90.67
306	16	2026-04-23	87.92	85.2	97.3	72.88
307	16	2026-04-22	87.5	85.1	95.42	71.05
308	16	2026-04-21	97.29	91	97.8	86.59
309	16	2026-04-20	92.71	84.1	98.22	76.58
310	16	2026-04-19	93.54	82.1	96.47	74.08
311	16	2026-04-18	90.63	85.6	96.61	74.95
312	16	2026-04-17	93.96	80.6	96.15	72.82
313	16	2026-04-16	94.38	97.9	97.55	90.13
314	16	2026-04-15	94.38	82.1	98.05	75.97
315	16	2026-04-14	93.96	94.7	97.78	87.01
316	16	2026-04-13	99.17	89.5	96.42	85.58
317	16	2026-04-12	87.71	96.1	97.4	82.09
318	16	2026-04-11	90.83	84.3	97.27	74.48
319	16	2026-04-10	98.54	82.7	95.04	77.45
320	16	2026-04-09	95	90.6	97.57	83.98
321	16	2026-04-08	96.46	81.1	97.41	76.2
322	16	2026-04-07	96.04	84.4	98.46	79.81
323	16	2026-04-06	93.13	86.7	97.81	78.97
324	16	2026-04-05	95.21	85.8	98.25	80.26
325	16	2026-04-04	93.54	81.8	95.72	73.24
326	16	2026-04-03	96.46	97	95.98	89.8
327	16	2026-04-02	93.13	90.8	99.01	83.72
328	16	2026-04-01	95	87.8	96.81	80.75
329	16	2026-03-31	88.75	86.2	98.26	75.17
330	16	2026-03-30	100	92.7	97.73	90.6
331	17	2026-04-28	89.58	81.1	97.78	71.04
332	17	2026-04-27	94.58	94.3	98.41	87.77
333	17	2026-04-26	89.58	92.5	98.81	81.88
334	17	2026-04-25	94.17	80.1	96.88	73.07
335	17	2026-04-24	96.46	97.3	96.71	90.77
336	17	2026-04-23	97.71	88.3	95.58	82.47
337	17	2026-04-22	94.17	86	95.47	77.31
338	17	2026-04-21	97.5	94.5	98.62	90.87
339	17	2026-04-20	93.13	93.6	97.97	85.4
340	17	2026-04-19	95.21	93.5	97.43	86.73
341	17	2026-04-18	98.33	94.6	96.3	89.58
342	17	2026-04-17	96.88	82.8	97.34	78.08
343	17	2026-04-16	96.88	94.2	98.83	90.19
344	17	2026-04-15	96.25	96.2	97.61	90.38
345	17	2026-04-14	89.79	89.1	95.74	76.59
346	17	2026-04-13	91.67	91.6	97.82	82.13
347	17	2026-04-12	92.71	88.6	98.98	81.31
348	17	2026-04-11	91.67	90.5	97.13	80.58
349	17	2026-04-10	98.96	80.6	97.27	77.58
350	17	2026-04-09	100	81.5	96.93	79
351	17	2026-04-08	97.92	84.9	96.23	80
352	17	2026-04-07	94.58	86	97.79	79.54
353	17	2026-04-06	97.5	88.9	95.16	82.48
354	17	2026-04-05	97.92	96.8	96.18	91.16
355	17	2026-04-04	88.54	96.9	97.21	83.41
356	17	2026-04-03	92.29	80.1	97.25	71.9
357	17	2026-04-02	95.42	84.3	98.1	78.91
358	17	2026-04-01	97.92	80.8	97.52	77.16
359	17	2026-03-31	98.33	87	98.39	84.17
360	17	2026-03-30	98.75	82.2	96.23	78.11
361	18	2026-04-28	89.58	92.1	98.26	81.07
362	18	2026-04-27	100	82.8	97.1	80.4
363	18	2026-04-26	91.04	82.3	95.75	71.74
364	18	2026-04-25	94.38	95.3	95.91	86.26
365	18	2026-04-24	99.79	91	97.69	88.71
366	18	2026-04-23	99.17	87.3	97.02	83.99
367	18	2026-04-22	88.13	86.2	96.06	72.97
368	18	2026-04-21	93.54	96.1	97.61	87.74
369	18	2026-04-20	88.33	89.2	96.08	75.7
370	18	2026-04-19	95.42	93.6	98.29	87.78
371	18	2026-04-18	92.5	83.5	95.33	73.63
372	18	2026-04-17	92.92	94.5	95.34	83.72
373	18	2026-04-16	96.67	84.8	95.52	78.3
374	18	2026-04-15	87.92	91.5	98.03	78.86
375	18	2026-04-14	91.46	94.4	98.83	85.33
376	18	2026-04-13	91.67	86.4	97.8	77.46
377	18	2026-04-12	87.5	92	99.02	79.71
378	18	2026-04-11	95	89.6	98.33	83.7
379	18	2026-04-10	95.42	96.6	97.2	89.6
380	18	2026-04-09	96.88	84.2	98.69	80.5
381	18	2026-04-08	87.71	81.3	96.56	68.85
382	18	2026-04-07	100	82.5	95.76	79
383	18	2026-04-06	97.29	82.3	95.38	76.37
384	18	2026-04-05	96.88	90.7	98.02	86.12
385	18	2026-04-04	97.71	88	98.86	85.01
386	18	2026-04-03	92.29	87.9	97.84	79.37
387	18	2026-04-02	98.33	91.2	96.71	86.73
388	18	2026-04-01	99.38	92.3	95.88	87.95
389	18	2026-03-31	90.63	82.3	97.08	72.41
390	18	2026-03-30	99.79	92.4	96.54	89.01
391	19	2026-04-28	94.79	96.4	95.54	87.3
392	19	2026-04-27	93.96	80.6	97.39	73.76
393	19	2026-04-26	91.25	93.6	95.09	81.21
394	19	2026-04-25	95.21	89.3	97.31	82.74
395	19	2026-04-24	99.58	83	98.07	81.06
396	19	2026-04-23	95.83	94.1	98.83	89.13
397	19	2026-04-22	94.38	97	96.49	88.33
398	19	2026-04-21	88.33	88.4	97.17	75.88
399	19	2026-04-20	93.75	80.8	95.79	72.56
400	19	2026-04-19	100	82.4	98.18	80.9
401	19	2026-04-18	97.5	88	95.23	81.71
402	19	2026-04-17	88.54	97.9	97.85	84.82
403	19	2026-04-16	95.63	92.8	98.71	87.59
404	19	2026-04-15	98.54	81.6	97.92	78.73
405	19	2026-04-14	88.33	95.3	97.17	81.8
406	19	2026-04-13	95.83	87.5	95.66	80.21
407	19	2026-04-12	91.46	91.7	95.75	80.3
408	19	2026-04-11	94.38	86.2	98.14	79.84
409	19	2026-04-10	88.96	84.1	97.74	73.12
410	19	2026-04-09	93.54	96	98.54	88.49
411	19	2026-04-08	92.08	95.1	98.63	86.37
412	19	2026-04-07	94.38	83.2	95.79	75.22
413	19	2026-04-06	91.88	85.3	95.9	75.15
414	19	2026-04-05	95.21	80.3	98.26	75.12
415	19	2026-04-04	100	81.1	98.64	80
416	19	2026-04-03	93.75	90.8	98.57	83.91
417	19	2026-04-02	89.79	85.3	95.19	72.91
418	19	2026-04-01	93.54	93.9	98.94	86.9
419	19	2026-03-31	92.92	83.5	97.49	75.63
420	19	2026-03-30	94.17	85.6	96.73	77.97
421	20	2026-04-28	88.96	93.1	96.46	79.88
422	20	2026-04-27	96.88	84.1	97.86	79.73
423	20	2026-04-26	88.54	89.3	96.53	76.32
424	20	2026-04-25	91.67	85	95.06	74.07
425	20	2026-04-24	93.13	83.8	97.49	76.08
426	20	2026-04-23	97.5	87.5	97.71	83.36
427	20	2026-04-22	92.92	85.8	96.74	77.12
428	20	2026-04-21	93.13	93.8	95.42	83.35
429	20	2026-04-20	96.25	83.1	96.39	77.1
430	20	2026-04-19	95.21	82.7	98.31	77.4
431	20	2026-04-18	97.29	89	95.39	82.6
432	20	2026-04-17	97.29	93	95.7	86.59
433	20	2026-04-16	96.67	87.1	96.56	81.3
434	20	2026-04-15	94.79	92.6	98.06	86.07
435	20	2026-04-14	97.92	89.3	95.63	83.62
436	20	2026-04-13	99.38	88.4	98.3	86.36
437	20	2026-04-12	88.75	89.1	95.51	75.53
438	20	2026-04-11	95	86	98.84	80.75
439	20	2026-04-10	99.38	83.6	97.61	81.09
440	20	2026-04-09	90	92.2	96.64	80.19
441	20	2026-04-08	99.58	84.9	98	82.85
442	20	2026-04-07	88.13	96.4	95.44	81.08
443	20	2026-04-06	88.75	80.1	95.38	67.81
444	20	2026-04-05	98.13	85.2	95.31	79.68
445	20	2026-04-04	97.08	93.8	98.93	90.09
446	20	2026-04-03	93.54	95.8	98.43	88.21
447	20	2026-04-02	87.92	84.2	98.57	72.97
448	20	2026-04-01	87.5	80.3	95.89	67.38
449	20	2026-03-31	90.21	89	96.07	77.13
450	20	2026-03-30	92.5	95.4	96.75	85.38
451	21	2026-04-28	88.75	85.6	98.95	75.17
452	21	2026-04-27	93.13	97.7	97.65	88.84
453	21	2026-04-26	97.71	86.3	98.61	83.15
454	21	2026-04-25	100	96	97.81	93.9
455	21	2026-04-24	95.42	84.8	97.52	78.91
456	21	2026-04-23	95.21	86.7	97.92	80.83
457	21	2026-04-22	99.79	96.4	97.72	94
458	21	2026-04-21	88.96	89.5	98.77	78.64
459	21	2026-04-20	98.13	80.8	95.67	75.85
460	21	2026-04-19	91.46	85.4	98.01	76.55
461	21	2026-04-18	87.92	91.8	96.3	77.72
462	21	2026-04-17	87.5	84.1	95.96	70.61
463	21	2026-04-16	90.21	82.1	96.95	71.81
464	21	2026-04-15	96.04	86.6	98.27	81.73
465	21	2026-04-14	98.33	80	97.13	76.4
466	21	2026-04-13	88.96	95.5	95.92	81.49
467	21	2026-04-12	100	80.4	98.26	79
468	21	2026-04-11	92.5	84.9	95.64	75.11
469	21	2026-04-10	92.92	91.3	95.51	81.02
470	21	2026-04-09	90.42	90.6	96.14	78.75
471	21	2026-04-08	90	81.9	95.6	70.47
472	21	2026-04-07	92.29	84.6	96.1	75.03
473	21	2026-04-06	90.83	91.7	97.71	81.39
474	21	2026-04-05	97.08	88	95.57	81.65
475	21	2026-04-04	90.83	80.6	98.26	71.94
476	21	2026-04-03	95.83	83.5	97.72	78.2
477	21	2026-04-02	99.38	83.6	97.85	81.29
478	21	2026-04-01	98.33	89.3	96.86	85.06
479	21	2026-03-31	87.5	85.6	95.79	71.75
480	21	2026-03-30	97.5	97.7	96.83	92.23
481	22	2026-04-28	92.71	89.9	97.78	81.49
482	22	2026-04-27	95.83	84.1	96.31	77.63
483	22	2026-04-26	95.63	82.9	99.03	78.51
484	22	2026-04-25	91.04	86.5	95.03	74.84
485	22	2026-04-24	90.21	94.4	98.41	83.8
486	22	2026-04-23	90.63	85.2	97.18	75.04
487	22	2026-04-22	92.08	85.7	97.55	76.98
488	22	2026-04-21	88.54	81.7	98.53	71.28
489	22	2026-04-20	97.5	88.7	97.07	83.95
490	22	2026-04-19	92.29	85.8	97.67	77.34
491	22	2026-04-18	91.88	93.1	97.1	83.06
492	22	2026-04-17	94.79	80.7	95.54	73.08
493	22	2026-04-16	98.54	97.3	97.23	93.22
494	22	2026-04-15	98.13	92.5	95.78	86.94
495	22	2026-04-14	88.33	92.7	97.09	79.5
496	22	2026-04-13	93.75	90.4	97.68	82.78
497	22	2026-04-12	90.83	88.8	96.06	77.48
498	22	2026-04-11	87.92	92.4	96	77.98
499	22	2026-04-10	90.63	83.3	95.92	72.41
500	22	2026-04-09	93.33	81.8	98.78	75.41
501	22	2026-04-08	91.04	86.9	97.12	76.84
502	22	2026-04-07	95.21	81	96.54	74.45
503	22	2026-04-06	97.5	83.2	95.91	77.81
504	22	2026-04-05	91.67	87.7	97.38	78.28
505	22	2026-04-04	95.21	87.6	97.72	81.5
506	22	2026-04-03	89.17	94.9	95.68	80.96
507	22	2026-04-02	89.79	85.8	98.14	75.6
508	22	2026-04-01	97.92	96.4	98.44	92.92
509	22	2026-03-31	97.71	93.2	97.1	88.43
510	22	2026-03-30	88.54	93.2	99.03	81.72
511	23	2026-04-28	93.96	91.4	95.4	81.93
512	23	2026-04-27	90	87	95.52	74.79
513	23	2026-04-26	87.71	81.8	95.97	68.85
514	23	2026-04-25	90.83	89.8	96.33	78.57
515	23	2026-04-24	93.54	96.1	96.46	86.71
516	23	2026-04-23	90.63	87.6	95.32	75.67
517	23	2026-04-22	95.63	96.2	98.54	90.65
518	23	2026-04-21	93.54	97.9	96.83	88.68
519	23	2026-04-20	96.46	95.4	98.64	90.77
520	23	2026-04-19	97.71	87.1	96.56	82.17
521	23	2026-04-18	94.58	93.6	97.44	86.26
522	23	2026-04-17	93.75	88.1	97.96	80.91
523	23	2026-04-16	93.96	89	98.43	82.31
524	23	2026-04-15	98.13	96	96.98	91.35
525	23	2026-04-14	90.63	82	97.32	72.32
526	23	2026-04-13	94.58	86.1	98.95	80.58
527	23	2026-04-12	92.29	81.1	98.52	73.74
528	23	2026-04-11	91.04	91.2	96.49	80.12
529	23	2026-04-10	96.25	82.3	97.33	77.1
530	23	2026-04-09	98.33	91	98.46	88.11
531	23	2026-04-08	88.96	93.6	98.5	82.02
532	23	2026-04-07	88.96	97.2	95.88	82.91
533	23	2026-04-06	88.33	97.2	97.74	83.92
534	23	2026-04-05	97.08	81.4	96.07	75.92
535	23	2026-04-04	99.17	80.3	97.88	77.95
536	23	2026-04-03	95	90.2	95.57	81.89
537	23	2026-04-02	93.75	88.5	96.16	79.78
538	23	2026-04-01	89.38	91	98.13	79.81
539	23	2026-03-31	99.38	92.1	95.66	87.55
540	23	2026-03-30	87.71	96.8	96.28	81.74
541	24	2026-04-28	99.58	93	96.88	89.72
542	24	2026-04-27	89.17	83.8	98.33	73.47
543	24	2026-04-26	97.5	89.7	96.77	84.63
544	24	2026-04-25	92.71	86.6	98.96	79.45
545	24	2026-04-24	91.46	90.2	95.45	78.75
546	24	2026-04-23	91.25	96.2	96.36	84.59
547	24	2026-04-22	90.21	94.4	98.73	84.07
548	24	2026-04-21	93.75	91.4	99.02	84.84
549	24	2026-04-20	98.13	97.7	95.5	91.55
550	24	2026-04-19	98.75	80	96	75.84
551	24	2026-04-18	90.21	95.8	97.08	83.89
552	24	2026-04-17	91.46	82.7	97.1	73.44
553	24	2026-04-16	92.5	94.7	97.99	85.84
554	24	2026-04-15	88.13	94.8	96.41	80.55
555	24	2026-04-14	94.79	95	97.89	88.16
556	24	2026-04-13	90.63	89.1	98.09	79.21
557	24	2026-04-12	99.58	88.2	95.12	83.55
558	24	2026-04-11	88.13	91.2	95.61	76.85
559	24	2026-04-10	90.83	84.4	96.56	74.03
560	24	2026-04-09	91.46	85.7	97.08	76.09
561	24	2026-04-08	87.71	95.8	95.3	80.08
562	24	2026-04-07	95.83	80.5	95.53	73.7
563	24	2026-04-06	99.38	97.7	96.21	93.41
564	24	2026-04-05	93.33	97.7	97.03	88.48
565	24	2026-04-04	98.54	94.6	95.45	88.98
566	24	2026-04-03	87.92	89.1	98.09	76.84
567	24	2026-04-02	93.54	90.7	96.69	82.04
568	24	2026-04-01	98.54	85.2	97.77	82.09
569	24	2026-03-31	100	89.3	96.86	86.5
570	24	2026-03-30	91.25	82.1	98.9	74.09
571	25	2026-04-28	98.96	84.8	98.82	82.93
572	25	2026-04-27	96.46	89	95.84	82.28
573	25	2026-04-26	89.38	83.3	98.68	73.47
574	25	2026-04-25	87.5	97.4	95.17	81.11
575	25	2026-04-24	89.58	95.5	95.08	81.34
576	25	2026-04-23	95.21	97.8	98.57	91.78
577	25	2026-04-22	92.5	92.6	96.11	82.33
578	25	2026-04-21	100	92.9	95.16	88.4
579	25	2026-04-20	96.04	80.9	98.76	76.74
580	25	2026-04-19	92.71	94.6	97.04	85.11
581	25	2026-04-18	96.25	94.4	98.31	89.32
582	25	2026-04-17	93.54	92.8	96.55	83.81
583	25	2026-04-16	99.58	85.3	96.01	81.56
584	25	2026-04-15	91.04	97.4	95.38	84.58
585	25	2026-04-14	87.92	87.3	96.68	74.2
586	25	2026-04-13	97.5	95.7	95.19	88.82
587	25	2026-04-12	92.08	93.5	96.9	83.43
588	25	2026-04-11	98.96	97.3	97.84	94.21
589	25	2026-04-10	98.33	92.9	96.02	87.71
590	25	2026-04-09	99.58	81.9	98.78	80.56
591	25	2026-04-08	90	88.3	96.83	76.95
592	25	2026-04-07	89.38	92	97.72	80.35
593	25	2026-04-06	97.5	96.4	98.34	92.43
594	25	2026-04-05	88.33	89.9	98.22	78
595	25	2026-04-04	99.17	97.3	98.97	95.5
596	25	2026-04-03	98.33	81.7	97.31	78.17
597	25	2026-04-02	89.58	96.5	95.85	82.86
598	25	2026-04-01	95.21	96.7	97.83	90.07
599	25	2026-03-31	91.46	91.6	95.74	80.21
600	25	2026-03-30	95.42	85.2	96.71	78.62
601	26	2026-04-28	91.04	85.2	96.95	75.2
602	26	2026-04-27	87.92	92.2	96.75	78.42
603	26	2026-04-26	91.88	84.4	99.05	76.81
604	26	2026-04-25	92.08	94.7	95.78	83.52
605	26	2026-04-24	88.54	93.2	97.96	80.84
606	26	2026-04-23	93.13	97.6	96.72	87.91
607	26	2026-04-22	89.38	85.8	96.04	73.65
608	26	2026-04-21	90.63	91.8	98.15	81.65
609	26	2026-04-20	96.46	82.6	96.25	76.68
610	26	2026-04-19	96.46	91.5	98.8	87.2
611	26	2026-04-18	89.58	81.1	95.44	69.34
612	26	2026-04-17	88.75	85.1	97.06	73.31
613	26	2026-04-16	90	96.3	96.05	83.25
614	26	2026-04-15	87.5	91.1	98.02	78.14
615	26	2026-04-14	91.25	91	96.37	80.03
616	26	2026-04-13	93.13	81.9	95.48	72.82
617	26	2026-04-12	88.75	80	95.5	67.8
618	26	2026-04-11	95.63	81.3	97.66	75.93
619	26	2026-04-10	95.42	97.7	96.62	90.07
620	26	2026-04-09	96.46	91.8	98.8	87.49
621	26	2026-04-08	87.71	88.4	97.51	75.6
622	26	2026-04-07	92.5	93.5	96.79	83.71
623	26	2026-04-06	93.33	94.6	98.31	86.8
624	26	2026-04-05	93.75	92.5	96.97	84.09
625	26	2026-04-04	92.29	88.6	95.37	77.99
626	26	2026-04-03	87.92	84.1	95.24	70.42
627	26	2026-04-02	88.54	90.6	97.13	77.92
628	26	2026-04-01	89.58	84.1	97.38	73.37
629	26	2026-03-31	91.88	95.9	95.62	84.25
630	26	2026-03-30	98.54	95.5	96.13	90.46
631	27	2026-04-28	92.29	97.8	95.5	86.2
632	27	2026-04-27	88.96	85.1	97.88	74.1
633	27	2026-04-26	97.71	85.3	97.3	81.1
634	27	2026-04-25	98.13	97.8	97.75	93.81
635	27	2026-04-24	90	96.2	96.78	83.79
636	27	2026-04-23	94.58	91.2	98.68	85.13
637	27	2026-04-22	95.63	82.2	96.11	75.54
638	27	2026-04-21	99.17	88.5	95.14	83.5
639	27	2026-04-20	90.21	83.8	98.45	74.42
640	27	2026-04-19	98.96	84.8	95.75	80.35
641	27	2026-04-18	87.92	91.3	98.14	78.77
642	27	2026-04-17	89.38	89.2	95.63	76.24
643	27	2026-04-16	98.13	83.9	97.62	80.36
644	27	2026-04-15	92.08	80.4	95.15	70.44
645	27	2026-04-14	98.54	84.8	97.88	81.79
646	27	2026-04-13	92.92	87.7	95.67	77.96
647	27	2026-04-12	96.46	95.4	97.06	89.32
648	27	2026-04-11	88.96	93.7	98.4	82.02
649	27	2026-04-10	96.67	89.5	95.2	82.36
650	27	2026-04-09	96.88	86.1	96.52	80.5
651	27	2026-04-08	91.25	87.3	96.68	77.02
652	27	2026-04-07	91.25	81.6	95.1	70.81
653	27	2026-04-06	91.46	87.5	96.8	77.47
654	27	2026-04-05	88.13	87.3	95.99	73.85
655	27	2026-04-04	99.17	82.3	96.48	78.74
656	27	2026-04-03	98.96	80.4	97.89	77.88
657	27	2026-04-02	97.92	93.5	99.04	90.67
658	27	2026-04-01	96.88	85.3	97.66	80.7
659	27	2026-03-31	89.79	87.6	97.37	76.59
660	27	2026-03-30	90.42	89.9	97.11	78.93
661	28	2026-04-28	90.21	84.4	98.82	75.23
662	28	2026-04-27	98.75	81.1	99.01	79.3
663	28	2026-04-26	95	97.7	95.19	88.35
664	28	2026-04-25	87.5	83.4	97.96	71.49
665	28	2026-04-24	87.5	85.5	98.01	73.32
666	28	2026-04-23	98.96	85.1	96.24	81.05
667	28	2026-04-22	87.71	87.7	95.32	73.32
668	28	2026-04-21	95.83	96	98.75	90.85
669	28	2026-04-20	89.79	88.4	95.48	75.78
670	28	2026-04-19	94.38	83.2	96.27	75.59
671	28	2026-04-18	94.17	81.7	96.94	74.58
672	28	2026-04-17	96.46	91.6	98.8	87.29
673	28	2026-04-16	92.29	81.1	95.44	71.43
674	28	2026-04-15	98.96	94.9	96.94	91.04
675	28	2026-04-14	87.71	94	97.34	80.25
676	28	2026-04-13	94.17	88.8	96.17	80.42
677	28	2026-04-12	99.58	83	96.87	80.06
678	28	2026-04-11	92.29	94	96.17	83.43
679	28	2026-04-10	92.5	83.3	97.6	75.2
680	28	2026-04-09	91.46	93.7	97.01	83.14
681	28	2026-04-08	90.21	82.4	98.3	73.07
682	28	2026-04-07	93.96	87.9	96.59	79.77
683	28	2026-04-06	90.42	94.6	97.99	83.82
684	28	2026-04-05	96.25	95.5	98.01	90.09
685	28	2026-04-04	87.5	82.9	95.3	69.13
686	28	2026-04-03	91.88	82.1	98.9	74.6
687	28	2026-04-02	96.46	90.4	96.68	84.3
688	28	2026-04-01	98.75	96.7	97.72	93.32
689	28	2026-03-31	95.21	94.1	98.51	88.26
690	28	2026-03-30	87.5	96.9	95.36	80.85
691	29	2026-04-28	90.42	94.5	96.3	82.28
692	29	2026-04-27	97.5	86.5	97.34	82.09
693	29	2026-04-26	94.38	94.9	96.52	86.45
694	29	2026-04-25	87.71	86.2	98.03	74.11
695	29	2026-04-24	88.75	84.4	98.93	74.11
696	29	2026-04-23	96.67	94.7	95.46	87.39
697	29	2026-04-22	88.54	96.6	97.1	83.05
698	29	2026-04-21	91.25	96.4	98.96	87.05
699	29	2026-04-20	96.04	86.2	96.75	80.1
700	29	2026-04-19	89.79	88.1	98.18	77.67
701	29	2026-04-18	90.42	86.6	95.84	75.05
702	29	2026-04-17	92.5	86.6	97.11	77.79
703	29	2026-04-16	96.46	80.5	95.4	74.08
704	29	2026-04-15	97.92	88.2	95.12	82.15
705	29	2026-04-14	98.96	85	97.88	82.33
706	29	2026-04-13	90	95	97.89	83.7
707	29	2026-04-12	99.79	97.4	97.54	94.8
708	29	2026-04-11	97.29	89.1	95.85	83.09
709	29	2026-04-10	95.42	85.1	96.94	78.72
710	29	2026-04-09	94.17	89.7	98.33	83.06
711	29	2026-04-08	92.08	94.9	98.1	85.73
712	29	2026-04-07	97.08	83.1	96.75	78.05
713	29	2026-04-06	99.17	85.2	96.48	81.52
714	29	2026-04-05	94.17	91	95.93	82.21
715	29	2026-04-04	88.96	96.6	97.31	83.62
716	29	2026-04-03	93.75	86.5	96.88	78.56
717	29	2026-04-02	88.54	87.6	98.29	76.23
718	29	2026-04-01	99.17	85	96.47	81.32
719	29	2026-03-31	97.5	95.5	98.95	92.14
720	29	2026-03-30	94.17	83.5	96.65	75.99
721	30	2026-04-28	88.13	97.5	98.46	84.6
722	30	2026-04-27	87.71	87.3	95.99	73.5
723	30	2026-04-26	89.17	95.3	99.06	84.17
724	30	2026-04-25	89.58	95.1	96.85	82.51
725	30	2026-04-24	99.79	95.5	96.54	92.01
726	30	2026-04-23	89.79	85	97.88	74.71
727	30	2026-04-22	93.96	93.6	95.51	84
728	30	2026-04-21	99.17	90.9	96.81	87.27
729	30	2026-04-20	88.96	88.7	95.83	75.61
730	30	2026-04-19	93.33	97.7	95.8	87.36
731	30	2026-04-18	97.92	85.7	98.72	82.84
732	30	2026-04-17	98.75	81.7	95.23	76.83
733	30	2026-04-16	90.21	82.7	98.31	73.34
734	30	2026-04-15	91.67	81.8	96.58	72.42
735	30	2026-04-14	89.79	81.7	96.45	70.76
736	30	2026-04-13	97.92	87.4	97.94	83.82
737	30	2026-04-12	91.67	86.7	96.89	77
738	30	2026-04-11	96.88	85.3	95.9	79.24
739	30	2026-04-10	90	84.1	96.08	72.72
740	30	2026-04-09	89.17	82	98.9	72.31
741	30	2026-04-08	88.33	97.6	98.77	85.15
742	30	2026-04-07	89.79	89.4	95.53	76.68
743	30	2026-04-06	92.08	96.9	96.28	85.91
744	30	2026-04-05	92.92	93	98.92	85.48
745	30	2026-04-04	95	91.6	97.82	85.12
746	30	2026-04-03	92.5	96.9	98.35	88.15
747	30	2026-04-02	97.5	91.3	99.01	88.14
748	30	2026-04-01	90.21	81.4	98.53	72.35
749	30	2026-03-31	91.25	92.2	97.18	81.76
750	30	2026-03-30	92.08	86.6	97.92	78.09
751	31	2026-04-28	100	88.1	95.23	83.9
752	31	2026-04-27	93.96	97.7	98.77	90.67
753	31	2026-04-26	95	87.9	97.16	81.13
754	31	2026-04-25	96.88	82.1	98.54	78.37
755	31	2026-04-24	94.58	85.5	96.73	78.22
756	31	2026-04-23	94.17	94.5	95.77	85.22
757	31	2026-04-22	97.5	91.7	95.2	85.12
758	31	2026-04-21	92.92	81	98.15	73.87
759	31	2026-04-20	88.75	96.9	98.76	84.93
760	31	2026-04-19	88.54	96.8	98.24	84.2
761	31	2026-04-18	89.17	85.7	96.27	73.56
762	31	2026-04-17	96.88	82.7	97.7	78.27
763	31	2026-04-16	91.46	83.6	95.69	73.17
764	31	2026-04-15	96.46	82.8	97.71	78.03
765	31	2026-04-14	99.38	80.1	95.88	76.32
766	31	2026-04-13	92.5	88.1	98.18	80.01
767	31	2026-04-12	89.38	94	95.53	80.26
768	31	2026-04-11	99.79	80.9	96.66	78.04
769	31	2026-04-10	99.58	95.2	98.53	93.41
770	31	2026-04-09	92.5	91.5	97.05	82.14
771	31	2026-04-08	92.08	86.3	96.64	76.8
772	31	2026-04-07	99.38	83.2	95.07	78.61
773	31	2026-04-06	91.88	81.5	95.58	71.57
774	31	2026-04-05	91.67	93.7	97.12	83.42
775	31	2026-04-04	92.29	93.9	96.81	83.89
776	31	2026-04-03	87.5	86.1	95.59	72.01
777	31	2026-04-02	92.08	90	97.56	80.85
778	31	2026-04-01	92.08	89.7	95.65	79.01
779	31	2026-03-31	96.88	85.6	98.25	81.47
780	31	2026-03-30	94.58	83.9	95.23	75.57
781	32	2026-04-28	92.5	85.4	98.71	77.98
782	32	2026-04-27	88.33	96.5	98.03	83.56
783	32	2026-04-26	96.88	94.3	98.62	90.09
784	32	2026-04-25	87.92	96	98.54	83.17
785	32	2026-04-24	95.63	82.4	95.51	75.26
786	32	2026-04-23	89.17	81.7	96.7	70.44
787	32	2026-04-22	96.67	81.2	97.66	76.66
788	32	2026-04-21	97.08	90.2	96.23	84.27
789	32	2026-04-20	89.17	97.8	95.19	83.01
790	32	2026-04-19	92.92	87	96.09	77.68
791	32	2026-04-18	88.13	91.5	96.17	77.55
792	32	2026-04-17	96.88	90.5	97.57	85.54
793	32	2026-04-16	93.13	94	98.4	86.14
794	32	2026-04-15	88.75	90	95.56	76.33
795	32	2026-04-14	96.67	83.3	97.84	78.78
796	32	2026-04-13	97.29	94.8	97.36	89.8
797	32	2026-04-12	98.75	85.6	96.38	81.47
798	32	2026-04-11	95.63	80.8	95.3	73.63
799	32	2026-04-10	94.58	82	96.34	74.72
800	32	2026-04-09	93.96	91.6	98.25	84.56
801	32	2026-04-08	94.58	85.1	95.65	76.99
802	32	2026-04-07	90.63	84.9	95.52	73.5
803	32	2026-04-06	94.58	93.5	97.65	86.35
804	32	2026-04-05	91.04	89.1	98.43	79.84
805	32	2026-04-04	99.17	93.4	96.79	89.65
806	32	2026-04-03	93.75	94.6	96.19	85.31
807	32	2026-04-02	89.38	93.9	96.06	80.62
808	32	2026-04-01	98.96	84.9	98	82.33
809	32	2026-03-31	99.17	87.6	95.89	83.3
810	32	2026-03-30	94.79	88.1	98.3	82.09
811	33	2026-04-28	89.38	92.6	98.7	81.69
812	33	2026-04-27	87.71	96	98.13	82.62
813	33	2026-04-26	98.75	81.5	97.18	78.21
814	33	2026-04-25	97.29	82.7	98.07	78.9
815	33	2026-04-24	90.21	97.3	96.51	84.71
816	33	2026-04-23	99.38	85.6	96.26	81.88
817	33	2026-04-22	98.75	84.8	95.87	80.28
818	33	2026-04-21	90.21	91.9	97.93	81.19
819	33	2026-04-20	91.04	92.9	98.71	83.49
820	33	2026-04-19	95	92	95.43	83.41
821	33	2026-04-18	98.13	91	96.04	85.76
822	33	2026-04-17	97.08	82.1	96.47	76.89
823	33	2026-04-16	96.67	84.5	96.21	78.59
824	33	2026-04-15	90.21	96.8	95.25	83.17
825	33	2026-04-14	93.33	95.7	97.6	87.17
826	33	2026-04-13	91.88	84.1	96.2	74.33
827	33	2026-04-12	88.54	97.7	96.01	83.05
828	33	2026-04-11	91.25	89.2	95.29	77.56
829	33	2026-04-10	97.92	88.6	96.61	83.82
830	33	2026-04-09	92.5	89.8	96.99	80.57
831	33	2026-04-08	91.04	88.3	96.94	77.93
832	33	2026-04-07	91.25	87.1	96.9	77.01
833	33	2026-04-06	88.96	96	96.56	82.46
834	33	2026-04-05	94.17	81.4	95.21	72.98
835	33	2026-04-04	94.38	92.4	97.08	84.65
836	33	2026-04-03	98.75	83	95.78	78.51
837	33	2026-04-02	99.38	85.9	98.72	84.27
838	33	2026-04-01	100	93.9	99.04	93
839	33	2026-03-31	98.54	85	98.71	82.68
840	33	2026-03-30	89.58	83.4	96.52	72.11
841	34	2026-04-28	97.29	96.8	95.45	89.9
842	34	2026-04-27	87.5	97.2	95.16	80.94
843	34	2026-04-26	92.5	80.2	97.26	72.15
844	34	2026-04-25	100	95.8	97.49	93.4
845	34	2026-04-24	98.96	81.7	98.9	79.96
846	34	2026-04-23	87.71	80.5	97.39	68.76
847	34	2026-04-22	95.21	89.7	95.32	81.4
848	34	2026-04-21	90.63	91.3	96.28	79.66
849	34	2026-04-20	90.21	91.1	97.15	79.83
850	34	2026-04-19	96.46	97.3	98.97	92.89
851	34	2026-04-18	90	86.1	97.21	75.33
852	34	2026-04-17	96.67	90.4	96.02	83.91
853	34	2026-04-16	92.92	91	97.14	82.14
854	34	2026-04-15	90.83	89.5	98.99	80.48
855	34	2026-04-14	96.04	81.5	95.21	74.53
856	34	2026-04-13	95.42	84.4	98.1	79
857	34	2026-04-12	95.63	89.5	97.21	83.19
858	34	2026-04-11	92.71	83.6	96.77	75
859	34	2026-04-10	94.58	97.1	98.76	90.71
860	34	2026-04-09	93.54	85.5	97.54	78.01
861	34	2026-04-08	97.92	87.4	96	82.15
862	34	2026-04-07	89.79	91.7	97.82	80.54
863	34	2026-04-06	89.17	94.7	98.2	82.92
864	34	2026-04-05	99.17	81.4	97.54	78.74
865	34	2026-04-04	87.92	87.5	95.2	73.23
866	34	2026-04-03	89.79	84.5	95.15	72.19
867	34	2026-04-02	93.13	92	95.43	81.76
868	34	2026-04-01	87.92	90.1	97.34	77.1
869	34	2026-03-31	100	88.4	97.51	86.2
870	34	2026-03-30	92.71	90.4	95.58	80.1
871	35	2026-04-28	95.63	84.7	96.34	78.03
872	35	2026-04-27	98.13	97.9	96.63	92.83
873	35	2026-04-26	95	86.2	95.48	78.19
874	35	2026-04-25	93.33	97.1	97.84	88.67
875	35	2026-04-24	92.29	93.8	96.38	83.43
876	35	2026-04-23	88.96	91	99.01	80.15
877	35	2026-04-22	93.13	86.5	98.96	79.72
878	35	2026-04-21	99.17	87	96.67	83.4
879	35	2026-04-20	94.17	88.1	95.23	79.01
880	35	2026-04-19	94.58	94.6	95.56	85.5
881	35	2026-04-18	97.5	83.8	96.66	78.97
882	35	2026-04-17	97.92	97.1	96.6	91.85
883	35	2026-04-16	95.21	87.6	97.72	81.5
884	35	2026-04-15	99.38	94.5	95.77	89.93
885	35	2026-04-14	96.46	81.1	96.3	75.33
886	35	2026-04-13	88.33	80.5	96.65	68.72
887	35	2026-04-12	97.92	84.5	96.57	79.9
888	35	2026-04-11	95.63	88.5	95.71	80.99
889	35	2026-04-10	95.42	88.5	97.51	82.34
890	35	2026-04-09	97.29	83.8	98.21	80.07
891	35	2026-04-08	89.58	82.3	98.78	72.83
892	35	2026-04-07	88.96	95.6	97.59	83
893	35	2026-04-06	96.67	95.9	95.41	88.45
894	35	2026-04-05	90.83	82.5	97.7	73.21
895	35	2026-04-04	91.25	87	96.09	76.28
896	35	2026-04-03	92.08	92.9	97.2	83.15
897	35	2026-04-02	92.5	88.4	97.74	79.92
898	35	2026-04-01	95	94.3	96.29	86.26
899	35	2026-03-31	92.71	93.8	97.65	84.92
900	35	2026-03-30	89.38	97.5	96.1	83.74
901	36	2026-04-28	98.96	88.4	97.29	85.1
902	36	2026-04-27	99.58	89.3	95.18	84.65
903	36	2026-04-26	88.13	88	96.82	75.08
904	36	2026-04-25	93.75	97.2	96.3	87.75
905	36	2026-04-24	90.63	91.8	98.15	81.65
906	36	2026-04-23	88.13	82.5	98.42	71.56
907	36	2026-04-22	92.71	92.5	96	82.33
908	36	2026-04-21	96.46	96.1	97.71	90.57
909	36	2026-04-20	96.46	93.7	98.4	88.93
910	36	2026-04-19	90.63	93.9	97.12	82.65
911	36	2026-04-18	98.96	83.5	95.21	78.67
912	36	2026-04-17	99.79	96	97.29	93.21
913	36	2026-04-16	90.21	90.4	98.34	80.2
914	36	2026-04-15	97.29	96.3	96.47	90.38
915	36	2026-04-14	99.17	97.3	98.56	95.1
916	36	2026-04-13	93.75	90.4	96.57	81.84
917	36	2026-04-12	88.54	81.2	95.2	68.44
918	36	2026-04-11	99.79	84.1	98.22	82.43
919	36	2026-04-10	90.42	86.5	96.42	75.41
920	36	2026-04-09	94.38	90	99	84.09
921	36	2026-04-08	92.5	88.9	95.84	78.81
922	36	2026-04-07	91.46	84.9	96.11	74.63
923	36	2026-04-06	98.33	94.6	96.83	90.07
924	36	2026-04-05	95.21	97.9	96.53	89.97
925	36	2026-04-04	96.88	80	97.5	75.56
926	36	2026-04-03	91.67	82.7	97.7	74.07
927	36	2026-04-02	92.71	82	96.59	73.43
928	36	2026-04-01	97.5	96.9	96.49	91.16
929	36	2026-03-31	92.5	92.7	97.84	83.9
930	36	2026-03-30	97.5	97.7	96.21	91.65
931	37	2026-04-28	95.83	88.5	95.93	81.36
932	37	2026-04-27	91.04	81.6	96.81	71.92
933	37	2026-04-26	96.04	83.7	96.54	77.6
934	37	2026-04-25	98.54	86.7	98.85	84.45
935	37	2026-04-24	94.58	96.6	98.14	89.66
936	37	2026-04-23	92.71	83.2	97.12	74.91
937	37	2026-04-22	96.88	82	98.05	77.89
938	37	2026-04-21	88.33	86.3	96.87	73.85
939	37	2026-04-20	88.96	83	95.54	70.54
940	37	2026-04-19	87.92	82.9	97.1	70.77
941	37	2026-04-18	95.83	87.3	98.74	82.61
942	37	2026-04-17	94.17	93.8	97.33	85.97
943	37	2026-04-16	94.17	87.7	97.15	80.23
944	37	2026-04-15	87.92	91.4	98.25	78.95
945	37	2026-04-14	98.13	86.9	96.55	82.33
946	37	2026-04-13	94.58	91.9	98.48	85.6
947	37	2026-04-12	89.79	82.7	95.53	70.94
948	37	2026-04-11	96.88	89.5	98.21	85.15
949	37	2026-04-10	95.63	88.4	96.95	81.95
950	37	2026-04-09	89.38	82	95.85	70.25
951	37	2026-04-08	92.92	83.9	97.26	75.82
952	37	2026-04-07	91.04	86	98.72	77.29
953	37	2026-04-06	88.54	83.3	97	71.54
954	37	2026-04-05	93.96	85.6	96.38	77.52
955	37	2026-04-04	92.71	87.1	97.13	78.43
956	37	2026-04-03	98.54	81.1	97.53	77.95
957	37	2026-04-02	98.54	86.5	96.65	82.38
958	37	2026-04-01	95.21	80.5	98.51	75.5
959	37	2026-03-31	95.42	96.3	97.61	89.69
960	37	2026-03-30	90	81.9	95.6	70.47
961	38	2026-04-28	87.5	91	98.35	78.31
962	38	2026-04-27	88.75	88	96.48	75.35
963	38	2026-04-26	97.71	97.5	95.49	90.97
964	38	2026-04-25	96.46	97.2	98.46	92.31
965	38	2026-04-24	96.04	94.4	98.2	89.03
966	38	2026-04-23	96.67	86.3	97.33	81.2
967	38	2026-04-22	98.96	96.5	98.13	93.71
968	38	2026-04-21	89.79	96.7	96.17	83.51
969	38	2026-04-20	95.42	84.1	97.03	77.86
970	38	2026-04-19	98.75	85.2	95.89	80.68
971	38	2026-04-18	89.38	91.6	96.4	78.92
972	38	2026-04-17	99.79	93.8	98.83	92.51
973	38	2026-04-16	87.71	94.5	97.14	80.52
974	38	2026-04-15	98.54	88.4	97.74	85.14
975	38	2026-04-14	90.63	87.8	98.75	78.57
976	38	2026-04-13	99.79	85.2	96.13	81.73
977	38	2026-04-12	95.21	90	98.11	84.07
978	38	2026-04-11	97.08	97.1	96.19	90.68
979	38	2026-04-10	96.67	87.8	97.95	83.13
980	38	2026-04-09	91.25	87.6	96.23	76.92
981	38	2026-04-08	100	86.1	95.47	82.2
982	38	2026-04-07	89.58	95.8	95.09	81.61
983	38	2026-04-06	97.5	82.4	96.84	77.81
984	38	2026-04-05	95.83	96.7	95.66	88.65
985	38	2026-04-04	94.58	80.2	96.01	72.83
986	38	2026-04-03	90.21	87.1	98.28	77.22
987	38	2026-04-02	91.67	94.4	96.4	83.42
988	38	2026-04-01	92.08	88.4	97.17	79.1
989	38	2026-03-31	90	93.8	97.55	82.35
990	38	2026-03-30	97.08	97.4	97.84	92.52
991	39	2026-04-28	95.83	87.7	97.61	82.03
992	39	2026-04-27	88.33	87.4	96.11	74.2
993	39	2026-04-26	93.33	96.4	96.68	86.99
994	39	2026-04-25	92.08	82.5	97.82	74.31
995	39	2026-04-24	98.33	96	96.56	91.15
996	39	2026-04-23	96.67	82.9	99.03	79.36
997	39	2026-04-22	88.75	95.7	95.61	81.21
998	39	2026-04-21	98.96	92.9	97.63	89.76
999	39	2026-04-20	98.13	90.9	95.93	85.56
1000	39	2026-04-19	89.17	88.3	96.49	75.97
1001	39	2026-04-18	92.5	95.3	96.01	84.64
1002	39	2026-04-17	98.54	89.1	95.74	84.06
1003	39	2026-04-16	92.5	90.4	95.46	79.83
1004	39	2026-04-15	89.58	84.3	98.34	74.26
1005	39	2026-04-14	92.92	89.7	95.99	80
1006	39	2026-04-13	93.96	88.6	96.28	80.15
1007	39	2026-04-12	99.17	85.7	95.22	80.92
1008	39	2026-04-11	93.75	87.6	97.49	80.06
1009	39	2026-04-10	98.75	84.5	96.21	80.28
1010	39	2026-04-09	95.42	93.4	98.18	87.5
1011	39	2026-04-08	88.13	87.6	97.26	75.08
1012	39	2026-04-07	88.96	88.5	98.08	77.22
1013	39	2026-04-06	93.33	85.5	95.32	76.07
1014	39	2026-04-05	94.79	84.3	96.44	77.07
1015	39	2026-04-04	90.21	80.4	97.26	70.54
1016	39	2026-04-03	90.42	96.5	97.31	84.9
1017	39	2026-04-02	98.96	86.9	95.4	82.04
1018	39	2026-04-01	93.75	93.3	98.07	85.78
1019	39	2026-03-31	89.17	91	98.02	79.54
1020	39	2026-03-30	90.63	84.2	95.49	72.86
1021	40	2026-04-28	93.33	80	97.25	72.61
1022	40	2026-04-27	87.71	88	95.45	73.67
1023	40	2026-04-26	94.38	84.1	95.48	75.78
1024	40	2026-04-25	99.79	81.7	97.18	79.23
1025	40	2026-04-24	97.92	85.9	97.67	82.15
1026	40	2026-04-23	90	89.2	97.09	77.94
1027	40	2026-04-22	93.54	86.2	96.17	77.55
1028	40	2026-04-21	96.04	89.7	95.65	82.4
1029	40	2026-04-20	90.42	88	97.73	77.76
1030	40	2026-04-19	95	92.4	98.81	86.74
1031	40	2026-04-18	90.42	83.2	96.27	72.42
1032	40	2026-04-17	94.17	97.3	96.3	88.23
1033	40	2026-04-16	88.33	88.8	97.18	76.23
1034	40	2026-04-15	87.71	88.7	98.87	76.92
1035	40	2026-04-14	91.25	92.8	98.28	83.22
1036	40	2026-04-13	90	85.4	96.6	74.25
1037	40	2026-04-12	89.58	81	98.64	71.58
1038	40	2026-04-11	92.08	93.7	96.48	83.24
1039	40	2026-04-10	98.96	92.9	96.45	88.67
1040	40	2026-04-09	95	92	96.63	84.45
1041	40	2026-04-08	94.58	89.7	96.21	81.63
1042	40	2026-04-07	91.25	93	98.06	83.22
1043	40	2026-04-06	95	92.2	96.2	84.27
1044	40	2026-04-05	91.67	86.8	96.66	76.91
1045	40	2026-04-04	99.79	84.2	96.91	81.43
1046	40	2026-04-03	94.79	90	95.11	81.14
1047	40	2026-04-02	89.38	92.5	95.68	79.1
1048	40	2026-04-01	89.79	89.4	97.32	78.12
1049	40	2026-03-31	90.42	86	96.16	74.77
1050	40	2026-03-30	91.88	95.3	98.43	86.18
1051	41	2026-04-28	94.58	93.2	95.49	84.18
1052	41	2026-04-27	94.58	84.7	96.46	77.27
1053	41	2026-04-26	92.5	86.8	95.97	77.05
1054	41	2026-04-25	90	96.6	97.83	85.05
1055	41	2026-04-24	93.54	87.9	96.59	79.42
1056	41	2026-04-23	95.42	91.7	98.91	86.54
1057	41	2026-04-22	97.92	87.4	95.08	81.37
1058	41	2026-04-21	100	83.3	98.08	81.7
1059	41	2026-04-20	91.04	89.9	95.66	78.3
1060	41	2026-04-19	91.46	93.9	96.7	83.04
1061	41	2026-04-18	95.21	86.1	98.95	81.12
1062	41	2026-04-17	96.67	89.3	96.86	83.62
1063	41	2026-04-16	98.33	86.3	97.68	82.89
1064	41	2026-04-15	97.08	81.1	95.44	75.14
1065	41	2026-04-14	97.08	85.9	98.84	82.42
1066	41	2026-04-13	100	88.8	97.97	87
1067	41	2026-04-12	93.75	86.8	98.16	79.88
1068	41	2026-04-11	96.67	86	98.37	81.78
1069	41	2026-04-10	88.13	96	97.5	82.48
1070	41	2026-04-09	93.33	90.4	95.24	80.36
1071	41	2026-04-08	97.08	97.7	95.39	90.48
1072	41	2026-04-07	97.08	88.4	97.17	83.39
1073	41	2026-04-06	99.58	88.9	96.96	85.84
1074	41	2026-04-05	87.5	96.2	98.34	82.78
1075	41	2026-04-04	95.83	91.3	96.17	84.14
1076	41	2026-04-03	97.92	83.1	98.07	79.8
1077	41	2026-04-02	89.17	80.3	97.63	69.91
1078	41	2026-04-01	95.83	89	96.85	82.61
1079	41	2026-03-31	98.96	80.3	96.51	76.69
1080	41	2026-03-30	93.75	81.6	98.53	75.37
1081	42	2026-04-28	90.42	81.5	95.46	70.34
1082	42	2026-04-27	93.33	94.9	97.15	86.05
1083	42	2026-04-26	93.13	97.9	97.45	88.84
1084	42	2026-04-25	92.71	89.4	98.88	81.95
1085	42	2026-04-24	97.5	89	96.07	83.36
1086	42	2026-04-23	95.21	97.6	95.18	88.45
1087	42	2026-04-22	97.5	84.8	95.75	79.17
1088	42	2026-04-21	95.83	94.7	97.15	88.17
1089	42	2026-04-20	99.17	87.2	98.17	84.89
1090	42	2026-04-19	100	97.8	98.06	95.9
1091	42	2026-04-18	99.38	87.8	97.49	85.06
1092	42	2026-04-17	93.33	90.6	96.69	81.76
1093	42	2026-04-16	89.38	93.7	95.84	80.26
1094	42	2026-04-15	91.04	94.6	97.78	84.21
1095	42	2026-04-14	89.79	96.9	97.52	84.85
1096	42	2026-04-13	90.83	90.6	97.79	80.48
1097	42	2026-04-12	99.79	87.7	96.01	84.02
1098	42	2026-04-11	88.13	92.3	97.18	79.05
1099	42	2026-04-10	95.42	80.8	97.4	75.09
1100	42	2026-04-09	88.13	83	96.14	70.32
1101	42	2026-04-08	91.04	88.4	98.19	79.02
1102	42	2026-04-07	93.33	88.3	98.07	80.83
1103	42	2026-04-06	99.38	89	96.74	85.56
1104	42	2026-04-05	92.29	83.4	96.88	74.57
1105	42	2026-04-04	87.92	82.1	96.59	69.72
1106	42	2026-04-03	99.58	87.5	95.54	83.25
1107	42	2026-04-02	87.92	91.3	96.93	77.81
1108	42	2026-04-01	98.75	83.5	96.17	79.3
1109	42	2026-03-31	91.46	92.1	95.77	80.67
1110	42	2026-03-30	96.67	87	98.05	82.46
1111	43	2026-04-28	93.96	90.4	98.56	83.72
1112	43	2026-04-27	87.5	81.8	97.43	69.74
1113	43	2026-04-26	92.5	90	95.11	79.18
1114	43	2026-04-25	93.96	97.4	98.67	90.29
1115	43	2026-04-24	93.75	82.2	95.62	73.69
1116	43	2026-04-23	91.46	96.3	96.88	85.33
1117	43	2026-04-22	95.63	90	95.22	81.95
1118	43	2026-04-21	92.71	84.7	95.4	74.91
1119	43	2026-04-20	92.92	92.4	96.1	82.51
1120	43	2026-04-19	98.96	89.3	97.87	86.49
1121	43	2026-04-18	94.38	80	96.63	72.95
1122	43	2026-04-17	87.71	87.8	98.06	75.52
1123	43	2026-04-16	87.5	82.8	97.83	70.87
1124	43	2026-04-15	97.92	90.4	95.13	84.21
1125	43	2026-04-14	97.29	88.3	98.41	84.55
1126	43	2026-04-13	93.54	82.7	95.53	73.9
1127	43	2026-04-12	88.13	92.7	98.92	80.81
1128	43	2026-04-11	94.17	90.5	97.35	82.96
1129	43	2026-04-10	95.21	82	97.2	75.88
1130	43	2026-04-09	88.96	81.5	96.07	69.65
1131	43	2026-04-08	89.17	92	98.91	81.14
1132	43	2026-04-07	90.21	83.6	97.73	73.7
1133	43	2026-04-06	97.5	93.2	96.57	87.75
1134	43	2026-04-05	89.58	91.5	95.85	78.56
1135	43	2026-04-04	97.71	91	98.02	87.16
1136	43	2026-04-03	97.29	87.4	97.03	82.5
1137	43	2026-04-02	98.54	89.3	96.19	84.65
1138	43	2026-04-01	94.17	90.6	96.47	82.3
1139	43	2026-03-31	94.38	88.9	96.06	80.6
1140	43	2026-03-30	89.58	92.3	95.88	79.28
1141	44	2026-04-28	95.63	81.1	96.92	75.16
1142	44	2026-04-27	94.17	91.3	96.5	82.96
1143	44	2026-04-26	93.75	97.9	96.12	88.22
1144	44	2026-04-25	91.67	81.4	96.31	71.87
1145	44	2026-04-24	94.58	84.8	98.82	79.26
1146	44	2026-04-23	94.38	87	98.62	80.97
1147	44	2026-04-22	91.04	87.8	96.92	77.48
1148	44	2026-04-21	97.71	90.2	98.89	87.16
1149	44	2026-04-20	99.58	95.1	96.53	91.42
1150	44	2026-04-19	88.96	97.7	96.32	83.71
1151	44	2026-04-18	98.33	85.2	97.89	82.01
1152	44	2026-04-17	94.38	84.8	97.52	78.05
1153	44	2026-04-16	87.92	89.4	98.32	77.28
1154	44	2026-04-15	99.79	97.6	95.39	92.91
1155	44	2026-04-14	97.5	96.9	98.35	92.92
1156	44	2026-04-13	95.63	82.6	97.46	76.98
1157	44	2026-04-12	95	88.4	98.3	82.55
1158	44	2026-04-11	99.38	89.3	98.43	87.35
1159	44	2026-04-10	97.71	89.6	97.88	85.69
1160	44	2026-04-09	91.25	83	95.42	72.27
1161	44	2026-04-08	98.33	87.5	98.17	84.47
1162	44	2026-04-07	94.38	95.6	98.95	89.28
1163	44	2026-04-06	96.67	84.7	97.52	79.85
1164	44	2026-04-05	87.71	87.3	96.11	73.59
1165	44	2026-04-04	88.33	95.8	95.51	80.83
1166	44	2026-04-03	94.17	92.3	95.67	83.15
1167	44	2026-04-02	88.54	96.6	95.76	81.9
1168	44	2026-04-01	88.13	80.2	96.88	68.47
1169	44	2026-03-31	87.5	82.1	95.49	68.6
1170	44	2026-03-30	91.25	86.1	97.1	76.28
1171	45	2026-04-28	91.04	88.3	97.51	78.39
1172	45	2026-04-27	93.13	89.5	95.2	79.34
1173	45	2026-04-26	95	87.6	98.4	81.89
1174	45	2026-04-25	96.25	82.4	97.33	77.19
1175	45	2026-04-24	92.29	86.1	96.63	76.79
1176	45	2026-04-23	98.13	94.4	95.97	88.9
1177	45	2026-04-22	90.63	90.2	95.79	78.3
1178	45	2026-04-21	90.21	83.3	98.92	74.33
1179	45	2026-04-20	89.79	89.9	97	78.3
1180	45	2026-04-19	97.5	90.2	97.56	85.8
1181	45	2026-04-18	97.29	85.3	95.66	79.39
1182	45	2026-04-17	100	94.6	95.88	90.7
1183	45	2026-04-16	91.88	85.1	97.65	76.35
1184	45	2026-04-15	89.79	90.4	97.12	78.84
1185	45	2026-04-14	88.33	80.5	98.76	70.22
1186	45	2026-04-13	91.04	89.2	96.86	78.66
1187	45	2026-04-12	91.46	96.8	95.66	84.69
1188	45	2026-04-11	98.33	96.9	98.35	93.71
1189	45	2026-04-10	88.75	82.6	98.79	72.42
1190	45	2026-04-09	89.17	89.8	96.66	77.4
1191	45	2026-04-08	97.92	95.5	95.6	89.4
1192	45	2026-04-07	98.13	92.2	95.55	86.45
1193	45	2026-04-06	90.42	82	99.02	73.42
1194	45	2026-04-05	99.58	89.5	97.54	86.94
1195	45	2026-04-04	94.17	87.8	95.56	79.01
1196	45	2026-04-03	92.92	95.3	97.69	86.51
1197	45	2026-04-02	96.46	89.8	95.55	82.76
1198	45	2026-04-01	94.38	92	97.28	84.47
1199	45	2026-03-31	96.25	82	96.95	76.52
1200	45	2026-03-30	89.38	82.6	96.85	71.5
1201	46	2026-04-28	95.21	82.8	96.62	76.17
1202	46	2026-04-27	87.92	93.2	98.07	80.36
1203	46	2026-04-26	97.92	87.6	97.95	84.01
1204	46	2026-04-25	93.75	93	96.88	84.47
1205	46	2026-04-24	89.79	92.3	96.32	79.82
1206	46	2026-04-23	97.5	95	97.37	90.19
1207	46	2026-04-22	92.71	89.5	98.32	81.58
1208	46	2026-04-21	91.88	90.4	95.58	79.38
1209	46	2026-04-20	90.83	96.1	95.32	83.2
1210	46	2026-04-19	89.58	96.3	97.2	83.85
1211	46	2026-04-18	87.5	90.6	97.57	77.35
1212	46	2026-04-17	96.88	97.4	95.38	90
1213	46	2026-04-16	94.17	93.5	97.75	86.07
1214	46	2026-04-15	94.58	86.5	96.88	79.26
1215	46	2026-04-14	89.79	83.9	96.42	72.64
1216	46	2026-04-13	90	82.3	97.21	72
1217	46	2026-04-12	96.88	85.8	96.27	80.02
1218	46	2026-04-11	90.63	94.6	96.93	83.1
1219	46	2026-04-10	93.75	89.7	95.43	80.25
1220	46	2026-04-09	88.13	88	97.73	75.79
1221	46	2026-04-08	89.58	92.4	95.13	78.74
1222	46	2026-04-07	94.58	96.6	95.24	87.02
1223	46	2026-04-06	92.5	93	98.6	84.82
1224	46	2026-04-05	95.21	94	97.23	87.02
1225	46	2026-04-04	97.08	81.1	97.53	76.79
1226	46	2026-04-03	96.25	83.8	96.66	77.96
1227	46	2026-04-02	92.29	84.9	97.29	76.23
1228	46	2026-04-01	96.67	88.7	98.2	84.2
1229	46	2026-03-31	96.67	80.4	98.88	76.85
1230	46	2026-03-30	93.75	82.6	97.34	75.37
1231	47	2026-04-28	88.75	87.8	96.24	74.99
1232	47	2026-04-27	92.29	86.8	96.89	77.62
1233	47	2026-04-26	91.88	81.7	95.72	71.85
1234	47	2026-04-25	91.88	94.6	98.94	85.99
1235	47	2026-04-24	94.38	84.7	95.75	76.54
1236	47	2026-04-23	91.46	93.8	95.74	82.13
1237	47	2026-04-22	98.33	90.6	97.13	86.53
1238	47	2026-04-21	87.71	82.2	96.11	69.29
1239	47	2026-04-20	91.67	89.3	96.98	79.38
1240	47	2026-04-19	96.67	88.3	95.36	81.39
1241	47	2026-04-18	97.5	89.7	96.66	84.53
1242	47	2026-04-17	91.46	84.4	99.05	76.46
1243	47	2026-04-16	87.5	84.4	95.5	70.52
1244	47	2026-04-15	94.38	88.3	96.26	80.22
1245	47	2026-04-14	100	86.5	98.96	85.6
1246	47	2026-04-13	98.13	90.4	95.58	84.78
1247	47	2026-04-12	91.46	94.2	97.35	83.87
1248	47	2026-04-11	100	86.2	97.1	83.7
1249	47	2026-04-10	95.21	95.6	98.12	89.31
1250	47	2026-04-09	92.08	88.6	95.71	78.09
1251	47	2026-04-08	88.75	93.7	96.37	80.14
1252	47	2026-04-07	88.33	83.6	95.22	70.31
1253	47	2026-04-06	89.58	80	98.13	70.32
1254	47	2026-04-05	91.46	89.5	98.77	80.85
1255	47	2026-04-04	92.5	93.5	97.54	84.36
1256	47	2026-04-03	88.13	92	96.85	78.52
1257	47	2026-04-02	97.29	90.5	98.67	86.88
1258	47	2026-04-01	96.46	90.3	98.56	85.85
1259	47	2026-03-31	90	96.1	97.19	84.06
1260	47	2026-03-30	90.21	80.4	95.15	69.01
1261	48	2026-04-28	100	88.5	96.95	85.8
1262	48	2026-04-27	92.71	82.2	97.08	73.98
1263	48	2026-04-26	96.67	94.3	95.23	86.81
1264	48	2026-04-25	89.79	81.8	95.97	70.49
1265	48	2026-04-24	96.04	86.8	96.77	80.68
1266	48	2026-04-23	87.71	83.1	96.03	69.99
1267	48	2026-04-22	93.33	86.2	97.8	78.68
1268	48	2026-04-21	89.38	97.6	98.98	86.34
1269	48	2026-04-20	97.92	96.6	98.24	92.92
1270	48	2026-04-19	88.75	90.5	97.24	78.1
1271	48	2026-04-18	91.04	85.5	97.78	76.11
1272	48	2026-04-17	100	80	97.25	77.8
1273	48	2026-04-16	99.79	88.6	95.37	84.32
1274	48	2026-04-15	88.96	86.1	95.47	73.12
1275	48	2026-04-14	90	96.4	97.3	84.42
1276	48	2026-04-13	92.92	81.9	98.17	74.7
1277	48	2026-04-12	89.38	94.7	96.2	81.42
1278	48	2026-04-11	94.38	81.6	99.02	76.26
1279	48	2026-04-10	99.58	81.7	98.78	80.36
1280	48	2026-04-09	94.17	88.2	97.73	81.17
1281	48	2026-04-08	91.46	90.8	96.81	80.39
1282	48	2026-04-07	93.96	80.2	98.88	74.51
1283	48	2026-04-06	92.29	82	95.49	72.26
1284	48	2026-04-05	91.88	85.3	98.36	77.08
1285	48	2026-04-04	87.71	97.6	98.16	84.02
1286	48	2026-04-03	98.13	88.3	98.07	84.98
1287	48	2026-04-02	92.92	92.5	96.86	83.25
1288	48	2026-04-01	90.21	97.9	97.04	85.7
1289	48	2026-03-31	95.63	85.6	97.78	80.04
1290	48	2026-03-30	97.08	80.5	98.01	76.6
1291	49	2026-04-28	92.08	91.8	96.84	81.86
1292	49	2026-04-27	92.71	93.1	95.27	82.23
1293	49	2026-04-26	100	94.8	97.05	92
1294	49	2026-04-25	91.88	88.6	98.65	80.3
1295	49	2026-04-24	98.96	81.1	98.03	78.67
1296	49	2026-04-23	89.79	83.4	98.56	73.81
1297	49	2026-04-22	98.96	80	95.75	75.8
1298	49	2026-04-21	88.33	90.3	98.67	78.7
1299	49	2026-04-20	97.71	85.7	95.45	79.93
1300	49	2026-04-19	95.83	93.5	97.11	87.02
1301	49	2026-04-18	88.75	84.1	98.57	73.57
1302	49	2026-04-17	94.17	88.4	97.74	81.36
1303	49	2026-04-16	95.83	85.2	96.71	78.97
1304	49	2026-04-15	97.71	87.5	98.63	84.32
1305	49	2026-04-14	92.5	80	97.63	72.24
1306	49	2026-04-13	95.21	91.4	98.25	85.5
1307	49	2026-04-12	89.79	81	97.65	71.03
1308	49	2026-04-11	97.08	92.5	97.3	87.38
1309	49	2026-04-10	97.92	81.7	95.96	76.77
1310	49	2026-04-09	91.04	90.4	96.02	79.02
1311	49	2026-04-08	92.29	80.9	96.91	72.36
1312	49	2026-04-07	98.13	97.6	96.62	92.53
1313	49	2026-04-06	97.08	83.5	97.13	78.73
1314	49	2026-04-05	97.71	87.3	98.85	84.32
1315	49	2026-04-04	91.46	84.8	95.87	74.36
1316	49	2026-04-03	90.42	85.5	97.43	75.32
1317	49	2026-04-02	100	93.2	97.64	91
1318	49	2026-04-01	90	85.3	99.06	76.05
1319	49	2026-03-31	98.13	90.9	96.7	86.25
1320	49	2026-03-30	87.71	82.7	97.34	70.61
1321	50	2026-04-28	88.33	95.8	98.64	83.47
1322	50	2026-04-27	90.21	92.1	98.05	81.46
1323	50	2026-04-26	96.88	95.5	95.6	88.45
1324	50	2026-04-25	87.92	81.6	98.9	70.95
1325	50	2026-04-24	97.5	88.9	95.39	82.68
1326	50	2026-04-23	93.33	96.3	98.65	88.67
1327	50	2026-04-22	93.96	88.9	95.73	79.96
1328	50	2026-04-21	92.92	86.9	95.97	77.49
1329	50	2026-04-20	88.13	88.9	98.31	77.02
1330	50	2026-04-19	97.5	92.9	96.99	87.85
1331	50	2026-04-18	95.42	92.9	97.31	86.26
1332	50	2026-04-17	96.25	94.4	98.83	89.8
1333	50	2026-04-16	99.58	94.6	97.89	92.21
1334	50	2026-04-15	96.25	90.8	97.69	85.37
1335	50	2026-04-14	92.29	82.6	96.13	73.28
1336	50	2026-04-13	91.04	91.1	96.82	80.3
1337	50	2026-04-12	99.58	90.6	95.47	86.14
1338	50	2026-04-11	88.96	96.2	98.44	84.24
1339	50	2026-04-10	92.71	83.1	98.56	75.93
1340	50	2026-04-09	97.29	80.4	96.14	75.21
1341	50	2026-04-08	89.79	93.5	96.04	80.63
1342	50	2026-04-07	96.25	85.9	96.62	79.89
1343	50	2026-04-06	92.92	81.2	98.28	74.15
1344	50	2026-04-05	89.79	91.7	98.36	80.99
1345	50	2026-04-04	93.96	94.3	95.12	84.28
1346	50	2026-04-03	99.17	84	95.6	79.63
1347	50	2026-04-02	90.83	92.2	97.72	81.84
1348	50	2026-04-01	91.46	97.8	98.06	87.71
1349	50	2026-03-31	99.38	86	95.58	81.69
1350	50	2026-03-30	92.5	91.1	95.72	80.66
1351	51	2026-04-28	91.04	81.6	98.04	72.83
1352	51	2026-04-27	97.5	84.8	99.06	81.9
1353	51	2026-04-26	96.04	89.7	98.22	84.61
1354	51	2026-04-25	98.75	84.5	95.62	79.79
1355	51	2026-04-24	90	95.5	97.8	84.06
1356	51	2026-04-23	94.17	82	97.07	74.96
1357	51	2026-04-22	99.58	91.3	99.01	90.02
1358	51	2026-04-21	88.13	82.1	98.9	71.56
1359	51	2026-04-20	91.88	90.1	96.12	79.56
1360	51	2026-04-19	95	91	98.02	84.74
1361	51	2026-04-18	94.17	97.3	97.94	89.74
1362	51	2026-04-17	97.92	94.2	95.44	88.03
1363	51	2026-04-16	91.46	87	96.32	76.64
1364	51	2026-04-15	87.5	89.1	97.98	76.39
1365	51	2026-04-14	89.38	96	98.44	84.46
1366	51	2026-04-13	95.21	94.5	95.77	86.16
1367	51	2026-04-12	90	95.8	99.06	85.41
1368	51	2026-04-11	90.83	93.1	96.13	81.3
1369	51	2026-04-10	89.58	87.6	98.97	77.67
1370	51	2026-04-09	91.88	92.5	96.11	81.68
1371	51	2026-04-08	88.96	96.6	95.86	82.38
1372	51	2026-04-07	99.38	96.8	97.42	93.71
1373	51	2026-04-06	87.92	83.9	98.81	72.88
1374	51	2026-04-05	98.75	85.8	97.44	82.56
1375	51	2026-04-04	96.46	89.4	96.2	82.95
1376	51	2026-04-03	87.92	95.6	98.33	82.64
1377	51	2026-04-02	89.58	92.1	95.33	78.65
1378	51	2026-04-01	94.38	85.9	97.79	79.28
1379	51	2026-03-31	98.54	81.8	98.78	79.62
1380	51	2026-03-30	96.46	94.9	96.31	88.16
1381	52	2026-04-28	95.21	88.7	98.53	83.21
1382	52	2026-04-27	92.92	89.9	98.33	82.14
1383	52	2026-04-26	87.92	86.9	98.16	74.99
1384	52	2026-04-25	99.58	91.6	97.05	88.53
1385	52	2026-04-24	91.04	93.1	95.17	80.66
1386	52	2026-04-23	95.42	93.6	98.82	88.26
1387	52	2026-04-22	88.33	94.1	98.3	81.71
1388	52	2026-04-21	89.58	82	96.71	71.04
1389	52	2026-04-20	92.71	86.6	95.61	76.76
1390	52	2026-04-19	90.83	92.7	96.22	81.02
1391	52	2026-04-18	87.5	81.7	95.35	68.16
1392	52	2026-04-17	89.38	85.7	96.15	73.65
1393	52	2026-04-16	97.71	96.1	98.23	92.24
1394	52	2026-04-15	100	95.1	96.53	91.8
1395	52	2026-04-14	98.54	89	96.52	84.65
1396	52	2026-04-13	92.29	93.4	96.25	82.97
1397	52	2026-04-12	97.5	81	95.19	75.17
1398	52	2026-04-11	99.58	88.8	95.38	84.35
1399	52	2026-04-10	93.13	89.7	96.88	80.93
1400	52	2026-04-09	98.75	91.4	97.92	88.38
1401	52	2026-04-08	94.17	85	98.94	79.19
1402	52	2026-04-07	92.08	92.2	97.83	83.06
1403	52	2026-04-06	92.71	86.2	96.29	76.95
1404	52	2026-04-05	90.42	90.4	96.57	78.93
1405	52	2026-04-04	94.58	92	98.59	85.79
1406	52	2026-04-03	95.63	96.3	95.43	87.88
1407	52	2026-04-02	89.17	87.9	96.47	75.61
1408	52	2026-04-01	93.33	87.2	95.64	77.84
1409	52	2026-03-31	99.58	90	97.22	87.14
1410	52	2026-03-30	90.63	91.3	95.62	79.12
1411	53	2026-04-28	90.63	87.9	96.25	76.67
1412	53	2026-04-27	96.25	93.4	98.82	88.84
1413	53	2026-04-26	89.58	80.8	95.54	69.16
1414	53	2026-04-25	89.79	92.9	96.88	80.81
1415	53	2026-04-24	91.25	84.7	96.58	74.64
1416	53	2026-04-23	88.75	80.3	95.14	67.81
1417	53	2026-04-22	94.17	89.5	98.66	83.15
1418	53	2026-04-21	90.42	92.7	98.06	82.19
1419	53	2026-04-20	87.71	85.8	96.5	72.62
1420	53	2026-04-19	92.71	92.9	98.49	84.83
1421	53	2026-04-18	92.29	97.7	95.39	86.02
1422	53	2026-04-17	93.75	85.2	96.48	77.06
1423	53	2026-04-16	87.71	88.6	95.6	74.29
1424	53	2026-04-15	97.92	85.2	98.24	81.96
1425	53	2026-04-14	97.92	88.6	97.07	84.21
1426	53	2026-04-13	88.96	88	96.82	75.79
1427	53	2026-04-12	87.71	84.8	95.28	70.87
1428	53	2026-04-11	99.17	85.7	97.08	82.51
1429	53	2026-04-10	96.04	95.9	95.93	88.36
1430	53	2026-04-09	97.5	86.4	96.18	81.02
1431	53	2026-04-08	92.71	95.1	97.58	86.03
1432	53	2026-04-07	99.17	83.7	98.57	81.81
1433	53	2026-04-06	94.79	83	98.92	77.82
1434	53	2026-04-05	96.88	89.2	95.29	82.34
1435	53	2026-04-04	90.83	82.5	96.61	72.39
1436	53	2026-04-03	95.83	85.4	97.66	79.92
1437	53	2026-04-02	98.13	94.8	95.46	88.8
1438	53	2026-04-01	88.96	91.2	97.04	78.73
1439	53	2026-03-31	93.54	94.4	95.44	84.28
1440	53	2026-03-30	87.71	92.1	97.5	78.76
1441	54	2026-04-28	97.5	97.7	98.46	93.8
1442	54	2026-04-27	89.58	96.1	98.96	85.19
1443	54	2026-04-26	97.5	87.6	96	82
1444	54	2026-04-25	91.25	94.3	95.97	82.58
1445	54	2026-04-24	92.29	96.2	97.09	86.2
1446	54	2026-04-23	99.17	97.5	96	92.82
1447	54	2026-04-22	90.21	81.9	96.21	71.08
1448	54	2026-04-21	94.58	84.6	96.34	77.09
1449	54	2026-04-20	97.5	96.4	96.68	90.87
1450	54	2026-04-19	96.67	94.3	95.55	87.1
1451	54	2026-04-18	92.5	86.8	97.81	78.53
1452	54	2026-04-17	92.08	97.5	96	86.19
1453	54	2026-04-16	98.96	92.9	98.17	90.25
1454	54	2026-04-15	97.08	86.7	96.66	81.36
1455	54	2026-04-14	93.13	87.5	95.54	77.85
1456	54	2026-04-13	95.21	90.1	95.78	82.16
1457	54	2026-04-12	97.08	82.3	99.03	79.12
1458	54	2026-04-11	100	86.7	99.08	85.9
1459	54	2026-04-10	96.25	93	96.13	86.05
1460	54	2026-04-09	96.67	93.8	98.51	89.32
1461	54	2026-04-08	94.79	94.2	96.92	86.54
1462	54	2026-04-07	90.63	89.4	97.2	78.75
1463	54	2026-04-06	98.13	88	96.02	82.92
1464	54	2026-04-05	90.42	87.6	95.32	75.5
1465	54	2026-04-04	99.38	80.1	99	78.8
1466	54	2026-04-03	91.46	86.8	98.27	78.01
1467	54	2026-04-02	99.17	81.8	95.35	77.35
1468	54	2026-04-01	98.54	92.9	96.23	88.1
1469	54	2026-03-31	96.67	96.6	97.41	90.96
1470	54	2026-03-30	97.5	90.1	97.89	86
1471	55	2026-04-28	97.71	85.2	95.89	79.83
1472	55	2026-04-27	95.42	81.1	99.01	76.62
1473	55	2026-04-26	88.13	83.3	95.92	70.41
1474	55	2026-04-25	89.38	88.2	96.94	76.42
1475	55	2026-04-24	88.75	86.6	97.69	75.08
1476	55	2026-04-23	95.21	83.4	96.52	76.64
1477	55	2026-04-22	90	80.6	95.91	69.57
1478	55	2026-04-21	99.17	87.4	96.68	83.8
1479	55	2026-04-20	87.92	91.4	98.58	79.21
1480	55	2026-04-19	87.92	85.7	98.25	74.03
1481	55	2026-04-18	96.25	82	98.54	77.77
1482	55	2026-04-17	95	80.4	95.9	73.25
1483	55	2026-04-16	98.13	93.5	95.94	88.02
1484	55	2026-04-15	96.04	94.3	96.18	87.11
1485	55	2026-04-14	89.38	82.8	98.79	73.11
1486	55	2026-04-13	89.79	89.7	96.1	77.4
1487	55	2026-04-12	98.13	84.4	95.97	79.48
1488	55	2026-04-11	91.88	85.8	96.04	75.7
1489	55	2026-04-10	94.17	85.3	98.71	79.29
1490	55	2026-04-09	93.33	88.6	97.52	80.64
1491	55	2026-04-08	95	80.7	95.29	73.06
1492	55	2026-04-07	87.92	89.8	98.55	77.81
1493	55	2026-04-06	88.54	84.1	97.74	72.78
1494	55	2026-04-05	87.71	88.5	95.71	74.29
1495	55	2026-04-04	95.63	83.2	97.6	77.65
1496	55	2026-04-03	98.13	91.5	97.49	87.53
1497	55	2026-04-02	96.04	91.9	95.1	83.94
1498	55	2026-04-01	94.79	95.9	96.98	88.16
1499	55	2026-03-31	90.42	80.3	98.38	71.43
1500	55	2026-03-30	94.17	89.1	98.77	82.87
1501	56	2026-04-28	89.38	91.7	96.73	79.28
1502	56	2026-04-27	87.92	92.4	96.97	78.77
1503	56	2026-04-26	96.67	89.4	98.21	84.87
1504	56	2026-04-25	99.79	85.7	96.85	82.83
1505	56	2026-04-24	98.96	81.1	98.15	78.77
1506	56	2026-04-23	96.67	88.7	96.96	83.13
1507	56	2026-04-22	91.46	86.1	98.72	77.74
1508	56	2026-04-21	88.75	89.7	96.21	76.59
1509	56	2026-04-20	95.63	94.7	97.04	87.88
1510	56	2026-04-19	94.17	86.6	97.81	79.76
1511	56	2026-04-18	98.96	80.5	97.64	77.78
1512	56	2026-04-17	100	90.7	97.91	88.8
1513	56	2026-04-16	87.71	97.5	96.62	82.62
1514	56	2026-04-15	97.92	80.9	95.06	75.3
1515	56	2026-04-14	94.58	91.3	96.6	83.42
1516	56	2026-04-13	91.46	80.1	96	70.33
1517	56	2026-04-12	98.13	85	95.18	79.38
1518	56	2026-04-11	96.46	84.9	98.7	80.83
1519	56	2026-04-10	97.71	90.9	97.8	86.86
1520	56	2026-04-09	93.75	88.9	95.95	79.97
1521	56	2026-04-08	88.96	81.1	95.44	68.85
1522	56	2026-04-07	92.92	92.9	95.8	82.7
1523	56	2026-04-06	99.79	96.4	98.76	95
1524	56	2026-04-05	92.5	97.5	96.82	87.32
1525	56	2026-04-04	98.33	87.6	97.49	83.98
1526	56	2026-04-03	98.75	81.8	95.11	76.83
1527	56	2026-04-02	91.04	90.9	95.27	78.84
1528	56	2026-04-01	97.71	88.9	95.84	83.25
1529	56	2026-03-31	88.96	94.7	98.73	83.18
1530	56	2026-03-30	95.83	84.1	97.62	78.68
1531	57	2026-04-28	88.54	90.1	98.56	78.63
1532	57	2026-04-27	88.75	86.6	96.54	74.19
1533	57	2026-04-26	91.88	88.3	98.3	79.75
1534	57	2026-04-25	97.5	97.6	98.46	93.7
1535	57	2026-04-24	90.42	94.3	98.3	83.82
1536	57	2026-04-23	98.33	91.4	96.39	86.63
1537	57	2026-04-22	90.83	87.9	97.5	77.84
1538	57	2026-04-21	88.96	93.4	98.93	82.2
1539	57	2026-04-20	99.17	96.8	96.38	92.52
1540	57	2026-04-19	88.96	86.4	95.6	73.48
1541	57	2026-04-18	92.29	84.3	97.03	75.49
1542	57	2026-04-17	96.46	90.8	96.26	84.3
1543	57	2026-04-16	96.46	96.4	95.64	88.93
1544	57	2026-04-15	100	83.1	98.32	81.7
1545	57	2026-04-14	99.17	92.6	95.14	87.37
1546	57	2026-04-13	99.38	90.8	95.15	85.86
1547	57	2026-04-12	99.17	83.1	97.71	80.52
1548	57	2026-04-11	89.58	80.7	97.03	70.14
1549	57	2026-04-10	97.29	83.1	96.27	77.83
1550	57	2026-04-09	94.38	93.3	97.11	85.5
1551	57	2026-04-08	90.42	83.5	97.84	73.87
1552	57	2026-04-07	96.25	96.6	98.86	91.92
1553	57	2026-04-06	92.29	85.6	95.56	75.49
1554	57	2026-04-05	94.58	93.3	95.71	84.46
1555	57	2026-04-04	98.54	93.4	97.64	89.87
1556	57	2026-04-03	92.29	82.1	95.86	72.63
1557	57	2026-04-02	98.96	83	98.92	81.24
1558	57	2026-04-01	89.79	82.8	96.14	71.47
1559	57	2026-03-31	98.54	82.5	95.88	77.95
1560	57	2026-03-30	98.96	85.1	95.18	80.16
1561	58	2026-04-28	97.92	97.5	98.77	94.29
1562	58	2026-04-27	90.83	91.4	95.19	79.03
1563	58	2026-04-26	89.17	90.8	99.01	80.16
1564	58	2026-04-25	88.13	82.8	95.53	69.71
1565	58	2026-04-24	90.42	95.6	96.44	83.36
1566	58	2026-04-23	98.54	81.3	97.42	78.05
1567	58	2026-04-22	92.08	81.1	95.19	71.09
1568	58	2026-04-21	88.75	82.4	96.84	70.82
1569	58	2026-04-20	91.04	93.5	96.47	82.12
1570	58	2026-04-19	91.25	88.9	95.95	77.84
1571	58	2026-04-18	96.04	88.3	98.07	83.17
1572	58	2026-04-17	100	90.1	95.56	86.1
1573	58	2026-04-16	91.88	90.7	95.48	79.56
1574	58	2026-04-15	94.58	90.5	97.9	83.8
1575	58	2026-04-14	96.46	80.3	99	76.68
1576	58	2026-04-13	93.33	89.7	96.99	81.2
1577	58	2026-04-12	94.58	97.5	95.59	88.15
1578	58	2026-04-11	92.71	95.1	97.27	85.76
1579	58	2026-04-10	91.46	93.1	95.49	81.31
1580	58	2026-04-09	99.79	92.7	95.79	88.62
1581	58	2026-04-08	98.96	94.8	97.05	91.04
1582	58	2026-04-07	95.21	80.5	95.65	73.31
1583	58	2026-04-06	92.08	82.1	97.32	73.57
1584	58	2026-04-05	98.96	92.2	95.23	86.89
1585	58	2026-04-04	94.58	87.7	97.61	80.96
1586	58	2026-04-03	97.71	91	95.05	84.52
1587	58	2026-04-02	97.08	84.3	98.46	80.58
1588	58	2026-04-01	90.63	83.9	95.59	72.68
1589	58	2026-03-31	99.58	89.8	98.55	88.13
1590	58	2026-03-30	90.63	88.9	97.3	78.39
1591	59	2026-04-28	89.79	91.3	97.81	80.18
1592	59	2026-04-27	87.5	80.6	99.01	69.83
1593	59	2026-04-26	95	89.7	97.88	83.41
1594	59	2026-04-25	91.25	82.8	99.03	74.82
1595	59	2026-04-24	99.58	89.3	96.08	85.44
1596	59	2026-04-23	93.75	87.1	98.51	80.44
1597	59	2026-04-22	95.63	88.2	95.69	80.71
1598	59	2026-04-21	87.92	96.6	97.31	82.64
1599	59	2026-04-20	99.58	96.5	95.96	92.21
1600	59	2026-04-19	98.33	97.4	99.08	94.89
1601	59	2026-04-18	89.58	96.2	98.65	85.01
1602	59	2026-04-17	98.13	90.5	96.46	85.66
1603	59	2026-04-16	98.33	95.2	98.95	92.63
1604	59	2026-04-15	90.83	85.1	96.83	74.85
1605	59	2026-04-14	88.54	96	95.94	81.55
1606	59	2026-04-13	87.5	91.6	97.82	78.4
1607	59	2026-04-12	88.13	90.5	97.57	77.81
1608	59	2026-04-11	96.88	87.8	95.9	81.57
1609	59	2026-04-10	92.5	93.3	97.11	83.81
1610	59	2026-04-09	92.71	97.9	97.04	88.07
1611	59	2026-04-08	91.25	86.5	98.15	77.47
1612	59	2026-04-07	92.71	96.2	96.67	86.22
1613	59	2026-04-06	92.71	82.6	98.67	75.56
1614	59	2026-04-05	88.75	94.3	95.65	80.05
1615	59	2026-04-04	87.92	96.3	98.96	83.78
1616	59	2026-04-03	91.46	80.2	96.76	70.97
1617	59	2026-04-02	95.21	85.1	96.59	78.26
1618	59	2026-04-01	97.71	91.8	96.41	86.47
1619	59	2026-03-31	99.38	95.3	96.01	90.93
1620	59	2026-03-30	95.42	88.3	98.3	82.82
1621	60	2026-04-28	93.33	87.8	98.75	80.92
1622	60	2026-04-27	93.54	86.7	98.85	80.17
1623	60	2026-04-26	91.46	91.3	95.07	79.39
1624	60	2026-04-25	94.58	85.6	95.09	76.99
1625	60	2026-04-24	99.38	84.5	97.51	81.88
1626	60	2026-04-23	88.13	92	98.7	80.02
1627	60	2026-04-22	89.38	96.4	95.75	82.49
1628	60	2026-04-21	90	94	95.21	80.55
1629	60	2026-04-20	88.33	93.5	99.04	81.8
1630	60	2026-04-19	98.13	80.7	97.77	77.42
1631	60	2026-04-18	98.54	81.5	97.55	78.34
1632	60	2026-04-17	98.13	81.6	97.18	77.81
1633	60	2026-04-16	93.75	91.7	97.6	83.91
1634	60	2026-04-15	92.5	94.9	97.79	85.84
1635	60	2026-04-14	90.83	81.6	97.67	72.39
1636	60	2026-04-13	93.54	97.5	97.85	89.24
1637	60	2026-04-12	92.71	94.4	98.31	86.03
1638	60	2026-04-11	98.54	96.4	97.41	92.53
1639	60	2026-04-10	91.67	83.4	97	74.16
1640	60	2026-04-09	91.25	89.3	98.77	80.48
1641	60	2026-04-08	88.54	84.2	95.84	71.45
1642	60	2026-04-07	94.38	80.7	97.15	73.99
1643	60	2026-04-06	92.92	93.4	95.4	82.79
1644	60	2026-04-05	88.13	82.8	97.83	71.38
1645	60	2026-04-04	87.5	86.4	97.69	73.85
1646	60	2026-04-03	98.96	82.2	98.78	80.35
1647	60	2026-04-02	88.13	87.4	97.37	74.99
1648	60	2026-04-01	94.58	88	96.36	80.21
1649	60	2026-03-31	100	94.7	95.46	90.4
1650	60	2026-03-30	87.92	93.9	98.72	81.5
1651	61	2026-04-28	88.13	81.4	95.95	68.83
1652	61	2026-04-27	94.38	93	96.99	85.13
1653	61	2026-04-26	99.38	94.7	98.73	92.92
1654	61	2026-04-25	88.54	96.4	98.34	83.94
1655	61	2026-04-24	94.17	95	98	87.67
1656	61	2026-04-23	97.92	93.6	95.3	87.34
1657	61	2026-04-22	95.63	94.6	96.41	87.21
1658	61	2026-04-21	97.08	92.6	96.44	86.7
1659	61	2026-04-20	95.63	84.4	96.45	77.84
1660	61	2026-04-19	88.33	93.4	97	80.03
1661	61	2026-04-18	96.88	91.1	98.24	86.7
1662	61	2026-04-17	97.71	81.7	97.67	77.97
1663	61	2026-04-16	96.67	82.9	98.43	78.88
1664	61	2026-04-15	96.46	83.6	95.93	77.36
1665	61	2026-04-14	93.13	96.5	97.1	87.26
1666	61	2026-04-13	93.13	89.7	96.43	80.55
1667	61	2026-04-12	91.25	85.5	97.08	75.74
1668	61	2026-04-11	90.21	89.7	96.88	78.39
1669	61	2026-04-10	92.08	82.6	95.88	72.93
1670	61	2026-04-09	99.17	88.9	98.54	86.87
1671	61	2026-04-08	88.54	83.7	96.54	71.54
1672	61	2026-04-07	94.58	88.1	98.18	81.81
1673	61	2026-04-06	95.21	93.7	97.97	87.4
1674	61	2026-04-05	96.25	89.6	96.32	83.06
1675	61	2026-04-04	92.71	95.4	95.7	84.64
1676	61	2026-04-03	93.96	83.2	96.51	75.45
1677	61	2026-04-02	95	91.5	97.49	84.74
1678	61	2026-04-01	88.54	86.8	96.77	74.37
1679	61	2026-03-31	93.54	97.4	98.46	89.71
1680	61	2026-03-30	95.42	97.3	95.38	88.55
1681	62	2026-04-28	97.71	96.9	98.25	93.02
1682	62	2026-04-27	93.96	86.7	96.08	78.27
1683	62	2026-04-26	90.83	86.5	95.61	75.12
1684	62	2026-04-25	96.88	94	95.53	86.99
1685	62	2026-04-24	88.33	90.9	96.37	77.38
1686	62	2026-04-23	100	86.6	97.69	84.6
1687	62	2026-04-22	92.92	80.7	95.91	71.92
1688	62	2026-04-21	93.96	82.6	97.58	75.73
1689	62	2026-04-20	90.42	85.5	96.84	74.86
1690	62	2026-04-19	89.17	81.3	98.52	71.42
1691	62	2026-04-18	87.71	89.9	98	77.27
1692	62	2026-04-17	94.58	96.3	97.72	89
1693	62	2026-04-16	95.42	95.4	97.38	88.64
1694	62	2026-04-15	98.96	92.7	96.98	88.96
1695	62	2026-04-14	94.17	96.2	96.99	87.86
1696	62	2026-04-13	99.17	89.9	97.66	87.07
1697	62	2026-04-12	99.79	82.6	97.46	80.33
1698	62	2026-04-11	96.67	92	98.26	87.39
1699	62	2026-04-10	90	90.4	97.01	78.93
1700	62	2026-04-09	98.13	89.5	96.31	84.58
1701	62	2026-04-08	100	83.8	98.81	82.8
1702	62	2026-04-07	96.25	96.4	97.3	90.28
1703	62	2026-04-06	97.08	92	98.8	88.25
1704	62	2026-04-05	89.58	94.6	95.45	80.89
1705	62	2026-04-04	90.42	82.6	99.03	73.96
1706	62	2026-04-03	95.42	89.2	97.53	83.01
1707	62	2026-04-02	94.38	96.3	96.26	87.49
1708	62	2026-04-01	99.79	96.7	95.97	92.61
1709	62	2026-03-31	89.58	85.4	97.07	74.26
1710	62	2026-03-30	92.92	95.3	98.74	87.43
1711	63	2026-04-28	94.17	93.2	98.93	86.82
1712	63	2026-04-27	92.08	91.3	98.14	82.51
1713	63	2026-04-26	88.13	90.6	97.13	77.55
1714	63	2026-04-25	88.54	92.7	95.15	78.09
1715	63	2026-04-24	95.21	82.4	95.15	74.64
1716	63	2026-04-23	97.29	83.5	95.21	77.35
1717	63	2026-04-22	95	91.2	97.37	84.36
1718	63	2026-04-21	90.21	83.8	95.35	72.08
1719	63	2026-04-20	89.17	91	96.15	78.02
1720	63	2026-04-19	88.54	80.5	97.64	69.59
1721	63	2026-04-18	87.92	90.2	96.45	76.49
1722	63	2026-04-17	87.5	84.2	96.56	71.14
1723	63	2026-04-16	98.13	80.1	98.13	77.13
1724	63	2026-04-15	91.88	94.6	98.2	85.35
1725	63	2026-04-14	97.29	97.6	95.7	90.87
1726	63	2026-04-13	93.96	88	95.8	79.21
1727	63	2026-04-12	88.75	95.7	96.03	81.56
1728	63	2026-04-11	90	85.6	98.25	75.69
1729	63	2026-04-10	94.38	95.4	97.38	87.67
1730	63	2026-04-09	89.58	94.6	95.77	81.16
1731	63	2026-04-08	97.92	80.3	96.89	76.18
1732	63	2026-04-07	93.96	89.4	97.76	82.12
1733	63	2026-04-06	99.17	82.9	96.86	79.63
1734	63	2026-04-05	95.83	94.7	98.84	89.7
1735	63	2026-04-04	91.25	90.9	98.24	81.49
1736	63	2026-04-03	90	95.4	96.33	82.71
1737	63	2026-04-02	92.71	90	97.67	81.49
1738	63	2026-04-01	94.38	90	95.44	81.07
1739	63	2026-03-31	89.58	91.3	96.5	78.92
1740	63	2026-03-30	89.38	96.9	98.97	85.71
1741	64	2026-04-28	87.71	81	96.42	68.5
1742	64	2026-04-27	99.58	96.2	97.09	93.01
1743	64	2026-04-26	96.46	89	98.99	84.98
1744	64	2026-04-25	89.79	84.8	95.17	72.46
1745	64	2026-04-24	92.29	86.3	96.18	76.6
1746	64	2026-04-23	95	93.3	97.75	86.64
1747	64	2026-04-22	88.96	86.6	98.96	76.24
1748	64	2026-04-21	100	96	96.88	93
1749	64	2026-04-20	97.92	91.2	95.72	85.48
1750	64	2026-04-19	94.38	84.8	96.34	77.1
1751	64	2026-04-18	94.79	88.7	98.65	82.94
1752	64	2026-04-17	97.08	97	96.29	90.68
1753	64	2026-04-16	88.13	82	98.17	70.94
1754	64	2026-04-15	89.38	82.3	97.81	71.95
1755	64	2026-04-14	87.71	86.2	96.87	73.24
1756	64	2026-04-13	91.25	85.1	98	76.1
1757	64	2026-04-12	95.21	87	96.21	79.69
1758	64	2026-04-11	95	92.9	97.63	86.16
1759	64	2026-04-10	93.54	81.5	95.46	72.78
1760	64	2026-04-09	88.96	85.1	96.59	73.12
1761	64	2026-04-08	89.38	83.8	97.97	73.38
1762	64	2026-04-07	92.71	82.3	98.42	75.09
1763	64	2026-04-06	91.25	80.1	95.51	69.81
1764	64	2026-04-05	97.08	89.6	98.21	85.43
1765	64	2026-04-04	94.79	89.5	96.09	81.52
1766	64	2026-04-03	94.58	80.9	96.54	73.87
1767	64	2026-04-02	94.58	93.6	98.29	87.02
1768	64	2026-04-01	92.08	80.7	97.4	72.38
1769	64	2026-03-31	93.54	96.9	96.18	87.18
1770	64	2026-03-30	95.63	80.8	97.15	75.07
1771	65	2026-04-28	96.46	88.5	98.64	84.21
1772	65	2026-04-27	92.92	96.3	95.43	85.39
1773	65	2026-04-26	95	84.8	95.17	76.66
1774	65	2026-04-25	89.17	88.3	96.94	76.33
1775	65	2026-04-24	96.46	81.4	96.81	76.01
1776	65	2026-04-23	99.17	96.4	98.13	93.81
1777	65	2026-04-22	90.63	97.8	97.96	86.82
1778	65	2026-04-21	97.08	91.1	98.68	87.28
1779	65	2026-04-20	97.5	90.2	97.67	85.9
1780	65	2026-04-19	93.54	83	96.63	75.02
1781	65	2026-04-18	93.96	81.8	96.7	74.32
1782	65	2026-04-17	95.21	96.4	95.23	87.4
1783	65	2026-04-16	97.92	93.7	98.29	90.18
1784	65	2026-04-15	90	92	95.98	79.47
1785	65	2026-04-14	97.08	92.7	98.06	88.25
1786	65	2026-04-13	97.08	86.3	95.94	80.38
1787	65	2026-04-12	98.96	93.5	97.75	90.45
1788	65	2026-04-11	92.08	97.2	97.43	87.2
1789	65	2026-04-10	100	86.9	98.96	86
1790	65	2026-04-09	98.13	81.3	98.89	78.89
1791	65	2026-04-08	88.54	80.5	96.15	68.53
1792	65	2026-04-07	96.46	82.5	98.55	78.42
1793	65	2026-04-06	91.46	93.7	97.97	83.96
1794	65	2026-04-05	91.46	87.2	98.17	78.29
1795	65	2026-04-04	97.29	86.3	95.71	80.36
1796	65	2026-04-03	97.71	86.5	95.95	81.1
1797	65	2026-04-02	90.21	95	96.21	82.45
1798	65	2026-04-01	91.88	95.6	98.64	86.64
1799	65	2026-03-31	95.42	96.4	98.03	90.17
1800	65	2026-03-30	88.33	91.3	99.01	79.85
1801	66	2026-04-28	87.92	93.4	97.97	80.44
1802	66	2026-04-27	99.79	94.9	96.21	91.11
1803	66	2026-04-26	95.42	95.9	98.23	89.88
1804	66	2026-04-25	87.71	82.6	99.03	71.75
1805	66	2026-04-24	97.08	87.8	95.56	81.45
1806	66	2026-04-23	98.33	96	95.94	90.56
1807	66	2026-04-22	96.46	85.2	98.71	81.12
1808	66	2026-04-21	97.5	81.6	95.1	75.66
1809	66	2026-04-20	96.88	92.4	96.86	86.7
1810	66	2026-04-19	95.21	91.7	99.02	86.45
1811	66	2026-04-18	96.25	86.5	96.99	80.75
1812	66	2026-04-17	91.67	95.4	97.69	85.43
1813	66	2026-04-16	98.75	97.3	97.64	93.81
1814	66	2026-04-15	97.5	97.7	95.29	90.77
1815	66	2026-04-14	94.79	94.3	97.99	87.59
1816	66	2026-04-13	96.46	85.1	97.3	79.87
1817	66	2026-04-12	99.58	95.3	98.32	93.31
1818	66	2026-04-11	88.54	82.6	96.49	70.57
1819	66	2026-04-10	89.17	86.9	97.93	75.88
1820	66	2026-04-09	88.75	87.1	96.44	74.55
1821	66	2026-04-08	92.5	80.6	96.03	71.59
1822	66	2026-04-07	92.92	82.4	98.42	75.36
1823	66	2026-04-06	94.58	90.2	95.68	81.63
1824	66	2026-04-05	93.13	81.4	95.58	72.45
1825	66	2026-04-04	96.67	91.9	97.71	86.81
1826	66	2026-04-03	96.25	95.2	95.38	87.39
1827	66	2026-04-02	90.21	93.5	98.72	83.26
1828	66	2026-04-01	98.33	90.7	97.46	86.93
1829	66	2026-03-31	98.96	89.5	96.76	85.7
1830	66	2026-03-30	92.92	96.7	95.76	86.04
1831	67	2026-04-28	97.08	81.2	95.94	75.63
1832	67	2026-04-27	97.08	91.3	97.92	86.79
1833	67	2026-04-26	96.67	94.2	95.33	86.81
1834	67	2026-04-25	96.67	85.5	96.26	79.56
1835	67	2026-04-24	89.17	92.8	95.69	79.18
1836	67	2026-04-23	94.17	90.8	95.81	81.92
1837	67	2026-04-22	94.58	90.1	95.67	81.53
1838	67	2026-04-21	93.96	86.2	96.4	78.08
1839	67	2026-04-20	89.38	81.9	98.17	71.86
1840	67	2026-04-19	91.88	86.9	98.39	78.55
1841	67	2026-04-18	87.92	95.7	96.97	81.59
1842	67	2026-04-17	98.54	90.8	95.81	85.73
1843	67	2026-04-16	97.92	97.7	96.83	92.63
1844	67	2026-04-15	98.33	95.4	98.53	92.43
1845	67	2026-04-14	90.21	88.9	97.19	77.94
1846	67	2026-04-13	90.83	93	97.2	82.11
1847	67	2026-04-12	88.54	94.3	96.18	80.31
1848	67	2026-04-11	98.54	84.9	96.94	81.1
1849	67	2026-04-10	96.67	89.8	97.1	84.29
1850	67	2026-04-09	100	85.1	97.65	83.1
1851	67	2026-04-08	96.04	92.1	98.59	87.21
1852	67	2026-04-07	91.46	86.8	97	77.01
1853	67	2026-04-06	97.92	95.8	96.76	90.77
1854	67	2026-04-05	91.46	82	96.46	72.34
1855	67	2026-04-04	91.04	89.3	95.18	77.39
1856	67	2026-04-03	90.63	84.9	96.23	74.04
1857	67	2026-04-02	90.63	95.5	96.86	83.83
1858	67	2026-04-01	92.08	87.4	97.94	78.82
1859	67	2026-03-31	97.71	84.2	98.22	80.8
1860	67	2026-03-30	88.75	92.9	96.99	79.96
1861	68	2026-04-28	99.79	93.3	95.18	88.62
1862	68	2026-04-27	95	91.4	97.37	84.55
1863	68	2026-04-26	87.5	92.7	96.76	78.49
1864	68	2026-04-25	90.83	89.3	97.09	78.75
1865	68	2026-04-24	90.83	84.4	98.34	75.39
1866	68	2026-04-23	88.54	93.6	96.69	80.13
1867	68	2026-04-22	89.58	90.1	97.67	78.83
1868	68	2026-04-21	97.92	95.4	96.86	90.47
1869	68	2026-04-20	95.63	94.6	95.03	85.97
1870	68	2026-04-19	87.71	90.6	95.47	75.87
1871	68	2026-04-18	99.58	86.7	96.77	83.55
1872	68	2026-04-17	92.71	93.7	98.93	85.94
1873	68	2026-04-16	98.13	93.7	95.52	87.82
1874	68	2026-04-15	88.33	93.1	98.71	81.18
1875	68	2026-04-14	97.92	85.5	98.71	82.64
1876	68	2026-04-13	92.08	93	95.05	81.4
1877	68	2026-04-12	88.96	81.6	98.65	71.61
1878	68	2026-04-11	92.71	81.2	95.81	72.13
1879	68	2026-04-10	88.96	90.4	95.46	76.77
1880	68	2026-04-09	91.04	80.4	95.9	70.19
1881	68	2026-04-08	98.54	83.4	97.96	80.51
1882	68	2026-04-07	100	86.9	97.93	85.1
1883	68	2026-04-06	94.58	86.3	98.96	80.77
1884	68	2026-04-05	93.13	96.3	97.72	87.63
1885	68	2026-04-04	89.58	80.2	95.26	68.44
1886	68	2026-04-03	92.5	83.8	96.78	75.02
1887	68	2026-04-02	98.75	90.1	96	85.42
1888	68	2026-04-01	91.46	87.3	97.14	77.56
1889	68	2026-03-31	88.33	82.8	95.17	69.61
1890	68	2026-03-30	95	93.5	95.83	85.12
1891	69	2026-04-28	91.88	92.1	95.66	80.94
1892	69	2026-04-27	97.71	91.5	97.6	87.25
1893	69	2026-04-26	95	89.8	97.1	82.84
1894	69	2026-04-25	98.96	81.6	98.04	79.17
1895	69	2026-04-24	96.46	97.2	95.99	90
1896	69	2026-04-23	88.75	83.1	95.91	70.73
1897	69	2026-04-22	89.38	86.1	98.03	75.43
1898	69	2026-04-21	93.13	94.5	95.45	84
1899	69	2026-04-20	99.79	88.4	98.64	87.02
1900	69	2026-04-19	92.71	96.3	98.86	88.26
1901	69	2026-04-18	88.75	86	96.86	73.93
1902	69	2026-04-17	95.83	89.6	97.88	84.05
1903	69	2026-04-16	87.71	81.3	96.43	68.76
1904	69	2026-04-15	96.67	94.7	98.84	90.48
1905	69	2026-04-14	100	89	97.42	86.7
1906	69	2026-04-13	96.25	95.5	97.28	89.42
1907	69	2026-04-12	94.58	95.7	96.13	87.02
1908	69	2026-04-11	88.54	82	96.71	70.21
1909	69	2026-04-10	89.58	83.1	97.35	72.47
1910	69	2026-04-09	97.29	96.4	96.16	90.19
1911	69	2026-04-08	98.54	84.1	98.57	81.69
1912	69	2026-04-07	88.54	94.5	95.66	80.04
1913	69	2026-04-06	94.79	96.8	98.35	90.24
1914	69	2026-04-05	96.67	83.2	98.92	79.56
1915	69	2026-04-04	93.96	86.4	98.96	80.33
1916	69	2026-04-03	94.38	97.1	97.94	89.75
1917	69	2026-04-02	97.92	82.4	97.33	78.53
1918	69	2026-04-01	87.71	92.7	95.15	77.36
1919	69	2026-03-31	89.79	85.3	96.01	73.54
1920	69	2026-03-30	97.08	94.1	98.3	89.8
1921	70	2026-04-28	91.04	85.6	95.44	74.38
1922	70	2026-04-27	95.83	91.7	96.18	84.53
1923	70	2026-04-26	95.63	89	95.17	80.99
1924	70	2026-04-25	96.04	80.4	98.88	76.35
1925	70	2026-04-24	93.96	94.2	98.83	87.48
1926	70	2026-04-23	95.42	92.8	98.17	86.92
1927	70	2026-04-22	96.25	97	96.91	90.48
1928	70	2026-04-21	92.08	97.3	95.58	85.64
1929	70	2026-04-20	89.58	97.4	95.48	83.31
1930	70	2026-04-19	90.42	85.3	95.31	73.51
1931	70	2026-04-18	89.17	92	96.09	78.82
1932	70	2026-04-17	97.71	87.9	95.9	82.37
1933	70	2026-04-16	100	89.5	97.77	87.5
1934	70	2026-04-15	90	81.2	97.66	71.37
1935	70	2026-04-14	97.71	80.8	98.14	77.48
1936	70	2026-04-13	90.42	85.3	96.13	74.14
1937	70	2026-04-12	94.58	82.8	98.55	77.18
1938	70	2026-04-11	92.92	91.2	97.7	82.79
1939	70	2026-04-10	99.79	85	98.12	83.23
1940	70	2026-04-09	89.58	94.3	95.55	80.71
1941	70	2026-04-08	93.54	87.3	97.48	79.6
1942	70	2026-04-07	89.58	82.9	98.67	73.28
1943	70	2026-04-06	93.96	80.3	95.64	72.16
1944	70	2026-04-05	88.96	94	96.6	80.77
1945	70	2026-04-04	98.13	93.5	96.47	88.51
1946	70	2026-04-03	88.96	92.8	97.52	80.51
1947	70	2026-04-02	92.29	95.5	95.18	83.89
1948	70	2026-04-01	97.08	80.1	97.88	76.11
1949	70	2026-03-31	89.58	89.4	98.99	79.28
1950	70	2026-03-30	99.79	80.8	96.04	77.44
1951	71	2026-04-28	97.29	81.9	97.31	77.54
1952	71	2026-04-27	89.17	85.9	97.09	74.37
1953	71	2026-04-26	90.21	93.6	96.26	81.28
1954	71	2026-04-25	95	81	95.06	73.15
1955	71	2026-04-24	95.42	83.4	96.52	76.81
1956	71	2026-04-23	94.38	87.3	98.63	81.26
1957	71	2026-04-22	92.92	91.7	98.04	83.53
1958	71	2026-04-21	95.63	86.7	99.08	82.14
1959	71	2026-04-20	97.5	91.7	97.06	86.78
1960	71	2026-04-19	91.04	95.1	96	83.12
1961	71	2026-04-18	93.33	84	95.36	74.76
1962	71	2026-04-17	88.33	93.5	96.58	79.77
1963	71	2026-04-16	95.42	88.8	97.18	82.34
1964	71	2026-04-15	93.96	88.4	96.15	79.86
1965	71	2026-04-14	99.58	94.8	95.89	90.52
1966	71	2026-04-13	87.92	97.9	95.61	82.29
1967	71	2026-04-12	97.29	85.2	95.31	79
1968	71	2026-04-11	92.92	96.1	96.77	86.41
1969	71	2026-04-10	95.21	89.6	95.65	81.59
1970	71	2026-04-09	96.88	83.5	97.01	78.47
1971	71	2026-04-08	89.79	80.3	97.63	70.4
1972	71	2026-04-07	92.29	92.8	99.03	84.82
1973	71	2026-04-06	87.5	85.5	96.96	72.54
1974	71	2026-04-05	94.79	88.8	98.99	83.32
1975	71	2026-04-04	98.75	92.4	98.81	90.16
1976	71	2026-04-03	90.63	94.9	99.05	85.19
1977	71	2026-04-02	96.25	83.8	95.58	77.1
1978	71	2026-04-01	97.71	82	97.44	78.07
1979	71	2026-03-31	91.67	85.3	95.08	74.34
1980	71	2026-03-30	89.58	90.2	98	79.19
1981	72	2026-04-28	99.17	94.3	97.88	91.53
1982	72	2026-04-27	91.25	87.7	97.49	78.02
1983	72	2026-04-26	90	91.9	95.97	79.38
1984	72	2026-04-25	95.63	96.4	95.12	87.69
1985	72	2026-04-24	98.33	82.8	95.89	78.08
1986	72	2026-04-23	99.38	92.2	98.26	90.03
1987	72	2026-04-22	99.58	92.4	97.51	89.72
1988	72	2026-04-21	92.92	94.4	98.52	86.41
1989	72	2026-04-20	98.33	92	95.54	86.44
1990	72	2026-04-19	95.42	83.9	95.35	76.33
1991	72	2026-04-18	93.96	90.8	96.26	82.12
1992	72	2026-04-17	88.96	84	97.5	72.86
1993	72	2026-04-16	90.63	94.6	98.73	84.64
1994	72	2026-04-15	92.5	89.4	98.43	81.4
1995	72	2026-04-14	90	80.5	98.76	71.55
1996	72	2026-04-13	95.21	92.6	96.76	85.31
1997	72	2026-04-12	89.17	89.7	95.32	76.24
1998	72	2026-04-11	89.38	90.7	98.24	79.63
1999	72	2026-04-10	92.92	84	95.48	74.52
2000	72	2026-04-09	89.58	94.4	95.76	80.98
2001	72	2026-04-08	93.13	81.3	96.56	73.1
2002	72	2026-04-07	90.21	97.7	95.8	84.43
2003	72	2026-04-06	95.83	86.7	98.5	81.84
2004	72	2026-04-05	93.75	80.7	95.29	72.09
2005	72	2026-04-04	92.71	90.5	96.02	80.56
2006	72	2026-04-03	88.33	92.2	98.92	80.56
2007	72	2026-04-02	88.33	89.1	98.88	77.82
2008	72	2026-04-01	98.96	90.7	97.79	87.78
2009	72	2026-03-31	88.54	89	97.64	76.94
2010	72	2026-03-30	100	89.7	95.32	85.5
2011	73	2026-04-28	88.75	83	98.67	72.69
2012	73	2026-04-27	95.63	87.2	97.36	81.19
2013	73	2026-04-26	90.21	93.4	96.47	81.28
2014	73	2026-04-25	98.33	82.9	97.47	79.45
2015	73	2026-04-24	99.38	89.7	97.21	86.65
2016	73	2026-04-23	92.5	93.5	95.83	82.88
2017	73	2026-04-22	87.92	92	99.02	80.09
2018	73	2026-04-21	91.67	80.4	98.88	72.87
2019	73	2026-04-20	92.5	86.9	97.58	78.44
2020	73	2026-04-19	88.13	93.7	96.58	79.75
2021	73	2026-04-18	94.17	94	98.62	87.29
2022	73	2026-04-17	96.67	89.8	97.77	84.87
2023	73	2026-04-16	94.79	88.8	98.65	83.04
2024	73	2026-04-15	95	80.8	98.39	75.53
2025	73	2026-04-14	91.25	91.4	96.06	80.12
2026	73	2026-04-13	97.29	83.1	96.99	78.42
2027	73	2026-04-12	100	86.7	96.42	83.6
2028	73	2026-04-11	98.33	95.8	95.72	90.17
2029	73	2026-04-10	91.88	97.5	97.85	87.65
2030	73	2026-04-09	98.13	93.7	97.76	89.88
2031	73	2026-04-08	88.33	96.4	95.85	81.62
2032	73	2026-04-07	93.54	80.3	96.14	72.21
2033	73	2026-04-06	100	88.1	98.64	86.9
2034	73	2026-04-05	96.67	88.4	95.36	81.49
2035	73	2026-04-04	88.75	97.1	96.81	83.42
2036	73	2026-04-03	94.17	84.4	97.27	77.31
2037	73	2026-04-02	94.17	90.3	98.45	83.71
2038	73	2026-04-01	97.92	88.6	96.05	83.33
2039	73	2026-03-31	93.75	86.4	96.06	77.81
2040	73	2026-03-30	91.25	83	96.51	73.09
2041	74	2026-04-28	99.58	88.8	96.17	85.04
2042	74	2026-04-27	97.92	85.5	96.61	80.88
2043	74	2026-04-26	91.04	81.8	97.07	72.29
2044	74	2026-04-25	93.13	95	96.74	85.58
2045	74	2026-04-24	88.75	95.6	96.55	81.92
2046	74	2026-04-23	94.38	83.2	98.68	77.48
2047	74	2026-04-22	99.38	97.7	95.6	92.82
2048	74	2026-04-21	89.58	81.3	97.05	70.68
2049	74	2026-04-20	87.92	85.5	96.96	72.88
2050	74	2026-04-19	90.83	92	96.41	80.57
2051	74	2026-04-18	91.46	86.9	95.28	75.73
2052	74	2026-04-17	95.21	81.7	98.16	76.36
2053	74	2026-04-16	92.5	95.6	96.86	85.65
2054	74	2026-04-15	94.38	88.5	96.05	80.22
2055	74	2026-04-14	93.33	86.2	98.14	78.96
2056	74	2026-04-13	91.88	85.6	98.48	77.45
2057	74	2026-04-12	90.63	84.5	95.62	73.22
2058	74	2026-04-11	92.71	85.3	98.59	77.97
2059	74	2026-04-10	99.79	80.5	96.65	77.64
2060	74	2026-04-09	99.17	90.1	98.78	88.26
2061	74	2026-04-08	93.13	91	98.13	83.16
2062	74	2026-04-07	88.33	83.6	95.81	70.75
2063	74	2026-04-06	98.33	86.1	96.63	81.81
2064	74	2026-04-05	87.92	86.1	95.12	72
2065	74	2026-04-04	94.58	91.1	97.69	84.18
2066	74	2026-04-03	88.75	87.8	98.41	76.68
2067	74	2026-04-02	90.42	83	97.23	72.97
2068	74	2026-04-01	94.38	87.1	98.74	81.16
2069	74	2026-03-31	99.79	86.6	97.23	84.02
2070	74	2026-03-30	94.58	87.5	96.11	79.54
2071	75	2026-04-28	92.71	86.6	97.58	78.34
2072	75	2026-04-27	95.42	81.6	96.2	74.9
2073	75	2026-04-26	95.21	81.1	96.42	74.45
2074	75	2026-04-25	91.04	80	98.88	72.01
2075	75	2026-04-24	93.13	85.2	97.54	77.39
2076	75	2026-04-23	92.29	95.8	96.87	85.65
2077	75	2026-04-22	90.42	88.5	95.25	76.22
2078	75	2026-04-21	88.54	94.2	95.44	79.6
2079	75	2026-04-20	89.58	94.4	96.5	81.61
2080	75	2026-04-19	88.96	92.2	97.18	79.71
2081	75	2026-04-18	96.46	91.8	95.64	84.69
2082	75	2026-04-17	87.92	88.8	95.27	74.38
2083	75	2026-04-16	98.13	90.6	97.35	86.55
2084	75	2026-04-15	88.54	93	97.31	80.13
2085	75	2026-04-14	96.88	93.5	98.5	89.22
2086	75	2026-04-13	94.17	87.4	95.19	78.35
2087	75	2026-04-12	93.33	82.5	95.76	73.73
2088	75	2026-04-11	93.54	87.4	97.6	79.79
2089	75	2026-04-10	90.63	92.1	98.81	82.47
2090	75	2026-04-09	89.17	85.3	96.48	73.38
2091	75	2026-04-08	99.58	87.3	95.19	82.75
2092	75	2026-04-07	91.04	83.1	95.91	72.56
2093	75	2026-04-06	88.13	89.1	96.86	76.05
2094	75	2026-04-05	91.25	83.2	96.51	73.27
2095	75	2026-04-04	92.29	97.4	95.17	85.55
2096	75	2026-04-03	99.17	87.2	97.71	84.49
2097	75	2026-04-02	98.54	96.3	99.07	94.01
2098	75	2026-04-01	91.25	82.1	97.81	73.27
2099	75	2026-03-31	98.75	97.2	98.56	94.6
2100	75	2026-03-30	90.42	83.7	95.82	72.51
2101	76	2026-04-28	97.29	86.4	96.64	81.24
2102	76	2026-04-27	93.75	85.2	98	78.28
2103	76	2026-04-26	93.13	83.6	96.41	75.06
2104	76	2026-04-25	95.63	97.7	97.75	91.32
2105	76	2026-04-24	91.25	86.7	95.39	75.46
2106	76	2026-04-23	95	93	95.27	84.17
2107	76	2026-04-22	99.79	89.4	98.55	87.92
2108	76	2026-04-21	95.63	94.2	98.2	88.45
2109	76	2026-04-20	87.71	96.6	96.69	81.92
2110	76	2026-04-19	93.13	88	95.11	77.95
2111	76	2026-04-18	99.58	87.7	98.75	86.24
2112	76	2026-04-17	97.5	87.1	98.28	83.46
2113	76	2026-04-16	91.67	82.2	97.32	73.33
2114	76	2026-04-15	98.96	88.5	95.82	83.92
2115	76	2026-04-14	94.58	82.6	98.55	76.99
2116	76	2026-04-13	95	89.6	97.21	82.75
2117	76	2026-04-12	95.21	84.1	97.38	77.98
2118	76	2026-04-11	88.13	80.4	98.13	69.53
2119	76	2026-04-10	93.75	82.3	95.75	73.88
2120	76	2026-04-09	88.33	82.2	96.96	70.4
2121	76	2026-04-08	90.21	82	96.71	71.54
2122	76	2026-04-07	93.96	93.9	95.95	84.66
2123	76	2026-04-06	95.63	91.5	96.17	84.15
2124	76	2026-04-05	91.88	97.7	97.85	87.83
2125	76	2026-04-04	94.38	90.1	95.23	80.97
2126	76	2026-04-03	96.67	86.1	98.84	82.26
2127	76	2026-04-02	98.13	97.2	95.88	91.45
2128	76	2026-04-01	90.42	95.8	98.02	84.9
2129	76	2026-03-31	96.88	81.4	95.82	75.56
2130	76	2026-03-30	94.38	93	97.74	85.79
2131	77	2026-04-28	98.54	85.1	95.89	80.41
2132	77	2026-04-27	90.42	90.5	96.69	79.11
2133	77	2026-04-26	92.29	83.6	97.37	75.13
2134	77	2026-04-25	93.33	87.2	95.76	77.93
2135	77	2026-04-24	98.54	97.1	97.84	93.61
2136	77	2026-04-23	98.54	92.2	98.05	89.08
2137	77	2026-04-22	93.96	89.4	97.76	82.12
2138	77	2026-04-21	88.54	97.9	95.1	82.43
2139	77	2026-04-20	94.38	83.4	95.68	75.31
2140	77	2026-04-19	92.5	80.4	96.27	71.59
2141	77	2026-04-18	90.21	95.7	96.87	83.62
2142	77	2026-04-17	95.83	80.9	96.91	75.13
2143	77	2026-04-16	87.92	90.1	96.45	76.4
2144	77	2026-04-15	95.63	85.8	96.74	79.37
2145	77	2026-04-14	98.54	96.9	96.39	92.04
2146	77	2026-04-13	97.71	95.8	95.41	89.31
2147	77	2026-04-12	92.5	94.4	97.78	85.38
2148	77	2026-04-11	93.75	88.5	97.06	80.53
2149	77	2026-04-10	96.25	96.6	98.96	92.02
2150	77	2026-04-09	88.75	89	97.64	77.12
2151	77	2026-04-08	89.79	80.2	97.38	70.13
2152	77	2026-04-07	96.04	91.1	95.83	83.84
2153	77	2026-04-06	87.71	80.2	97.88	68.85
2154	77	2026-04-05	88.75	82.6	96.85	71
2155	77	2026-04-04	88.96	93	97.85	80.95
2156	77	2026-04-03	98.96	94.3	97.24	90.74
2157	77	2026-04-02	87.5	91.5	97.05	77.7
2158	77	2026-04-01	94.58	89.8	95.77	81.34
2159	77	2026-03-31	93.13	91	95.6	81.02
2160	77	2026-03-30	90	88	97.05	76.86
2161	78	2026-04-28	97.29	82.6	99.03	79.58
2162	78	2026-04-27	91.25	82.7	97.94	73.91
2163	78	2026-04-26	98.13	89.8	95.21	83.9
2164	78	2026-04-25	91.67	88	95.91	77.37
2165	78	2026-04-24	91.46	96	98.54	86.52
2166	78	2026-04-23	95	92.5	98.49	86.54
2167	78	2026-04-22	94.79	87.8	96.01	79.91
2168	78	2026-04-21	91.46	80.4	95.27	70.06
2169	78	2026-04-20	92.71	86.2	96.52	77.13
2170	78	2026-04-19	98.96	80.3	97.63	77.58
2171	78	2026-04-18	96.67	97.9	97.24	92.03
2172	78	2026-04-17	96.04	83.5	98.68	79.14
2173	78	2026-04-16	90.63	89	98.76	79.66
2174	78	2026-04-15	93.13	81.3	95.33	72.17
2175	78	2026-04-14	90.63	89.6	95.76	77.76
2176	78	2026-04-13	89.38	90.8	98.02	79.54
2177	78	2026-04-12	97.08	97.8	97.85	92.91
2178	78	2026-04-11	99.17	96.8	96.8	92.92
2179	78	2026-04-10	92.71	92.4	96.54	82.7
2180	78	2026-04-09	97.29	96.6	95.96	90.19
2181	78	2026-04-08	90	96.3	96.47	83.61
2182	78	2026-04-07	89.79	89.2	97.65	78.21
2183	78	2026-04-06	90.21	88.2	96.03	76.41
2184	78	2026-04-05	99.58	85.9	98.14	83.95
2185	78	2026-04-04	94.58	80.3	99	75.19
2186	78	2026-04-03	99.38	90.4	97.57	87.65
2187	78	2026-04-02	95.63	97.7	98.46	91.99
2188	78	2026-04-01	99.38	80.2	96.51	76.92
2189	78	2026-03-31	99.58	93.4	97.11	90.32
2190	78	2026-03-30	95.21	89.4	98.21	83.59
2191	79	2026-04-28	95.21	92.1	97.72	85.69
2192	79	2026-04-27	98.33	96.3	98.34	93.12
2193	79	2026-04-26	94.58	81.8	96.7	74.82
2194	79	2026-04-25	87.71	89.1	97.64	76.31
2195	79	2026-04-24	91.25	86.2	96.98	76.28
2196	79	2026-04-23	99.79	92.3	96.97	89.31
2197	79	2026-04-22	99.38	86.3	97.22	83.38
2198	79	2026-04-21	92.5	84.3	98.1	76.5
2199	79	2026-04-20	88.54	82.3	98.18	71.54
2200	79	2026-04-19	96.88	81.4	97.05	76.53
2201	79	2026-04-18	89.58	95	95.47	81.25
2202	79	2026-04-17	95	82.4	97.33	76.19
2203	79	2026-04-16	94.38	81.5	97.18	74.75
2204	79	2026-04-15	94.17	88.2	95.12	79.01
2205	79	2026-04-14	89.58	94	95.64	80.54
2206	79	2026-04-13	87.92	86.5	98.27	74.73
2207	79	2026-04-12	93.13	80.3	98.88	73.94
2208	79	2026-04-11	88.75	89	96.07	75.88
2209	79	2026-04-10	91.04	86.9	97.24	76.93
2210	79	2026-04-09	92.5	90.8	98.68	82.88
2211	79	2026-04-08	92.5	95.8	97.49	86.39
2212	79	2026-04-07	97.71	80.6	96.15	75.72
2213	79	2026-04-06	90.83	85.9	97.32	75.94
2214	79	2026-04-05	98.13	85.2	96.24	80.46
2215	79	2026-04-04	97.08	83.3	98.92	80
2216	79	2026-04-03	95	81.2	97.66	75.33
2217	79	2026-04-02	92.92	97.5	95.49	86.51
2218	79	2026-04-01	91.46	84.3	97.03	74.81
2219	79	2026-03-31	95	92.2	95.12	83.31
2220	79	2026-03-30	88.13	85.3	95.9	72.09
2221	80	2026-04-28	92.08	96.7	95.86	85.36
2222	80	2026-04-27	88.54	89.9	97	77.21
2223	80	2026-04-26	95.42	93.5	97.22	86.73
2224	80	2026-04-25	97.29	81.6	95.1	75.5
2225	80	2026-04-24	98.33	85.3	95.43	80.04
2226	80	2026-04-23	91.88	86.1	97.1	76.81
2227	80	2026-04-22	91.25	82.7	98.43	74.28
2228	80	2026-04-21	90.63	84.8	95.4	73.32
2229	80	2026-04-20	93.13	93.4	95.93	83.44
2230	80	2026-04-19	96.25	83.8	99.05	79.89
2231	80	2026-04-18	92.71	85.6	98.25	77.97
2232	80	2026-04-17	91.25	81.1	98.64	73
2233	80	2026-04-16	96.25	88.7	95.83	81.81
2234	80	2026-04-15	94.79	83.8	96.9	76.97
2235	80	2026-04-14	91.04	83.9	98.69	75.38
2236	80	2026-04-13	97.5	82.9	95.78	77.42
2237	80	2026-04-12	90.83	90.6	98.12	80.75
2238	80	2026-04-11	90.83	85	97.76	75.48
2239	80	2026-04-10	97.08	84	97.62	79.61
2240	80	2026-04-09	98.33	87.8	98.29	84.86
2241	80	2026-04-08	91.46	88.9	98.2	79.84
2242	80	2026-04-07	97.08	90.6	97.46	85.72
2243	80	2026-04-06	92.71	81.5	96.69	73.05
2244	80	2026-04-05	88.13	89.6	97.99	77.37
2245	80	2026-04-04	88.13	93.1	96.13	78.87
2246	80	2026-04-03	92.5	83.8	98.21	76.13
2247	80	2026-04-02	93.75	84.5	96.45	76.41
2248	80	2026-04-01	97.29	95.7	95.82	89.22
2249	80	2026-03-31	91.04	84.6	98.7	76.02
2250	80	2026-03-30	98.54	82.5	96.48	78.44
2251	81	2026-04-28	100	88.5	97.29	86.1
2252	81	2026-04-27	98.96	86.1	95.47	81.34
2253	81	2026-04-26	97.08	87.8	98.86	84.27
2254	81	2026-04-25	90.83	91	96.37	79.66
2255	81	2026-04-24	93.75	90.7	97.57	82.97
2256	81	2026-04-23	96.25	82.2	95.38	75.46
2257	81	2026-04-22	91.88	94.9	95.26	83.06
2258	81	2026-04-21	93.13	94.6	95.67	84.28
2259	81	2026-04-20	96.04	81.7	98.53	77.31
2260	81	2026-04-19	94.17	91.5	97.27	83.81
2261	81	2026-04-18	96.25	80.1	97.38	75.08
2262	81	2026-04-17	96.25	82.3	96.23	76.23
2263	81	2026-04-16	87.5	93.1	96.99	79.01
2264	81	2026-04-15	88.75	82	95.73	69.67
2265	81	2026-04-14	94.38	87.4	98.63	81.35
2266	81	2026-04-13	97.29	85.8	95.57	79.78
2267	81	2026-04-12	92.92	96.8	98.66	88.74
2268	81	2026-04-11	98.33	87.3	96.33	82.7
2269	81	2026-04-10	99.79	85.6	96.73	82.63
2270	81	2026-04-09	93.33	83.4	98.92	77
2271	81	2026-04-08	89.79	80.5	97.52	70.49
2272	81	2026-04-07	88.96	90.8	96.92	78.28
2273	81	2026-04-06	99.79	96.4	97.93	94.2
2274	81	2026-04-05	91.25	84.6	96.45	74.46
2275	81	2026-04-04	91.88	90.1	97.45	80.67
2276	81	2026-04-03	94.17	96.8	96.59	88.05
2277	81	2026-04-02	94.38	96.8	98.66	90.13
2278	81	2026-04-01	92.08	86.7	97.69	77.99
2279	81	2026-03-31	89.79	86.1	98.26	75.96
2280	81	2026-03-30	91.88	97.2	97.22	86.82
2281	82	2026-04-28	93.96	87.9	95.56	78.92
2282	82	2026-04-27	90.42	86.6	96.19	75.32
2283	82	2026-04-26	98.96	91.7	98.58	89.46
2284	82	2026-04-25	88.96	89.9	98.55	78.82
2285	82	2026-04-24	94.38	81.6	96.32	74.18
2286	82	2026-04-23	95.83	88.3	96.49	81.65
2287	82	2026-04-22	88.75	85	97.06	73.22
2288	82	2026-04-21	99.79	83.5	95.33	79.43
2289	82	2026-04-20	87.5	82.3	97.08	69.91
2290	82	2026-04-19	89.17	83.2	98.44	73.03
2291	82	2026-04-18	88.96	92.2	95.34	78.19
2292	82	2026-04-17	91.04	88.4	98.64	79.39
2293	82	2026-04-16	99.38	91.1	97.8	88.54
2294	82	2026-04-15	90	92.6	98.38	81.99
2295	82	2026-04-14	90.63	82.6	96.49	72.23
2296	82	2026-04-13	91.46	96.8	97.73	86.52
2297	82	2026-04-12	98.96	86.5	97.92	83.82
2298	82	2026-04-11	99.38	91.9	98.48	89.93
2299	82	2026-04-10	88.13	95.5	96.13	80.9
2300	82	2026-04-09	95.21	93.9	96.27	86.07
2301	82	2026-04-08	91.88	96.4	95.54	84.62
2302	82	2026-04-07	93.75	89.6	96.43	81
2303	82	2026-04-06	91.46	83.7	95.34	72.98
2304	82	2026-04-05	89.58	88.4	97.85	77.49
2305	82	2026-04-04	94.38	86.5	96.3	78.61
2306	82	2026-04-03	97.08	80	96.75	75.14
2307	82	2026-04-02	91.04	97.7	96.42	85.76
2308	82	2026-04-01	96.04	94.9	96.94	88.36
2309	82	2026-03-31	93.96	85.1	95.77	76.58
2310	82	2026-03-30	87.5	80.3	98.13	68.95
2311	83	2026-04-28	92.5	86.3	96.41	76.96
2312	83	2026-04-27	95.63	86.5	98.96	81.86
2313	83	2026-04-26	93.33	95.4	97.27	86.61
2314	83	2026-04-25	87.71	89.7	96.77	76.13
2315	83	2026-04-24	92.71	95.4	97.17	85.94
2316	83	2026-04-23	89.38	96.6	95.55	82.49
2317	83	2026-04-22	91.88	93.5	98.72	84.8
2318	83	2026-04-21	95.42	95.1	96.53	87.59
2319	83	2026-04-20	96.46	80.4	97.39	75.53
2320	83	2026-04-19	92.92	83.1	95.19	73.5
2321	83	2026-04-18	89.58	94.7	95.56	81.07
2322	83	2026-04-17	92.5	94.4	95.13	83.06
2323	83	2026-04-16	87.71	80.9	98.15	69.64
2324	83	2026-04-15	95.83	95.9	98.75	90.75
2325	83	2026-04-14	98.75	85.2	98.36	82.75
2326	83	2026-04-13	95.42	96.9	98.97	91.5
2327	83	2026-04-12	90.21	90.7	95.81	78.39
2328	83	2026-04-11	92.92	83.6	97.01	75.36
2329	83	2026-04-10	89.79	80.3	97.63	70.4
2330	83	2026-04-09	96.46	84.8	98.94	80.93
2331	83	2026-04-08	99.17	90.4	98.23	88.06
2332	83	2026-04-07	99.38	88.7	96.62	85.16
2333	83	2026-04-06	95.42	80	96.88	73.95
2334	83	2026-04-05	93.33	94.4	97.88	86.24
2335	83	2026-04-04	95.63	94.4	97.03	87.59
2336	83	2026-04-03	91.88	97	96.19	85.72
2337	83	2026-04-02	89.17	97.6	97.44	84.8
2338	83	2026-04-01	92.5	89.8	98.89	82.14
2339	83	2026-03-31	94.79	87	96.32	79.44
2340	83	2026-03-30	98.33	89.5	95.2	83.78
2341	84	2026-04-28	97.71	97.9	96.22	92.04
2342	84	2026-04-27	87.5	87.7	97.83	75.08
2343	84	2026-04-26	98.75	82.7	96.37	78.7
2344	84	2026-04-25	91.04	89.2	97.42	79.12
2345	84	2026-04-24	95.63	86.1	97.21	80.04
2346	84	2026-04-23	88.75	81	96.17	69.14
2347	84	2026-04-22	97.08	82.6	97.7	78.35
2348	84	2026-04-21	90.63	80.5	97.14	70.87
2349	84	2026-04-20	87.5	93.4	95.82	78.31
2350	84	2026-04-19	88.75	89.5	98.88	78.54
2351	84	2026-04-18	96.67	97.5	97.54	91.93
2352	84	2026-04-17	96.67	80.4	98.88	76.85
2353	84	2026-04-16	88.33	84.6	97.04	72.52
2354	84	2026-04-15	87.71	82.1	96.83	69.73
2355	84	2026-04-14	98.33	96.4	98.65	93.52
2356	84	2026-04-13	98.54	85.5	98.95	83.37
2357	84	2026-04-12	92.5	80.5	96.02	71.5
2358	84	2026-04-11	92.5	95.1	95.69	84.17
2359	84	2026-04-10	99.17	82.4	98.67	80.62
2360	84	2026-04-09	94.58	90.7	96.8	83.04
2361	84	2026-04-08	88.96	81.4	96.68	70.01
2362	84	2026-04-07	93.54	96.7	95.97	86.81
2363	84	2026-04-06	89.38	85.3	96.01	73.2
2364	84	2026-04-05	93.13	84	95.12	74.41
2365	84	2026-04-04	90.42	80.1	97	70.25
2366	84	2026-04-03	95.21	97.1	95.67	88.45
2367	84	2026-04-02	98.33	92.4	95.67	86.93
2368	84	2026-04-01	89.79	86.3	98.73	76.5
2369	84	2026-03-31	94.38	85.6	96.5	77.95
2370	84	2026-03-30	97.08	96.1	97.81	91.26
2371	85	2026-04-28	91.04	80.5	97.14	71.19
2372	85	2026-04-27	88.75	94.1	96.92	80.94
2373	85	2026-04-26	87.71	93.9	95.85	78.94
2374	85	2026-04-25	92.71	83.4	98.56	76.21
2375	85	2026-04-24	99.79	92.4	95.24	87.82
2376	85	2026-04-23	95.83	94	97.34	87.69
2377	85	2026-04-22	92.08	80.6	96.03	71.27
2378	85	2026-04-21	90.42	83.1	95.43	71.7
2379	85	2026-04-20	94.38	86.5	95.84	78.24
2380	85	2026-04-19	92.71	94.9	96.52	84.92
2381	85	2026-04-18	93.75	92.5	98.81	85.69
2382	85	2026-04-17	95	82.4	96	75.14
2383	85	2026-04-16	100	84.6	96.81	81.9
2384	85	2026-04-15	95.42	85.3	99.06	80.63
2385	85	2026-04-14	92.29	90.6	98.9	82.69
2386	85	2026-04-13	95.21	85.8	96.85	79.12
2387	85	2026-04-12	91.25	91.4	97.16	81.03
2388	85	2026-04-11	97.92	84.2	97.62	80.49
2389	85	2026-04-10	91.46	85	96	74.63
2390	85	2026-04-09	88.13	86.4	98.73	75.17
2391	85	2026-04-08	94.17	92.9	98.82	86.45
2392	85	2026-04-07	97.08	94.4	95.87	87.86
2393	85	2026-04-06	98.33	86.1	95.82	81.12
2394	85	2026-04-05	98.54	90.1	98.67	87.6
2395	85	2026-04-04	91.67	88.4	97.51	79.02
2396	85	2026-04-03	94.79	89.1	96.63	81.62
2397	85	2026-04-02	98.75	97.8	98.67	95.29
2398	85	2026-04-01	97.08	82.2	96.59	77.08
2399	85	2026-03-31	92.71	91.3	98.47	83.34
2400	85	2026-03-30	88.75	88.4	98.08	76.95
2401	86	2026-04-28	94.79	96.2	98.34	89.67
2402	86	2026-04-27	87.92	90.3	97.23	77.19
2403	86	2026-04-26	91.46	91.6	98.25	82.31
2404	86	2026-04-25	90.83	89.5	96.76	78.66
2405	86	2026-04-24	89.38	91	98.02	79.72
2406	86	2026-04-23	90.21	81.7	98.29	72.44
2407	86	2026-04-22	90.42	91.8	96.51	80.11
2408	86	2026-04-21	89.38	92	98.26	80.8
2409	86	2026-04-20	91.46	84.6	98.11	75.91
2410	86	2026-04-19	95.63	84.7	96.46	78.13
2411	86	2026-04-18	97.29	80.5	98.01	76.76
2412	86	2026-04-17	92.08	87.4	97.94	78.82
2413	86	2026-04-16	94.79	89	97.19	81.99
2414	86	2026-04-15	96.88	89.9	98.78	86.02
2415	86	2026-04-14	87.5	80.7	97.65	68.95
2416	86	2026-04-13	88.96	96.2	98.13	83.98
2417	86	2026-04-12	99.38	87	98.16	84.87
2418	86	2026-04-11	95	92.5	96.54	84.84
2419	86	2026-04-10	88.96	93.6	97.76	81.4
2420	86	2026-04-09	95.42	91.1	97.04	84.35
2421	86	2026-04-08	87.71	96.5	98.86	83.67
2422	86	2026-04-07	97.71	90.9	98.9	87.84
2423	86	2026-04-06	91.25	83.8	98.69	75.46
2424	86	2026-04-05	94.58	95.1	95.27	85.69
2425	86	2026-04-04	98.54	96.8	97.93	93.42
2426	86	2026-04-03	97.71	86.5	97.34	82.27
2427	86	2026-04-02	97.5	92.7	95.36	86.19
2428	86	2026-04-01	96.04	81.9	96.21	75.68
2429	86	2026-03-31	98.75	92.7	95.79	87.69
2430	86	2026-03-30	89.79	95.5	95.5	81.89
2431	87	2026-04-28	96.46	94	98.62	89.42
2432	87	2026-04-27	92.29	93.2	97.53	83.89
2433	87	2026-04-26	95	97.6	96.11	89.11
2434	87	2026-04-25	95.63	85	96.94	78.8
2435	87	2026-04-24	96.46	93.9	96.49	87.39
2436	87	2026-04-23	88.54	86.3	97.91	74.82
2437	87	2026-04-22	89.79	91.2	96.38	78.93
2438	87	2026-04-21	89.58	85.6	98.25	75.34
2439	87	2026-04-20	97.92	84	97.38	80.1
2440	87	2026-04-19	91.25	80.7	96.03	70.72
2441	87	2026-04-18	88.13	81	97.16	69.35
2442	87	2026-04-17	91.04	84.7	97.76	75.38
2443	87	2026-04-16	93.54	96.6	96.58	87.27
2444	87	2026-04-15	98.75	93	98.49	90.46
2445	87	2026-04-14	94.79	92.7	97.3	85.5
2446	87	2026-04-13	98.96	97.4	98.36	94.8
2447	87	2026-04-12	91.25	90.3	96.35	79.39
2448	87	2026-04-11	98.54	84.6	97.87	81.59
2449	87	2026-04-10	99.79	80.2	98.5	78.84
2450	87	2026-04-09	99.79	97.8	95.3	93.01
2451	87	2026-04-08	96.88	91.8	95.32	84.77
2452	87	2026-04-07	87.5	88.9	98.76	76.82
2453	87	2026-04-06	98.96	85.8	98.83	83.92
2454	87	2026-04-05	97.71	92.4	97.73	88.23
2455	87	2026-04-04	89.38	87.1	97.82	76.15
2456	87	2026-04-03	91.25	85.1	98.24	76.28
2457	87	2026-04-02	92.92	80	98.5	73.22
2458	87	2026-04-01	88.33	94.2	98.09	81.62
2459	87	2026-03-31	95.21	96.6	98.96	91.02
2460	87	2026-03-30	90	88.8	96.17	76.86
2461	88	2026-04-28	99.38	91.7	97.06	88.44
2462	88	2026-04-27	97.71	91.5	96.07	85.89
2463	88	2026-04-26	98.33	93.9	98.3	90.76
2464	88	2026-04-25	92.92	91.7	96.29	82.05
2465	88	2026-04-24	97.29	96.9	96.59	91.06
2466	88	2026-04-23	87.71	90.1	97	76.66
2467	88	2026-04-22	97.08	81.8	95.6	75.92
2468	88	2026-04-21	92.5	95.5	95.08	83.99
2469	88	2026-04-20	93.54	96.4	97.1	87.55
2470	88	2026-04-19	90.83	80.8	96.78	71.03
2471	88	2026-04-18	89.58	80.7	96.53	69.79
2472	88	2026-04-17	98.96	94.2	98.51	91.83
2473	88	2026-04-16	92.08	83.3	98.32	75.42
2474	88	2026-04-15	94.58	81.2	97.04	74.53
2475	88	2026-04-14	96.88	80.3	99	77.02
2476	88	2026-04-13	87.71	92.3	97.18	78.67
2477	88	2026-04-12	92.92	97.3	96.81	87.53
2478	88	2026-04-11	95.63	89.7	98.77	84.72
2479	88	2026-04-10	93.75	92.5	98.49	85.41
2480	88	2026-04-09	89.58	84.7	96.81	73.46
2481	88	2026-04-08	94.17	94.5	98.31	87.48
2482	88	2026-04-07	92.5	90.8	96.48	81.03
2483	88	2026-04-06	99.58	93.2	98.82	91.72
2484	88	2026-04-05	89.79	91.4	97.92	80.36
2485	88	2026-04-04	91.67	81.5	95.21	71.13
2486	88	2026-04-03	92.92	88.9	95.95	79.26
2487	88	2026-04-02	97.29	93	96.67	87.47
2488	88	2026-04-01	89.58	96.2	98.23	84.66
2489	88	2026-03-31	87.92	90.9	95.27	76.14
2490	88	2026-03-30	92.08	89.8	98.89	81.77
2491	89	2026-04-28	89.17	80.2	97.51	69.73
2492	89	2026-04-27	87.92	81.4	96.56	69.1
2493	89	2026-04-26	98.54	85	98	82.09
2494	89	2026-04-25	98.13	82.6	97.22	78.79
2495	89	2026-04-24	96.04	92.8	96.66	86.15
2496	89	2026-04-23	91.25	95.7	98.33	85.87
2497	89	2026-04-22	97.08	93.4	98.29	89.12
2498	89	2026-04-21	91.46	81.2	97.29	72.25
2499	89	2026-04-20	90	85	96.82	74.07
2500	89	2026-04-19	90.63	81.4	95.82	70.69
2501	89	2026-04-18	89.38	85.7	97.32	74.54
2502	89	2026-04-17	99.38	88.7	96.28	84.87
2503	89	2026-04-16	94.79	82.2	97.69	76.12
2504	89	2026-04-15	95.21	89.3	96.3	81.88
2505	89	2026-04-14	97.08	84.2	96.2	78.64
2506	89	2026-04-13	89.17	86.6	97.69	75.44
2507	89	2026-04-12	92.71	81.7	98.78	74.82
2508	89	2026-04-11	96.25	95.4	96.23	88.36
2509	89	2026-04-10	97.29	96.5	95.75	89.9
2510	89	2026-04-09	89.38	84.8	96.7	73.29
2511	89	2026-04-08	90.63	92.3	97.51	81.56
2512	89	2026-04-07	91.25	82	96.95	72.54
2513	89	2026-04-06	88.75	89.4	98.55	78.19
2514	89	2026-04-05	97.29	82.7	96.25	77.44
2515	89	2026-04-04	89.17	86	97.33	74.63
2516	89	2026-04-03	88.13	85.9	98.49	74.55
2517	89	2026-04-02	91.25	93.4	98.39	83.86
2518	89	2026-04-01	93.13	84.8	97.17	76.73
2519	89	2026-03-31	94.17	83.5	96.53	75.9
2520	89	2026-03-30	95.63	84.8	97.05	78.7
2521	90	2026-04-28	94.79	94.2	96.71	86.36
2522	90	2026-04-27	100	80.8	96.04	77.6
2523	90	2026-04-26	91.67	87.7	98.97	79.57
2524	90	2026-04-25	88.75	81.7	96.45	69.93
2525	90	2026-04-24	93.96	92.9	96.12	83.9
2526	90	2026-04-23	92.29	87.3	98.85	79.65
2527	90	2026-04-22	94.17	94.9	98	87.58
2528	90	2026-04-21	99.38	96	97.92	93.41
2529	90	2026-04-20	96.04	82.1	96.35	75.97
2530	90	2026-04-19	98.75	80.2	97.63	77.32
2531	90	2026-04-18	95.21	92.7	99.03	87.4
2532	90	2026-04-17	90.21	84.7	97.64	74.6
2533	90	2026-04-16	98.54	88.3	96.04	83.56
2534	90	2026-04-15	90.42	81.9	99.02	73.33
2535	90	2026-04-14	97.92	83.7	95.82	78.53
2536	90	2026-04-13	99.17	91.7	95.53	86.87
2537	90	2026-04-12	97.5	86.2	97.45	81.9
2538	90	2026-04-11	97.92	87.2	96.1	82.05
2539	90	2026-04-10	92.5	91	97.69	82.23
2540	90	2026-04-09	97.08	82.1	95.86	76.4
2541	90	2026-04-08	98.13	88.1	96.03	83.01
2542	90	2026-04-07	95.63	93.8	97.33	87.31
2543	90	2026-04-06	87.92	89.8	98.66	77.89
2544	90	2026-04-05	95.83	90.6	98.01	85.1
2545	90	2026-04-04	93.96	84.6	96.22	76.48
2546	90	2026-04-03	98.75	89.1	95.4	83.94
2547	90	2026-04-02	98.54	86.4	96.3	81.99
2548	90	2026-04-01	99.79	88.5	98.98	87.42
2549	90	2026-03-31	95.42	85.8	97.55	79.86
2550	90	2026-03-30	91.46	92.5	96.22	81.4
2551	91	2026-04-28	98.13	80.6	96.03	75.95
2552	91	2026-04-27	90.21	92.7	96.01	80.29
2553	91	2026-04-26	96.67	85	97.41	80.04
2554	91	2026-04-25	91.25	94.3	98.2	84.5
2555	91	2026-04-24	88.33	86.2	98.84	75.26
2556	91	2026-04-23	90.21	89.7	95.65	77.4
2557	91	2026-04-22	99.58	96.4	95.64	91.82
2558	91	2026-04-21	90	87.1	97.59	76.5
2559	91	2026-04-20	97.92	84.9	98.94	82.25
2560	91	2026-04-19	99.17	96.7	96.28	92.32
2561	91	2026-04-18	91.67	85.2	96.36	75.26
2562	91	2026-04-17	92.5	83.4	97.48	75.2
2563	91	2026-04-16	94.58	87.2	98.39	81.15
2564	91	2026-04-15	96.88	95.1	95.48	87.96
2565	91	2026-04-14	90.63	89.5	97.88	79.39
2566	91	2026-04-13	98.96	81.2	97.04	77.98
2567	91	2026-04-12	88.96	93.5	96.36	80.15
2568	91	2026-04-11	98.33	93.9	98.72	91.15
2569	91	2026-04-10	96.46	81.1	97.29	76.11
2570	91	2026-04-09	89.17	85.3	98.83	75.17
2571	91	2026-04-08	98.13	92.4	97.62	88.51
2572	91	2026-04-07	90	84.2	96.56	73.17
2573	91	2026-04-06	95.63	86	98.49	80.99
2574	91	2026-04-05	98.13	83.7	98.09	80.56
2575	91	2026-04-04	95.42	81.3	98.89	76.72
2576	91	2026-04-03	87.5	83.4	97.12	70.87
2577	91	2026-04-02	95.42	94	97.34	87.31
2578	91	2026-04-01	97.08	82.7	97.58	78.35
2579	91	2026-03-31	91.04	93.9	96.49	82.48
2580	91	2026-03-30	91.25	90.6	95.81	79.21
2581	92	2026-04-28	89.17	81.3	96.43	69.91
2582	92	2026-04-27	91.67	89.3	97.76	80.02
2583	92	2026-04-26	89.58	90.9	96.7	78.74
2584	92	2026-04-25	96.25	94.1	96.17	87.11
2585	92	2026-04-24	95.83	96.5	96.27	89.03
2586	92	2026-04-23	95.63	90.8	97.91	85.01
2587	92	2026-04-22	94.79	84.4	96.09	76.88
2588	92	2026-04-21	88.75	81.9	96.95	70.47
2589	92	2026-04-20	92.5	90.6	96.91	81.22
2590	92	2026-04-19	93.96	81.6	98.28	75.35
2591	92	2026-04-18	92.5	94.7	98.73	86.49
2592	92	2026-04-17	98.33	86.8	96.54	82.4
2593	92	2026-04-16	90.42	87.6	98.97	78.39
2594	92	2026-04-15	91.88	92.4	98.38	83.51
2595	92	2026-04-14	93.96	92.5	95.78	83.25
2596	92	2026-04-13	89.38	89.8	95.99	77.04
2597	92	2026-04-12	88.33	84	97.86	72.61
2598	92	2026-04-11	87.71	82.4	96.72	69.9
2599	92	2026-04-10	92.92	93.5	95.29	82.79
2600	92	2026-04-09	98.75	80.4	97.51	77.42
2601	92	2026-04-08	91.46	89	96.18	78.29
2602	92	2026-04-07	92.92	85.8	95.45	76.1
2603	92	2026-04-06	96.88	95.2	98.32	90.67
2604	92	2026-04-05	87.5	88.2	96.15	74.2
2605	92	2026-04-04	88.13	80.4	95.4	67.59
2606	92	2026-04-03	95.42	87.5	98.4	82.15
2607	92	2026-04-02	98.75	96.9	98.14	93.91
2608	92	2026-04-01	88.75	89.9	97.66	77.92
2609	92	2026-03-31	98.54	81.1	97.78	78.14
2610	92	2026-03-30	97.5	87.2	97.71	83.07
2611	93	2026-04-28	97.29	94	95.21	87.08
2612	93	2026-04-27	97.08	85.9	96.16	80.19
2613	93	2026-04-26	87.92	93.6	98.61	81.15
2614	93	2026-04-25	96.25	83.1	97.11	77.67
2615	93	2026-04-24	94.79	81.5	98.53	76.12
2616	93	2026-04-23	98.75	89	96.85	85.12
2617	93	2026-04-22	99.38	94	96.7	90.33
2618	93	2026-04-21	98.33	92.6	97.41	88.7
2619	93	2026-04-20	93.33	94.4	95.34	84
2620	93	2026-04-19	95.42	91.5	97.27	84.92
2621	93	2026-04-18	95.83	87.8	95.67	80.5
2622	93	2026-04-17	92.5	85.8	98.6	78.26
2623	93	2026-04-16	93.96	87.1	96.9	79.3
2624	93	2026-04-15	92.08	91.1	97.59	81.86
2625	93	2026-04-14	90.42	95.3	96.85	83.45
2626	93	2026-04-13	98.96	96.4	97.72	93.22
2627	93	2026-04-12	87.71	93.3	95.82	78.41
2628	93	2026-04-11	99.58	93.4	97.43	90.62
2629	93	2026-04-10	98.33	97.9	96.94	93.32
2630	93	2026-04-09	99.79	89.6	98.88	88.42
2631	93	2026-04-08	90.42	95	98.53	84.63
2632	93	2026-04-07	96.46	87.1	97.47	81.89
2633	93	2026-04-06	93.96	96.4	97.51	88.32
2634	93	2026-04-05	91.67	96.3	95.33	84.15
2635	93	2026-04-04	88.33	84.2	95.61	71.11
2636	93	2026-04-03	94.58	85.6	96.96	78.5
2637	93	2026-04-02	91.67	96.7	96.9	85.89
2638	93	2026-04-01	91.88	82	96.1	72.4
2639	93	2026-03-31	90.42	94	97.34	82.73
2640	93	2026-03-30	90.83	81.1	96.42	71.03
2641	94	2026-04-28	87.71	81.2	97.66	69.55
2642	94	2026-04-27	95.21	80.4	95.77	73.31
2643	94	2026-04-26	91.46	96.9	95.56	84.69
2644	94	2026-04-25	88.54	81.6	98.28	71.01
2645	94	2026-04-24	95	86	96.05	78.47
2646	94	2026-04-23	92.92	95.8	97.7	86.97
2647	94	2026-04-22	92.29	91.7	97.71	82.69
2648	94	2026-04-21	88.75	94.1	95.64	79.87
2649	94	2026-04-20	99.38	90.8	96.37	86.95
2650	94	2026-04-19	91.67	94.8	97.15	84.42
2651	94	2026-04-18	92.71	88.1	97.62	79.73
2652	94	2026-04-17	96.46	97.7	96.93	91.35
2653	94	2026-04-16	94.58	84	95.6	75.95
2654	94	2026-04-15	95.21	80	98.25	74.83
2655	94	2026-04-14	95.83	95.2	98	89.41
2656	94	2026-04-13	95	83.5	96.89	76.85
2657	94	2026-04-12	89.38	97.9	95.61	83.66
2658	94	2026-04-11	97.08	86.2	95.59	80
2659	94	2026-04-10	91.46	88.2	96.15	77.56
2660	94	2026-04-09	92.92	83.6	95.33	74.05
2661	94	2026-04-08	97.29	85.8	96.85	80.85
2662	94	2026-04-07	96.67	81.2	97.17	76.27
2663	94	2026-04-06	95.21	82	95.85	74.83
2664	94	2026-04-05	95.42	82.7	97.7	77.1
2665	94	2026-04-04	93.33	91.3	98.36	83.81
2666	94	2026-04-03	95.83	87.9	95.34	80.31
2667	94	2026-04-02	96.46	81.1	98.52	77.07
2668	94	2026-04-01	98.33	97.4	96.1	92.04
2669	94	2026-03-31	94.79	96.4	98.76	90.24
2670	94	2026-03-30	91.04	84.9	96	74.2
2671	95	2026-04-28	100	80	98.13	78.5
2672	95	2026-04-27	97.08	83	96.87	78.05
2673	95	2026-04-26	88.54	90.2	96.67	77.21
2674	95	2026-04-25	95.21	94.9	95.89	86.64
2675	95	2026-04-24	96.04	81.8	97.19	76.35
2676	95	2026-04-23	87.71	90	98.78	77.97
2677	95	2026-04-22	89.38	81.5	98.65	71.86
2678	95	2026-04-21	88.54	83.2	98.68	72.69
2679	95	2026-04-20	93.33	84	95.71	75.04
2680	95	2026-04-19	91.46	85.1	98.71	76.83
2681	95	2026-04-18	88.75	87.6	98.4	76.5
2682	95	2026-04-17	98.75	95.1	99.05	93.02
2683	95	2026-04-16	98.54	90.7	95.48	85.34
2684	95	2026-04-15	99.17	82	98.17	79.83
2685	95	2026-04-14	90.63	85.4	98.48	76.22
2686	95	2026-04-13	94.79	88.4	98.53	82.56
2687	95	2026-04-12	88.54	86.9	95.63	73.58
2688	95	2026-04-11	99.38	92.3	99.02	90.83
2689	95	2026-04-10	87.92	87.5	98.74	75.96
2690	95	2026-04-09	100	83.8	98.57	82.6
2691	95	2026-04-08	94.17	85.3	97.89	78.63
2692	95	2026-04-07	88.75	80.6	98.26	70.29
2693	95	2026-04-06	95.63	93.2	97.53	86.92
2694	95	2026-04-05	95.83	82.7	97.94	77.62
2695	95	2026-04-04	93.54	88.4	95.59	79.04
2696	95	2026-04-03	90.83	83.2	95.55	72.21
2697	95	2026-04-02	90.83	80.3	98.75	72.03
2698	95	2026-04-01	96.25	80.9	97.28	75.75
2699	95	2026-03-31	89.79	90	98.78	79.82
2700	95	2026-03-30	98.13	97.4	98.05	93.71
2701	96	2026-04-28	92.08	83	95.66	73.11
2702	96	2026-04-27	93.96	90.5	98.56	83.81
2703	96	2026-04-26	99.58	96	96.56	92.31
2704	96	2026-04-25	93.96	88	97.84	80.9
2705	96	2026-04-24	88.13	83.9	98.69	72.97
2706	96	2026-04-23	99.17	93.4	96.47	89.35
2707	96	2026-04-22	97.29	81.1	96.55	76.18
2708	96	2026-04-21	98.75	89.6	97.43	86.21
2709	96	2026-04-20	95.42	85.7	95.57	78.15
2710	96	2026-04-19	95	95.7	98.33	89.39
2711	96	2026-04-18	98.75	89.4	98.1	86.6
2712	96	2026-04-17	91.46	85.6	98.6	77.19
2713	96	2026-04-16	91.04	86.2	98.03	76.93
2714	96	2026-04-15	90.83	88.1	98.07	78.48
2715	96	2026-04-14	98.75	82.9	97.59	79.89
2716	96	2026-04-13	92.08	94.8	95.89	83.7
2717	96	2026-04-12	90.21	83.6	98.33	74.15
2718	96	2026-04-11	95	88.2	96.83	81.13
2719	96	2026-04-10	93.13	88.5	95.03	78.32
2720	96	2026-04-09	96.46	88.6	95.82	81.89
2721	96	2026-04-08	93.96	80	96	72.16
2722	96	2026-04-07	92.71	92.2	97.07	82.97
2723	96	2026-04-06	90.83	95.5	95.92	83.2
2724	96	2026-04-05	91.25	91.9	96.95	81.3
2725	96	2026-04-04	93.75	81.4	96.81	73.87
2726	96	2026-04-03	99.58	84.1	98.93	82.85
2727	96	2026-04-02	100	84.9	98.35	83.5
2728	96	2026-04-01	95.42	87.5	98.06	81.87
2729	96	2026-03-31	97.08	83.7	97.01	78.83
2730	96	2026-03-30	98.54	93.9	97.12	89.87
2731	97	2026-04-28	94.79	81.6	98.53	76.21
2732	97	2026-04-27	98.54	88.4	95.14	82.87
2733	97	2026-04-26	89.38	89.1	95.85	76.33
2734	97	2026-04-25	99.79	91.5	96.94	88.52
2735	97	2026-04-24	93.54	84.1	96.08	75.58
2736	97	2026-04-23	93.13	83.1	98.68	76.36
2737	97	2026-04-22	90.21	94.2	96.6	82.09
2738	97	2026-04-21	93.96	80.5	98.26	74.32
2739	97	2026-04-20	91.67	93.5	95.51	81.86
2740	97	2026-04-19	91.04	80	97.88	71.29
2741	97	2026-04-18	98.33	85.6	99.07	83.39
2742	97	2026-04-17	93.75	88	95.91	79.13
2743	97	2026-04-16	97.71	85.3	95.08	79.24
2744	97	2026-04-15	93.54	97.2	98.87	89.89
2745	97	2026-04-14	93.54	88.1	96.59	79.6
2746	97	2026-04-13	89.17	88.2	96.26	75.7
2747	97	2026-04-12	95.83	94	95.43	85.96
2748	97	2026-04-11	92.5	84.9	98.12	77.05
2749	97	2026-04-10	91.46	87.3	98.97	79.02
2750	97	2026-04-09	96.67	87.4	95.42	80.62
2751	97	2026-04-08	91.25	88.8	98.31	79.66
2752	97	2026-04-07	96.25	83.5	97.72	78.54
2753	97	2026-04-06	90.42	81.1	99.01	72.6
2754	97	2026-04-05	96.88	81.5	99.02	78.18
2755	97	2026-04-04	97.29	97.7	97.24	92.43
2756	97	2026-04-03	98.96	89.5	97.43	86.29
2757	97	2026-04-02	95.83	85.6	96.03	78.78
2758	97	2026-04-01	94.79	81.1	96.79	74.41
2759	97	2026-03-31	87.5	89.2	95.96	74.9
2760	97	2026-03-30	97.5	92.1	98.48	88.43
2761	98	2026-04-28	95.63	81.1	95.81	74.3
2762	98	2026-04-27	97.71	86.4	97.45	82.27
2763	98	2026-04-26	87.92	87.6	95.78	73.76
2764	98	2026-04-25	88.75	87.3	96.79	74.99
2765	98	2026-04-24	98.75	89.3	96.19	84.83
2766	98	2026-04-23	88.75	94.2	96.6	80.76
2767	98	2026-04-22	97.92	92.6	99.03	89.79
2768	98	2026-04-21	92.29	93.9	96.27	83.43
2769	98	2026-04-20	97.29	90	95.44	83.57
2770	98	2026-04-19	97.71	81.8	96.45	77.09
2771	98	2026-04-18	91.88	92.5	99.03	84.16
2772	98	2026-04-17	90.21	96.9	98.66	86.24
2773	98	2026-04-16	89.38	89.8	95.1	76.33
2774	98	2026-04-15	92.08	92.3	95.88	81.49
2775	98	2026-04-14	99.38	95.9	98.02	93.41
2776	98	2026-04-13	100	90.8	97.25	88.3
2777	98	2026-04-12	89.17	88.2	96.71	76.06
2778	98	2026-04-11	95	81.8	98.53	76.57
2779	98	2026-04-10	91.25	87	96.32	76.47
2780	98	2026-04-09	99.38	82.4	97.69	80
2781	98	2026-04-08	94.17	90.3	96.23	81.83
2782	98	2026-04-07	91.04	95.4	97.9	85.03
2783	98	2026-04-06	94.38	82.9	95.9	75.03
2784	98	2026-04-05	96.25	83.6	97.37	78.35
2785	98	2026-04-04	91.25	86.2	96.4	75.83
2786	98	2026-04-03	89.17	97.1	98.46	85.24
2787	98	2026-04-02	95.42	91.8	97.71	85.59
2788	98	2026-04-01	93.75	86.2	98.84	79.88
2789	98	2026-03-31	88.13	84.7	96.46	72
2790	98	2026-03-30	97.71	96.4	97.61	91.94
2791	99	2026-04-28	90.63	93.9	98.08	83.47
2792	99	2026-04-27	90.42	84.9	96.58	74.14
2793	99	2026-04-26	96.67	88.8	95.16	81.68
2794	99	2026-04-25	90.63	94.1	95.43	81.38
2795	99	2026-04-24	92.92	95.6	96.23	85.48
2796	99	2026-04-23	93.13	88.3	95.36	78.41
2797	99	2026-04-22	97.5	92.1	97.72	87.75
2798	99	2026-04-21	92.5	91	95.27	80.2
2799	99	2026-04-20	99.58	96.5	96.06	92.31
2800	99	2026-04-19	98.13	97.2	96.4	91.94
2801	99	2026-04-18	96.88	82	99.02	78.66
2802	99	2026-04-17	90.42	89.4	98.55	79.66
2803	99	2026-04-16	93.96	89.7	95.43	80.43
2804	99	2026-04-15	100	93.2	96.46	89.9
2805	99	2026-04-14	88.96	96.5	96.27	82.64
2806	99	2026-04-13	97.29	92.4	96.65	86.88
2807	99	2026-04-12	97.08	88	98.07	83.78
2808	99	2026-04-11	91.88	80.2	98.38	72.49
2809	99	2026-04-10	97.29	82.7	97.82	78.71
2810	99	2026-04-09	91.46	96	97.19	85.33
2811	99	2026-04-08	98.96	92.2	98.16	89.56
2812	99	2026-04-07	95.83	91.2	98.25	85.87
2813	99	2026-04-06	91.88	93	98.06	83.79
2814	99	2026-04-05	97.08	87.1	97.36	82.33
2815	99	2026-04-04	98.13	85	95.76	79.87
2816	99	2026-04-03	90.42	88.2	95.46	76.13
2817	99	2026-04-02	91.88	91.7	97.93	82.5
2818	99	2026-04-01	91.25	86.7	96.42	76.28
2819	99	2026-03-31	95.83	83.5	98.32	78.68
2820	99	2026-03-30	99.17	81.9	98.05	79.63
2821	100	2026-04-28	91.46	96.4	96.68	85.24
2822	100	2026-04-27	91.46	95.4	97.27	84.87
2823	100	2026-04-26	98.13	93.8	95.95	88.31
2824	100	2026-04-25	94.58	96.9	95.56	87.58
2825	100	2026-04-24	93.33	82	97.68	74.76
2826	100	2026-04-23	94.17	84.3	97.51	77.41
2827	100	2026-04-22	100	89.6	95.2	85.3
2828	100	2026-04-21	93.13	95.3	96.64	85.77
2829	100	2026-04-20	95.83	84	98.69	79.45
2830	100	2026-04-19	97.71	80.3	99	77.68
2831	100	2026-04-18	90.63	84.1	97.62	74.4
2832	100	2026-04-17	91.88	83.6	95.45	73.32
2833	100	2026-04-16	96.46	94.4	96.72	88.07
2834	100	2026-04-15	91.46	87.9	98.07	78.84
2835	100	2026-04-14	90.21	81.1	95.56	69.91
2836	100	2026-04-13	99.79	94.8	98.95	93.6
2837	100	2026-04-12	97.92	97.5	98.36	93.9
2838	100	2026-04-11	90.21	96.2	97.19	84.34
2839	100	2026-04-10	92.92	80.9	96.91	72.85
2840	100	2026-04-09	97.92	92.5	97.41	88.22
2841	100	2026-04-08	93.96	82.8	97.22	75.64
2842	100	2026-04-07	92.08	85.5	95.2	74.96
2843	100	2026-04-06	90	84.4	95.38	72.45
2844	100	2026-04-05	87.71	86.1	96.28	72.71
2845	100	2026-04-04	96.88	88.1	96.71	82.54
2846	100	2026-04-03	89.58	81.3	96.19	70.05
2847	100	2026-04-02	95.21	91.6	98.25	85.69
2848	100	2026-04-01	90.63	90	99	80.75
2849	100	2026-03-31	96.67	86.5	96.53	80.72
2850	100	2026-03-30	97.08	91	96.92	85.63
2851	101	2026-04-28	88.96	82.4	95.27	69.83
2852	101	2026-04-27	93.13	92.6	95.68	82.51
2853	101	2026-04-26	91.25	96.8	97.42	86.05
2854	101	2026-04-25	91.46	86.3	97.8	77.19
2855	101	2026-04-24	93.75	80.1	98	73.59
2856	101	2026-04-23	88.96	83.8	98.33	73.3
2857	101	2026-04-22	89.79	91.8	95.42	78.66
2858	101	2026-04-21	95.63	94.8	95.99	87.02
2859	101	2026-04-20	92.71	96.9	98.97	88.91
2860	101	2026-04-19	92.29	85.4	98.01	77.25
2861	101	2026-04-18	87.71	80.1	97.5	68.5
2862	101	2026-04-17	91.67	87.5	96.8	77.64
2863	101	2026-04-16	92.29	87.3	96.91	78.08
2864	101	2026-04-15	95.21	91.7	95.31	83.21
2865	101	2026-04-14	94.38	86.9	96.2	78.9
2866	101	2026-04-13	89.17	81.8	95.72	69.82
2867	101	2026-04-12	90	86.1	95.82	74.25
2868	101	2026-04-11	90.63	83.5	96.65	73.13
2869	101	2026-04-10	97.08	93.1	96.46	87.18
2870	101	2026-04-09	91.25	92.9	97.2	82.4
2871	101	2026-04-08	92.5	93.1	97.31	83.81
2872	101	2026-04-07	90.83	85.1	96.94	74.94
2873	101	2026-04-06	95.21	84.1	97.74	78.26
2874	101	2026-04-05	98.13	92.2	97.83	88.51
2875	101	2026-04-04	88.33	84.4	98.1	73.14
2876	101	2026-04-03	97.08	89.2	95.74	82.91
2877	101	2026-04-02	87.71	95.8	97.7	82.09
2878	101	2026-04-01	89.79	85.7	98.6	75.87
2879	101	2026-03-31	92.71	92.1	95.44	81.49
2880	101	2026-03-30	100	84	95.48	80.2
2881	102	2026-04-28	99.58	91.7	98.91	90.32
2882	102	2026-04-27	87.92	87.5	96.57	74.29
2883	102	2026-04-26	96.88	93.4	96.68	87.48
2884	102	2026-04-25	89.79	85.2	99.06	75.78
2885	102	2026-04-24	93.54	83.2	96.88	75.39
2886	102	2026-04-23	89.17	92.9	96.66	80.07
2887	102	2026-04-22	94.58	84	95.71	76.05
2888	102	2026-04-21	94.58	83.7	96.18	76.14
2889	102	2026-04-20	91.25	91.7	98.8	82.67
2890	102	2026-04-19	89.58	90.6	96.8	78.56
2891	102	2026-04-18	95.21	84.3	95.14	76.36
2892	102	2026-04-17	98.54	86.6	97.92	83.56
2893	102	2026-04-16	98.13	92.4	95.24	86.35
2894	102	2026-04-15	93.13	91.8	96.41	82.42
2895	102	2026-04-14	100	97.9	95.4	93.4
2896	102	2026-04-13	94.38	82.7	97.7	76.25
2897	102	2026-04-12	95.63	96.4	95.33	87.88
2898	102	2026-04-11	92.71	89.8	96.77	80.56
2899	102	2026-04-10	94.58	96.7	98.86	90.42
2900	102	2026-04-09	87.92	91.9	96.52	77.98
2901	102	2026-04-08	89.38	94.1	97.77	82.23
2902	102	2026-04-07	91.46	93.9	95.42	81.95
2903	102	2026-04-06	90.83	92.5	97.84	82.2
2904	102	2026-04-05	87.5	85.3	98.36	73.41
2905	102	2026-04-04	97.71	81.6	97.18	77.48
2906	102	2026-04-03	91.46	80	96.63	70.7
2907	102	2026-04-02	88.13	96	96.25	81.43
2908	102	2026-04-01	91.04	93	96.56	81.76
2909	102	2026-03-31	97.29	84.4	97.39	79.97
2910	102	2026-03-30	98.54	85.9	97.9	82.87
2911	103	2026-04-28	91.25	92.9	97.42	82.58
2912	103	2026-04-27	90	88.3	98.07	77.94
2913	103	2026-04-26	90.83	83.8	97.85	74.48
2914	103	2026-04-25	91.46	85.5	95.56	74.72
2915	103	2026-04-24	90	82.8	96.5	71.91
2916	103	2026-04-23	93.96	91.7	97.06	83.62
2917	103	2026-04-22	90.83	85	96.35	74.39
2918	103	2026-04-21	93.75	86.7	98.85	80.34
2919	103	2026-04-20	90.63	96.7	95.14	83.38
2920	103	2026-04-19	93.96	80.1	95.76	72.07
2921	103	2026-04-18	93.96	86.8	97.12	79.21
2922	103	2026-04-17	94.58	86.6	98.85	80.96
2923	103	2026-04-16	90.83	87.8	97.84	78.03
2924	103	2026-04-15	98.96	88.9	96.18	84.61
2925	103	2026-04-14	91.25	88.9	95.16	77.2
2926	103	2026-04-13	97.5	85.1	98.82	82
2927	103	2026-04-12	96.46	96.5	97.41	90.67
2928	103	2026-04-11	88.13	83.2	97.12	71.21
2929	103	2026-04-10	98.54	87	95.17	81.59
2930	103	2026-04-09	95.83	94.2	99.04	89.41
2931	103	2026-04-08	90.83	95.6	95.29	82.75
2932	103	2026-04-07	94.38	90.3	97.67	83.24
2933	103	2026-04-06	96.25	86.5	98.73	82.2
2934	103	2026-04-05	98.33	92.1	96.74	87.61
2935	103	2026-04-04	95.21	92	96.85	84.83
2936	103	2026-04-03	94.58	95.9	96.14	87.21
2937	103	2026-04-02	94.38	84.5	97.4	77.67
2938	103	2026-04-01	97.71	85.8	97.09	81.39
2939	103	2026-03-31	91.46	82.5	96.36	72.71
2940	103	2026-03-30	91.46	94.2	98.09	84.51
2941	104	2026-04-28	96.67	86.2	98.49	82.07
2942	104	2026-04-27	91.25	81.4	95.95	71.27
2943	104	2026-04-26	93.13	82.3	98.42	75.43
2944	104	2026-04-25	90.21	88.1	95.35	75.77
2945	104	2026-04-24	96.04	93.7	97.97	88.17
2946	104	2026-04-23	94.38	85.5	96.84	78.14
2947	104	2026-04-22	88.96	88.4	95.59	75.17
2948	104	2026-04-21	92.08	90.7	96.03	80.2
2949	104	2026-04-20	100	97.7	95.39	93.2
2950	104	2026-04-19	97.5	82.8	96.5	77.9
2951	104	2026-04-18	92.71	90.9	97.8	82.42
2952	104	2026-04-17	89.58	85.4	96.02	73.46
2953	104	2026-04-16	95.83	95.6	97.59	89.41
2954	104	2026-04-15	100	90.9	96.92	88.1
2955	104	2026-04-14	95.63	87.5	96.46	80.71
2956	104	2026-04-13	93.33	87.1	97.01	78.87
2957	104	2026-04-12	93.96	91.2	98.57	84.47
2958	104	2026-04-11	99.38	87	96.9	83.77
2959	104	2026-04-10	93.96	81.3	95.82	73.19
2960	104	2026-04-09	97.29	89.4	95.86	83.38
2961	104	2026-04-08	93.96	95.8	95.3	85.78
2962	104	2026-04-07	91.46	93.2	98.82	84.23
2963	104	2026-04-06	99.58	90.9	95.93	86.84
2964	104	2026-04-05	90.42	95.7	98.22	84.99
2965	104	2026-04-04	91.88	92.9	96.12	82.04
2966	104	2026-04-03	91.67	82.2	98.42	74.16
2967	104	2026-04-02	92.29	82.7	98.19	74.94
2968	104	2026-04-01	92.92	89.6	95.31	79.35
2969	104	2026-03-31	98.96	81.5	98.04	79.07
2970	104	2026-03-30	87.71	83.4	96.88	70.87
2971	105	2026-04-28	96.46	83.2	96.15	77.17
2972	105	2026-04-27	91.67	84.9	97.41	75.81
2973	105	2026-04-26	95.21	88.7	97.18	82.07
2974	105	2026-04-25	94.38	88	98.64	81.92
2975	105	2026-04-24	91.67	89.1	98.54	80.48
2976	105	2026-04-23	87.71	93	96.02	78.32
2977	105	2026-04-22	99.17	97.5	95.49	92.32
2978	105	2026-04-21	92.08	90.5	96.69	80.57
2979	105	2026-04-20	99.58	82.3	95.26	78.07
2980	105	2026-04-19	89.38	86.9	95.51	74.18
2981	105	2026-04-18	93.75	80.8	98.27	74.44
2982	105	2026-04-17	88.33	81.1	96.42	69.08
2983	105	2026-04-16	94.17	82.5	98.91	76.84
2984	105	2026-04-15	90	90.4	96.68	78.66
2985	105	2026-04-14	97.5	84.1	95.12	78
2986	105	2026-04-13	90.42	81.7	96.57	71.34
2987	105	2026-04-12	94.17	85.7	96.5	77.88
2988	105	2026-04-11	96.88	89.4	95.08	82.34
2989	105	2026-04-10	88.96	89.8	97.88	78.19
2990	105	2026-04-09	92.92	80	97.63	72.57
2991	105	2026-04-08	95.63	83	98.19	77.93
2992	105	2026-04-07	100	83.4	95.56	79.7
2993	105	2026-04-06	91.67	95.2	95.59	83.42
2994	105	2026-04-05	90.21	88.8	98.65	79.02
2995	105	2026-04-04	96.88	95.1	97.79	90.09
2996	105	2026-04-03	98.13	85.2	95.31	79.68
2997	105	2026-04-02	95.83	94.1	96.71	87.21
2998	105	2026-04-01	99.79	93	95.59	88.71
2999	105	2026-03-31	94.17	86.5	96.65	78.72
3000	105	2026-03-30	97.29	95.7	97.91	91.16
\.


--
-- TOC entry 3947 (class 0 OID 89670)
-- Dependencies: 247
-- Data for Name: parca; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parca (parca_id, parca_adi, tahmini_omur_saati, parca_maliyeti, tedarik_gun_suresi, kategori_id, tedarikci_id, stok_miktari, min_stok_seviyesi) FROM stdin;
1	HAVA FILTRESI X10	2500.50	450	3	2	1	100	10
2	Kesici Takım / İş Mili (Spindle) Rulmanları	8000.00	5000	7	\N	1	\N	\N
3	X-Y-Z Eksen Motorları ve Sürücüleri	15000.00	5000	7	\N	1	\N	\N
4	Pnömatik Mengene Valfi	12000.00	5000	7	\N	1	\N	\N
5	Bor Yağı Pompası	10000.00	5000	7	\N	1	\N	\N
6	Ana Hidrolik Pompa	15000.00	5000	7	\N	1	\N	\N
7	Hidrolik Yön Valfleri ve Keçeler	10000.00	5000	7	\N	1	\N	\N
8	Mekanik Gövde / Kılavuz Yatakları	30000.00	5000	7	\N	1	\N	\N
9	Isıtıcı Rezistans Bantları	8000.00	5000	7	\N	1	\N	\N
10	Enjeksiyon Vidası ve Kovan (Barel)	20000.00	5000	7	\N	1	\N	\N
11	Kalıp Soğutma Valfleri (Eşanjör)	12000.00	5000	7	\N	1	\N	\N
12	Pto Sensör X-V2	1500.00	2450	12	\N	2	5	15
13	RULMAN 6204-2RS	15000.00	120	3	4	1	65	10
\.


--
-- TOC entry 3949 (class 0 OID 89677)
-- Dependencies: 249
-- Data for Name: parca_degisim; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parca_degisim (parca_degisim_id, bakim_id, parca_id, adet, bakim_kaydi_id) FROM stdin;
\.


--
-- TOC entry 3977 (class 0 OID 89786)
-- Dependencies: 277
-- Data for Name: parca_kategori; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parca_kategori (kategori_id, kategori_adi) FROM stdin;
2	FILTRE GRUBU
4	MEKANIK
\.


--
-- TOC entry 3992 (class 0 OID 114149)
-- Dependencies: 302
-- Data for Name: parca_stok_hareketleri; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.parca_stok_hareketleri (hareket_id, parca_id, eklenen_miktar, islem_tarihi) FROM stdin;
1	13	50	2026-05-01 12:13:17.723262
2	13	15	2026-05-01 12:14:53.603711
\.


--
-- TOC entry 3951 (class 0 OID 89684)
-- Dependencies: 251
-- Data for Name: risk_skoru; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.risk_skoru (risk_id, makine_id, risk_skoru, risk_seviyesi, hesaplama_tarihi) FROM stdin;
\.


--
-- TOC entry 3953 (class 0 OID 89691)
-- Dependencies: 253
-- Data for Name: rol; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rol (rol_id, rol_adi) FROM stdin;
1	YONETICI
2	TEKNISYEN
3	OPERATOR
4	SERVİS
5	BAKIM_SORUMLUSU
6	SERVIS
\.


--
-- TOC entry 3979 (class 0 OID 89793)
-- Dependencies: 279
-- Data for Name: sektor; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sektor (sektor_id, sektor_adi) FROM stdin;
\.


--
-- TOC entry 3955 (class 0 OID 89700)
-- Dependencies: 255
-- Data for Name: servis_firma; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_firma (servis_firma_id, firma_adi, aktiflik, iletisim_id) FROM stdin;
8	Güvenilir Servis A.Ş.	t	2
9	ProMekanik Genel Bakım	t	\N
10	FixIt Elektronik & PCB	t	\N
11	Robotix Otomasyon	t	\N
12	SpindleMaster Revizyon	t	\N
\.


--
-- TOC entry 3980 (class 0 OID 89799)
-- Dependencies: 280
-- Data for Name: servis_firma_uzmanlik; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_firma_uzmanlik (servis_firma_id, uzmanlik_adi) FROM stdin;
9	Genel Mekanik
10	Elektronik & PCB
11	Robotik
12	Motor & Spindle
\.


--
-- TOC entry 3967 (class 0 OID 89745)
-- Dependencies: 267
-- Data for Name: servis_puan; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_puan (puan_id, servis_firma_id, puanlayan_kullanici_id, puan, yorum, tarih) FROM stdin;
1	9	6	4	Zamanında ve kaliteli hizmet.	2026-04-29
2	9	6	5	Zamanında ve kaliteli hizmet.	2026-04-20
3	9	6	5	Zamanında ve kaliteli hizmet.	2026-04-17
4	9	6	5	Zamanında ve kaliteli hizmet.	2026-03-30
5	9	6	5	Zamanında ve kaliteli hizmet.	2026-04-29
6	9	6	5	Zamanında ve kaliteli hizmet.	2026-04-25
7	9	6	5	Zamanında ve kaliteli hizmet.	2026-04-23
8	9	6	5	Zamanında ve kaliteli hizmet.	2026-04-07
9	9	6	5	Zamanında ve kaliteli hizmet.	2026-04-06
10	9	6	5	Zamanında ve kaliteli hizmet.	2026-04-12
11	10	6	2	Teknik destek zayıf.	2026-04-05
12	10	6	1	Teknik destek zayıf.	2026-04-14
13	10	6	1	Teknik destek zayıf.	2026-04-07
14	10	6	2	Teknik destek zayıf.	2026-04-18
15	10	6	1	Teknik destek zayıf.	2026-04-15
16	10	6	2	Teknik destek zayıf.	2026-04-27
17	10	6	2	Teknik destek zayıf.	2026-04-26
18	10	6	2	Teknik destek zayıf.	2026-04-02
19	10	6	2	Teknik destek zayıf.	2026-04-27
20	10	6	1	Teknik destek zayıf.	2026-04-17
21	11	6	5	Zamanında ve kaliteli hizmet.	2026-04-16
22	11	6	4	Zamanında ve kaliteli hizmet.	2026-04-09
23	11	6	5	Zamanında ve kaliteli hizmet.	2026-04-09
24	11	6	5	Zamanında ve kaliteli hizmet.	2026-04-15
25	11	6	4	Zamanında ve kaliteli hizmet.	2026-04-02
26	11	6	5	Zamanında ve kaliteli hizmet.	2026-04-19
27	11	6	5	Zamanında ve kaliteli hizmet.	2026-04-29
28	11	6	5	Zamanında ve kaliteli hizmet.	2026-04-18
29	11	6	5	Zamanında ve kaliteli hizmet.	2026-04-27
30	11	6	5	Zamanında ve kaliteli hizmet.	2026-04-17
31	12	6	4	Zamanında ve kaliteli hizmet.	2026-04-29
32	12	6	4	Zamanında ve kaliteli hizmet.	2026-04-23
33	12	6	4	Zamanında ve kaliteli hizmet.	2026-04-14
34	12	6	4	Zamanında ve kaliteli hizmet.	2026-04-04
35	12	6	3	Teknik destek zayıf.	2026-04-11
36	12	6	4	Zamanında ve kaliteli hizmet.	2026-04-20
37	12	6	4	Zamanında ve kaliteli hizmet.	2026-04-08
38	12	6	3	Teknik destek zayıf.	2026-04-18
39	12	6	4	Zamanında ve kaliteli hizmet.	2026-04-07
40	12	6	4	Zamanında ve kaliteli hizmet.	2026-04-19
\.


--
-- TOC entry 3969 (class 0 OID 89754)
-- Dependencies: 269
-- Data for Name: servis_sorumlusu; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servis_sorumlusu (sorumlu_id, servis_firma_id, ad, soyad, telefon, aktiflik, unvan, sorumlu_adi) FROM stdin;
\.


--
-- TOC entry 3957 (class 0 OID 89707)
-- Dependencies: 257
-- Data for Name: tedarikci; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tedarikci (tedarikci_id, firma_adi, aktiflik, guvenilirlik_skoru, vergi_no, yetkili_kisi, kayit_tarihi, iletisim_id) FROM stdin;
1	SANAYI COZUMLERI LTD	t	45.20	4561237890	Mehmet Can	2026-03-27 00:00:00+00	1
2	Kaan Sensör Teknolojileri	t	45.00	VN123456	\N	\N	\N
\.


--
-- TOC entry 3982 (class 0 OID 89807)
-- Dependencies: 282
-- Data for Name: tedarikci_parca; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tedarikci_parca (tedarikci_parca_id, tedarik_id, parca_id, tedarik_maliyeti) FROM stdin;
\.


--
-- TOC entry 3984 (class 0 OID 89814)
-- Dependencies: 284
-- Data for Name: tedarikci_puan; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tedarikci_puan (puan_id, tedarikci_id, puanlayan_kullanici_id, puan, yorum, tarih) FROM stdin;
\.


--
-- TOC entry 3988 (class 0 OID 105969)
-- Dependencies: 298
-- Data for Name: uretim_kaydi; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.uretim_kaydi (uretim_id, makine_id, vardiya_tarihi, vardiya_turu, planlanan_sure_dk, fiili_sure_dk, durus_sure_dk, teorik_uretim, gercek_uretim, hatali_uretim, olusturma_tarihi, kullanici_id) FROM stdin;
1	6	2026-04-28	Gündüz	480	433	47	1000	964	36	2026-04-29 13:06:28.773+00	\N
2	6	2026-04-27	Gündüz	480	438	42	1000	883	10	2026-04-29 13:06:28.817+00	\N
3	6	2026-04-26	Gündüz	480	429	51	1000	848	13	2026-04-29 13:06:28.834+00	\N
4	6	2026-04-25	Gündüz	480	429	51	1000	950	29	2026-04-29 13:06:28.847+00	\N
5	6	2026-04-24	Gündüz	480	445	35	1000	817	10	2026-04-29 13:06:28.861+00	\N
6	6	2026-04-23	Gündüz	480	473	7	1000	876	35	2026-04-29 13:06:28.874+00	\N
7	6	2026-04-22	Gündüz	480	434	46	1000	885	26	2026-04-29 13:06:28.89+00	\N
8	6	2026-04-21	Gündüz	480	448	32	1000	802	8	2026-04-29 13:06:28.904+00	\N
9	6	2026-04-20	Gündüz	480	426	54	1000	948	18	2026-04-29 13:06:28.917+00	\N
10	6	2026-04-19	Gündüz	480	476	4	1000	820	14	2026-04-29 13:06:28.926+00	\N
11	6	2026-04-18	Gündüz	480	435	45	1000	832	9	2026-04-29 13:06:28.936+00	\N
12	6	2026-04-17	Gündüz	480	431	49	1000	906	18	2026-04-29 13:06:28.946+00	\N
13	6	2026-04-16	Gündüz	480	421	59	1000	957	25	2026-04-29 13:06:28.958+00	\N
14	6	2026-04-15	Gündüz	480	473	7	1000	959	29	2026-04-29 13:06:28.983+00	\N
15	6	2026-04-14	Gündüz	480	444	36	1000	933	29	2026-04-29 13:06:28.996+00	\N
16	6	2026-04-13	Gündüz	480	472	8	1000	881	30	2026-04-29 13:06:29.009+00	\N
17	6	2026-04-12	Gündüz	480	430	50	1000	934	25	2026-04-29 13:06:29.023+00	\N
18	6	2026-04-11	Gündüz	480	456	24	1000	960	36	2026-04-29 13:06:29.035+00	\N
19	6	2026-04-10	Gündüz	480	421	59	1000	800	15	2026-04-29 13:06:29.047+00	\N
20	6	2026-04-09	Gündüz	480	464	16	1000	846	25	2026-04-29 13:06:29.059+00	\N
21	6	2026-04-08	Gündüz	480	458	22	1000	826	33	2026-04-29 13:06:29.071+00	\N
22	6	2026-04-07	Gündüz	480	478	2	1000	898	39	2026-04-29 13:06:29.084+00	\N
23	6	2026-04-06	Gündüz	480	440	40	1000	959	22	2026-04-29 13:06:29.099+00	\N
24	6	2026-04-05	Gündüz	480	451	29	1000	817	17	2026-04-29 13:06:29.115+00	\N
25	6	2026-04-04	Gündüz	480	439	41	1000	931	36	2026-04-29 13:06:29.135+00	\N
26	6	2026-04-03	Gündüz	480	431	49	1000	828	20	2026-04-29 13:06:29.153+00	\N
27	6	2026-04-02	Gündüz	480	477	3	1000	869	32	2026-04-29 13:06:29.169+00	\N
28	6	2026-04-01	Gündüz	480	434	46	1000	907	9	2026-04-29 13:06:29.183+00	\N
29	6	2026-03-31	Gündüz	480	446	34	1000	855	33	2026-04-29 13:06:29.197+00	\N
30	6	2026-03-30	Gündüz	480	431	49	1000	916	33	2026-04-29 13:06:29.213+00	\N
31	7	2026-04-28	Gündüz	480	453	27	1000	910	43	2026-04-29 13:06:29.234+00	\N
32	7	2026-04-27	Gündüz	480	469	11	1000	938	41	2026-04-29 13:06:29.249+00	\N
33	7	2026-04-26	Gündüz	480	423	57	1000	935	44	2026-04-29 13:06:29.262+00	\N
34	7	2026-04-25	Gündüz	480	434	46	1000	853	27	2026-04-29 13:06:29.275+00	\N
35	7	2026-04-24	Gündüz	480	426	54	1000	915	25	2026-04-29 13:06:29.288+00	\N
36	7	2026-04-23	Gündüz	480	427	53	1000	819	27	2026-04-29 13:06:29.301+00	\N
37	7	2026-04-22	Gündüz	480	438	42	1000	918	40	2026-04-29 13:06:29.314+00	\N
38	7	2026-04-21	Gündüz	480	470	10	1000	813	32	2026-04-29 13:06:29.328+00	\N
39	7	2026-04-20	Gündüz	480	448	32	1000	953	36	2026-04-29 13:06:29.341+00	\N
40	7	2026-04-19	Gündüz	480	426	54	1000	945	37	2026-04-29 13:06:29.356+00	\N
41	7	2026-04-18	Gündüz	480	472	8	1000	859	41	2026-04-29 13:06:29.368+00	\N
42	7	2026-04-17	Gündüz	480	439	41	1000	898	28	2026-04-29 13:06:29.381+00	\N
43	7	2026-04-16	Gündüz	480	453	27	1000	889	34	2026-04-29 13:06:29.394+00	\N
44	7	2026-04-15	Gündüz	480	459	21	1000	854	15	2026-04-29 13:06:29.407+00	\N
45	7	2026-04-14	Gündüz	480	432	48	1000	978	27	2026-04-29 13:06:29.42+00	\N
46	7	2026-04-13	Gündüz	480	465	15	1000	950	22	2026-04-29 13:06:29.434+00	\N
47	7	2026-04-12	Gündüz	480	464	16	1000	862	21	2026-04-29 13:06:29.447+00	\N
48	7	2026-04-11	Gündüz	480	464	16	1000	887	23	2026-04-29 13:06:29.459+00	\N
49	7	2026-04-10	Gündüz	480	422	58	1000	873	21	2026-04-29 13:06:29.472+00	\N
50	7	2026-04-09	Gündüz	480	443	37	1000	934	26	2026-04-29 13:06:29.485+00	\N
51	7	2026-04-08	Gündüz	480	461	19	1000	882	28	2026-04-29 13:06:29.503+00	\N
52	7	2026-04-07	Gündüz	480	473	7	1000	818	30	2026-04-29 13:06:29.518+00	\N
53	7	2026-04-06	Gündüz	480	452	28	1000	854	36	2026-04-29 13:06:29.535+00	\N
54	7	2026-04-05	Gündüz	480	473	7	1000	871	37	2026-04-29 13:06:29.551+00	\N
55	7	2026-04-04	Gündüz	480	454	26	1000	900	11	2026-04-29 13:06:29.563+00	\N
56	7	2026-04-03	Gündüz	480	422	58	1000	839	27	2026-04-29 13:06:29.58+00	\N
57	7	2026-04-02	Gündüz	480	439	41	1000	952	41	2026-04-29 13:06:29.601+00	\N
58	7	2026-04-01	Gündüz	480	474	6	1000	894	20	2026-04-29 13:06:29.62+00	\N
59	7	2026-03-31	Gündüz	480	426	54	1000	908	34	2026-04-29 13:06:29.637+00	\N
60	7	2026-03-30	Gündüz	480	434	46	1000	926	45	2026-04-29 13:06:29.652+00	\N
61	8	2026-04-28	Gündüz	480	443	37	1000	833	12	2026-04-29 13:06:29.665+00	\N
62	8	2026-04-27	Gündüz	480	475	5	1000	816	35	2026-04-29 13:06:29.679+00	\N
63	8	2026-04-26	Gündüz	480	465	15	1000	828	19	2026-04-29 13:06:29.695+00	\N
64	8	2026-04-25	Gündüz	480	470	10	1000	948	16	2026-04-29 13:06:29.71+00	\N
65	8	2026-04-24	Gündüz	480	438	42	1000	924	22	2026-04-29 13:06:29.723+00	\N
66	8	2026-04-23	Gündüz	480	445	35	1000	925	43	2026-04-29 13:06:29.738+00	\N
67	8	2026-04-22	Gündüz	480	452	28	1000	887	18	2026-04-29 13:06:29.752+00	\N
68	8	2026-04-21	Gündüz	480	465	15	1000	895	30	2026-04-29 13:06:29.769+00	\N
69	8	2026-04-20	Gündüz	480	467	13	1000	940	39	2026-04-29 13:06:29.786+00	\N
70	8	2026-04-19	Gündüz	480	459	21	1000	852	34	2026-04-29 13:06:29.801+00	\N
71	8	2026-04-18	Gündüz	480	462	18	1000	888	18	2026-04-29 13:06:29.816+00	\N
72	8	2026-04-17	Gündüz	480	444	36	1000	812	13	2026-04-29 13:06:29.834+00	\N
73	8	2026-04-16	Gündüz	480	477	3	1000	900	43	2026-04-29 13:06:29.848+00	\N
74	8	2026-04-15	Gündüz	480	429	51	1000	894	14	2026-04-29 13:06:29.867+00	\N
75	8	2026-04-14	Gündüz	480	447	33	1000	915	39	2026-04-29 13:06:29.888+00	\N
76	8	2026-04-13	Gündüz	480	477	3	1000	811	21	2026-04-29 13:06:29.909+00	\N
77	8	2026-04-12	Gündüz	480	420	60	1000	827	36	2026-04-29 13:06:29.93+00	\N
78	8	2026-04-11	Gündüz	480	420	60	1000	922	25	2026-04-29 13:06:29.953+00	\N
79	8	2026-04-10	Gündüz	480	448	32	1000	971	30	2026-04-29 13:06:29.972+00	\N
80	8	2026-04-09	Gündüz	480	465	15	1000	918	22	2026-04-29 13:06:29.991+00	\N
81	8	2026-04-08	Gündüz	480	446	34	1000	857	20	2026-04-29 13:06:30.01+00	\N
82	8	2026-04-07	Gündüz	480	435	45	1000	814	9	2026-04-29 13:06:30.028+00	\N
83	8	2026-04-06	Gündüz	480	433	47	1000	952	23	2026-04-29 13:06:30.044+00	\N
84	8	2026-04-05	Gündüz	480	477	3	1000	859	20	2026-04-29 13:06:30.063+00	\N
85	8	2026-04-04	Gündüz	480	467	13	1000	932	42	2026-04-29 13:06:30.091+00	\N
86	8	2026-04-03	Gündüz	480	473	7	1000	885	35	2026-04-29 13:06:30.108+00	\N
87	8	2026-04-02	Gündüz	480	431	49	1000	939	44	2026-04-29 13:06:30.125+00	\N
88	8	2026-04-01	Gündüz	480	434	46	1000	937	17	2026-04-29 13:06:30.143+00	\N
89	8	2026-03-31	Gündüz	480	431	49	1000	878	10	2026-04-29 13:06:30.162+00	\N
90	8	2026-03-30	Gündüz	480	477	3	1000	879	29	2026-04-29 13:06:30.189+00	\N
91	9	2026-04-28	Gündüz	480	452	28	1000	861	41	2026-04-29 13:06:30.205+00	\N
92	9	2026-04-27	Gündüz	480	437	43	1000	895	29	2026-04-29 13:06:30.223+00	\N
93	9	2026-04-26	Gündüz	480	478	2	1000	964	40	2026-04-29 13:06:30.241+00	\N
94	9	2026-04-25	Gündüz	480	423	57	1000	804	12	2026-04-29 13:06:30.259+00	\N
95	9	2026-04-24	Gündüz	480	466	14	1000	810	37	2026-04-29 13:06:30.274+00	\N
96	9	2026-04-23	Gündüz	480	471	9	1000	946	44	2026-04-29 13:06:30.287+00	\N
97	9	2026-04-22	Gündüz	480	478	2	1000	863	41	2026-04-29 13:06:30.306+00	\N
98	9	2026-04-21	Gündüz	480	443	37	1000	972	24	2026-04-29 13:06:30.328+00	\N
99	9	2026-04-20	Gündüz	480	426	54	1000	829	17	2026-04-29 13:06:30.35+00	\N
100	9	2026-04-19	Gündüz	480	461	19	1000	895	14	2026-04-29 13:06:30.37+00	\N
101	9	2026-04-18	Gündüz	480	431	49	1000	924	17	2026-04-29 13:06:30.39+00	\N
102	9	2026-04-17	Gündüz	480	450	30	1000	805	33	2026-04-29 13:06:30.41+00	\N
103	9	2026-04-16	Gündüz	480	466	14	1000	974	17	2026-04-29 13:06:30.43+00	\N
104	9	2026-04-15	Gündüz	480	480	0	1000	962	15	2026-04-29 13:06:30.448+00	\N
105	9	2026-04-14	Gündüz	480	424	56	1000	831	31	2026-04-29 13:06:30.461+00	\N
106	9	2026-04-13	Gündüz	480	446	34	1000	850	18	2026-04-29 13:06:30.479+00	\N
107	9	2026-04-12	Gündüz	480	438	42	1000	862	15	2026-04-29 13:06:30.496+00	\N
108	9	2026-04-11	Gündüz	480	473	7	1000	806	28	2026-04-29 13:06:30.514+00	\N
109	9	2026-04-10	Gündüz	480	450	30	1000	924	20	2026-04-29 13:06:30.541+00	\N
110	9	2026-04-09	Gündüz	480	455	25	1000	855	29	2026-04-29 13:06:30.557+00	\N
111	9	2026-04-08	Gündüz	480	434	46	1000	975	27	2026-04-29 13:06:30.574+00	\N
112	9	2026-04-07	Gündüz	480	474	6	1000	881	19	2026-04-29 13:06:30.59+00	\N
113	9	2026-04-06	Gündüz	480	427	53	1000	807	11	2026-04-29 13:06:30.606+00	\N
114	9	2026-04-05	Gündüz	480	429	51	1000	873	31	2026-04-29 13:06:30.624+00	\N
115	9	2026-04-04	Gündüz	480	436	44	1000	837	27	2026-04-29 13:06:30.642+00	\N
116	9	2026-04-03	Gündüz	480	437	43	1000	957	46	2026-04-29 13:06:30.66+00	\N
117	9	2026-04-02	Gündüz	480	460	20	1000	924	36	2026-04-29 13:06:30.676+00	\N
118	9	2026-04-01	Gündüz	480	425	55	1000	970	35	2026-04-29 13:06:30.694+00	\N
119	9	2026-03-31	Gündüz	480	457	23	1000	821	9	2026-04-29 13:06:30.711+00	\N
120	9	2026-03-30	Gündüz	480	465	15	1000	827	26	2026-04-29 13:06:30.728+00	\N
121	10	2026-04-28	Gündüz	480	474	6	1000	949	28	2026-04-29 13:06:30.747+00	\N
122	10	2026-04-27	Gündüz	480	473	7	1000	887	15	2026-04-29 13:06:30.764+00	\N
123	10	2026-04-26	Gündüz	480	470	10	1000	885	19	2026-04-29 13:06:30.78+00	\N
124	10	2026-04-25	Gündüz	480	462	18	1000	849	38	2026-04-29 13:06:30.794+00	\N
125	10	2026-04-24	Gündüz	480	456	24	1000	935	17	2026-04-29 13:06:30.81+00	\N
126	10	2026-04-23	Gündüz	480	445	35	1000	882	26	2026-04-29 13:06:30.826+00	\N
127	10	2026-04-22	Gündüz	480	433	47	1000	908	30	2026-04-29 13:06:30.841+00	\N
128	10	2026-04-21	Gündüz	480	470	10	1000	916	27	2026-04-29 13:06:30.857+00	\N
129	10	2026-04-20	Gündüz	480	440	40	1000	882	26	2026-04-29 13:06:30.874+00	\N
130	10	2026-04-19	Gündüz	480	420	60	1000	922	22	2026-04-29 13:06:30.89+00	\N
131	10	2026-04-18	Gündüz	480	476	4	1000	847	36	2026-04-29 13:06:30.906+00	\N
132	10	2026-04-17	Gündüz	480	432	48	1000	876	42	2026-04-29 13:06:30.923+00	\N
133	10	2026-04-16	Gündüz	480	428	52	1000	901	21	2026-04-29 13:06:30.94+00	\N
134	10	2026-04-15	Gündüz	480	428	52	1000	864	9	2026-04-29 13:06:30.954+00	\N
135	10	2026-04-14	Gündüz	480	446	34	1000	966	41	2026-04-29 13:06:30.97+00	\N
136	10	2026-04-13	Gündüz	480	461	19	1000	889	41	2026-04-29 13:06:30.988+00	\N
137	10	2026-04-12	Gündüz	480	448	32	1000	871	42	2026-04-29 13:06:31.004+00	\N
138	10	2026-04-11	Gündüz	480	464	16	1000	889	24	2026-04-29 13:06:31.018+00	\N
139	10	2026-04-10	Gündüz	480	476	4	1000	886	43	2026-04-29 13:06:31.034+00	\N
140	10	2026-04-09	Gündüz	480	471	9	1000	847	40	2026-04-29 13:06:31.049+00	\N
141	10	2026-04-08	Gündüz	480	433	47	1000	846	39	2026-04-29 13:06:31.068+00	\N
142	10	2026-04-07	Gündüz	480	431	49	1000	822	38	2026-04-29 13:06:31.084+00	\N
143	10	2026-04-06	Gündüz	480	469	11	1000	935	38	2026-04-29 13:06:31.101+00	\N
144	10	2026-04-05	Gündüz	480	461	19	1000	926	38	2026-04-29 13:06:31.118+00	\N
145	10	2026-04-04	Gündüz	480	426	54	1000	856	34	2026-04-29 13:06:31.135+00	\N
146	10	2026-04-03	Gündüz	480	472	8	1000	915	36	2026-04-29 13:06:31.152+00	\N
147	10	2026-04-02	Gündüz	480	471	9	1000	946	19	2026-04-29 13:06:31.169+00	\N
148	10	2026-04-01	Gündüz	480	458	22	1000	974	44	2026-04-29 13:06:31.186+00	\N
149	10	2026-03-31	Gündüz	480	473	7	1000	834	37	2026-04-29 13:06:31.202+00	\N
150	10	2026-03-30	Gündüz	480	450	30	1000	879	32	2026-04-29 13:06:31.217+00	\N
151	11	2026-04-28	Gündüz	480	463	17	1000	870	23	2026-04-29 13:06:31.236+00	\N
152	11	2026-04-27	Gündüz	480	427	53	1000	867	24	2026-04-29 13:06:31.253+00	\N
153	11	2026-04-26	Gündüz	480	451	29	1000	835	39	2026-04-29 13:06:31.269+00	\N
154	11	2026-04-25	Gündüz	480	452	28	1000	961	10	2026-04-29 13:06:31.284+00	\N
155	11	2026-04-24	Gündüz	480	472	8	1000	863	8	2026-04-29 13:06:31.307+00	\N
156	11	2026-04-23	Gündüz	480	438	42	1000	887	12	2026-04-29 13:06:31.32+00	\N
157	11	2026-04-22	Gündüz	480	459	21	1000	856	17	2026-04-29 13:06:31.336+00	\N
158	11	2026-04-21	Gündüz	480	454	26	1000	891	19	2026-04-29 13:06:31.35+00	\N
159	11	2026-04-20	Gündüz	480	456	24	1000	947	11	2026-04-29 13:06:31.373+00	\N
160	11	2026-04-19	Gündüz	480	465	15	1000	962	15	2026-04-29 13:06:31.389+00	\N
161	11	2026-04-18	Gündüz	480	431	49	1000	820	19	2026-04-29 13:06:31.405+00	\N
162	11	2026-04-17	Gündüz	480	427	53	1000	951	11	2026-04-29 13:06:31.422+00	\N
163	11	2026-04-16	Gündüz	480	451	29	1000	969	14	2026-04-29 13:06:31.439+00	\N
164	11	2026-04-15	Gündüz	480	452	28	1000	949	15	2026-04-29 13:06:31.455+00	\N
165	11	2026-04-14	Gündüz	480	430	50	1000	971	33	2026-04-29 13:06:31.471+00	\N
166	11	2026-04-13	Gündüz	480	429	51	1000	803	39	2026-04-29 13:06:31.488+00	\N
167	11	2026-04-12	Gündüz	480	434	46	1000	975	43	2026-04-29 13:06:31.504+00	\N
168	11	2026-04-11	Gündüz	480	456	24	1000	853	8	2026-04-29 13:06:31.52+00	\N
169	11	2026-04-10	Gündüz	480	468	12	1000	942	29	2026-04-29 13:06:31.539+00	\N
170	11	2026-04-09	Gündüz	480	457	23	1000	934	21	2026-04-29 13:06:31.556+00	\N
171	11	2026-04-08	Gündüz	480	465	15	1000	963	43	2026-04-29 13:06:31.572+00	\N
172	11	2026-04-07	Gündüz	480	457	23	1000	937	44	2026-04-29 13:06:31.589+00	\N
173	11	2026-04-06	Gündüz	480	465	15	1000	815	12	2026-04-29 13:06:31.605+00	\N
174	11	2026-04-05	Gündüz	480	445	35	1000	907	44	2026-04-29 13:06:31.622+00	\N
175	11	2026-04-04	Gündüz	480	427	53	1000	852	37	2026-04-29 13:06:31.637+00	\N
176	11	2026-04-03	Gündüz	480	455	25	1000	817	21	2026-04-29 13:06:31.652+00	\N
177	11	2026-04-02	Gündüz	480	450	30	1000	940	11	2026-04-29 13:06:31.668+00	\N
178	11	2026-04-01	Gündüz	480	448	32	1000	820	35	2026-04-29 13:06:31.683+00	\N
179	11	2026-03-31	Gündüz	480	476	4	1000	887	40	2026-04-29 13:06:31.699+00	\N
180	11	2026-03-30	Gündüz	480	439	41	1000	868	33	2026-04-29 13:06:31.711+00	\N
181	12	2026-04-28	Gündüz	480	425	55	1000	967	39	2026-04-29 13:06:31.726+00	\N
182	12	2026-04-27	Gündüz	480	439	41	1000	940	22	2026-04-29 13:06:31.741+00	\N
183	12	2026-04-26	Gündüz	480	429	51	1000	876	9	2026-04-29 13:06:31.755+00	\N
184	12	2026-04-25	Gündüz	480	454	26	1000	815	30	2026-04-29 13:06:31.769+00	\N
185	12	2026-04-24	Gündüz	480	441	39	1000	800	37	2026-04-29 13:06:31.781+00	\N
186	12	2026-04-23	Gündüz	480	453	27	1000	895	11	2026-04-29 13:06:31.794+00	\N
187	12	2026-04-22	Gündüz	480	439	41	1000	865	28	2026-04-29 13:06:31.808+00	\N
188	12	2026-04-21	Gündüz	480	455	25	1000	857	15	2026-04-29 13:06:31.821+00	\N
189	12	2026-04-20	Gündüz	480	452	28	1000	840	23	2026-04-29 13:06:31.833+00	\N
190	12	2026-04-19	Gündüz	480	474	6	1000	832	32	2026-04-29 13:06:31.848+00	\N
191	12	2026-04-18	Gündüz	480	464	16	1000	933	28	2026-04-29 13:06:31.861+00	\N
192	12	2026-04-17	Gündüz	480	475	5	1000	953	37	2026-04-29 13:06:31.874+00	\N
193	12	2026-04-16	Gündüz	480	430	50	1000	829	17	2026-04-29 13:06:31.886+00	\N
194	12	2026-04-15	Gündüz	480	444	36	1000	872	34	2026-04-29 13:06:31.899+00	\N
195	12	2026-04-14	Gündüz	480	468	12	1000	880	24	2026-04-29 13:06:31.913+00	\N
196	12	2026-04-13	Gündüz	480	433	47	1000	894	13	2026-04-29 13:06:31.928+00	\N
197	12	2026-04-12	Gündüz	480	453	27	1000	846	28	2026-04-29 13:06:31.942+00	\N
198	12	2026-04-11	Gündüz	480	456	24	1000	859	34	2026-04-29 13:06:31.957+00	\N
199	12	2026-04-10	Gündüz	480	449	31	1000	825	19	2026-04-29 13:06:31.971+00	\N
200	12	2026-04-09	Gündüz	480	475	5	1000	906	37	2026-04-29 13:06:31.986+00	\N
201	12	2026-04-08	Gündüz	480	441	39	1000	817	34	2026-04-29 13:06:32.002+00	\N
202	12	2026-04-07	Gündüz	480	473	7	1000	942	40	2026-04-29 13:06:32.018+00	\N
203	12	2026-04-06	Gündüz	480	422	58	1000	867	30	2026-04-29 13:06:32.033+00	\N
204	12	2026-04-05	Gündüz	480	462	18	1000	827	11	2026-04-29 13:06:32.05+00	\N
205	12	2026-04-04	Gündüz	480	467	13	1000	949	12	2026-04-29 13:06:32.065+00	\N
206	12	2026-04-03	Gündüz	480	467	13	1000	874	28	2026-04-29 13:06:32.08+00	\N
207	12	2026-04-02	Gündüz	480	456	24	1000	961	14	2026-04-29 13:06:32.095+00	\N
208	12	2026-04-01	Gündüz	480	436	44	1000	901	12	2026-04-29 13:06:32.109+00	\N
209	12	2026-03-31	Gündüz	480	469	11	1000	858	12	2026-04-29 13:06:32.123+00	\N
210	12	2026-03-30	Gündüz	480	465	15	1000	971	41	2026-04-29 13:06:32.136+00	\N
211	13	2026-04-28	Gündüz	480	443	37	1000	837	34	2026-04-29 13:06:32.149+00	\N
212	13	2026-04-27	Gündüz	480	451	29	1000	975	28	2026-04-29 13:06:32.162+00	\N
213	13	2026-04-26	Gündüz	480	467	13	1000	972	13	2026-04-29 13:06:32.175+00	\N
214	13	2026-04-25	Gündüz	480	474	6	1000	931	45	2026-04-29 13:06:32.188+00	\N
215	13	2026-04-24	Gündüz	480	477	3	1000	951	11	2026-04-29 13:06:32.2+00	\N
216	13	2026-04-23	Gündüz	480	452	28	1000	958	42	2026-04-29 13:06:32.213+00	\N
217	13	2026-04-22	Gündüz	480	445	35	1000	947	44	2026-04-29 13:06:32.226+00	\N
218	13	2026-04-21	Gündüz	480	447	33	1000	935	26	2026-04-29 13:06:32.238+00	\N
219	13	2026-04-20	Gündüz	480	436	44	1000	868	10	2026-04-29 13:06:32.251+00	\N
220	13	2026-04-19	Gündüz	480	427	53	1000	818	26	2026-04-29 13:06:32.263+00	\N
221	13	2026-04-18	Gündüz	480	442	38	1000	948	18	2026-04-29 13:06:32.275+00	\N
222	13	2026-04-17	Gündüz	480	444	36	1000	928	21	2026-04-29 13:06:32.286+00	\N
223	13	2026-04-16	Gündüz	480	443	37	1000	804	11	2026-04-29 13:06:32.299+00	\N
224	13	2026-04-15	Gündüz	480	455	25	1000	889	43	2026-04-29 13:06:32.313+00	\N
225	13	2026-04-14	Gündüz	480	465	15	1000	951	46	2026-04-29 13:06:32.327+00	\N
226	13	2026-04-13	Gündüz	480	448	32	1000	918	13	2026-04-29 13:06:32.341+00	\N
227	13	2026-04-12	Gündüz	480	468	12	1000	919	11	2026-04-29 13:06:32.353+00	\N
228	13	2026-04-11	Gündüz	480	469	11	1000	836	14	2026-04-29 13:06:32.368+00	\N
229	13	2026-04-10	Gündüz	480	424	56	1000	938	32	2026-04-29 13:06:32.382+00	\N
230	13	2026-04-09	Gündüz	480	463	17	1000	814	13	2026-04-29 13:06:32.396+00	\N
231	13	2026-04-08	Gündüz	480	467	13	1000	934	22	2026-04-29 13:06:32.413+00	\N
232	13	2026-04-07	Gündüz	480	446	34	1000	904	30	2026-04-29 13:06:32.429+00	\N
233	13	2026-04-06	Gündüz	480	457	23	1000	872	33	2026-04-29 13:06:32.445+00	\N
234	13	2026-04-05	Gündüz	480	420	60	1000	814	28	2026-04-29 13:06:32.46+00	\N
235	13	2026-04-04	Gündüz	480	436	44	1000	950	16	2026-04-29 13:06:32.476+00	\N
236	13	2026-04-03	Gündüz	480	456	24	1000	842	24	2026-04-29 13:06:32.493+00	\N
237	13	2026-04-02	Gündüz	480	480	0	1000	871	35	2026-04-29 13:06:32.51+00	\N
238	13	2026-04-01	Gündüz	480	447	33	1000	812	11	2026-04-29 13:06:32.52+00	\N
239	13	2026-03-31	Gündüz	480	467	13	1000	959	24	2026-04-29 13:06:32.535+00	\N
240	13	2026-03-30	Gündüz	480	434	46	1000	827	39	2026-04-29 13:06:32.552+00	\N
241	14	2026-04-28	Gündüz	480	433	47	1000	930	42	2026-04-29 13:06:32.567+00	\N
242	14	2026-04-27	Gündüz	480	476	4	1000	847	23	2026-04-29 13:06:32.578+00	\N
243	14	2026-04-26	Gündüz	480	436	44	1000	895	32	2026-04-29 13:06:32.588+00	\N
244	14	2026-04-25	Gündüz	480	449	31	1000	970	38	2026-04-29 13:06:32.603+00	\N
245	14	2026-04-24	Gündüz	480	476	4	1000	838	33	2026-04-29 13:06:32.618+00	\N
246	14	2026-04-23	Gündüz	480	448	32	1000	960	21	2026-04-29 13:06:32.635+00	\N
247	14	2026-04-22	Gündüz	480	465	15	1000	865	35	2026-04-29 13:06:32.651+00	\N
248	14	2026-04-21	Gündüz	480	438	42	1000	898	27	2026-04-29 13:06:32.666+00	\N
249	14	2026-04-20	Gündüz	480	428	52	1000	866	26	2026-04-29 13:06:32.683+00	\N
250	14	2026-04-19	Gündüz	480	444	36	1000	899	40	2026-04-29 13:06:32.696+00	\N
251	14	2026-04-18	Gündüz	480	472	8	1000	885	37	2026-04-29 13:06:32.707+00	\N
252	14	2026-04-17	Gündüz	480	463	17	1000	849	33	2026-04-29 13:06:32.72+00	\N
253	14	2026-04-16	Gündüz	480	466	14	1000	965	37	2026-04-29 13:06:32.734+00	\N
254	14	2026-04-15	Gündüz	480	474	6	1000	863	13	2026-04-29 13:06:32.748+00	\N
255	14	2026-04-14	Gündüz	480	445	35	1000	934	36	2026-04-29 13:06:32.763+00	\N
256	14	2026-04-13	Gündüz	480	423	57	1000	912	31	2026-04-29 13:06:32.778+00	\N
257	14	2026-04-12	Gündüz	480	461	19	1000	936	46	2026-04-29 13:06:32.792+00	\N
258	14	2026-04-11	Gündüz	480	426	54	1000	901	41	2026-04-29 13:06:32.806+00	\N
259	14	2026-04-10	Gündüz	480	439	41	1000	933	33	2026-04-29 13:06:32.82+00	\N
260	14	2026-04-09	Gündüz	480	455	25	1000	846	23	2026-04-29 13:06:32.833+00	\N
261	14	2026-04-08	Gündüz	480	430	50	1000	979	18	2026-04-29 13:06:32.849+00	\N
262	14	2026-04-07	Gündüz	480	423	57	1000	908	14	2026-04-29 13:06:32.865+00	\N
263	14	2026-04-06	Gündüz	480	475	5	1000	958	13	2026-04-29 13:06:32.882+00	\N
264	14	2026-04-05	Gündüz	480	439	41	1000	974	28	2026-04-29 13:06:32.902+00	\N
265	14	2026-04-04	Gündüz	480	445	35	1000	819	39	2026-04-29 13:06:32.916+00	\N
266	14	2026-04-03	Gündüz	480	442	38	1000	826	11	2026-04-29 13:06:32.932+00	\N
267	14	2026-04-02	Gündüz	480	435	45	1000	942	37	2026-04-29 13:06:32.946+00	\N
268	14	2026-04-01	Gündüz	480	444	36	1000	845	9	2026-04-29 13:06:32.963+00	\N
269	14	2026-03-31	Gündüz	480	427	53	1000	901	14	2026-04-29 13:06:32.98+00	\N
270	14	2026-03-30	Gündüz	480	430	50	1000	866	34	2026-04-29 13:06:32.995+00	\N
271	15	2026-04-28	Gündüz	480	441	39	1000	947	15	2026-04-29 13:06:33.015+00	\N
272	15	2026-04-27	Gündüz	480	421	59	1000	977	36	2026-04-29 13:06:33.031+00	\N
273	15	2026-04-26	Gündüz	480	441	39	1000	801	39	2026-04-29 13:06:33.047+00	\N
274	15	2026-04-25	Gündüz	480	431	49	1000	896	13	2026-04-29 13:06:33.064+00	\N
275	15	2026-04-24	Gündüz	480	479	1	1000	863	43	2026-04-29 13:06:33.082+00	\N
276	15	2026-04-23	Gündüz	480	423	57	1000	838	18	2026-04-29 13:06:33.102+00	\N
277	15	2026-04-22	Gündüz	480	470	10	1000	859	12	2026-04-29 13:06:33.119+00	\N
278	15	2026-04-21	Gündüz	480	473	7	1000	951	43	2026-04-29 13:06:33.137+00	\N
279	15	2026-04-20	Gündüz	480	424	56	1000	860	20	2026-04-29 13:06:33.154+00	\N
280	15	2026-04-19	Gündüz	480	480	0	1000	940	46	2026-04-29 13:06:33.17+00	\N
281	15	2026-04-18	Gündüz	480	471	9	1000	816	15	2026-04-29 13:06:33.18+00	\N
282	15	2026-04-17	Gündüz	480	473	7	1000	808	30	2026-04-29 13:06:33.197+00	\N
283	15	2026-04-16	Gündüz	480	439	41	1000	943	31	2026-04-29 13:06:33.212+00	\N
284	15	2026-04-15	Gündüz	480	425	55	1000	928	14	2026-04-29 13:06:33.227+00	\N
285	15	2026-04-14	Gündüz	480	463	17	1000	951	10	2026-04-29 13:06:33.242+00	\N
286	15	2026-04-13	Gündüz	480	466	14	1000	949	32	2026-04-29 13:06:33.257+00	\N
287	15	2026-04-12	Gündüz	480	454	26	1000	972	39	2026-04-29 13:06:33.27+00	\N
288	15	2026-04-11	Gündüz	480	423	57	1000	801	39	2026-04-29 13:06:33.283+00	\N
289	15	2026-04-10	Gündüz	480	458	22	1000	927	18	2026-04-29 13:06:33.296+00	\N
290	15	2026-04-09	Gündüz	480	463	17	1000	935	31	2026-04-29 13:06:33.31+00	\N
291	15	2026-04-08	Gündüz	480	476	4	1000	883	12	2026-04-29 13:06:33.323+00	\N
292	15	2026-04-07	Gündüz	480	478	2	1000	915	27	2026-04-29 13:06:33.335+00	\N
293	15	2026-04-06	Gündüz	480	426	54	1000	802	23	2026-04-29 13:06:33.348+00	\N
294	15	2026-04-05	Gündüz	480	452	28	1000	872	19	2026-04-29 13:06:33.36+00	\N
295	15	2026-04-04	Gündüz	480	474	6	1000	817	24	2026-04-29 13:06:33.371+00	\N
296	15	2026-04-03	Gündüz	480	432	48	1000	864	27	2026-04-29 13:06:33.383+00	\N
297	15	2026-04-02	Gündüz	480	445	35	1000	909	16	2026-04-29 13:06:33.395+00	\N
298	15	2026-04-01	Gündüz	480	477	3	1000	952	22	2026-04-29 13:06:33.407+00	\N
299	15	2026-03-31	Gündüz	480	420	60	1000	912	20	2026-04-29 13:06:33.418+00	\N
300	15	2026-03-30	Gündüz	480	464	16	1000	806	27	2026-04-29 13:06:33.431+00	\N
301	16	2026-04-28	Gündüz	480	461	19	1000	962	23	2026-04-29 13:06:33.444+00	\N
302	16	2026-04-27	Gündüz	480	480	0	1000	866	34	2026-04-29 13:06:33.457+00	\N
303	16	2026-04-26	Gündüz	480	430	50	1000	970	36	2026-04-29 13:06:33.465+00	\N
304	16	2026-04-25	Gündüz	480	474	6	1000	871	28	2026-04-29 13:06:33.479+00	\N
305	16	2026-04-24	Gündüz	480	462	18	1000	974	32	2026-04-29 13:06:33.494+00	\N
306	16	2026-04-23	Gündüz	480	422	58	1000	852	23	2026-04-29 13:06:33.507+00	\N
307	16	2026-04-22	Gündüz	480	420	60	1000	851	39	2026-04-29 13:06:33.522+00	\N
308	16	2026-04-21	Gündüz	480	467	13	1000	910	20	2026-04-29 13:06:33.535+00	\N
309	16	2026-04-20	Gündüz	480	445	35	1000	841	15	2026-04-29 13:06:33.548+00	\N
310	16	2026-04-19	Gündüz	480	449	31	1000	821	29	2026-04-29 13:06:33.56+00	\N
311	16	2026-04-18	Gündüz	480	435	45	1000	856	29	2026-04-29 13:06:33.575+00	\N
312	16	2026-04-17	Gündüz	480	451	29	1000	806	31	2026-04-29 13:06:33.59+00	\N
313	16	2026-04-16	Gündüz	480	453	27	1000	979	24	2026-04-29 13:06:33.606+00	\N
314	16	2026-04-15	Gündüz	480	453	27	1000	821	16	2026-04-29 13:06:33.621+00	\N
315	16	2026-04-14	Gündüz	480	451	29	1000	947	21	2026-04-29 13:06:33.635+00	\N
316	16	2026-04-13	Gündüz	480	476	4	1000	895	32	2026-04-29 13:06:33.653+00	\N
317	16	2026-04-12	Gündüz	480	421	59	1000	961	25	2026-04-29 13:06:33.713+00	\N
318	16	2026-04-11	Gündüz	480	436	44	1000	843	23	2026-04-29 13:06:33.73+00	\N
319	16	2026-04-10	Gündüz	480	473	7	1000	827	41	2026-04-29 13:06:33.744+00	\N
320	16	2026-04-09	Gündüz	480	456	24	1000	906	22	2026-04-29 13:06:33.756+00	\N
321	16	2026-04-08	Gündüz	480	463	17	1000	811	21	2026-04-29 13:06:33.769+00	\N
322	16	2026-04-07	Gündüz	480	461	19	1000	844	13	2026-04-29 13:06:33.784+00	\N
323	16	2026-04-06	Gündüz	480	447	33	1000	867	19	2026-04-29 13:06:33.797+00	\N
324	16	2026-04-05	Gündüz	480	457	23	1000	858	15	2026-04-29 13:06:33.813+00	\N
325	16	2026-04-04	Gündüz	480	449	31	1000	818	35	2026-04-29 13:06:33.827+00	\N
326	16	2026-04-03	Gündüz	480	463	17	1000	970	39	2026-04-29 13:06:33.841+00	\N
327	16	2026-04-02	Gündüz	480	447	33	1000	908	9	2026-04-29 13:06:33.856+00	\N
328	16	2026-04-01	Gündüz	480	456	24	1000	878	28	2026-04-29 13:06:33.871+00	\N
329	16	2026-03-31	Gündüz	480	426	54	1000	862	15	2026-04-29 13:06:33.886+00	\N
330	16	2026-03-30	Gündüz	480	480	0	1000	927	21	2026-04-29 13:06:33.9+00	\N
331	17	2026-04-28	Gündüz	480	430	50	1000	811	18	2026-04-29 13:06:33.91+00	\N
332	17	2026-04-27	Gündüz	480	454	26	1000	943	15	2026-04-29 13:06:33.923+00	\N
333	17	2026-04-26	Gündüz	480	430	50	1000	925	11	2026-04-29 13:06:33.937+00	\N
334	17	2026-04-25	Gündüz	480	452	28	1000	801	25	2026-04-29 13:06:33.952+00	\N
335	17	2026-04-24	Gündüz	480	463	17	1000	973	32	2026-04-29 13:06:33.967+00	\N
336	17	2026-04-23	Gündüz	480	469	11	1000	883	39	2026-04-29 13:06:33.983+00	\N
337	17	2026-04-22	Gündüz	480	452	28	1000	860	39	2026-04-29 13:06:33.999+00	\N
338	17	2026-04-21	Gündüz	480	468	12	1000	945	13	2026-04-29 13:06:34.014+00	\N
339	17	2026-04-20	Gündüz	480	447	33	1000	936	19	2026-04-29 13:06:34.03+00	\N
340	17	2026-04-19	Gündüz	480	457	23	1000	935	24	2026-04-29 13:06:34.044+00	\N
341	17	2026-04-18	Gündüz	480	472	8	1000	946	35	2026-04-29 13:06:34.059+00	\N
342	17	2026-04-17	Gündüz	480	465	15	1000	828	22	2026-04-29 13:06:34.075+00	\N
343	17	2026-04-16	Gündüz	480	465	15	1000	942	11	2026-04-29 13:06:34.091+00	\N
344	17	2026-04-15	Gündüz	480	462	18	1000	962	23	2026-04-29 13:06:34.106+00	\N
345	17	2026-04-14	Gündüz	480	431	49	1000	891	38	2026-04-29 13:06:34.122+00	\N
346	17	2026-04-13	Gündüz	480	440	40	1000	916	20	2026-04-29 13:06:34.137+00	\N
347	17	2026-04-12	Gündüz	480	445	35	1000	886	9	2026-04-29 13:06:34.15+00	\N
348	17	2026-04-11	Gündüz	480	440	40	1000	905	26	2026-04-29 13:06:34.164+00	\N
349	17	2026-04-10	Gündüz	480	475	5	1000	806	22	2026-04-29 13:06:34.177+00	\N
350	17	2026-04-09	Gündüz	480	480	0	1000	815	25	2026-04-29 13:06:34.192+00	\N
351	17	2026-04-08	Gündüz	480	470	10	1000	849	32	2026-04-29 13:06:34.2+00	\N
352	17	2026-04-07	Gündüz	480	454	26	1000	860	19	2026-04-29 13:06:34.213+00	\N
353	17	2026-04-06	Gündüz	480	468	12	1000	889	43	2026-04-29 13:06:34.225+00	\N
354	17	2026-04-05	Gündüz	480	470	10	1000	968	37	2026-04-29 13:06:34.238+00	\N
355	17	2026-04-04	Gündüz	480	425	55	1000	969	27	2026-04-29 13:06:34.252+00	\N
356	17	2026-04-03	Gündüz	480	443	37	1000	801	22	2026-04-29 13:06:34.266+00	\N
357	17	2026-04-02	Gündüz	480	458	22	1000	843	16	2026-04-29 13:06:34.28+00	\N
358	17	2026-04-01	Gündüz	480	470	10	1000	808	20	2026-04-29 13:06:34.296+00	\N
359	17	2026-03-31	Gündüz	480	472	8	1000	870	14	2026-04-29 13:06:34.311+00	\N
360	17	2026-03-30	Gündüz	480	474	6	1000	822	31	2026-04-29 13:06:34.325+00	\N
361	18	2026-04-28	Gündüz	480	430	50	1000	921	16	2026-04-29 13:06:34.341+00	\N
362	18	2026-04-27	Gündüz	480	480	0	1000	828	24	2026-04-29 13:06:34.354+00	\N
363	18	2026-04-26	Gündüz	480	437	43	1000	823	35	2026-04-29 13:06:34.364+00	\N
364	18	2026-04-25	Gündüz	480	453	27	1000	953	39	2026-04-29 13:06:34.379+00	\N
365	18	2026-04-24	Gündüz	480	479	1	1000	910	21	2026-04-29 13:06:34.392+00	\N
366	18	2026-04-23	Gündüz	480	476	4	1000	873	26	2026-04-29 13:06:34.408+00	\N
367	18	2026-04-22	Gündüz	480	423	57	1000	862	34	2026-04-29 13:06:34.423+00	\N
368	18	2026-04-21	Gündüz	480	449	31	1000	961	23	2026-04-29 13:06:34.44+00	\N
369	18	2026-04-20	Gündüz	480	424	56	1000	892	35	2026-04-29 13:06:34.453+00	\N
370	18	2026-04-19	Gündüz	480	458	22	1000	936	16	2026-04-29 13:06:34.468+00	\N
371	18	2026-04-18	Gündüz	480	444	36	1000	835	39	2026-04-29 13:06:34.48+00	\N
372	18	2026-04-17	Gündüz	480	446	34	1000	945	44	2026-04-29 13:06:34.494+00	\N
373	18	2026-04-16	Gündüz	480	464	16	1000	848	38	2026-04-29 13:06:34.511+00	\N
374	18	2026-04-15	Gündüz	480	422	58	1000	915	18	2026-04-29 13:06:34.523+00	\N
375	18	2026-04-14	Gündüz	480	439	41	1000	944	11	2026-04-29 13:06:34.535+00	\N
376	18	2026-04-13	Gündüz	480	440	40	1000	864	19	2026-04-29 13:06:34.546+00	\N
377	18	2026-04-12	Gündüz	480	420	60	1000	920	9	2026-04-29 13:06:34.557+00	\N
378	18	2026-04-11	Gündüz	480	456	24	1000	896	15	2026-04-29 13:06:34.567+00	\N
379	18	2026-04-10	Gündüz	480	458	22	1000	966	27	2026-04-29 13:06:34.575+00	\N
380	18	2026-04-09	Gündüz	480	465	15	1000	842	11	2026-04-29 13:06:34.585+00	\N
381	18	2026-04-08	Gündüz	480	421	59	1000	813	28	2026-04-29 13:06:34.595+00	\N
382	18	2026-04-07	Gündüz	480	480	0	1000	825	35	2026-04-29 13:06:34.607+00	\N
383	18	2026-04-06	Gündüz	480	467	13	1000	823	38	2026-04-29 13:06:34.616+00	\N
384	18	2026-04-05	Gündüz	480	465	15	1000	907	18	2026-04-29 13:06:34.631+00	\N
385	18	2026-04-04	Gündüz	480	469	11	1000	880	10	2026-04-29 13:06:34.647+00	\N
386	18	2026-04-03	Gündüz	480	443	37	1000	879	19	2026-04-29 13:06:34.663+00	\N
387	18	2026-04-02	Gündüz	480	472	8	1000	912	30	2026-04-29 13:06:34.677+00	\N
388	18	2026-04-01	Gündüz	480	477	3	1000	923	38	2026-04-29 13:06:34.689+00	\N
389	18	2026-03-31	Gündüz	480	435	45	1000	823	24	2026-04-29 13:06:34.705+00	\N
390	18	2026-03-30	Gündüz	480	479	1	1000	924	32	2026-04-29 13:06:34.721+00	\N
391	19	2026-04-28	Gündüz	480	455	25	1000	964	43	2026-04-29 13:06:34.737+00	\N
392	19	2026-04-27	Gündüz	480	451	29	1000	806	21	2026-04-29 13:06:34.754+00	\N
393	19	2026-04-26	Gündüz	480	438	42	1000	936	46	2026-04-29 13:06:34.772+00	\N
394	19	2026-04-25	Gündüz	480	457	23	1000	893	24	2026-04-29 13:06:34.787+00	\N
395	19	2026-04-24	Gündüz	480	478	2	1000	830	16	2026-04-29 13:06:34.8+00	\N
396	19	2026-04-23	Gündüz	480	460	20	1000	941	11	2026-04-29 13:06:34.81+00	\N
397	19	2026-04-22	Gündüz	480	453	27	1000	970	34	2026-04-29 13:06:34.82+00	\N
398	19	2026-04-21	Gündüz	480	424	56	1000	884	25	2026-04-29 13:06:34.829+00	\N
399	19	2026-04-20	Gündüz	480	450	30	1000	808	34	2026-04-29 13:06:34.841+00	\N
400	19	2026-04-19	Gündüz	480	480	0	1000	824	15	2026-04-29 13:06:34.854+00	\N
401	19	2026-04-18	Gündüz	480	468	12	1000	880	42	2026-04-29 13:06:34.863+00	\N
402	19	2026-04-17	Gündüz	480	425	55	1000	979	21	2026-04-29 13:06:34.88+00	\N
403	19	2026-04-16	Gündüz	480	459	21	1000	928	12	2026-04-29 13:06:34.899+00	\N
404	19	2026-04-15	Gündüz	480	473	7	1000	816	17	2026-04-29 13:06:34.917+00	\N
405	19	2026-04-14	Gündüz	480	424	56	1000	953	27	2026-04-29 13:06:34.933+00	\N
406	19	2026-04-13	Gündüz	480	460	20	1000	875	38	2026-04-29 13:06:34.947+00	\N
407	19	2026-04-12	Gündüz	480	439	41	1000	917	39	2026-04-29 13:06:34.957+00	\N
408	19	2026-04-11	Gündüz	480	453	27	1000	862	16	2026-04-29 13:06:34.965+00	\N
409	19	2026-04-10	Gündüz	480	427	53	1000	841	19	2026-04-29 13:06:34.979+00	\N
410	19	2026-04-09	Gündüz	480	449	31	1000	960	14	2026-04-29 13:06:34.991+00	\N
411	19	2026-04-08	Gündüz	480	442	38	1000	951	13	2026-04-29 13:06:35.004+00	\N
412	19	2026-04-07	Gündüz	480	453	27	1000	832	35	2026-04-29 13:06:35.019+00	\N
413	19	2026-04-06	Gündüz	480	441	39	1000	853	35	2026-04-29 13:06:35.036+00	\N
414	19	2026-04-05	Gündüz	480	457	23	1000	803	14	2026-04-29 13:06:35.052+00	\N
415	19	2026-04-04	Gündüz	480	480	0	1000	811	11	2026-04-29 13:06:35.067+00	\N
416	19	2026-04-03	Gündüz	480	450	30	1000	908	13	2026-04-29 13:06:35.08+00	\N
417	19	2026-04-02	Gündüz	480	431	49	1000	853	41	2026-04-29 13:06:35.1+00	\N
418	19	2026-04-01	Gündüz	480	449	31	1000	939	10	2026-04-29 13:06:35.115+00	\N
419	19	2026-03-31	Gündüz	480	446	34	1000	835	21	2026-04-29 13:06:35.132+00	\N
420	19	2026-03-30	Gündüz	480	452	28	1000	856	28	2026-04-29 13:06:35.146+00	\N
421	20	2026-04-28	Gündüz	480	427	53	1000	931	33	2026-04-29 13:06:35.164+00	\N
422	20	2026-04-27	Gündüz	480	465	15	1000	841	18	2026-04-29 13:06:35.181+00	\N
423	20	2026-04-26	Gündüz	480	425	55	1000	893	31	2026-04-29 13:06:35.198+00	\N
424	20	2026-04-25	Gündüz	480	440	40	1000	850	42	2026-04-29 13:06:35.213+00	\N
425	20	2026-04-24	Gündüz	480	447	33	1000	838	21	2026-04-29 13:06:35.229+00	\N
426	20	2026-04-23	Gündüz	480	468	12	1000	875	20	2026-04-29 13:06:35.249+00	\N
427	20	2026-04-22	Gündüz	480	446	34	1000	858	28	2026-04-29 13:06:35.267+00	\N
428	20	2026-04-21	Gündüz	480	447	33	1000	938	43	2026-04-29 13:06:35.284+00	\N
429	20	2026-04-20	Gündüz	480	462	18	1000	831	30	2026-04-29 13:06:35.302+00	\N
430	20	2026-04-19	Gündüz	480	457	23	1000	827	14	2026-04-29 13:06:35.32+00	\N
431	20	2026-04-18	Gündüz	480	467	13	1000	890	41	2026-04-29 13:06:35.335+00	\N
432	20	2026-04-17	Gündüz	480	467	13	1000	930	40	2026-04-29 13:06:35.344+00	\N
433	20	2026-04-16	Gündüz	480	464	16	1000	871	30	2026-04-29 13:06:35.357+00	\N
434	20	2026-04-15	Gündüz	480	455	25	1000	926	18	2026-04-29 13:06:35.373+00	\N
435	20	2026-04-14	Gündüz	480	470	10	1000	893	39	2026-04-29 13:06:35.388+00	\N
436	20	2026-04-13	Gündüz	480	477	3	1000	884	15	2026-04-29 13:06:35.402+00	\N
437	20	2026-04-12	Gündüz	480	426	54	1000	891	40	2026-04-29 13:06:35.416+00	\N
438	20	2026-04-11	Gündüz	480	456	24	1000	860	10	2026-04-29 13:06:35.432+00	\N
439	20	2026-04-10	Gündüz	480	477	3	1000	836	20	2026-04-29 13:06:35.446+00	\N
440	20	2026-04-09	Gündüz	480	432	48	1000	922	31	2026-04-29 13:06:35.457+00	\N
441	20	2026-04-08	Gündüz	480	478	2	1000	849	17	2026-04-29 13:06:35.465+00	\N
442	20	2026-04-07	Gündüz	480	423	57	1000	964	44	2026-04-29 13:06:35.475+00	\N
443	20	2026-04-06	Gündüz	480	426	54	1000	801	37	2026-04-29 13:06:35.488+00	\N
444	20	2026-04-05	Gündüz	480	471	9	1000	852	40	2026-04-29 13:06:35.5+00	\N
445	20	2026-04-04	Gündüz	480	466	14	1000	938	10	2026-04-29 13:06:35.512+00	\N
446	20	2026-04-03	Gündüz	480	449	31	1000	958	15	2026-04-29 13:06:35.524+00	\N
447	20	2026-04-02	Gündüz	480	422	58	1000	842	12	2026-04-29 13:06:35.54+00	\N
448	20	2026-04-01	Gündüz	480	420	60	1000	803	33	2026-04-29 13:06:35.554+00	\N
449	20	2026-03-31	Gündüz	480	433	47	1000	890	35	2026-04-29 13:06:35.569+00	\N
450	20	2026-03-30	Gündüz	480	444	36	1000	954	31	2026-04-29 13:06:35.581+00	\N
451	21	2026-04-28	Gündüz	480	426	54	1000	856	9	2026-04-29 13:06:35.593+00	\N
452	21	2026-04-27	Gündüz	480	447	33	1000	977	23	2026-04-29 13:06:35.607+00	\N
453	21	2026-04-26	Gündüz	480	469	11	1000	863	12	2026-04-29 13:06:35.622+00	\N
454	21	2026-04-25	Gündüz	480	480	0	1000	960	21	2026-04-29 13:06:35.637+00	\N
455	21	2026-04-24	Gündüz	480	458	22	1000	848	21	2026-04-29 13:06:35.648+00	\N
456	21	2026-04-23	Gündüz	480	457	23	1000	867	18	2026-04-29 13:06:35.663+00	\N
457	21	2026-04-22	Gündüz	480	479	1	1000	964	22	2026-04-29 13:06:35.679+00	\N
458	21	2026-04-21	Gündüz	480	427	53	1000	895	11	2026-04-29 13:06:35.692+00	\N
459	21	2026-04-20	Gündüz	480	471	9	1000	808	35	2026-04-29 13:06:35.705+00	\N
460	21	2026-04-19	Gündüz	480	439	41	1000	854	17	2026-04-29 13:06:35.714+00	\N
461	21	2026-04-18	Gündüz	480	422	58	1000	918	34	2026-04-29 13:06:35.723+00	\N
462	21	2026-04-17	Gündüz	480	420	60	1000	841	34	2026-04-29 13:06:35.731+00	\N
463	21	2026-04-16	Gündüz	480	433	47	1000	821	25	2026-04-29 13:06:35.741+00	\N
464	21	2026-04-15	Gündüz	480	461	19	1000	866	15	2026-04-29 13:06:35.751+00	\N
465	21	2026-04-14	Gündüz	480	472	8	1000	800	23	2026-04-29 13:06:35.764+00	\N
466	21	2026-04-13	Gündüz	480	427	53	1000	955	39	2026-04-29 13:06:35.779+00	\N
467	21	2026-04-12	Gündüz	480	480	0	1000	804	14	2026-04-29 13:06:35.792+00	\N
468	21	2026-04-11	Gündüz	480	444	36	1000	849	37	2026-04-29 13:06:35.804+00	\N
469	21	2026-04-10	Gündüz	480	446	34	1000	913	41	2026-04-29 13:06:35.82+00	\N
470	21	2026-04-09	Gündüz	480	434	46	1000	906	35	2026-04-29 13:06:35.837+00	\N
471	21	2026-04-08	Gündüz	480	432	48	1000	819	36	2026-04-29 13:06:35.855+00	\N
472	21	2026-04-07	Gündüz	480	443	37	1000	846	33	2026-04-29 13:06:35.873+00	\N
473	21	2026-04-06	Gündüz	480	436	44	1000	917	21	2026-04-29 13:06:35.892+00	\N
474	21	2026-04-05	Gündüz	480	466	14	1000	880	39	2026-04-29 13:06:35.904+00	\N
475	21	2026-04-04	Gündüz	480	436	44	1000	806	14	2026-04-29 13:06:35.913+00	\N
476	21	2026-04-03	Gündüz	480	460	20	1000	835	19	2026-04-29 13:06:35.922+00	\N
477	21	2026-04-02	Gündüz	480	477	3	1000	836	18	2026-04-29 13:06:35.931+00	\N
478	21	2026-04-01	Gündüz	480	472	8	1000	893	28	2026-04-29 13:06:35.94+00	\N
479	21	2026-03-31	Gündüz	480	420	60	1000	856	36	2026-04-29 13:06:35.95+00	\N
480	21	2026-03-30	Gündüz	480	468	12	1000	977	31	2026-04-29 13:06:35.963+00	\N
481	22	2026-04-28	Gündüz	480	445	35	1000	899	20	2026-04-29 13:06:35.978+00	\N
482	22	2026-04-27	Gündüz	480	460	20	1000	841	31	2026-04-29 13:06:35.995+00	\N
483	22	2026-04-26	Gündüz	480	459	21	1000	829	8	2026-04-29 13:06:36.01+00	\N
484	22	2026-04-25	Gündüz	480	437	43	1000	865	43	2026-04-29 13:06:36.027+00	\N
485	22	2026-04-24	Gündüz	480	433	47	1000	944	15	2026-04-29 13:06:36.045+00	\N
486	22	2026-04-23	Gündüz	480	435	45	1000	852	24	2026-04-29 13:06:36.059+00	\N
487	22	2026-04-22	Gündüz	480	442	38	1000	857	21	2026-04-29 13:06:36.07+00	\N
488	22	2026-04-21	Gündüz	480	425	55	1000	817	12	2026-04-29 13:06:36.08+00	\N
489	22	2026-04-20	Gündüz	480	468	12	1000	887	26	2026-04-29 13:06:36.088+00	\N
490	22	2026-04-19	Gündüz	480	443	37	1000	858	20	2026-04-29 13:06:36.098+00	\N
491	22	2026-04-18	Gündüz	480	441	39	1000	931	27	2026-04-29 13:06:36.111+00	\N
492	22	2026-04-17	Gündüz	480	455	25	1000	807	36	2026-04-29 13:06:36.127+00	\N
493	22	2026-04-16	Gündüz	480	473	7	1000	973	27	2026-04-29 13:06:36.144+00	\N
494	22	2026-04-15	Gündüz	480	471	9	1000	925	39	2026-04-29 13:06:36.163+00	\N
495	22	2026-04-14	Gündüz	480	424	56	1000	927	27	2026-04-29 13:06:36.182+00	\N
496	22	2026-04-13	Gündüz	480	450	30	1000	904	21	2026-04-29 13:06:36.198+00	\N
497	22	2026-04-12	Gündüz	480	436	44	1000	888	35	2026-04-29 13:06:36.211+00	\N
498	22	2026-04-11	Gündüz	480	422	58	1000	924	37	2026-04-29 13:06:36.221+00	\N
499	22	2026-04-10	Gündüz	480	435	45	1000	833	34	2026-04-29 13:06:36.23+00	\N
500	22	2026-04-09	Gündüz	480	448	32	1000	818	10	2026-04-29 13:06:36.239+00	\N
501	22	2026-04-08	Gündüz	480	437	43	1000	869	25	2026-04-29 13:06:36.25+00	\N
502	22	2026-04-07	Gündüz	480	457	23	1000	810	28	2026-04-29 13:06:36.262+00	\N
503	22	2026-04-06	Gündüz	480	468	12	1000	832	34	2026-04-29 13:06:36.276+00	\N
504	22	2026-04-05	Gündüz	480	440	40	1000	877	23	2026-04-29 13:06:36.293+00	\N
505	22	2026-04-04	Gündüz	480	457	23	1000	876	20	2026-04-29 13:06:36.31+00	\N
506	22	2026-04-03	Gündüz	480	428	52	1000	949	41	2026-04-29 13:06:36.326+00	\N
507	22	2026-04-02	Gündüz	480	431	49	1000	858	16	2026-04-29 13:06:36.34+00	\N
508	22	2026-04-01	Gündüz	480	470	10	1000	964	15	2026-04-29 13:06:36.353+00	\N
509	22	2026-03-31	Gündüz	480	469	11	1000	932	27	2026-04-29 13:06:36.368+00	\N
510	22	2026-03-30	Gündüz	480	425	55	1000	932	9	2026-04-29 13:06:36.383+00	\N
511	23	2026-04-28	Gündüz	480	451	29	1000	914	42	2026-04-29 13:06:36.398+00	\N
512	23	2026-04-27	Gündüz	480	432	48	1000	870	39	2026-04-29 13:06:36.412+00	\N
513	23	2026-04-26	Gündüz	480	421	59	1000	818	33	2026-04-29 13:06:36.424+00	\N
514	23	2026-04-25	Gündüz	480	436	44	1000	898	33	2026-04-29 13:06:36.437+00	\N
515	23	2026-04-24	Gündüz	480	449	31	1000	961	34	2026-04-29 13:06:36.45+00	\N
516	23	2026-04-23	Gündüz	480	435	45	1000	876	41	2026-04-29 13:06:36.463+00	\N
517	23	2026-04-22	Gündüz	480	459	21	1000	962	14	2026-04-29 13:06:36.477+00	\N
518	23	2026-04-21	Gündüz	480	449	31	1000	979	31	2026-04-29 13:06:36.495+00	\N
519	23	2026-04-20	Gündüz	480	463	17	1000	954	13	2026-04-29 13:06:36.513+00	\N
520	23	2026-04-19	Gündüz	480	469	11	1000	871	30	2026-04-29 13:06:36.526+00	\N
521	23	2026-04-18	Gündüz	480	454	26	1000	936	24	2026-04-29 13:06:36.539+00	\N
522	23	2026-04-17	Gündüz	480	450	30	1000	881	18	2026-04-29 13:06:36.551+00	\N
523	23	2026-04-16	Gündüz	480	451	29	1000	890	14	2026-04-29 13:06:36.566+00	\N
524	23	2026-04-15	Gündüz	480	471	9	1000	960	29	2026-04-29 13:06:36.582+00	\N
525	23	2026-04-14	Gündüz	480	435	45	1000	820	22	2026-04-29 13:06:36.598+00	\N
526	23	2026-04-13	Gündüz	480	454	26	1000	861	9	2026-04-29 13:06:36.613+00	\N
527	23	2026-04-12	Gündüz	480	443	37	1000	811	12	2026-04-29 13:06:36.629+00	\N
528	23	2026-04-11	Gündüz	480	437	43	1000	912	32	2026-04-29 13:06:36.644+00	\N
529	23	2026-04-10	Gündüz	480	462	18	1000	823	22	2026-04-29 13:06:36.656+00	\N
530	23	2026-04-09	Gündüz	480	472	8	1000	910	14	2026-04-29 13:06:36.667+00	\N
531	23	2026-04-08	Gündüz	480	427	53	1000	936	14	2026-04-29 13:06:36.679+00	\N
532	23	2026-04-07	Gündüz	480	427	53	1000	972	40	2026-04-29 13:06:36.693+00	\N
533	23	2026-04-06	Gündüz	480	424	56	1000	972	22	2026-04-29 13:06:36.708+00	\N
534	23	2026-04-05	Gündüz	480	466	14	1000	814	32	2026-04-29 13:06:36.76+00	\N
535	23	2026-04-04	Gündüz	480	476	4	1000	803	17	2026-04-29 13:06:36.787+00	\N
536	23	2026-04-03	Gündüz	480	456	24	1000	902	40	2026-04-29 13:06:36.8+00	\N
537	23	2026-04-02	Gündüz	480	450	30	1000	885	34	2026-04-29 13:06:36.811+00	\N
538	23	2026-04-01	Gündüz	480	429	51	1000	910	17	2026-04-29 13:06:36.823+00	\N
539	23	2026-03-31	Gündüz	480	477	3	1000	921	40	2026-04-29 13:06:36.836+00	\N
540	23	2026-03-30	Gündüz	480	421	59	1000	968	36	2026-04-29 13:06:36.847+00	\N
541	24	2026-04-28	Gündüz	480	478	2	1000	930	29	2026-04-29 13:06:36.861+00	\N
542	24	2026-04-27	Gündüz	480	428	52	1000	838	14	2026-04-29 13:06:36.876+00	\N
543	24	2026-04-26	Gündüz	480	468	12	1000	897	29	2026-04-29 13:06:36.895+00	\N
544	24	2026-04-25	Gündüz	480	445	35	1000	866	9	2026-04-29 13:06:36.915+00	\N
545	24	2026-04-24	Gündüz	480	439	41	1000	902	41	2026-04-29 13:06:36.935+00	\N
546	24	2026-04-23	Gündüz	480	438	42	1000	962	35	2026-04-29 13:06:36.955+00	\N
547	24	2026-04-22	Gündüz	480	433	47	1000	944	12	2026-04-29 13:06:36.975+00	\N
548	24	2026-04-21	Gündüz	480	450	30	1000	914	9	2026-04-29 13:06:36.991+00	\N
549	24	2026-04-20	Gündüz	480	471	9	1000	977	44	2026-04-29 13:06:37.011+00	\N
550	24	2026-04-19	Gündüz	480	474	6	1000	800	32	2026-04-29 13:06:37.028+00	\N
551	24	2026-04-18	Gündüz	480	433	47	1000	958	28	2026-04-29 13:06:37.046+00	\N
552	24	2026-04-17	Gündüz	480	439	41	1000	827	24	2026-04-29 13:06:37.067+00	\N
553	24	2026-04-16	Gündüz	480	444	36	1000	947	19	2026-04-29 13:06:37.087+00	\N
554	24	2026-04-15	Gündüz	480	423	57	1000	948	34	2026-04-29 13:06:37.103+00	\N
555	24	2026-04-14	Gündüz	480	455	25	1000	950	20	2026-04-29 13:06:37.122+00	\N
556	24	2026-04-13	Gündüz	480	435	45	1000	891	17	2026-04-29 13:06:37.14+00	\N
557	24	2026-04-12	Gündüz	480	478	2	1000	882	43	2026-04-29 13:06:37.16+00	\N
558	24	2026-04-11	Gündüz	480	423	57	1000	912	40	2026-04-29 13:06:37.179+00	\N
559	24	2026-04-10	Gündüz	480	436	44	1000	844	29	2026-04-29 13:06:37.194+00	\N
560	24	2026-04-09	Gündüz	480	439	41	1000	857	25	2026-04-29 13:06:37.205+00	\N
561	24	2026-04-08	Gündüz	480	421	59	1000	958	45	2026-04-29 13:06:37.221+00	\N
562	24	2026-04-07	Gündüz	480	460	20	1000	805	36	2026-04-29 13:06:37.241+00	\N
563	24	2026-04-06	Gündüz	480	477	3	1000	977	37	2026-04-29 13:06:37.259+00	\N
564	24	2026-04-05	Gündüz	480	448	32	1000	977	29	2026-04-29 13:06:37.279+00	\N
565	24	2026-04-04	Gündüz	480	473	7	1000	946	43	2026-04-29 13:06:37.297+00	\N
566	24	2026-04-03	Gündüz	480	422	58	1000	891	17	2026-04-29 13:06:37.328+00	\N
567	24	2026-04-02	Gündüz	480	449	31	1000	907	30	2026-04-29 13:06:37.338+00	\N
568	24	2026-04-01	Gündüz	480	473	7	1000	852	19	2026-04-29 13:06:37.347+00	\N
569	24	2026-03-31	Gündüz	480	480	0	1000	893	28	2026-04-29 13:06:37.356+00	\N
570	24	2026-03-30	Gündüz	480	438	42	1000	821	9	2026-04-29 13:06:37.365+00	\N
571	25	2026-04-28	Gündüz	480	475	5	1000	848	10	2026-04-29 13:06:37.382+00	\N
572	25	2026-04-27	Gündüz	480	463	17	1000	890	37	2026-04-29 13:06:37.401+00	\N
573	25	2026-04-26	Gündüz	480	429	51	1000	833	11	2026-04-29 13:06:37.419+00	\N
574	25	2026-04-25	Gündüz	480	420	60	1000	974	47	2026-04-29 13:06:37.438+00	\N
575	25	2026-04-24	Gündüz	480	430	50	1000	955	47	2026-04-29 13:06:37.454+00	\N
576	25	2026-04-23	Gündüz	480	457	23	1000	978	14	2026-04-29 13:06:37.466+00	\N
577	25	2026-04-22	Gündüz	480	444	36	1000	926	36	2026-04-29 13:06:37.476+00	\N
578	25	2026-04-21	Gündüz	480	480	0	1000	929	45	2026-04-29 13:06:37.485+00	\N
579	25	2026-04-20	Gündüz	480	461	19	1000	809	10	2026-04-29 13:06:37.491+00	\N
580	25	2026-04-19	Gündüz	480	445	35	1000	946	28	2026-04-29 13:06:37.5+00	\N
581	25	2026-04-18	Gündüz	480	462	18	1000	944	16	2026-04-29 13:06:37.51+00	\N
582	25	2026-04-17	Gündüz	480	449	31	1000	928	32	2026-04-29 13:06:37.526+00	\N
583	25	2026-04-16	Gündüz	480	478	2	1000	853	34	2026-04-29 13:06:37.541+00	\N
584	25	2026-04-15	Gündüz	480	437	43	1000	974	45	2026-04-29 13:06:37.558+00	\N
585	25	2026-04-14	Gündüz	480	422	58	1000	873	29	2026-04-29 13:06:37.576+00	\N
586	25	2026-04-13	Gündüz	480	468	12	1000	957	46	2026-04-29 13:06:37.595+00	\N
587	25	2026-04-12	Gündüz	480	442	38	1000	935	29	2026-04-29 13:06:37.61+00	\N
588	25	2026-04-11	Gündüz	480	475	5	1000	973	21	2026-04-29 13:06:37.625+00	\N
589	25	2026-04-10	Gündüz	480	472	8	1000	929	37	2026-04-29 13:06:37.638+00	\N
590	25	2026-04-09	Gündüz	480	478	2	1000	819	10	2026-04-29 13:06:37.648+00	\N
591	25	2026-04-08	Gündüz	480	432	48	1000	883	28	2026-04-29 13:06:37.661+00	\N
592	25	2026-04-07	Gündüz	480	429	51	1000	920	21	2026-04-29 13:06:37.675+00	\N
593	25	2026-04-06	Gündüz	480	468	12	1000	964	16	2026-04-29 13:06:37.69+00	\N
594	25	2026-04-05	Gündüz	480	424	56	1000	899	16	2026-04-29 13:06:37.704+00	\N
595	25	2026-04-04	Gündüz	480	476	4	1000	973	10	2026-04-29 13:06:37.719+00	\N
596	25	2026-04-03	Gündüz	480	472	8	1000	817	22	2026-04-29 13:06:37.732+00	\N
597	25	2026-04-02	Gündüz	480	430	50	1000	965	40	2026-04-29 13:06:37.744+00	\N
598	25	2026-04-01	Gündüz	480	457	23	1000	967	21	2026-04-29 13:06:37.756+00	\N
599	25	2026-03-31	Gündüz	480	439	41	1000	916	39	2026-04-29 13:06:37.769+00	\N
600	25	2026-03-30	Gündüz	480	458	22	1000	852	28	2026-04-29 13:06:37.784+00	\N
601	26	2026-04-28	Gündüz	480	437	43	1000	852	26	2026-04-29 13:06:37.797+00	\N
602	26	2026-04-27	Gündüz	480	422	58	1000	922	30	2026-04-29 13:06:37.809+00	\N
603	26	2026-04-26	Gündüz	480	441	39	1000	844	8	2026-04-29 13:06:37.821+00	\N
604	26	2026-04-25	Gündüz	480	442	38	1000	947	40	2026-04-29 13:06:37.833+00	\N
605	26	2026-04-24	Gündüz	480	425	55	1000	932	19	2026-04-29 13:06:37.845+00	\N
606	26	2026-04-23	Gündüz	480	447	33	1000	976	32	2026-04-29 13:06:37.859+00	\N
607	26	2026-04-22	Gündüz	480	429	51	1000	858	34	2026-04-29 13:06:37.873+00	\N
608	26	2026-04-21	Gündüz	480	435	45	1000	918	17	2026-04-29 13:06:37.885+00	\N
609	26	2026-04-20	Gündüz	480	463	17	1000	826	31	2026-04-29 13:06:37.901+00	\N
610	26	2026-04-19	Gündüz	480	463	17	1000	915	11	2026-04-29 13:06:37.917+00	\N
611	26	2026-04-18	Gündüz	480	430	50	1000	811	37	2026-04-29 13:06:37.934+00	\N
612	26	2026-04-17	Gündüz	480	426	54	1000	851	25	2026-04-29 13:06:37.949+00	\N
613	26	2026-04-16	Gündüz	480	432	48	1000	963	38	2026-04-29 13:06:37.966+00	\N
614	26	2026-04-15	Gündüz	480	420	60	1000	911	18	2026-04-29 13:06:37.985+00	\N
615	26	2026-04-14	Gündüz	480	438	42	1000	910	33	2026-04-29 13:06:38.002+00	\N
616	26	2026-04-13	Gündüz	480	447	33	1000	819	37	2026-04-29 13:06:38.023+00	\N
617	26	2026-04-12	Gündüz	480	426	54	1000	800	36	2026-04-29 13:06:38.038+00	\N
618	26	2026-04-11	Gündüz	480	459	21	1000	813	19	2026-04-29 13:06:38.055+00	\N
619	26	2026-04-10	Gündüz	480	458	22	1000	977	33	2026-04-29 13:06:38.068+00	\N
620	26	2026-04-09	Gündüz	480	463	17	1000	918	11	2026-04-29 13:06:38.078+00	\N
621	26	2026-04-08	Gündüz	480	421	59	1000	884	22	2026-04-29 13:06:38.087+00	\N
622	26	2026-04-07	Gündüz	480	444	36	1000	935	30	2026-04-29 13:06:38.096+00	\N
623	26	2026-04-06	Gündüz	480	448	32	1000	946	16	2026-04-29 13:06:38.105+00	\N
624	26	2026-04-05	Gündüz	480	450	30	1000	925	28	2026-04-29 13:06:38.118+00	\N
625	26	2026-04-04	Gündüz	480	443	37	1000	886	41	2026-04-29 13:06:38.13+00	\N
626	26	2026-04-03	Gündüz	480	422	58	1000	841	40	2026-04-29 13:06:38.144+00	\N
627	26	2026-04-02	Gündüz	480	425	55	1000	906	26	2026-04-29 13:06:38.157+00	\N
628	26	2026-04-01	Gündüz	480	430	50	1000	841	22	2026-04-29 13:06:38.169+00	\N
629	26	2026-03-31	Gündüz	480	441	39	1000	959	42	2026-04-29 13:06:38.182+00	\N
630	26	2026-03-30	Gündüz	480	473	7	1000	955	37	2026-04-29 13:06:38.195+00	\N
631	27	2026-04-28	Gündüz	480	443	37	1000	978	44	2026-04-29 13:06:38.207+00	\N
632	27	2026-04-27	Gündüz	480	427	53	1000	851	18	2026-04-29 13:06:38.219+00	\N
633	27	2026-04-26	Gündüz	480	469	11	1000	853	23	2026-04-29 13:06:38.231+00	\N
634	27	2026-04-25	Gündüz	480	471	9	1000	978	22	2026-04-29 13:06:38.241+00	\N
635	27	2026-04-24	Gündüz	480	432	48	1000	962	31	2026-04-29 13:06:38.252+00	\N
636	27	2026-04-23	Gündüz	480	454	26	1000	912	12	2026-04-29 13:06:38.263+00	\N
637	27	2026-04-22	Gündüz	480	459	21	1000	822	32	2026-04-29 13:06:38.275+00	\N
638	27	2026-04-21	Gündüz	480	476	4	1000	885	43	2026-04-29 13:06:38.288+00	\N
639	27	2026-04-20	Gündüz	480	433	47	1000	838	13	2026-04-29 13:06:38.299+00	\N
640	27	2026-04-19	Gündüz	480	475	5	1000	848	36	2026-04-29 13:06:38.31+00	\N
641	27	2026-04-18	Gündüz	480	422	58	1000	913	17	2026-04-29 13:06:38.322+00	\N
642	27	2026-04-17	Gündüz	480	429	51	1000	892	39	2026-04-29 13:06:38.334+00	\N
643	27	2026-04-16	Gündüz	480	471	9	1000	839	20	2026-04-29 13:06:38.347+00	\N
644	27	2026-04-15	Gündüz	480	442	38	1000	804	39	2026-04-29 13:06:38.358+00	\N
645	27	2026-04-14	Gündüz	480	473	7	1000	848	18	2026-04-29 13:06:38.367+00	\N
646	27	2026-04-13	Gündüz	480	446	34	1000	877	38	2026-04-29 13:06:38.375+00	\N
647	27	2026-04-12	Gündüz	480	463	17	1000	954	28	2026-04-29 13:06:38.387+00	\N
648	27	2026-04-11	Gündüz	480	427	53	1000	937	15	2026-04-29 13:06:38.397+00	\N
649	27	2026-04-10	Gündüz	480	464	16	1000	895	43	2026-04-29 13:06:38.407+00	\N
650	27	2026-04-09	Gündüz	480	465	15	1000	861	30	2026-04-29 13:06:38.418+00	\N
651	27	2026-04-08	Gündüz	480	438	42	1000	873	29	2026-04-29 13:06:38.427+00	\N
652	27	2026-04-07	Gündüz	480	438	42	1000	816	40	2026-04-29 13:06:38.436+00	\N
653	27	2026-04-06	Gündüz	480	439	41	1000	875	28	2026-04-29 13:06:38.446+00	\N
654	27	2026-04-05	Gündüz	480	423	57	1000	873	35	2026-04-29 13:06:38.457+00	\N
655	27	2026-04-04	Gündüz	480	476	4	1000	823	29	2026-04-29 13:06:38.469+00	\N
656	27	2026-04-03	Gündüz	480	475	5	1000	804	17	2026-04-29 13:06:38.478+00	\N
657	27	2026-04-02	Gündüz	480	470	10	1000	935	9	2026-04-29 13:06:38.486+00	\N
658	27	2026-04-01	Gündüz	480	465	15	1000	853	20	2026-04-29 13:06:38.494+00	\N
659	27	2026-03-31	Gündüz	480	431	49	1000	876	23	2026-04-29 13:06:38.505+00	\N
660	27	2026-03-30	Gündüz	480	434	46	1000	899	26	2026-04-29 13:06:38.515+00	\N
661	28	2026-04-28	Gündüz	480	433	47	1000	844	10	2026-04-29 13:06:38.527+00	\N
662	28	2026-04-27	Gündüz	480	474	6	1000	811	8	2026-04-29 13:06:38.538+00	\N
663	28	2026-04-26	Gündüz	480	456	24	1000	977	47	2026-04-29 13:06:38.552+00	\N
664	28	2026-04-25	Gündüz	480	420	60	1000	834	17	2026-04-29 13:06:38.562+00	\N
665	28	2026-04-24	Gündüz	480	420	60	1000	855	17	2026-04-29 13:06:38.572+00	\N
666	28	2026-04-23	Gündüz	480	475	5	1000	851	32	2026-04-29 13:06:38.584+00	\N
667	28	2026-04-22	Gündüz	480	421	59	1000	877	41	2026-04-29 13:06:38.597+00	\N
668	28	2026-04-21	Gündüz	480	460	20	1000	960	12	2026-04-29 13:06:38.61+00	\N
669	28	2026-04-20	Gündüz	480	431	49	1000	884	40	2026-04-29 13:06:38.621+00	\N
670	28	2026-04-19	Gündüz	480	453	27	1000	832	31	2026-04-29 13:06:38.631+00	\N
671	28	2026-04-18	Gündüz	480	452	28	1000	817	25	2026-04-29 13:06:38.641+00	\N
672	28	2026-04-17	Gündüz	480	463	17	1000	916	11	2026-04-29 13:06:38.652+00	\N
673	28	2026-04-16	Gündüz	480	443	37	1000	811	37	2026-04-29 13:06:38.663+00	\N
674	28	2026-04-15	Gündüz	480	475	5	1000	949	29	2026-04-29 13:06:38.677+00	\N
675	28	2026-04-14	Gündüz	480	421	59	1000	940	25	2026-04-29 13:06:38.691+00	\N
676	28	2026-04-13	Gündüz	480	452	28	1000	888	34	2026-04-29 13:06:38.704+00	\N
677	28	2026-04-12	Gündüz	480	478	2	1000	830	26	2026-04-29 13:06:38.718+00	\N
678	28	2026-04-11	Gündüz	480	443	37	1000	940	36	2026-04-29 13:06:38.733+00	\N
679	28	2026-04-10	Gündüz	480	444	36	1000	833	20	2026-04-29 13:06:38.75+00	\N
680	28	2026-04-09	Gündüz	480	439	41	1000	937	28	2026-04-29 13:06:38.762+00	\N
681	28	2026-04-08	Gündüz	480	433	47	1000	824	14	2026-04-29 13:06:38.778+00	\N
682	28	2026-04-07	Gündüz	480	451	29	1000	879	30	2026-04-29 13:06:38.793+00	\N
683	28	2026-04-06	Gündüz	480	434	46	1000	946	19	2026-04-29 13:06:38.809+00	\N
684	28	2026-04-05	Gündüz	480	462	18	1000	955	19	2026-04-29 13:06:38.822+00	\N
685	28	2026-04-04	Gündüz	480	420	60	1000	829	39	2026-04-29 13:06:38.834+00	\N
686	28	2026-04-03	Gündüz	480	441	39	1000	821	9	2026-04-29 13:06:38.844+00	\N
687	28	2026-04-02	Gündüz	480	463	17	1000	904	30	2026-04-29 13:06:38.855+00	\N
688	28	2026-04-01	Gündüz	480	474	6	1000	967	22	2026-04-29 13:06:38.866+00	\N
689	28	2026-03-31	Gündüz	480	457	23	1000	941	14	2026-04-29 13:06:38.879+00	\N
690	28	2026-03-30	Gündüz	480	420	60	1000	969	45	2026-04-29 13:06:38.892+00	\N
691	29	2026-04-28	Gündüz	480	434	46	1000	945	35	2026-04-29 13:06:38.904+00	\N
692	29	2026-04-27	Gündüz	480	468	12	1000	865	23	2026-04-29 13:06:38.919+00	\N
693	29	2026-04-26	Gündüz	480	453	27	1000	949	33	2026-04-29 13:06:38.937+00	\N
694	29	2026-04-25	Gündüz	480	421	59	1000	862	17	2026-04-29 13:06:38.948+00	\N
695	29	2026-04-24	Gündüz	480	426	54	1000	844	9	2026-04-29 13:06:38.959+00	\N
696	29	2026-04-23	Gündüz	480	464	16	1000	947	43	2026-04-29 13:06:38.972+00	\N
697	29	2026-04-22	Gündüz	480	425	55	1000	966	28	2026-04-29 13:06:38.983+00	\N
698	29	2026-04-21	Gündüz	480	438	42	1000	964	10	2026-04-29 13:06:38.995+00	\N
699	29	2026-04-20	Gündüz	480	461	19	1000	862	28	2026-04-29 13:06:39.006+00	\N
700	29	2026-04-19	Gündüz	480	431	49	1000	881	16	2026-04-29 13:06:39.019+00	\N
701	29	2026-04-18	Gündüz	480	434	46	1000	866	36	2026-04-29 13:06:39.032+00	\N
702	29	2026-04-17	Gündüz	480	444	36	1000	866	25	2026-04-29 13:06:39.046+00	\N
703	29	2026-04-16	Gündüz	480	463	17	1000	805	37	2026-04-29 13:06:39.06+00	\N
704	29	2026-04-15	Gündüz	480	470	10	1000	882	43	2026-04-29 13:06:39.074+00	\N
705	29	2026-04-14	Gündüz	480	475	5	1000	850	18	2026-04-29 13:06:39.088+00	\N
706	29	2026-04-13	Gündüz	480	432	48	1000	950	20	2026-04-29 13:06:39.102+00	\N
707	29	2026-04-12	Gündüz	480	479	1	1000	974	24	2026-04-29 13:06:39.117+00	\N
708	29	2026-04-11	Gündüz	480	467	13	1000	891	37	2026-04-29 13:06:39.13+00	\N
709	29	2026-04-10	Gündüz	480	458	22	1000	851	26	2026-04-29 13:06:39.143+00	\N
710	29	2026-04-09	Gündüz	480	452	28	1000	897	15	2026-04-29 13:06:39.155+00	\N
711	29	2026-04-08	Gündüz	480	442	38	1000	949	18	2026-04-29 13:06:39.165+00	\N
712	29	2026-04-07	Gündüz	480	466	14	1000	831	27	2026-04-29 13:06:39.175+00	\N
713	29	2026-04-06	Gündüz	480	476	4	1000	852	30	2026-04-29 13:06:39.186+00	\N
714	29	2026-04-05	Gündüz	480	452	28	1000	910	37	2026-04-29 13:06:39.196+00	\N
715	29	2026-04-04	Gündüz	480	427	53	1000	966	26	2026-04-29 13:06:39.206+00	\N
716	29	2026-04-03	Gündüz	480	450	30	1000	865	27	2026-04-29 13:06:39.214+00	\N
717	29	2026-04-02	Gündüz	480	425	55	1000	876	15	2026-04-29 13:06:39.223+00	\N
718	29	2026-04-01	Gündüz	480	476	4	1000	850	30	2026-04-29 13:06:39.234+00	\N
719	29	2026-03-31	Gündüz	480	468	12	1000	955	10	2026-04-29 13:06:39.245+00	\N
720	29	2026-03-30	Gündüz	480	452	28	1000	835	28	2026-04-29 13:06:39.256+00	\N
721	30	2026-04-28	Gündüz	480	423	57	1000	975	15	2026-04-29 13:06:39.269+00	\N
722	30	2026-04-27	Gündüz	480	421	59	1000	873	35	2026-04-29 13:06:39.282+00	\N
723	30	2026-04-26	Gündüz	480	428	52	1000	953	9	2026-04-29 13:06:39.295+00	\N
724	30	2026-04-25	Gündüz	480	430	50	1000	951	30	2026-04-29 13:06:39.307+00	\N
725	30	2026-04-24	Gündüz	480	479	1	1000	955	33	2026-04-29 13:06:39.319+00	\N
726	30	2026-04-23	Gündüz	480	431	49	1000	850	18	2026-04-29 13:06:39.334+00	\N
727	30	2026-04-22	Gündüz	480	451	29	1000	936	42	2026-04-29 13:06:39.345+00	\N
728	30	2026-04-21	Gündüz	480	476	4	1000	909	29	2026-04-29 13:06:39.355+00	\N
729	30	2026-04-20	Gündüz	480	427	53	1000	887	37	2026-04-29 13:06:39.367+00	\N
730	30	2026-04-19	Gündüz	480	448	32	1000	977	41	2026-04-29 13:06:39.378+00	\N
731	30	2026-04-18	Gündüz	480	470	10	1000	857	11	2026-04-29 13:06:39.388+00	\N
732	30	2026-04-17	Gündüz	480	474	6	1000	817	39	2026-04-29 13:06:39.398+00	\N
733	30	2026-04-16	Gündüz	480	433	47	1000	827	14	2026-04-29 13:06:39.408+00	\N
734	30	2026-04-15	Gündüz	480	440	40	1000	818	28	2026-04-29 13:06:39.419+00	\N
735	30	2026-04-14	Gündüz	480	431	49	1000	817	29	2026-04-29 13:06:39.431+00	\N
736	30	2026-04-13	Gündüz	480	470	10	1000	874	18	2026-04-29 13:06:39.443+00	\N
737	30	2026-04-12	Gündüz	480	440	40	1000	867	27	2026-04-29 13:06:39.456+00	\N
738	30	2026-04-11	Gündüz	480	465	15	1000	853	35	2026-04-29 13:06:39.469+00	\N
739	30	2026-04-10	Gündüz	480	432	48	1000	841	33	2026-04-29 13:06:39.483+00	\N
740	30	2026-04-09	Gündüz	480	428	52	1000	820	9	2026-04-29 13:06:39.497+00	\N
741	30	2026-04-08	Gündüz	480	424	56	1000	976	12	2026-04-29 13:06:39.512+00	\N
742	30	2026-04-07	Gündüz	480	431	49	1000	894	40	2026-04-29 13:06:39.526+00	\N
743	30	2026-04-06	Gündüz	480	442	38	1000	969	36	2026-04-29 13:06:39.539+00	\N
744	30	2026-04-05	Gündüz	480	446	34	1000	930	10	2026-04-29 13:06:39.552+00	\N
745	30	2026-04-04	Gündüz	480	456	24	1000	916	20	2026-04-29 13:06:39.566+00	\N
746	30	2026-04-03	Gündüz	480	444	36	1000	969	16	2026-04-29 13:06:39.579+00	\N
747	30	2026-04-02	Gündüz	480	468	12	1000	913	9	2026-04-29 13:06:39.592+00	\N
748	30	2026-04-01	Gündüz	480	433	47	1000	814	12	2026-04-29 13:06:39.606+00	\N
749	30	2026-03-31	Gündüz	480	438	42	1000	922	26	2026-04-29 13:06:39.62+00	\N
750	30	2026-03-30	Gündüz	480	442	38	1000	866	18	2026-04-29 13:06:39.634+00	\N
751	31	2026-04-28	Gündüz	480	480	0	1000	881	42	2026-04-29 13:06:39.651+00	\N
752	31	2026-04-27	Gündüz	480	451	29	1000	977	12	2026-04-29 13:06:39.661+00	\N
753	31	2026-04-26	Gündüz	480	456	24	1000	879	25	2026-04-29 13:06:39.679+00	\N
754	31	2026-04-25	Gündüz	480	465	15	1000	821	12	2026-04-29 13:06:39.695+00	\N
755	31	2026-04-24	Gündüz	480	454	26	1000	855	28	2026-04-29 13:06:39.71+00	\N
756	31	2026-04-23	Gündüz	480	452	28	1000	945	40	2026-04-29 13:06:39.726+00	\N
757	31	2026-04-22	Gündüz	480	468	12	1000	917	44	2026-04-29 13:06:39.74+00	\N
758	31	2026-04-21	Gündüz	480	446	34	1000	810	15	2026-04-29 13:06:39.755+00	\N
759	31	2026-04-20	Gündüz	480	426	54	1000	969	12	2026-04-29 13:06:39.767+00	\N
760	31	2026-04-19	Gündüz	480	425	55	1000	968	17	2026-04-29 13:06:39.78+00	\N
761	31	2026-04-18	Gündüz	480	428	52	1000	857	32	2026-04-29 13:06:39.793+00	\N
762	31	2026-04-17	Gündüz	480	465	15	1000	827	19	2026-04-29 13:06:39.804+00	\N
763	31	2026-04-16	Gündüz	480	439	41	1000	836	36	2026-04-29 13:06:39.818+00	\N
764	31	2026-04-15	Gündüz	480	463	17	1000	828	19	2026-04-29 13:06:39.828+00	\N
765	31	2026-04-14	Gündüz	480	477	3	1000	801	33	2026-04-29 13:06:39.838+00	\N
766	31	2026-04-13	Gündüz	480	444	36	1000	881	16	2026-04-29 13:06:39.847+00	\N
767	31	2026-04-12	Gündüz	480	429	51	1000	940	42	2026-04-29 13:06:39.855+00	\N
768	31	2026-04-11	Gündüz	480	479	1	1000	809	27	2026-04-29 13:06:39.864+00	\N
769	31	2026-04-10	Gündüz	480	478	2	1000	952	14	2026-04-29 13:06:39.875+00	\N
770	31	2026-04-09	Gündüz	480	444	36	1000	915	27	2026-04-29 13:06:39.886+00	\N
771	31	2026-04-08	Gündüz	480	442	38	1000	863	29	2026-04-29 13:06:39.896+00	\N
772	31	2026-04-07	Gündüz	480	477	3	1000	832	41	2026-04-29 13:06:39.906+00	\N
773	31	2026-04-06	Gündüz	480	441	39	1000	815	36	2026-04-29 13:06:39.917+00	\N
774	31	2026-04-05	Gündüz	480	440	40	1000	937	27	2026-04-29 13:06:39.929+00	\N
775	31	2026-04-04	Gündüz	480	443	37	1000	939	30	2026-04-29 13:06:39.943+00	\N
776	31	2026-04-03	Gündüz	480	420	60	1000	861	38	2026-04-29 13:06:39.954+00	\N
777	31	2026-04-02	Gündüz	480	442	38	1000	900	22	2026-04-29 13:06:39.968+00	\N
778	31	2026-04-01	Gündüz	480	442	38	1000	897	39	2026-04-29 13:06:39.981+00	\N
779	31	2026-03-31	Gündüz	480	465	15	1000	856	15	2026-04-29 13:06:39.991+00	\N
780	31	2026-03-30	Gündüz	480	454	26	1000	839	40	2026-04-29 13:06:40.002+00	\N
781	32	2026-04-28	Gündüz	480	444	36	1000	854	11	2026-04-29 13:06:40.013+00	\N
782	32	2026-04-27	Gündüz	480	424	56	1000	965	19	2026-04-29 13:06:40.023+00	\N
783	32	2026-04-26	Gündüz	480	465	15	1000	943	13	2026-04-29 13:06:40.033+00	\N
784	32	2026-04-25	Gündüz	480	422	58	1000	960	14	2026-04-29 13:06:40.044+00	\N
785	32	2026-04-24	Gündüz	480	459	21	1000	824	37	2026-04-29 13:06:40.054+00	\N
786	32	2026-04-23	Gündüz	480	428	52	1000	817	27	2026-04-29 13:06:40.065+00	\N
787	32	2026-04-22	Gündüz	480	464	16	1000	812	19	2026-04-29 13:06:40.076+00	\N
788	32	2026-04-21	Gündüz	480	466	14	1000	902	34	2026-04-29 13:06:40.087+00	\N
789	32	2026-04-20	Gündüz	480	428	52	1000	978	47	2026-04-29 13:06:40.098+00	\N
790	32	2026-04-19	Gündüz	480	446	34	1000	870	34	2026-04-29 13:06:40.112+00	\N
791	32	2026-04-18	Gündüz	480	423	57	1000	915	35	2026-04-29 13:06:40.128+00	\N
792	32	2026-04-17	Gündüz	480	465	15	1000	905	22	2026-04-29 13:06:40.139+00	\N
793	32	2026-04-16	Gündüz	480	447	33	1000	940	15	2026-04-29 13:06:40.152+00	\N
794	32	2026-04-15	Gündüz	480	426	54	1000	900	40	2026-04-29 13:06:40.163+00	\N
795	32	2026-04-14	Gündüz	480	464	16	1000	833	18	2026-04-29 13:06:40.174+00	\N
796	32	2026-04-13	Gündüz	480	467	13	1000	948	25	2026-04-29 13:06:40.186+00	\N
797	32	2026-04-12	Gündüz	480	474	6	1000	856	31	2026-04-29 13:06:40.196+00	\N
798	32	2026-04-11	Gündüz	480	459	21	1000	808	38	2026-04-29 13:06:40.207+00	\N
799	32	2026-04-10	Gündüz	480	454	26	1000	820	30	2026-04-29 13:06:40.218+00	\N
800	32	2026-04-09	Gündüz	480	451	29	1000	916	16	2026-04-29 13:06:40.229+00	\N
801	32	2026-04-08	Gündüz	480	454	26	1000	851	37	2026-04-29 13:06:40.242+00	\N
802	32	2026-04-07	Gündüz	480	435	45	1000	849	38	2026-04-29 13:06:40.254+00	\N
803	32	2026-04-06	Gündüz	480	454	26	1000	935	22	2026-04-29 13:06:40.266+00	\N
804	32	2026-04-05	Gündüz	480	437	43	1000	891	14	2026-04-29 13:06:40.278+00	\N
805	32	2026-04-04	Gündüz	480	476	4	1000	934	30	2026-04-29 13:06:40.29+00	\N
806	32	2026-04-03	Gündüz	480	450	30	1000	946	36	2026-04-29 13:06:40.304+00	\N
807	32	2026-04-02	Gündüz	480	429	51	1000	939	37	2026-04-29 13:06:40.32+00	\N
808	32	2026-04-01	Gündüz	480	475	5	1000	849	17	2026-04-29 13:06:40.333+00	\N
809	32	2026-03-31	Gündüz	480	476	4	1000	876	36	2026-04-29 13:06:40.343+00	\N
810	32	2026-03-30	Gündüz	480	455	25	1000	881	15	2026-04-29 13:06:40.351+00	\N
811	33	2026-04-28	Gündüz	480	429	51	1000	926	12	2026-04-29 13:06:40.36+00	\N
812	33	2026-04-27	Gündüz	480	421	59	1000	960	18	2026-04-29 13:06:40.37+00	\N
813	33	2026-04-26	Gündüz	480	474	6	1000	815	23	2026-04-29 13:06:40.38+00	\N
814	33	2026-04-25	Gündüz	480	467	13	1000	827	16	2026-04-29 13:06:40.391+00	\N
815	33	2026-04-24	Gündüz	480	433	47	1000	973	34	2026-04-29 13:06:40.401+00	\N
816	33	2026-04-23	Gündüz	480	477	3	1000	856	32	2026-04-29 13:06:40.41+00	\N
817	33	2026-04-22	Gündüz	480	474	6	1000	848	35	2026-04-29 13:06:40.421+00	\N
818	33	2026-04-21	Gündüz	480	433	47	1000	919	19	2026-04-29 13:06:40.43+00	\N
819	33	2026-04-20	Gündüz	480	437	43	1000	929	12	2026-04-29 13:06:40.441+00	\N
820	33	2026-04-19	Gündüz	480	456	24	1000	920	42	2026-04-29 13:06:40.452+00	\N
821	33	2026-04-18	Gündüz	480	471	9	1000	910	36	2026-04-29 13:06:40.463+00	\N
822	33	2026-04-17	Gündüz	480	466	14	1000	821	29	2026-04-29 13:06:40.474+00	\N
823	33	2026-04-16	Gündüz	480	464	16	1000	845	32	2026-04-29 13:06:40.485+00	\N
824	33	2026-04-15	Gündüz	480	433	47	1000	968	46	2026-04-29 13:06:40.495+00	\N
825	33	2026-04-14	Gündüz	480	448	32	1000	957	23	2026-04-29 13:06:40.504+00	\N
826	33	2026-04-13	Gündüz	480	441	39	1000	841	32	2026-04-29 13:06:40.514+00	\N
827	33	2026-04-12	Gündüz	480	425	55	1000	977	39	2026-04-29 13:06:40.523+00	\N
828	33	2026-04-11	Gündüz	480	438	42	1000	892	42	2026-04-29 13:06:40.533+00	\N
829	33	2026-04-10	Gündüz	480	470	10	1000	886	30	2026-04-29 13:06:40.543+00	\N
830	33	2026-04-09	Gündüz	480	444	36	1000	898	27	2026-04-29 13:06:40.555+00	\N
831	33	2026-04-08	Gündüz	480	437	43	1000	883	27	2026-04-29 13:06:40.566+00	\N
832	33	2026-04-07	Gündüz	480	438	42	1000	871	27	2026-04-29 13:06:40.577+00	\N
833	33	2026-04-06	Gündüz	480	427	53	1000	960	33	2026-04-29 13:06:40.591+00	\N
834	33	2026-04-05	Gündüz	480	452	28	1000	814	39	2026-04-29 13:06:40.603+00	\N
835	33	2026-04-04	Gündüz	480	453	27	1000	924	27	2026-04-29 13:06:40.614+00	\N
836	33	2026-04-03	Gündüz	480	474	6	1000	830	35	2026-04-29 13:06:40.627+00	\N
837	33	2026-04-02	Gündüz	480	477	3	1000	859	11	2026-04-29 13:06:40.639+00	\N
838	33	2026-04-01	Gündüz	480	480	0	1000	939	9	2026-04-29 13:06:40.651+00	\N
839	33	2026-03-31	Gündüz	480	473	7	1000	850	11	2026-04-29 13:06:40.659+00	\N
840	33	2026-03-30	Gündüz	480	430	50	1000	834	29	2026-04-29 13:06:40.672+00	\N
841	34	2026-04-28	Gündüz	480	467	13	1000	968	44	2026-04-29 13:06:40.683+00	\N
842	34	2026-04-27	Gündüz	480	420	60	1000	972	47	2026-04-29 13:06:40.695+00	\N
843	34	2026-04-26	Gündüz	480	444	36	1000	802	22	2026-04-29 13:06:40.707+00	\N
844	34	2026-04-25	Gündüz	480	480	0	1000	958	24	2026-04-29 13:06:40.719+00	\N
845	34	2026-04-24	Gündüz	480	475	5	1000	817	9	2026-04-29 13:06:40.727+00	\N
846	34	2026-04-23	Gündüz	480	421	59	1000	805	21	2026-04-29 13:06:40.741+00	\N
847	34	2026-04-22	Gündüz	480	457	23	1000	897	42	2026-04-29 13:06:40.755+00	\N
848	34	2026-04-21	Gündüz	480	435	45	1000	913	34	2026-04-29 13:06:40.768+00	\N
849	34	2026-04-20	Gündüz	480	433	47	1000	911	26	2026-04-29 13:06:40.783+00	\N
850	34	2026-04-19	Gündüz	480	463	17	1000	973	10	2026-04-29 13:06:40.796+00	\N
851	34	2026-04-18	Gündüz	480	432	48	1000	861	24	2026-04-29 13:06:40.809+00	\N
852	34	2026-04-17	Gündüz	480	464	16	1000	904	36	2026-04-29 13:06:40.825+00	\N
853	34	2026-04-16	Gündüz	480	446	34	1000	910	26	2026-04-29 13:06:40.84+00	\N
854	34	2026-04-15	Gündüz	480	436	44	1000	895	9	2026-04-29 13:06:40.85+00	\N
855	34	2026-04-14	Gündüz	480	461	19	1000	815	39	2026-04-29 13:06:40.86+00	\N
856	34	2026-04-13	Gündüz	480	458	22	1000	844	16	2026-04-29 13:06:40.869+00	\N
857	34	2026-04-12	Gündüz	480	459	21	1000	895	25	2026-04-29 13:06:40.88+00	\N
858	34	2026-04-11	Gündüz	480	445	35	1000	836	27	2026-04-29 13:06:40.892+00	\N
859	34	2026-04-10	Gündüz	480	454	26	1000	971	12	2026-04-29 13:06:40.905+00	\N
860	34	2026-04-09	Gündüz	480	449	31	1000	855	21	2026-04-29 13:06:40.917+00	\N
861	34	2026-04-08	Gündüz	480	470	10	1000	874	35	2026-04-29 13:06:40.929+00	\N
862	34	2026-04-07	Gündüz	480	431	49	1000	917	20	2026-04-29 13:06:40.941+00	\N
863	34	2026-04-06	Gündüz	480	428	52	1000	947	17	2026-04-29 13:06:40.953+00	\N
864	34	2026-04-05	Gündüz	480	476	4	1000	814	20	2026-04-29 13:06:40.964+00	\N
865	34	2026-04-04	Gündüz	480	422	58	1000	875	42	2026-04-29 13:06:40.976+00	\N
866	34	2026-04-03	Gündüz	480	431	49	1000	845	41	2026-04-29 13:06:40.985+00	\N
867	34	2026-04-02	Gündüz	480	447	33	1000	920	42	2026-04-29 13:06:40.995+00	\N
868	34	2026-04-01	Gündüz	480	422	58	1000	901	24	2026-04-29 13:06:41.004+00	\N
869	34	2026-03-31	Gündüz	480	480	0	1000	884	22	2026-04-29 13:06:41.014+00	\N
870	34	2026-03-30	Gündüz	480	445	35	1000	904	40	2026-04-29 13:06:41.022+00	\N
871	35	2026-04-28	Gündüz	480	459	21	1000	847	31	2026-04-29 13:06:41.033+00	\N
872	35	2026-04-27	Gündüz	480	471	9	1000	979	33	2026-04-29 13:06:41.044+00	\N
873	35	2026-04-26	Gündüz	480	456	24	1000	862	39	2026-04-29 13:06:41.058+00	\N
874	35	2026-04-25	Gündüz	480	448	32	1000	971	21	2026-04-29 13:06:41.072+00	\N
875	35	2026-04-24	Gündüz	480	443	37	1000	938	34	2026-04-29 13:06:41.087+00	\N
876	35	2026-04-23	Gündüz	480	427	53	1000	910	9	2026-04-29 13:06:41.102+00	\N
877	35	2026-04-22	Gündüz	480	447	33	1000	865	9	2026-04-29 13:06:41.119+00	\N
878	35	2026-04-21	Gündüz	480	476	4	1000	870	29	2026-04-29 13:06:41.136+00	\N
879	35	2026-04-20	Gündüz	480	452	28	1000	881	42	2026-04-29 13:06:41.151+00	\N
880	35	2026-04-19	Gündüz	480	454	26	1000	946	42	2026-04-29 13:06:41.165+00	\N
881	35	2026-04-18	Gündüz	480	468	12	1000	838	28	2026-04-29 13:06:41.177+00	\N
882	35	2026-04-17	Gündüz	480	470	10	1000	971	33	2026-04-29 13:06:41.191+00	\N
883	35	2026-04-16	Gündüz	480	457	23	1000	876	20	2026-04-29 13:06:41.206+00	\N
884	35	2026-04-15	Gündüz	480	477	3	1000	945	40	2026-04-29 13:06:41.221+00	\N
885	35	2026-04-14	Gündüz	480	463	17	1000	811	30	2026-04-29 13:06:41.238+00	\N
886	35	2026-04-13	Gündüz	480	424	56	1000	805	27	2026-04-29 13:06:41.254+00	\N
887	35	2026-04-12	Gündüz	480	470	10	1000	845	29	2026-04-29 13:06:41.271+00	\N
888	35	2026-04-11	Gündüz	480	459	21	1000	885	38	2026-04-29 13:06:41.287+00	\N
889	35	2026-04-10	Gündüz	480	458	22	1000	885	22	2026-04-29 13:06:41.302+00	\N
890	35	2026-04-09	Gündüz	480	467	13	1000	838	15	2026-04-29 13:06:41.316+00	\N
891	35	2026-04-08	Gündüz	480	430	50	1000	823	10	2026-04-29 13:06:41.337+00	\N
892	35	2026-04-07	Gündüz	480	427	53	1000	956	23	2026-04-29 13:06:41.351+00	\N
893	35	2026-04-06	Gündüz	480	464	16	1000	959	44	2026-04-29 13:06:41.365+00	\N
894	35	2026-04-05	Gündüz	480	436	44	1000	825	19	2026-04-29 13:06:41.38+00	\N
895	35	2026-04-04	Gündüz	480	438	42	1000	870	34	2026-04-29 13:06:41.396+00	\N
896	35	2026-04-03	Gündüz	480	442	38	1000	929	26	2026-04-29 13:06:41.411+00	\N
897	35	2026-04-02	Gündüz	480	444	36	1000	884	20	2026-04-29 13:06:41.427+00	\N
898	35	2026-04-01	Gündüz	480	456	24	1000	943	35	2026-04-29 13:06:41.444+00	\N
899	35	2026-03-31	Gündüz	480	445	35	1000	938	22	2026-04-29 13:06:41.461+00	\N
900	35	2026-03-30	Gündüz	480	429	51	1000	975	38	2026-04-29 13:06:41.479+00	\N
901	36	2026-04-28	Gündüz	480	475	5	1000	884	24	2026-04-29 13:06:41.497+00	\N
902	36	2026-04-27	Gündüz	480	478	2	1000	893	43	2026-04-29 13:06:41.512+00	\N
903	36	2026-04-26	Gündüz	480	423	57	1000	880	28	2026-04-29 13:06:41.528+00	\N
904	36	2026-04-25	Gündüz	480	450	30	1000	972	36	2026-04-29 13:06:41.543+00	\N
905	36	2026-04-24	Gündüz	480	435	45	1000	918	17	2026-04-29 13:06:41.559+00	\N
906	36	2026-04-23	Gündüz	480	423	57	1000	825	13	2026-04-29 13:06:41.573+00	\N
907	36	2026-04-22	Gündüz	480	445	35	1000	925	37	2026-04-29 13:06:41.588+00	\N
908	36	2026-04-21	Gündüz	480	463	17	1000	961	22	2026-04-29 13:06:41.604+00	\N
909	36	2026-04-20	Gündüz	480	463	17	1000	937	15	2026-04-29 13:06:41.622+00	\N
910	36	2026-04-19	Gündüz	480	435	45	1000	939	27	2026-04-29 13:06:41.634+00	\N
911	36	2026-04-18	Gündüz	480	475	5	1000	835	40	2026-04-29 13:06:41.648+00	\N
912	36	2026-04-17	Gündüz	480	479	1	1000	960	26	2026-04-29 13:06:41.659+00	\N
913	36	2026-04-16	Gündüz	480	433	47	1000	904	15	2026-04-29 13:06:41.672+00	\N
914	36	2026-04-15	Gündüz	480	467	13	1000	963	34	2026-04-29 13:06:41.687+00	\N
915	36	2026-04-14	Gündüz	480	476	4	1000	973	14	2026-04-29 13:06:41.704+00	\N
916	36	2026-04-13	Gündüz	480	450	30	1000	904	31	2026-04-29 13:06:41.72+00	\N
917	36	2026-04-12	Gündüz	480	425	55	1000	812	39	2026-04-29 13:06:41.735+00	\N
918	36	2026-04-11	Gündüz	480	479	1	1000	841	15	2026-04-29 13:06:41.75+00	\N
919	36	2026-04-10	Gündüz	480	434	46	1000	865	31	2026-04-29 13:06:41.765+00	\N
920	36	2026-04-09	Gündüz	480	453	27	1000	900	9	2026-04-29 13:06:41.78+00	\N
921	36	2026-04-08	Gündüz	480	444	36	1000	889	37	2026-04-29 13:06:41.793+00	\N
922	36	2026-04-07	Gündüz	480	439	41	1000	849	33	2026-04-29 13:06:41.805+00	\N
923	36	2026-04-06	Gündüz	480	472	8	1000	946	30	2026-04-29 13:06:41.817+00	\N
924	36	2026-04-05	Gündüz	480	457	23	1000	979	34	2026-04-29 13:06:41.831+00	\N
925	36	2026-04-04	Gündüz	480	465	15	1000	800	20	2026-04-29 13:06:41.845+00	\N
926	36	2026-04-03	Gündüz	480	440	40	1000	827	19	2026-04-29 13:06:41.854+00	\N
927	36	2026-04-02	Gündüz	480	445	35	1000	820	28	2026-04-29 13:06:41.865+00	\N
928	36	2026-04-01	Gündüz	480	468	12	1000	969	34	2026-04-29 13:06:41.878+00	\N
929	36	2026-03-31	Gündüz	480	444	36	1000	927	20	2026-04-29 13:06:41.891+00	\N
930	36	2026-03-30	Gündüz	480	468	12	1000	977	37	2026-04-29 13:06:41.904+00	\N
931	37	2026-04-28	Gündüz	480	460	20	1000	885	36	2026-04-29 13:06:41.916+00	\N
932	37	2026-04-27	Gündüz	480	437	43	1000	816	26	2026-04-29 13:06:41.929+00	\N
933	37	2026-04-26	Gündüz	480	461	19	1000	837	29	2026-04-29 13:06:41.943+00	\N
934	37	2026-04-25	Gündüz	480	473	7	1000	867	10	2026-04-29 13:06:41.958+00	\N
935	37	2026-04-24	Gündüz	480	454	26	1000	966	18	2026-04-29 13:06:41.973+00	\N
936	37	2026-04-23	Gündüz	480	445	35	1000	832	24	2026-04-29 13:06:41.988+00	\N
937	37	2026-04-22	Gündüz	480	465	15	1000	820	16	2026-04-29 13:06:42.003+00	\N
938	37	2026-04-21	Gündüz	480	424	56	1000	863	27	2026-04-29 13:06:42.017+00	\N
939	37	2026-04-20	Gündüz	480	427	53	1000	830	37	2026-04-29 13:06:42.032+00	\N
940	37	2026-04-19	Gündüz	480	422	58	1000	829	24	2026-04-29 13:06:42.047+00	\N
941	37	2026-04-18	Gündüz	480	460	20	1000	873	11	2026-04-29 13:06:42.06+00	\N
942	37	2026-04-17	Gündüz	480	452	28	1000	938	25	2026-04-29 13:06:42.074+00	\N
943	37	2026-04-16	Gündüz	480	452	28	1000	877	25	2026-04-29 13:06:42.088+00	\N
944	37	2026-04-15	Gündüz	480	422	58	1000	914	16	2026-04-29 13:06:42.102+00	\N
945	37	2026-04-14	Gündüz	480	471	9	1000	869	30	2026-04-29 13:06:42.115+00	\N
946	37	2026-04-13	Gündüz	480	454	26	1000	919	14	2026-04-29 13:06:42.129+00	\N
947	37	2026-04-12	Gündüz	480	431	49	1000	827	37	2026-04-29 13:06:42.145+00	\N
948	37	2026-04-11	Gündüz	480	465	15	1000	895	16	2026-04-29 13:06:42.159+00	\N
949	37	2026-04-10	Gündüz	480	459	21	1000	884	27	2026-04-29 13:06:42.173+00	\N
950	37	2026-04-09	Gündüz	480	429	51	1000	820	34	2026-04-29 13:06:42.187+00	\N
951	37	2026-04-08	Gündüz	480	446	34	1000	839	23	2026-04-29 13:06:42.2+00	\N
952	37	2026-04-07	Gündüz	480	437	43	1000	860	11	2026-04-29 13:06:42.213+00	\N
953	37	2026-04-06	Gündüz	480	425	55	1000	833	25	2026-04-29 13:06:42.227+00	\N
954	37	2026-04-05	Gündüz	480	451	29	1000	856	31	2026-04-29 13:06:42.24+00	\N
955	37	2026-04-04	Gündüz	480	445	35	1000	871	25	2026-04-29 13:06:42.253+00	\N
956	37	2026-04-03	Gündüz	480	473	7	1000	811	20	2026-04-29 13:06:42.266+00	\N
957	37	2026-04-02	Gündüz	480	473	7	1000	865	29	2026-04-29 13:06:42.279+00	\N
958	37	2026-04-01	Gündüz	480	457	23	1000	805	12	2026-04-29 13:06:42.292+00	\N
959	37	2026-03-31	Gündüz	480	458	22	1000	963	23	2026-04-29 13:06:42.307+00	\N
960	37	2026-03-30	Gündüz	480	432	48	1000	819	36	2026-04-29 13:06:42.32+00	\N
961	38	2026-04-28	Gündüz	480	420	60	1000	910	15	2026-04-29 13:06:42.341+00	\N
962	38	2026-04-27	Gündüz	480	426	54	1000	880	31	2026-04-29 13:06:42.354+00	\N
963	38	2026-04-26	Gündüz	480	469	11	1000	975	44	2026-04-29 13:06:42.369+00	\N
964	38	2026-04-25	Gündüz	480	463	17	1000	972	15	2026-04-29 13:06:42.384+00	\N
965	38	2026-04-24	Gündüz	480	461	19	1000	944	17	2026-04-29 13:06:42.399+00	\N
966	38	2026-04-23	Gündüz	480	464	16	1000	863	23	2026-04-29 13:06:42.416+00	\N
967	38	2026-04-22	Gündüz	480	475	5	1000	965	18	2026-04-29 13:06:42.433+00	\N
968	38	2026-04-21	Gündüz	480	431	49	1000	967	37	2026-04-29 13:06:42.449+00	\N
969	38	2026-04-20	Gündüz	480	458	22	1000	841	25	2026-04-29 13:06:42.465+00	\N
970	38	2026-04-19	Gündüz	480	474	6	1000	852	35	2026-04-29 13:06:42.482+00	\N
971	38	2026-04-18	Gündüz	480	429	51	1000	916	33	2026-04-29 13:06:42.498+00	\N
972	38	2026-04-17	Gündüz	480	479	1	1000	938	11	2026-04-29 13:06:42.515+00	\N
973	38	2026-04-16	Gündüz	480	421	59	1000	945	27	2026-04-29 13:06:42.532+00	\N
974	38	2026-04-15	Gündüz	480	473	7	1000	884	20	2026-04-29 13:06:42.547+00	\N
975	38	2026-04-14	Gündüz	480	435	45	1000	878	11	2026-04-29 13:06:42.563+00	\N
976	38	2026-04-13	Gündüz	480	479	1	1000	852	33	2026-04-29 13:06:42.579+00	\N
977	38	2026-04-12	Gündüz	480	457	23	1000	900	17	2026-04-29 13:06:42.595+00	\N
978	38	2026-04-11	Gündüz	480	466	14	1000	971	37	2026-04-29 13:06:42.61+00	\N
979	38	2026-04-10	Gündüz	480	464	16	1000	878	18	2026-04-29 13:06:42.625+00	\N
980	38	2026-04-09	Gündüz	480	438	42	1000	876	33	2026-04-29 13:06:42.64+00	\N
981	38	2026-04-08	Gündüz	480	480	0	1000	861	39	2026-04-29 13:06:42.654+00	\N
982	38	2026-04-07	Gündüz	480	430	50	1000	958	47	2026-04-29 13:06:42.663+00	\N
983	38	2026-04-06	Gündüz	480	468	12	1000	824	26	2026-04-29 13:06:42.677+00	\N
984	38	2026-04-05	Gündüz	480	460	20	1000	967	42	2026-04-29 13:06:42.691+00	\N
985	38	2026-04-04	Gündüz	480	454	26	1000	802	32	2026-04-29 13:06:42.705+00	\N
986	38	2026-04-03	Gündüz	480	433	47	1000	871	15	2026-04-29 13:06:42.718+00	\N
987	38	2026-04-02	Gündüz	480	440	40	1000	944	34	2026-04-29 13:06:42.731+00	\N
988	38	2026-04-01	Gündüz	480	442	38	1000	884	25	2026-04-29 13:06:42.744+00	\N
989	38	2026-03-31	Gündüz	480	432	48	1000	938	23	2026-04-29 13:06:42.758+00	\N
990	38	2026-03-30	Gündüz	480	466	14	1000	974	21	2026-04-29 13:06:42.773+00	\N
991	39	2026-04-28	Gündüz	480	460	20	1000	877	21	2026-04-29 13:06:42.79+00	\N
992	39	2026-04-27	Gündüz	480	424	56	1000	874	34	2026-04-29 13:06:42.806+00	\N
993	39	2026-04-26	Gündüz	480	448	32	1000	964	32	2026-04-29 13:06:42.821+00	\N
994	39	2026-04-25	Gündüz	480	442	38	1000	825	18	2026-04-29 13:06:42.839+00	\N
995	39	2026-04-24	Gündüz	480	472	8	1000	960	33	2026-04-29 13:06:42.852+00	\N
996	39	2026-04-23	Gündüz	480	464	16	1000	829	8	2026-04-29 13:06:42.863+00	\N
997	39	2026-04-22	Gündüz	480	426	54	1000	957	42	2026-04-29 13:06:42.873+00	\N
998	39	2026-04-21	Gündüz	480	475	5	1000	929	22	2026-04-29 13:06:42.885+00	\N
999	39	2026-04-20	Gündüz	480	471	9	1000	909	37	2026-04-29 13:06:42.896+00	\N
1000	39	2026-04-19	Gündüz	480	428	52	1000	883	31	2026-04-29 13:06:42.907+00	\N
1001	39	2026-04-18	Gündüz	480	444	36	1000	953	38	2026-04-29 13:06:42.92+00	\N
1002	39	2026-04-17	Gündüz	480	473	7	1000	891	38	2026-04-29 13:06:42.933+00	\N
1003	39	2026-04-16	Gündüz	480	444	36	1000	904	41	2026-04-29 13:06:42.947+00	\N
1004	39	2026-04-15	Gündüz	480	430	50	1000	843	14	2026-04-29 13:06:42.959+00	\N
1005	39	2026-04-14	Gündüz	480	446	34	1000	897	36	2026-04-29 13:06:42.969+00	\N
1006	39	2026-04-13	Gündüz	480	451	29	1000	886	33	2026-04-29 13:06:42.978+00	\N
1007	39	2026-04-12	Gündüz	480	476	4	1000	857	41	2026-04-29 13:06:42.987+00	\N
1008	39	2026-04-11	Gündüz	480	450	30	1000	876	22	2026-04-29 13:06:42.996+00	\N
1009	39	2026-04-10	Gündüz	480	474	6	1000	845	32	2026-04-29 13:06:43.006+00	\N
1010	39	2026-04-09	Gündüz	480	458	22	1000	934	17	2026-04-29 13:06:43.016+00	\N
1011	39	2026-04-08	Gündüz	480	423	57	1000	876	24	2026-04-29 13:06:43.026+00	\N
1012	39	2026-04-07	Gündüz	480	427	53	1000	885	17	2026-04-29 13:06:43.036+00	\N
1013	39	2026-04-06	Gündüz	480	448	32	1000	855	40	2026-04-29 13:06:43.046+00	\N
1014	39	2026-04-05	Gündüz	480	455	25	1000	843	30	2026-04-29 13:06:43.056+00	\N
1015	39	2026-04-04	Gündüz	480	433	47	1000	804	22	2026-04-29 13:06:43.067+00	\N
1016	39	2026-04-03	Gündüz	480	434	46	1000	965	26	2026-04-29 13:06:43.079+00	\N
1017	39	2026-04-02	Gündüz	480	475	5	1000	869	40	2026-04-29 13:06:43.09+00	\N
1018	39	2026-04-01	Gündüz	480	450	30	1000	933	18	2026-04-29 13:06:43.102+00	\N
1019	39	2026-03-31	Gündüz	480	428	52	1000	910	18	2026-04-29 13:06:43.113+00	\N
1020	39	2026-03-30	Gündüz	480	435	45	1000	842	38	2026-04-29 13:06:43.124+00	\N
1021	40	2026-04-28	Gündüz	480	448	32	1000	800	22	2026-04-29 13:06:43.137+00	\N
1022	40	2026-04-27	Gündüz	480	421	59	1000	880	40	2026-04-29 13:06:43.151+00	\N
1023	40	2026-04-26	Gündüz	480	453	27	1000	841	38	2026-04-29 13:06:43.164+00	\N
1024	40	2026-04-25	Gündüz	480	479	1	1000	817	23	2026-04-29 13:06:43.179+00	\N
1025	40	2026-04-24	Gündüz	480	470	10	1000	859	20	2026-04-29 13:06:43.191+00	\N
1026	40	2026-04-23	Gündüz	480	432	48	1000	892	26	2026-04-29 13:06:43.203+00	\N
1027	40	2026-04-22	Gündüz	480	449	31	1000	862	33	2026-04-29 13:06:43.214+00	\N
1028	40	2026-04-21	Gündüz	480	461	19	1000	897	39	2026-04-29 13:06:43.226+00	\N
1029	40	2026-04-20	Gündüz	480	434	46	1000	880	20	2026-04-29 13:06:43.238+00	\N
1030	40	2026-04-19	Gündüz	480	456	24	1000	924	11	2026-04-29 13:06:43.25+00	\N
1031	40	2026-04-18	Gündüz	480	434	46	1000	832	31	2026-04-29 13:06:43.263+00	\N
1032	40	2026-04-17	Gündüz	480	452	28	1000	973	36	2026-04-29 13:06:43.274+00	\N
1033	40	2026-04-16	Gündüz	480	424	56	1000	888	25	2026-04-29 13:06:43.286+00	\N
1034	40	2026-04-15	Gündüz	480	421	59	1000	887	10	2026-04-29 13:06:43.297+00	\N
1035	40	2026-04-14	Gündüz	480	438	42	1000	928	16	2026-04-29 13:06:43.307+00	\N
1036	40	2026-04-13	Gündüz	480	432	48	1000	854	29	2026-04-29 13:06:43.317+00	\N
1037	40	2026-04-12	Gündüz	480	430	50	1000	810	11	2026-04-29 13:06:43.333+00	\N
1038	40	2026-04-11	Gündüz	480	442	38	1000	937	33	2026-04-29 13:06:43.344+00	\N
1039	40	2026-04-10	Gündüz	480	475	5	1000	929	33	2026-04-29 13:06:43.355+00	\N
1040	40	2026-04-09	Gündüz	480	456	24	1000	920	31	2026-04-29 13:06:43.366+00	\N
1041	40	2026-04-08	Gündüz	480	454	26	1000	897	34	2026-04-29 13:06:43.379+00	\N
1042	40	2026-04-07	Gündüz	480	438	42	1000	930	18	2026-04-29 13:06:43.392+00	\N
1043	40	2026-04-06	Gündüz	480	456	24	1000	922	35	2026-04-29 13:06:43.405+00	\N
1044	40	2026-04-05	Gündüz	480	440	40	1000	868	29	2026-04-29 13:06:43.419+00	\N
1045	40	2026-04-04	Gündüz	480	479	1	1000	842	26	2026-04-29 13:06:43.433+00	\N
1046	40	2026-04-03	Gündüz	480	455	25	1000	900	44	2026-04-29 13:06:43.446+00	\N
1047	40	2026-04-02	Gündüz	480	429	51	1000	925	40	2026-04-29 13:06:43.46+00	\N
1048	40	2026-04-01	Gündüz	480	431	49	1000	894	24	2026-04-29 13:06:43.473+00	\N
1049	40	2026-03-31	Gündüz	480	434	46	1000	860	33	2026-04-29 13:06:43.488+00	\N
1050	40	2026-03-30	Gündüz	480	441	39	1000	953	15	2026-04-29 13:06:43.502+00	\N
1051	41	2026-04-28	Gündüz	480	454	26	1000	932	42	2026-04-29 13:06:43.515+00	\N
1052	41	2026-04-27	Gündüz	480	454	26	1000	847	30	2026-04-29 13:06:43.529+00	\N
1053	41	2026-04-26	Gündüz	480	444	36	1000	868	35	2026-04-29 13:06:43.542+00	\N
1054	41	2026-04-25	Gündüz	480	432	48	1000	966	21	2026-04-29 13:06:43.556+00	\N
1055	41	2026-04-24	Gündüz	480	449	31	1000	879	30	2026-04-29 13:06:43.569+00	\N
1056	41	2026-04-23	Gündüz	480	458	22	1000	917	10	2026-04-29 13:06:43.583+00	\N
1057	41	2026-04-22	Gündüz	480	470	10	1000	874	43	2026-04-29 13:06:43.596+00	\N
1058	41	2026-04-21	Gündüz	480	480	0	1000	833	16	2026-04-29 13:06:43.61+00	\N
1059	41	2026-04-20	Gündüz	480	437	43	1000	899	39	2026-04-29 13:06:43.617+00	\N
1060	41	2026-04-19	Gündüz	480	439	41	1000	939	31	2026-04-29 13:06:43.629+00	\N
1061	41	2026-04-18	Gündüz	480	457	23	1000	861	9	2026-04-29 13:06:43.641+00	\N
1062	41	2026-04-17	Gündüz	480	464	16	1000	893	28	2026-04-29 13:06:43.652+00	\N
1063	41	2026-04-16	Gündüz	480	472	8	1000	863	20	2026-04-29 13:06:43.665+00	\N
1064	41	2026-04-15	Gündüz	480	466	14	1000	811	37	2026-04-29 13:06:43.676+00	\N
1065	41	2026-04-14	Gündüz	480	466	14	1000	859	10	2026-04-29 13:06:43.687+00	\N
1066	41	2026-04-13	Gündüz	480	480	0	1000	888	18	2026-04-29 13:06:43.698+00	\N
1067	41	2026-04-12	Gündüz	480	450	30	1000	868	16	2026-04-29 13:06:43.706+00	\N
1068	41	2026-04-11	Gündüz	480	464	16	1000	860	14	2026-04-29 13:06:43.716+00	\N
1069	41	2026-04-10	Gündüz	480	423	57	1000	960	24	2026-04-29 13:06:43.726+00	\N
1070	41	2026-04-09	Gündüz	480	448	32	1000	904	43	2026-04-29 13:06:43.738+00	\N
1071	41	2026-04-08	Gündüz	480	466	14	1000	977	45	2026-04-29 13:06:43.747+00	\N
1072	41	2026-04-07	Gündüz	480	466	14	1000	884	25	2026-04-29 13:06:43.758+00	\N
1073	41	2026-04-06	Gündüz	480	478	2	1000	889	27	2026-04-29 13:06:43.769+00	\N
1074	41	2026-04-05	Gündüz	480	420	60	1000	962	16	2026-04-29 13:06:43.78+00	\N
1075	41	2026-04-04	Gündüz	480	460	20	1000	913	35	2026-04-29 13:06:43.796+00	\N
1076	41	2026-04-03	Gündüz	480	470	10	1000	831	16	2026-04-29 13:06:43.813+00	\N
1077	41	2026-04-02	Gündüz	480	428	52	1000	803	19	2026-04-29 13:06:43.824+00	\N
1078	41	2026-04-01	Gündüz	480	460	20	1000	890	28	2026-04-29 13:06:43.841+00	\N
1079	41	2026-03-31	Gündüz	480	475	5	1000	803	28	2026-04-29 13:06:43.853+00	\N
1080	41	2026-03-30	Gündüz	480	450	30	1000	816	12	2026-04-29 13:06:43.866+00	\N
1081	42	2026-04-28	Gündüz	480	434	46	1000	815	37	2026-04-29 13:06:43.878+00	\N
1082	42	2026-04-27	Gündüz	480	448	32	1000	949	27	2026-04-29 13:06:43.89+00	\N
1083	42	2026-04-26	Gündüz	480	447	33	1000	979	25	2026-04-29 13:06:43.902+00	\N
1084	42	2026-04-25	Gündüz	480	445	35	1000	894	10	2026-04-29 13:06:43.914+00	\N
1085	42	2026-04-24	Gündüz	480	468	12	1000	890	35	2026-04-29 13:06:43.925+00	\N
1086	42	2026-04-23	Gündüz	480	457	23	1000	976	47	2026-04-29 13:06:43.938+00	\N
1087	42	2026-04-22	Gündüz	480	468	12	1000	848	36	2026-04-29 13:06:43.95+00	\N
1088	42	2026-04-21	Gündüz	480	460	20	1000	947	27	2026-04-29 13:06:43.962+00	\N
1089	42	2026-04-20	Gündüz	480	476	4	1000	872	16	2026-04-29 13:06:43.973+00	\N
1090	42	2026-04-19	Gündüz	480	480	0	1000	978	19	2026-04-29 13:06:43.985+00	\N
1091	42	2026-04-18	Gündüz	480	477	3	1000	878	22	2026-04-29 13:06:43.993+00	\N
1092	42	2026-04-17	Gündüz	480	448	32	1000	906	30	2026-04-29 13:06:44.005+00	\N
1093	42	2026-04-16	Gündüz	480	429	51	1000	937	39	2026-04-29 13:06:44.019+00	\N
1094	42	2026-04-15	Gündüz	480	437	43	1000	946	21	2026-04-29 13:06:44.034+00	\N
1095	42	2026-04-14	Gündüz	480	431	49	1000	969	24	2026-04-29 13:06:44.048+00	\N
1096	42	2026-04-13	Gündüz	480	436	44	1000	906	20	2026-04-29 13:06:44.06+00	\N
1097	42	2026-04-12	Gündüz	480	479	1	1000	877	35	2026-04-29 13:06:44.074+00	\N
1098	42	2026-04-11	Gündüz	480	423	57	1000	923	26	2026-04-29 13:06:44.089+00	\N
1099	42	2026-04-10	Gündüz	480	458	22	1000	808	21	2026-04-29 13:06:44.101+00	\N
1100	42	2026-04-09	Gündüz	480	423	57	1000	830	32	2026-04-29 13:06:44.113+00	\N
1101	42	2026-04-08	Gündüz	480	437	43	1000	884	16	2026-04-29 13:06:44.125+00	\N
1102	42	2026-04-07	Gündüz	480	448	32	1000	883	17	2026-04-29 13:06:44.137+00	\N
1103	42	2026-04-06	Gündüz	480	477	3	1000	890	29	2026-04-29 13:06:44.147+00	\N
1104	42	2026-04-05	Gündüz	480	443	37	1000	834	26	2026-04-29 13:06:44.156+00	\N
1105	42	2026-04-04	Gündüz	480	422	58	1000	821	28	2026-04-29 13:06:44.168+00	\N
1106	42	2026-04-03	Gündüz	480	478	2	1000	875	39	2026-04-29 13:06:44.178+00	\N
1107	42	2026-04-02	Gündüz	480	422	58	1000	913	28	2026-04-29 13:06:44.189+00	\N
1108	42	2026-04-01	Gündüz	480	474	6	1000	835	32	2026-04-29 13:06:44.201+00	\N
1109	42	2026-03-31	Gündüz	480	439	41	1000	921	39	2026-04-29 13:06:44.214+00	\N
1110	42	2026-03-30	Gündüz	480	464	16	1000	870	17	2026-04-29 13:06:44.228+00	\N
1111	43	2026-04-28	Gündüz	480	451	29	1000	904	13	2026-04-29 13:06:44.242+00	\N
1112	43	2026-04-27	Gündüz	480	420	60	1000	818	21	2026-04-29 13:06:44.256+00	\N
1113	43	2026-04-26	Gündüz	480	444	36	1000	900	44	2026-04-29 13:06:44.269+00	\N
1114	43	2026-04-25	Gündüz	480	451	29	1000	974	13	2026-04-29 13:06:44.281+00	\N
1115	43	2026-04-24	Gündüz	480	450	30	1000	822	36	2026-04-29 13:06:44.293+00	\N
1116	43	2026-04-23	Gündüz	480	439	41	1000	963	30	2026-04-29 13:06:44.306+00	\N
1117	43	2026-04-22	Gündüz	480	459	21	1000	900	43	2026-04-29 13:06:44.318+00	\N
1118	43	2026-04-21	Gündüz	480	445	35	1000	847	39	2026-04-29 13:06:44.334+00	\N
1119	43	2026-04-20	Gündüz	480	446	34	1000	924	36	2026-04-29 13:06:44.345+00	\N
1120	43	2026-04-19	Gündüz	480	475	5	1000	893	19	2026-04-29 13:06:44.356+00	\N
1121	43	2026-04-18	Gündüz	480	453	27	1000	800	27	2026-04-29 13:06:44.37+00	\N
1122	43	2026-04-17	Gündüz	480	421	59	1000	878	17	2026-04-29 13:06:44.385+00	\N
1123	43	2026-04-16	Gündüz	480	420	60	1000	828	18	2026-04-29 13:06:44.4+00	\N
1124	43	2026-04-15	Gündüz	480	470	10	1000	904	44	2026-04-29 13:06:44.417+00	\N
1125	43	2026-04-14	Gündüz	480	467	13	1000	883	14	2026-04-29 13:06:44.433+00	\N
1126	43	2026-04-13	Gündüz	480	449	31	1000	827	37	2026-04-29 13:06:44.449+00	\N
1127	43	2026-04-12	Gündüz	480	423	57	1000	927	10	2026-04-29 13:06:44.463+00	\N
1128	43	2026-04-11	Gündüz	480	452	28	1000	905	24	2026-04-29 13:06:44.476+00	\N
1129	43	2026-04-10	Gündüz	480	457	23	1000	820	23	2026-04-29 13:06:44.494+00	\N
1130	43	2026-04-09	Gündüz	480	427	53	1000	815	32	2026-04-29 13:06:44.507+00	\N
1131	43	2026-04-08	Gündüz	480	428	52	1000	920	10	2026-04-29 13:06:44.521+00	\N
1132	43	2026-04-07	Gündüz	480	433	47	1000	836	19	2026-04-29 13:06:44.534+00	\N
1133	43	2026-04-06	Gündüz	480	468	12	1000	932	32	2026-04-29 13:06:44.545+00	\N
1134	43	2026-04-05	Gündüz	480	430	50	1000	915	38	2026-04-29 13:06:44.555+00	\N
1135	43	2026-04-04	Gündüz	480	469	11	1000	910	18	2026-04-29 13:06:44.564+00	\N
1136	43	2026-04-03	Gündüz	480	467	13	1000	874	26	2026-04-29 13:06:44.575+00	\N
1137	43	2026-04-02	Gündüz	480	473	7	1000	893	34	2026-04-29 13:06:44.586+00	\N
1138	43	2026-04-01	Gündüz	480	452	28	1000	906	32	2026-04-29 13:06:44.595+00	\N
1139	43	2026-03-31	Gündüz	480	453	27	1000	889	35	2026-04-29 13:06:44.604+00	\N
1140	43	2026-03-30	Gündüz	480	430	50	1000	923	38	2026-04-29 13:06:44.615+00	\N
1141	44	2026-04-28	Gündüz	480	459	21	1000	811	25	2026-04-29 13:06:44.631+00	\N
1142	44	2026-04-27	Gündüz	480	452	28	1000	913	32	2026-04-29 13:06:44.641+00	\N
1143	44	2026-04-26	Gündüz	480	450	30	1000	979	38	2026-04-29 13:06:44.651+00	\N
1144	44	2026-04-25	Gündüz	480	440	40	1000	814	30	2026-04-29 13:06:44.662+00	\N
1145	44	2026-04-24	Gündüz	480	454	26	1000	848	10	2026-04-29 13:06:44.675+00	\N
1146	44	2026-04-23	Gündüz	480	453	27	1000	870	12	2026-04-29 13:06:44.689+00	\N
1147	44	2026-04-22	Gündüz	480	437	43	1000	878	27	2026-04-29 13:06:44.702+00	\N
1148	44	2026-04-21	Gündüz	480	469	11	1000	902	10	2026-04-29 13:06:44.711+00	\N
1149	44	2026-04-20	Gündüz	480	478	2	1000	951	33	2026-04-29 13:06:44.721+00	\N
1150	44	2026-04-19	Gündüz	480	427	53	1000	977	36	2026-04-29 13:06:44.731+00	\N
1151	44	2026-04-18	Gündüz	480	472	8	1000	852	18	2026-04-29 13:06:44.739+00	\N
1152	44	2026-04-17	Gündüz	480	453	27	1000	848	21	2026-04-29 13:06:44.747+00	\N
1153	44	2026-04-16	Gündüz	480	422	58	1000	894	15	2026-04-29 13:06:44.756+00	\N
1154	44	2026-04-15	Gündüz	480	479	1	1000	976	45	2026-04-29 13:06:44.767+00	\N
1155	44	2026-04-14	Gündüz	480	468	12	1000	969	16	2026-04-29 13:06:44.776+00	\N
1156	44	2026-04-13	Gündüz	480	459	21	1000	826	21	2026-04-29 13:06:44.786+00	\N
1157	44	2026-04-12	Gündüz	480	456	24	1000	884	15	2026-04-29 13:06:44.799+00	\N
1158	44	2026-04-11	Gündüz	480	477	3	1000	893	14	2026-04-29 13:06:44.814+00	\N
1159	44	2026-04-10	Gündüz	480	469	11	1000	896	19	2026-04-29 13:06:44.829+00	\N
1160	44	2026-04-09	Gündüz	480	438	42	1000	830	38	2026-04-29 13:06:44.84+00	\N
1161	44	2026-04-08	Gündüz	480	472	8	1000	875	16	2026-04-29 13:06:44.852+00	\N
1162	44	2026-04-07	Gündüz	480	453	27	1000	956	10	2026-04-29 13:06:44.864+00	\N
1163	44	2026-04-06	Gündüz	480	464	16	1000	847	21	2026-04-29 13:06:44.879+00	\N
1164	44	2026-04-05	Gündüz	480	421	59	1000	873	34	2026-04-29 13:06:44.892+00	\N
1165	44	2026-04-04	Gündüz	480	424	56	1000	958	43	2026-04-29 13:06:44.907+00	\N
1166	44	2026-04-03	Gündüz	480	452	28	1000	923	40	2026-04-29 13:06:44.921+00	\N
1167	44	2026-04-02	Gündüz	480	425	55	1000	966	41	2026-04-29 13:06:44.936+00	\N
1168	44	2026-04-01	Gündüz	480	423	57	1000	802	25	2026-04-29 13:06:44.951+00	\N
1169	44	2026-03-31	Gündüz	480	420	60	1000	821	37	2026-04-29 13:06:44.967+00	\N
1170	44	2026-03-30	Gündüz	480	438	42	1000	861	25	2026-04-29 13:06:44.983+00	\N
1171	45	2026-04-28	Gündüz	480	437	43	1000	883	22	2026-04-29 13:06:44.998+00	\N
1172	45	2026-04-27	Gündüz	480	447	33	1000	895	43	2026-04-29 13:06:45.015+00	\N
1173	45	2026-04-26	Gündüz	480	456	24	1000	876	14	2026-04-29 13:06:45.031+00	\N
1174	45	2026-04-25	Gündüz	480	462	18	1000	824	22	2026-04-29 13:06:45.047+00	\N
1175	45	2026-04-24	Gündüz	480	443	37	1000	861	29	2026-04-29 13:06:45.062+00	\N
1176	45	2026-04-23	Gündüz	480	471	9	1000	944	38	2026-04-29 13:06:45.078+00	\N
1177	45	2026-04-22	Gündüz	480	435	45	1000	902	38	2026-04-29 13:06:45.094+00	\N
1178	45	2026-04-21	Gündüz	480	433	47	1000	833	9	2026-04-29 13:06:45.11+00	\N
1179	45	2026-04-20	Gündüz	480	431	49	1000	899	27	2026-04-29 13:06:45.126+00	\N
1180	45	2026-04-19	Gündüz	480	468	12	1000	902	22	2026-04-29 13:06:45.14+00	\N
1181	45	2026-04-18	Gündüz	480	467	13	1000	853	37	2026-04-29 13:06:45.155+00	\N
1182	45	2026-04-17	Gündüz	480	480	0	1000	946	39	2026-04-29 13:06:45.169+00	\N
1183	45	2026-04-16	Gündüz	480	441	39	1000	851	20	2026-04-29 13:06:45.179+00	\N
1184	45	2026-04-15	Gündüz	480	431	49	1000	904	26	2026-04-29 13:06:45.194+00	\N
1185	45	2026-04-14	Gündüz	480	424	56	1000	805	10	2026-04-29 13:06:45.208+00	\N
1186	45	2026-04-13	Gündüz	480	437	43	1000	892	28	2026-04-29 13:06:45.221+00	\N
1187	45	2026-04-12	Gündüz	480	439	41	1000	968	42	2026-04-29 13:06:45.235+00	\N
1188	45	2026-04-11	Gündüz	480	472	8	1000	969	16	2026-04-29 13:06:45.248+00	\N
1189	45	2026-04-10	Gündüz	480	426	54	1000	826	10	2026-04-29 13:06:45.261+00	\N
1190	45	2026-04-09	Gündüz	480	428	52	1000	898	30	2026-04-29 13:06:45.275+00	\N
1191	45	2026-04-08	Gündüz	480	470	10	1000	955	42	2026-04-29 13:06:45.291+00	\N
1192	45	2026-04-07	Gündüz	480	471	9	1000	922	41	2026-04-29 13:06:45.307+00	\N
1193	45	2026-04-06	Gündüz	480	434	46	1000	820	8	2026-04-29 13:06:45.323+00	\N
1194	45	2026-04-05	Gündüz	480	478	2	1000	895	22	2026-04-29 13:06:45.338+00	\N
1195	45	2026-04-04	Gündüz	480	452	28	1000	878	39	2026-04-29 13:06:45.349+00	\N
1196	45	2026-04-03	Gündüz	480	446	34	1000	953	22	2026-04-29 13:06:45.364+00	\N
1197	45	2026-04-02	Gündüz	480	463	17	1000	898	40	2026-04-29 13:06:45.379+00	\N
1198	45	2026-04-01	Gündüz	480	453	27	1000	920	25	2026-04-29 13:06:45.396+00	\N
1199	45	2026-03-31	Gündüz	480	462	18	1000	820	25	2026-04-29 13:06:45.41+00	\N
1200	45	2026-03-30	Gündüz	480	429	51	1000	826	26	2026-04-29 13:06:45.424+00	\N
1201	46	2026-04-28	Gündüz	480	457	23	1000	828	28	2026-04-29 13:06:45.44+00	\N
1202	46	2026-04-27	Gündüz	480	422	58	1000	932	18	2026-04-29 13:06:45.456+00	\N
1203	46	2026-04-26	Gündüz	480	470	10	1000	876	18	2026-04-29 13:06:45.472+00	\N
1204	46	2026-04-25	Gündüz	480	450	30	1000	930	29	2026-04-29 13:06:45.488+00	\N
1205	46	2026-04-24	Gündüz	480	431	49	1000	923	34	2026-04-29 13:06:45.503+00	\N
1206	46	2026-04-23	Gündüz	480	468	12	1000	950	25	2026-04-29 13:06:45.515+00	\N
1207	46	2026-04-22	Gündüz	480	445	35	1000	895	15	2026-04-29 13:06:45.528+00	\N
1208	46	2026-04-21	Gündüz	480	441	39	1000	904	40	2026-04-29 13:06:45.539+00	\N
1209	46	2026-04-20	Gündüz	480	436	44	1000	961	45	2026-04-29 13:06:45.55+00	\N
1210	46	2026-04-19	Gündüz	480	430	50	1000	963	27	2026-04-29 13:06:45.56+00	\N
1211	46	2026-04-18	Gündüz	480	420	60	1000	906	22	2026-04-29 13:06:45.57+00	\N
1212	46	2026-04-17	Gündüz	480	465	15	1000	974	45	2026-04-29 13:06:45.582+00	\N
1213	46	2026-04-16	Gündüz	480	452	28	1000	935	21	2026-04-29 13:06:45.593+00	\N
1214	46	2026-04-15	Gündüz	480	454	26	1000	865	27	2026-04-29 13:06:45.602+00	\N
1215	46	2026-04-14	Gündüz	480	431	49	1000	839	30	2026-04-29 13:06:45.611+00	\N
1216	46	2026-04-13	Gündüz	480	432	48	1000	823	23	2026-04-29 13:06:45.624+00	\N
1217	46	2026-04-12	Gündüz	480	465	15	1000	858	32	2026-04-29 13:06:45.638+00	\N
1218	46	2026-04-11	Gündüz	480	435	45	1000	946	29	2026-04-29 13:06:45.652+00	\N
1219	46	2026-04-10	Gündüz	480	450	30	1000	897	41	2026-04-29 13:06:45.666+00	\N
1220	46	2026-04-09	Gündüz	480	423	57	1000	880	20	2026-04-29 13:06:45.68+00	\N
1221	46	2026-04-08	Gündüz	480	430	50	1000	924	45	2026-04-29 13:06:45.695+00	\N
1222	46	2026-04-07	Gündüz	480	454	26	1000	966	46	2026-04-29 13:06:45.709+00	\N
1223	46	2026-04-06	Gündüz	480	444	36	1000	930	13	2026-04-29 13:06:45.722+00	\N
1224	46	2026-04-05	Gündüz	480	457	23	1000	940	26	2026-04-29 13:06:45.736+00	\N
1225	46	2026-04-04	Gündüz	480	466	14	1000	811	20	2026-04-29 13:06:45.749+00	\N
1226	46	2026-04-03	Gündüz	480	462	18	1000	838	28	2026-04-29 13:06:45.76+00	\N
1227	46	2026-04-02	Gündüz	480	443	37	1000	849	23	2026-04-29 13:06:45.773+00	\N
1228	46	2026-04-01	Gündüz	480	464	16	1000	887	16	2026-04-29 13:06:45.784+00	\N
1229	46	2026-03-31	Gündüz	480	464	16	1000	804	9	2026-04-29 13:06:45.795+00	\N
1230	46	2026-03-30	Gündüz	480	450	30	1000	826	22	2026-04-29 13:06:45.804+00	\N
1231	47	2026-04-28	Gündüz	480	426	54	1000	878	33	2026-04-29 13:06:45.813+00	\N
1232	47	2026-04-27	Gündüz	480	443	37	1000	868	27	2026-04-29 13:06:45.822+00	\N
1233	47	2026-04-26	Gündüz	480	441	39	1000	817	35	2026-04-29 13:06:45.834+00	\N
1234	47	2026-04-25	Gündüz	480	441	39	1000	946	10	2026-04-29 13:06:45.849+00	\N
1235	47	2026-04-24	Gündüz	480	453	27	1000	847	36	2026-04-29 13:06:45.86+00	\N
1236	47	2026-04-23	Gündüz	480	439	41	1000	938	40	2026-04-29 13:06:45.87+00	\N
1237	47	2026-04-22	Gündüz	480	472	8	1000	906	26	2026-04-29 13:06:45.88+00	\N
1238	47	2026-04-21	Gündüz	480	421	59	1000	822	32	2026-04-29 13:06:45.89+00	\N
1239	47	2026-04-20	Gündüz	480	440	40	1000	893	27	2026-04-29 13:06:45.901+00	\N
1240	47	2026-04-19	Gündüz	480	464	16	1000	883	41	2026-04-29 13:06:45.911+00	\N
1241	47	2026-04-18	Gündüz	480	468	12	1000	897	30	2026-04-29 13:06:45.923+00	\N
1242	47	2026-04-17	Gündüz	480	439	41	1000	844	8	2026-04-29 13:06:45.935+00	\N
1243	47	2026-04-16	Gündüz	480	420	60	1000	844	38	2026-04-29 13:06:45.947+00	\N
1244	47	2026-04-15	Gündüz	480	453	27	1000	883	33	2026-04-29 13:06:45.964+00	\N
1245	47	2026-04-14	Gündüz	480	480	0	1000	865	9	2026-04-29 13:06:45.977+00	\N
1246	47	2026-04-13	Gündüz	480	471	9	1000	904	40	2026-04-29 13:06:45.986+00	\N
1247	47	2026-04-12	Gündüz	480	439	41	1000	942	25	2026-04-29 13:06:45.999+00	\N
1248	47	2026-04-11	Gündüz	480	480	0	1000	862	25	2026-04-29 13:06:46.011+00	\N
1249	47	2026-04-10	Gündüz	480	457	23	1000	956	18	2026-04-29 13:06:46.019+00	\N
1250	47	2026-04-09	Gündüz	480	442	38	1000	886	38	2026-04-29 13:06:46.03+00	\N
1251	47	2026-04-08	Gündüz	480	426	54	1000	937	34	2026-04-29 13:06:46.042+00	\N
1252	47	2026-04-07	Gündüz	480	424	56	1000	836	40	2026-04-29 13:06:46.052+00	\N
1253	47	2026-04-06	Gündüz	480	430	50	1000	800	15	2026-04-29 13:06:46.063+00	\N
1254	47	2026-04-05	Gündüz	480	439	41	1000	895	11	2026-04-29 13:06:46.074+00	\N
1255	47	2026-04-04	Gündüz	480	444	36	1000	935	23	2026-04-29 13:06:46.086+00	\N
1256	47	2026-04-03	Gündüz	480	423	57	1000	920	29	2026-04-29 13:06:46.098+00	\N
1257	47	2026-04-02	Gündüz	480	467	13	1000	905	12	2026-04-29 13:06:46.111+00	\N
1258	47	2026-04-01	Gündüz	480	463	17	1000	903	13	2026-04-29 13:06:46.123+00	\N
1259	47	2026-03-31	Gündüz	480	432	48	1000	961	27	2026-04-29 13:06:46.135+00	\N
1260	47	2026-03-30	Gündüz	480	433	47	1000	804	39	2026-04-29 13:06:46.147+00	\N
1261	48	2026-04-28	Gündüz	480	480	0	1000	885	27	2026-04-29 13:06:46.158+00	\N
1262	48	2026-04-27	Gündüz	480	445	35	1000	822	24	2026-04-29 13:06:46.166+00	\N
1263	48	2026-04-26	Gündüz	480	464	16	1000	943	45	2026-04-29 13:06:46.177+00	\N
1264	48	2026-04-25	Gündüz	480	431	49	1000	818	33	2026-04-29 13:06:46.187+00	\N
1265	48	2026-04-24	Gündüz	480	461	19	1000	868	28	2026-04-29 13:06:46.198+00	\N
1266	48	2026-04-23	Gündüz	480	421	59	1000	831	33	2026-04-29 13:06:46.208+00	\N
1267	48	2026-04-22	Gündüz	480	448	32	1000	862	19	2026-04-29 13:06:46.218+00	\N
1268	48	2026-04-21	Gündüz	480	429	51	1000	976	10	2026-04-29 13:06:46.229+00	\N
1269	48	2026-04-20	Gündüz	480	470	10	1000	966	17	2026-04-29 13:06:46.241+00	\N
1270	48	2026-04-19	Gündüz	480	426	54	1000	905	25	2026-04-29 13:06:46.251+00	\N
1271	48	2026-04-18	Gündüz	480	437	43	1000	855	19	2026-04-29 13:06:46.262+00	\N
1272	48	2026-04-17	Gündüz	480	480	0	1000	800	22	2026-04-29 13:06:46.274+00	\N
1273	48	2026-04-16	Gündüz	480	479	1	1000	886	41	2026-04-29 13:06:46.28+00	\N
1274	48	2026-04-15	Gündüz	480	427	53	1000	861	39	2026-04-29 13:06:46.291+00	\N
1275	48	2026-04-14	Gündüz	480	432	48	1000	964	26	2026-04-29 13:06:46.303+00	\N
1276	48	2026-04-13	Gündüz	480	446	34	1000	819	15	2026-04-29 13:06:46.318+00	\N
1277	48	2026-04-12	Gündüz	480	429	51	1000	947	36	2026-04-29 13:06:46.332+00	\N
1278	48	2026-04-11	Gündüz	480	453	27	1000	816	8	2026-04-29 13:06:46.344+00	\N
1279	48	2026-04-10	Gündüz	480	478	2	1000	817	10	2026-04-29 13:06:46.353+00	\N
1280	48	2026-04-09	Gündüz	480	452	28	1000	882	20	2026-04-29 13:06:46.364+00	\N
1281	48	2026-04-08	Gündüz	480	439	41	1000	908	29	2026-04-29 13:06:46.374+00	\N
1282	48	2026-04-07	Gündüz	480	451	29	1000	802	9	2026-04-29 13:06:46.386+00	\N
1283	48	2026-04-06	Gündüz	480	443	37	1000	820	37	2026-04-29 13:06:46.397+00	\N
1284	48	2026-04-05	Gündüz	480	441	39	1000	853	14	2026-04-29 13:06:46.409+00	\N
1285	48	2026-04-04	Gündüz	480	421	59	1000	976	18	2026-04-29 13:06:46.421+00	\N
1286	48	2026-04-03	Gündüz	480	471	9	1000	883	17	2026-04-29 13:06:46.433+00	\N
1287	48	2026-04-02	Gündüz	480	446	34	1000	925	29	2026-04-29 13:06:46.445+00	\N
1288	48	2026-04-01	Gündüz	480	433	47	1000	979	29	2026-04-29 13:06:46.459+00	\N
1289	48	2026-03-31	Gündüz	480	459	21	1000	856	19	2026-04-29 13:06:46.471+00	\N
1290	48	2026-03-30	Gündüz	480	466	14	1000	805	16	2026-04-29 13:06:46.484+00	\N
1291	49	2026-04-28	Gündüz	480	442	38	1000	918	29	2026-04-29 13:06:46.498+00	\N
1292	49	2026-04-27	Gündüz	480	445	35	1000	931	44	2026-04-29 13:06:46.509+00	\N
1293	49	2026-04-26	Gündüz	480	480	0	1000	948	28	2026-04-29 13:06:46.523+00	\N
1294	49	2026-04-25	Gündüz	480	441	39	1000	886	12	2026-04-29 13:06:46.531+00	\N
1295	49	2026-04-24	Gündüz	480	475	5	1000	811	16	2026-04-29 13:06:46.544+00	\N
1296	49	2026-04-23	Gündüz	480	431	49	1000	834	12	2026-04-29 13:06:46.555+00	\N
1297	49	2026-04-22	Gündüz	480	475	5	1000	800	34	2026-04-29 13:06:46.569+00	\N
1298	49	2026-04-21	Gündüz	480	424	56	1000	903	12	2026-04-29 13:06:46.582+00	\N
1299	49	2026-04-20	Gündüz	480	469	11	1000	857	39	2026-04-29 13:06:46.595+00	\N
1300	49	2026-04-19	Gündüz	480	460	20	1000	935	27	2026-04-29 13:06:46.609+00	\N
1301	49	2026-04-18	Gündüz	480	426	54	1000	841	12	2026-04-29 13:06:46.621+00	\N
1302	49	2026-04-17	Gündüz	480	452	28	1000	884	20	2026-04-29 13:06:46.634+00	\N
1303	49	2026-04-16	Gündüz	480	460	20	1000	852	28	2026-04-29 13:06:46.649+00	\N
1304	49	2026-04-15	Gündüz	480	469	11	1000	875	12	2026-04-29 13:06:46.662+00	\N
1305	49	2026-04-14	Gündüz	480	444	36	1000	800	19	2026-04-29 13:06:46.674+00	\N
1306	49	2026-04-13	Gündüz	480	457	23	1000	914	16	2026-04-29 13:06:46.687+00	\N
1307	49	2026-04-12	Gündüz	480	431	49	1000	810	19	2026-04-29 13:06:46.699+00	\N
1308	49	2026-04-11	Gündüz	480	466	14	1000	925	25	2026-04-29 13:06:46.712+00	\N
1309	49	2026-04-10	Gündüz	480	470	10	1000	817	33	2026-04-29 13:06:46.724+00	\N
1310	49	2026-04-09	Gündüz	480	437	43	1000	904	36	2026-04-29 13:06:46.737+00	\N
1311	49	2026-04-08	Gündüz	480	443	37	1000	809	25	2026-04-29 13:06:46.751+00	\N
1312	49	2026-04-07	Gündüz	480	471	9	1000	976	33	2026-04-29 13:06:46.766+00	\N
1313	49	2026-04-06	Gündüz	480	466	14	1000	835	24	2026-04-29 13:06:46.781+00	\N
1314	49	2026-04-05	Gündüz	480	469	11	1000	873	10	2026-04-29 13:06:46.795+00	\N
1315	49	2026-04-04	Gündüz	480	439	41	1000	848	35	2026-04-29 13:06:46.811+00	\N
1316	49	2026-04-03	Gündüz	480	434	46	1000	855	22	2026-04-29 13:06:46.83+00	\N
1317	49	2026-04-02	Gündüz	480	480	0	1000	932	22	2026-04-29 13:06:46.843+00	\N
1318	49	2026-04-01	Gündüz	480	432	48	1000	853	8	2026-04-29 13:06:46.849+00	\N
1319	49	2026-03-31	Gündüz	480	471	9	1000	909	30	2026-04-29 13:06:46.861+00	\N
1320	49	2026-03-30	Gündüz	480	421	59	1000	827	22	2026-04-29 13:06:46.873+00	\N
1321	50	2026-04-28	Gündüz	480	424	56	1000	958	13	2026-04-29 13:06:46.885+00	\N
1322	50	2026-04-27	Gündüz	480	433	47	1000	921	18	2026-04-29 13:06:46.898+00	\N
1323	50	2026-04-26	Gündüz	480	465	15	1000	955	42	2026-04-29 13:06:46.909+00	\N
1324	50	2026-04-25	Gündüz	480	422	58	1000	816	9	2026-04-29 13:06:46.92+00	\N
1325	50	2026-04-24	Gündüz	480	468	12	1000	889	41	2026-04-29 13:06:46.929+00	\N
1326	50	2026-04-23	Gündüz	480	448	32	1000	963	13	2026-04-29 13:06:46.939+00	\N
1327	50	2026-04-22	Gündüz	480	451	29	1000	889	38	2026-04-29 13:06:46.949+00	\N
1328	50	2026-04-21	Gündüz	480	446	34	1000	869	35	2026-04-29 13:06:46.963+00	\N
1329	50	2026-04-20	Gündüz	480	423	57	1000	889	15	2026-04-29 13:06:46.976+00	\N
1330	50	2026-04-19	Gündüz	480	468	12	1000	929	28	2026-04-29 13:06:46.989+00	\N
1331	50	2026-04-18	Gündüz	480	458	22	1000	929	25	2026-04-29 13:06:47.005+00	\N
1332	50	2026-04-17	Gündüz	480	462	18	1000	944	11	2026-04-29 13:06:47.021+00	\N
1333	50	2026-04-16	Gündüz	480	478	2	1000	946	20	2026-04-29 13:06:47.039+00	\N
1334	50	2026-04-15	Gündüz	480	462	18	1000	908	21	2026-04-29 13:06:47.056+00	\N
1335	50	2026-04-14	Gündüz	480	443	37	1000	826	32	2026-04-29 13:06:47.07+00	\N
1336	50	2026-04-13	Gündüz	480	437	43	1000	911	29	2026-04-29 13:06:47.085+00	\N
1337	50	2026-04-12	Gündüz	480	478	2	1000	906	41	2026-04-29 13:06:47.098+00	\N
1338	50	2026-04-11	Gündüz	480	427	53	1000	962	15	2026-04-29 13:06:47.112+00	\N
1339	50	2026-04-10	Gündüz	480	445	35	1000	831	12	2026-04-29 13:06:47.126+00	\N
1340	50	2026-04-09	Gündüz	480	467	13	1000	804	31	2026-04-29 13:06:47.141+00	\N
1341	50	2026-04-08	Gündüz	480	431	49	1000	935	37	2026-04-29 13:06:47.152+00	\N
1342	50	2026-04-07	Gündüz	480	462	18	1000	859	29	2026-04-29 13:06:47.164+00	\N
1343	50	2026-04-06	Gündüz	480	446	34	1000	812	14	2026-04-29 13:06:47.175+00	\N
1344	50	2026-04-05	Gündüz	480	431	49	1000	917	15	2026-04-29 13:06:47.188+00	\N
1345	50	2026-04-04	Gündüz	480	451	29	1000	943	46	2026-04-29 13:06:47.199+00	\N
1346	50	2026-04-03	Gündüz	480	476	4	1000	840	37	2026-04-29 13:06:47.213+00	\N
1347	50	2026-04-02	Gündüz	480	436	44	1000	922	21	2026-04-29 13:06:47.225+00	\N
1348	50	2026-04-01	Gündüz	480	439	41	1000	978	19	2026-04-29 13:06:47.24+00	\N
1349	50	2026-03-31	Gündüz	480	477	3	1000	860	38	2026-04-29 13:06:47.254+00	\N
1350	50	2026-03-30	Gündüz	480	444	36	1000	911	39	2026-04-29 13:06:47.269+00	\N
1351	51	2026-04-28	Gündüz	480	437	43	1000	816	16	2026-04-29 13:06:47.284+00	\N
1352	51	2026-04-27	Gündüz	480	468	12	1000	848	8	2026-04-29 13:06:47.325+00	\N
1353	51	2026-04-26	Gündüz	480	461	19	1000	897	16	2026-04-29 13:06:47.342+00	\N
1354	51	2026-04-25	Gündüz	480	474	6	1000	845	37	2026-04-29 13:06:47.353+00	\N
1355	51	2026-04-24	Gündüz	480	432	48	1000	955	21	2026-04-29 13:06:47.367+00	\N
1356	51	2026-04-23	Gündüz	480	452	28	1000	820	24	2026-04-29 13:06:47.38+00	\N
1357	51	2026-04-22	Gündüz	480	478	2	1000	913	9	2026-04-29 13:06:47.392+00	\N
1358	51	2026-04-21	Gündüz	480	423	57	1000	821	9	2026-04-29 13:06:47.404+00	\N
1359	51	2026-04-20	Gündüz	480	441	39	1000	901	35	2026-04-29 13:06:47.415+00	\N
1360	51	2026-04-19	Gündüz	480	456	24	1000	910	18	2026-04-29 13:06:47.428+00	\N
1361	51	2026-04-18	Gündüz	480	452	28	1000	973	20	2026-04-29 13:06:47.44+00	\N
1362	51	2026-04-17	Gündüz	480	470	10	1000	942	43	2026-04-29 13:06:47.451+00	\N
1363	51	2026-04-16	Gündüz	480	439	41	1000	870	32	2026-04-29 13:06:47.462+00	\N
1364	51	2026-04-15	Gündüz	480	420	60	1000	891	18	2026-04-29 13:06:47.472+00	\N
1365	51	2026-04-14	Gündüz	480	429	51	1000	960	15	2026-04-29 13:06:47.483+00	\N
1366	51	2026-04-13	Gündüz	480	457	23	1000	945	40	2026-04-29 13:06:47.493+00	\N
1367	51	2026-04-12	Gündüz	480	432	48	1000	958	9	2026-04-29 13:06:47.504+00	\N
1368	51	2026-04-11	Gündüz	480	436	44	1000	931	36	2026-04-29 13:06:47.516+00	\N
1369	51	2026-04-10	Gündüz	480	430	50	1000	876	9	2026-04-29 13:06:47.528+00	\N
1370	51	2026-04-09	Gündüz	480	441	39	1000	925	36	2026-04-29 13:06:47.54+00	\N
1371	51	2026-04-08	Gündüz	480	427	53	1000	966	40	2026-04-29 13:06:47.554+00	\N
1372	51	2026-04-07	Gündüz	480	477	3	1000	968	25	2026-04-29 13:06:47.567+00	\N
1373	51	2026-04-06	Gündüz	480	422	58	1000	839	10	2026-04-29 13:06:47.58+00	\N
1374	51	2026-04-05	Gündüz	480	474	6	1000	858	22	2026-04-29 13:06:47.591+00	\N
1375	51	2026-04-04	Gündüz	480	463	17	1000	894	34	2026-04-29 13:06:47.605+00	\N
1376	51	2026-04-03	Gündüz	480	422	58	1000	956	16	2026-04-29 13:06:47.618+00	\N
1377	51	2026-04-02	Gündüz	480	430	50	1000	921	43	2026-04-29 13:06:47.632+00	\N
1378	51	2026-04-01	Gündüz	480	453	27	1000	859	19	2026-04-29 13:06:47.644+00	\N
1379	51	2026-03-31	Gündüz	480	473	7	1000	818	10	2026-04-29 13:06:47.656+00	\N
1380	51	2026-03-30	Gündüz	480	463	17	1000	949	35	2026-04-29 13:06:47.668+00	\N
1381	52	2026-04-28	Gündüz	480	457	23	1000	887	13	2026-04-29 13:06:47.682+00	\N
1382	52	2026-04-27	Gündüz	480	446	34	1000	899	15	2026-04-29 13:06:47.696+00	\N
1383	52	2026-04-26	Gündüz	480	422	58	1000	869	16	2026-04-29 13:06:47.713+00	\N
1384	52	2026-04-25	Gündüz	480	478	2	1000	916	27	2026-04-29 13:06:47.73+00	\N
1385	52	2026-04-24	Gündüz	480	437	43	1000	931	45	2026-04-29 13:06:47.746+00	\N
1386	52	2026-04-23	Gündüz	480	458	22	1000	936	11	2026-04-29 13:06:47.763+00	\N
1387	52	2026-04-22	Gündüz	480	424	56	1000	941	16	2026-04-29 13:06:47.785+00	\N
1388	52	2026-04-21	Gündüz	480	430	50	1000	820	27	2026-04-29 13:06:47.799+00	\N
1389	52	2026-04-20	Gündüz	480	445	35	1000	866	38	2026-04-29 13:06:47.812+00	\N
1390	52	2026-04-19	Gündüz	480	436	44	1000	927	35	2026-04-29 13:06:47.829+00	\N
1391	52	2026-04-18	Gündüz	480	420	60	1000	817	38	2026-04-29 13:06:47.841+00	\N
1392	52	2026-04-17	Gündüz	480	429	51	1000	857	33	2026-04-29 13:06:47.853+00	\N
1393	52	2026-04-16	Gündüz	480	469	11	1000	961	17	2026-04-29 13:06:47.867+00	\N
1394	52	2026-04-15	Gündüz	480	480	0	1000	951	33	2026-04-29 13:06:47.88+00	\N
1395	52	2026-04-14	Gündüz	480	473	7	1000	890	31	2026-04-29 13:06:47.888+00	\N
1396	52	2026-04-13	Gündüz	480	443	37	1000	934	35	2026-04-29 13:06:47.901+00	\N
1397	52	2026-04-12	Gündüz	480	468	12	1000	810	39	2026-04-29 13:06:47.912+00	\N
1398	52	2026-04-11	Gündüz	480	478	2	1000	888	41	2026-04-29 13:06:47.925+00	\N
1399	52	2026-04-10	Gündüz	480	447	33	1000	897	28	2026-04-29 13:06:47.94+00	\N
1400	52	2026-04-09	Gündüz	480	474	6	1000	914	19	2026-04-29 13:06:47.951+00	\N
1401	52	2026-04-08	Gündüz	480	452	28	1000	850	9	2026-04-29 13:06:47.963+00	\N
1402	52	2026-04-07	Gündüz	480	442	38	1000	922	20	2026-04-29 13:06:47.973+00	\N
1403	52	2026-04-06	Gündüz	480	445	35	1000	862	32	2026-04-29 13:06:47.985+00	\N
1404	52	2026-04-05	Gündüz	480	434	46	1000	904	31	2026-04-29 13:06:47.997+00	\N
1405	52	2026-04-04	Gündüz	480	454	26	1000	920	13	2026-04-29 13:06:48.011+00	\N
1406	52	2026-04-03	Gündüz	480	459	21	1000	963	44	2026-04-29 13:06:48.024+00	\N
1407	52	2026-04-02	Gündüz	480	428	52	1000	879	31	2026-04-29 13:06:48.036+00	\N
1408	52	2026-04-01	Gündüz	480	448	32	1000	872	38	2026-04-29 13:06:48.048+00	\N
1409	52	2026-03-31	Gündüz	480	478	2	1000	900	25	2026-04-29 13:06:48.06+00	\N
1410	52	2026-03-30	Gündüz	480	435	45	1000	913	40	2026-04-29 13:06:48.079+00	\N
1411	53	2026-04-28	Gündüz	480	435	45	1000	879	33	2026-04-29 13:06:48.096+00	\N
1412	53	2026-04-27	Gündüz	480	462	18	1000	934	11	2026-04-29 13:06:48.117+00	\N
1413	53	2026-04-26	Gündüz	480	430	50	1000	808	36	2026-04-29 13:06:48.132+00	\N
1414	53	2026-04-25	Gündüz	480	431	49	1000	929	29	2026-04-29 13:06:48.146+00	\N
1415	53	2026-04-24	Gündüz	480	438	42	1000	847	29	2026-04-29 13:06:48.162+00	\N
1416	53	2026-04-23	Gündüz	480	426	54	1000	803	39	2026-04-29 13:06:48.175+00	\N
1417	53	2026-04-22	Gündüz	480	452	28	1000	895	12	2026-04-29 13:06:48.19+00	\N
1418	53	2026-04-21	Gündüz	480	434	46	1000	927	18	2026-04-29 13:06:48.203+00	\N
1419	53	2026-04-20	Gündüz	480	421	59	1000	858	30	2026-04-29 13:06:48.213+00	\N
1420	53	2026-04-19	Gündüz	480	445	35	1000	929	14	2026-04-29 13:06:48.222+00	\N
1421	53	2026-04-18	Gündüz	480	443	37	1000	977	45	2026-04-29 13:06:48.233+00	\N
1422	53	2026-04-17	Gündüz	480	450	30	1000	852	30	2026-04-29 13:06:48.246+00	\N
1423	53	2026-04-16	Gündüz	480	421	59	1000	886	39	2026-04-29 13:06:48.258+00	\N
1424	53	2026-04-15	Gündüz	480	470	10	1000	852	15	2026-04-29 13:06:48.27+00	\N
1425	53	2026-04-14	Gündüz	480	470	10	1000	886	26	2026-04-29 13:06:48.281+00	\N
1426	53	2026-04-13	Gündüz	480	427	53	1000	880	28	2026-04-29 13:06:48.291+00	\N
1427	53	2026-04-12	Gündüz	480	421	59	1000	848	40	2026-04-29 13:06:48.301+00	\N
1428	53	2026-04-11	Gündüz	480	476	4	1000	857	25	2026-04-29 13:06:48.311+00	\N
1429	53	2026-04-10	Gündüz	480	461	19	1000	959	39	2026-04-29 13:06:48.369+00	\N
1430	53	2026-04-09	Gündüz	480	468	12	1000	864	33	2026-04-29 13:06:48.385+00	\N
1431	53	2026-04-08	Gündüz	480	445	35	1000	951	23	2026-04-29 13:06:48.399+00	\N
1432	53	2026-04-07	Gündüz	480	476	4	1000	837	12	2026-04-29 13:06:48.417+00	\N
1433	53	2026-04-06	Gündüz	480	455	25	1000	830	9	2026-04-29 13:06:48.436+00	\N
1434	53	2026-04-05	Gündüz	480	465	15	1000	892	42	2026-04-29 13:06:48.448+00	\N
1435	53	2026-04-04	Gündüz	480	436	44	1000	825	28	2026-04-29 13:06:48.457+00	\N
1436	53	2026-04-03	Gündüz	480	460	20	1000	854	20	2026-04-29 13:06:48.467+00	\N
1437	53	2026-04-02	Gündüz	480	471	9	1000	948	43	2026-04-29 13:06:48.477+00	\N
1438	53	2026-04-01	Gündüz	480	427	53	1000	912	27	2026-04-29 13:06:48.487+00	\N
1439	53	2026-03-31	Gündüz	480	449	31	1000	944	43	2026-04-29 13:06:48.496+00	\N
1440	53	2026-03-30	Gündüz	480	421	59	1000	921	23	2026-04-29 13:06:48.508+00	\N
1441	54	2026-04-28	Gündüz	480	468	12	1000	977	15	2026-04-29 13:06:48.521+00	\N
1442	54	2026-04-27	Gündüz	480	430	50	1000	961	10	2026-04-29 13:06:48.533+00	\N
1443	54	2026-04-26	Gündüz	480	468	12	1000	876	35	2026-04-29 13:06:48.546+00	\N
1444	54	2026-04-25	Gündüz	480	438	42	1000	943	38	2026-04-29 13:06:48.56+00	\N
1445	54	2026-04-24	Gündüz	480	443	37	1000	962	28	2026-04-29 13:06:48.575+00	\N
1446	54	2026-04-23	Gündüz	480	476	4	1000	975	39	2026-04-29 13:06:48.591+00	\N
1447	54	2026-04-22	Gündüz	480	433	47	1000	819	31	2026-04-29 13:06:48.611+00	\N
1448	54	2026-04-21	Gündüz	480	454	26	1000	846	31	2026-04-29 13:06:48.626+00	\N
1449	54	2026-04-20	Gündüz	480	468	12	1000	964	32	2026-04-29 13:06:48.642+00	\N
1450	54	2026-04-19	Gündüz	480	464	16	1000	943	42	2026-04-29 13:06:48.655+00	\N
1451	54	2026-04-18	Gündüz	480	444	36	1000	868	19	2026-04-29 13:06:48.67+00	\N
1452	54	2026-04-17	Gündüz	480	442	38	1000	975	39	2026-04-29 13:06:48.685+00	\N
1453	54	2026-04-16	Gündüz	480	475	5	1000	929	17	2026-04-29 13:06:48.7+00	\N
1454	54	2026-04-15	Gündüz	480	466	14	1000	867	29	2026-04-29 13:06:48.715+00	\N
1455	54	2026-04-14	Gündüz	480	447	33	1000	875	39	2026-04-29 13:06:48.731+00	\N
1456	54	2026-04-13	Gündüz	480	457	23	1000	901	38	2026-04-29 13:06:48.747+00	\N
1457	54	2026-04-12	Gündüz	480	466	14	1000	823	8	2026-04-29 13:06:48.764+00	\N
1458	54	2026-04-11	Gündüz	480	480	0	1000	867	8	2026-04-29 13:06:48.781+00	\N
1459	54	2026-04-10	Gündüz	480	462	18	1000	930	36	2026-04-29 13:06:48.79+00	\N
1460	54	2026-04-09	Gündüz	480	464	16	1000	938	14	2026-04-29 13:06:48.81+00	\N
1461	54	2026-04-08	Gündüz	480	455	25	1000	942	29	2026-04-29 13:06:48.823+00	\N
1462	54	2026-04-07	Gündüz	480	435	45	1000	894	25	2026-04-29 13:06:48.836+00	\N
1463	54	2026-04-06	Gündüz	480	471	9	1000	880	35	2026-04-29 13:06:48.848+00	\N
1464	54	2026-04-05	Gündüz	480	434	46	1000	876	41	2026-04-29 13:06:48.861+00	\N
1465	54	2026-04-04	Gündüz	480	477	3	1000	801	8	2026-04-29 13:06:48.874+00	\N
1466	54	2026-04-03	Gündüz	480	439	41	1000	868	15	2026-04-29 13:06:48.886+00	\N
1467	54	2026-04-02	Gündüz	480	476	4	1000	818	38	2026-04-29 13:06:48.897+00	\N
1468	54	2026-04-01	Gündüz	480	473	7	1000	929	35	2026-04-29 13:06:48.914+00	\N
1469	54	2026-03-31	Gündüz	480	464	16	1000	966	25	2026-04-29 13:06:48.933+00	\N
1470	54	2026-03-30	Gündüz	480	468	12	1000	901	19	2026-04-29 13:06:48.943+00	\N
1471	55	2026-04-28	Gündüz	480	469	11	1000	852	35	2026-04-29 13:06:48.954+00	\N
1472	55	2026-04-27	Gündüz	480	458	22	1000	811	8	2026-04-29 13:06:48.965+00	\N
1473	55	2026-04-26	Gündüz	480	423	57	1000	833	34	2026-04-29 13:06:48.976+00	\N
1474	55	2026-04-25	Gündüz	480	429	51	1000	882	27	2026-04-29 13:06:48.988+00	\N
1475	55	2026-04-24	Gündüz	480	426	54	1000	866	20	2026-04-29 13:06:48.999+00	\N
1476	55	2026-04-23	Gündüz	480	457	23	1000	834	29	2026-04-29 13:06:49.01+00	\N
1477	55	2026-04-22	Gündüz	480	432	48	1000	806	33	2026-04-29 13:06:49.021+00	\N
1478	55	2026-04-21	Gündüz	480	476	4	1000	874	29	2026-04-29 13:06:49.036+00	\N
1479	55	2026-04-20	Gündüz	480	422	58	1000	914	13	2026-04-29 13:06:49.05+00	\N
1480	55	2026-04-19	Gündüz	480	422	58	1000	857	15	2026-04-29 13:06:49.063+00	\N
1481	55	2026-04-18	Gündüz	480	462	18	1000	820	12	2026-04-29 13:06:49.075+00	\N
1482	55	2026-04-17	Gündüz	480	456	24	1000	804	33	2026-04-29 13:06:49.089+00	\N
1483	55	2026-04-16	Gündüz	480	471	9	1000	935	38	2026-04-29 13:06:49.103+00	\N
1484	55	2026-04-15	Gündüz	480	461	19	1000	943	36	2026-04-29 13:06:49.12+00	\N
1485	55	2026-04-14	Gündüz	480	429	51	1000	828	10	2026-04-29 13:06:49.135+00	\N
1486	55	2026-04-13	Gündüz	480	431	49	1000	897	35	2026-04-29 13:06:49.149+00	\N
1487	55	2026-04-12	Gündüz	480	471	9	1000	844	34	2026-04-29 13:06:49.164+00	\N
1488	55	2026-04-11	Gündüz	480	441	39	1000	858	34	2026-04-29 13:06:49.179+00	\N
1489	55	2026-04-10	Gündüz	480	452	28	1000	853	11	2026-04-29 13:06:49.199+00	\N
1490	55	2026-04-09	Gündüz	480	448	32	1000	886	22	2026-04-29 13:06:49.216+00	\N
1491	55	2026-04-08	Gündüz	480	456	24	1000	807	38	2026-04-29 13:06:49.232+00	\N
1492	55	2026-04-07	Gündüz	480	422	58	1000	898	13	2026-04-29 13:06:49.247+00	\N
1493	55	2026-04-06	Gündüz	480	425	55	1000	841	19	2026-04-29 13:06:49.263+00	\N
1494	55	2026-04-05	Gündüz	480	421	59	1000	885	38	2026-04-29 13:06:49.278+00	\N
1495	55	2026-04-04	Gündüz	480	459	21	1000	832	20	2026-04-29 13:06:49.294+00	\N
1496	55	2026-04-03	Gündüz	480	471	9	1000	915	23	2026-04-29 13:06:49.31+00	\N
1497	55	2026-04-02	Gündüz	480	461	19	1000	919	45	2026-04-29 13:06:49.323+00	\N
1498	55	2026-04-01	Gündüz	480	455	25	1000	959	29	2026-04-29 13:06:49.335+00	\N
1499	55	2026-03-31	Gündüz	480	434	46	1000	803	13	2026-04-29 13:06:49.346+00	\N
1500	55	2026-03-30	Gündüz	480	452	28	1000	891	11	2026-04-29 13:06:49.358+00	\N
1501	56	2026-04-28	Gündüz	480	429	51	1000	917	30	2026-04-29 13:06:49.37+00	\N
1502	56	2026-04-27	Gündüz	480	422	58	1000	924	28	2026-04-29 13:06:49.383+00	\N
1503	56	2026-04-26	Gündüz	480	464	16	1000	894	16	2026-04-29 13:06:49.397+00	\N
1504	56	2026-04-25	Gündüz	480	479	1	1000	857	27	2026-04-29 13:06:49.41+00	\N
1505	56	2026-04-24	Gündüz	480	475	5	1000	811	15	2026-04-29 13:06:49.421+00	\N
1506	56	2026-04-23	Gündüz	480	464	16	1000	887	27	2026-04-29 13:06:49.432+00	\N
1507	56	2026-04-22	Gündüz	480	439	41	1000	861	11	2026-04-29 13:06:49.446+00	\N
1508	56	2026-04-21	Gündüz	480	426	54	1000	897	34	2026-04-29 13:06:49.46+00	\N
1509	56	2026-04-20	Gündüz	480	459	21	1000	947	28	2026-04-29 13:06:49.474+00	\N
1510	56	2026-04-19	Gündüz	480	452	28	1000	866	19	2026-04-29 13:06:49.487+00	\N
1511	56	2026-04-18	Gündüz	480	475	5	1000	805	19	2026-04-29 13:06:49.498+00	\N
1512	56	2026-04-17	Gündüz	480	480	0	1000	907	19	2026-04-29 13:06:49.51+00	\N
1513	56	2026-04-16	Gündüz	480	421	59	1000	975	33	2026-04-29 13:06:49.517+00	\N
1514	56	2026-04-15	Gündüz	480	470	10	1000	809	40	2026-04-29 13:06:49.528+00	\N
1515	56	2026-04-14	Gündüz	480	454	26	1000	913	31	2026-04-29 13:06:49.54+00	\N
1516	56	2026-04-13	Gündüz	480	439	41	1000	801	32	2026-04-29 13:06:49.551+00	\N
1517	56	2026-04-12	Gündüz	480	471	9	1000	850	41	2026-04-29 13:06:49.563+00	\N
1518	56	2026-04-11	Gündüz	480	463	17	1000	849	11	2026-04-29 13:06:49.577+00	\N
1519	56	2026-04-10	Gündüz	480	469	11	1000	909	20	2026-04-29 13:06:49.59+00	\N
1520	56	2026-04-09	Gündüz	480	450	30	1000	889	36	2026-04-29 13:06:49.606+00	\N
1521	56	2026-04-08	Gündüz	480	427	53	1000	811	37	2026-04-29 13:06:49.62+00	\N
1522	56	2026-04-07	Gündüz	480	446	34	1000	929	39	2026-04-29 13:06:49.63+00	\N
1523	56	2026-04-06	Gündüz	480	479	1	1000	964	12	2026-04-29 13:06:49.641+00	\N
1524	56	2026-04-05	Gündüz	480	444	36	1000	975	31	2026-04-29 13:06:49.653+00	\N
1525	56	2026-04-04	Gündüz	480	472	8	1000	876	22	2026-04-29 13:06:49.664+00	\N
1526	56	2026-04-03	Gündüz	480	474	6	1000	818	40	2026-04-29 13:06:49.676+00	\N
1527	56	2026-04-02	Gündüz	480	437	43	1000	909	43	2026-04-29 13:06:49.688+00	\N
1528	56	2026-04-01	Gündüz	480	469	11	1000	889	37	2026-04-29 13:06:49.698+00	\N
1529	56	2026-03-31	Gündüz	480	427	53	1000	947	12	2026-04-29 13:06:49.71+00	\N
1530	56	2026-03-30	Gündüz	480	460	20	1000	841	20	2026-04-29 13:06:49.72+00	\N
1531	57	2026-04-28	Gündüz	480	425	55	1000	901	13	2026-04-29 13:06:49.731+00	\N
1532	57	2026-04-27	Gündüz	480	426	54	1000	866	30	2026-04-29 13:06:49.74+00	\N
1533	57	2026-04-26	Gündüz	480	441	39	1000	883	15	2026-04-29 13:06:49.751+00	\N
1534	57	2026-04-25	Gündüz	480	468	12	1000	976	15	2026-04-29 13:06:49.762+00	\N
1535	57	2026-04-24	Gündüz	480	434	46	1000	943	16	2026-04-29 13:06:49.774+00	\N
1536	57	2026-04-23	Gündüz	480	472	8	1000	914	33	2026-04-29 13:06:49.785+00	\N
1537	57	2026-04-22	Gündüz	480	436	44	1000	879	22	2026-04-29 13:06:49.793+00	\N
1538	57	2026-04-21	Gündüz	480	427	53	1000	934	10	2026-04-29 13:06:49.802+00	\N
1539	57	2026-04-20	Gündüz	480	476	4	1000	968	35	2026-04-29 13:06:49.814+00	\N
1540	57	2026-04-19	Gündüz	480	427	53	1000	864	38	2026-04-29 13:06:49.826+00	\N
1541	57	2026-04-18	Gündüz	480	443	37	1000	843	25	2026-04-29 13:06:49.84+00	\N
1542	57	2026-04-17	Gündüz	480	463	17	1000	908	34	2026-04-29 13:06:49.855+00	\N
1543	57	2026-04-16	Gündüz	480	463	17	1000	964	42	2026-04-29 13:06:49.87+00	\N
1544	57	2026-04-15	Gündüz	480	480	0	1000	831	14	2026-04-29 13:06:49.883+00	\N
1545	57	2026-04-14	Gündüz	480	476	4	1000	926	45	2026-04-29 13:06:49.891+00	\N
1546	57	2026-04-13	Gündüz	480	477	3	1000	908	44	2026-04-29 13:06:49.903+00	\N
1547	57	2026-04-12	Gündüz	480	476	4	1000	831	19	2026-04-29 13:06:49.918+00	\N
1548	57	2026-04-11	Gündüz	480	430	50	1000	807	24	2026-04-29 13:06:49.931+00	\N
1549	57	2026-04-10	Gündüz	480	467	13	1000	831	31	2026-04-29 13:06:49.946+00	\N
1550	57	2026-04-09	Gündüz	480	453	27	1000	933	27	2026-04-29 13:06:49.967+00	\N
1551	57	2026-04-08	Gündüz	480	434	46	1000	835	18	2026-04-29 13:06:49.981+00	\N
1552	57	2026-04-07	Gündüz	480	462	18	1000	966	11	2026-04-29 13:06:49.994+00	\N
1553	57	2026-04-06	Gündüz	480	443	37	1000	856	38	2026-04-29 13:06:50.005+00	\N
1554	57	2026-04-05	Gündüz	480	454	26	1000	933	40	2026-04-29 13:06:50.016+00	\N
1555	57	2026-04-04	Gündüz	480	473	7	1000	934	22	2026-04-29 13:06:50.028+00	\N
1556	57	2026-04-03	Gündüz	480	443	37	1000	821	34	2026-04-29 13:06:50.038+00	\N
1557	57	2026-04-02	Gündüz	480	475	5	1000	830	9	2026-04-29 13:06:50.048+00	\N
1558	57	2026-04-01	Gündüz	480	431	49	1000	828	32	2026-04-29 13:06:50.056+00	\N
1559	57	2026-03-31	Gündüz	480	473	7	1000	825	34	2026-04-29 13:06:50.067+00	\N
1560	57	2026-03-30	Gündüz	480	475	5	1000	851	41	2026-04-29 13:06:50.077+00	\N
1561	58	2026-04-28	Gündüz	480	470	10	1000	975	12	2026-04-29 13:06:50.086+00	\N
1562	58	2026-04-27	Gündüz	480	436	44	1000	914	44	2026-04-29 13:06:50.096+00	\N
1563	58	2026-04-26	Gündüz	480	428	52	1000	908	9	2026-04-29 13:06:50.105+00	\N
1564	58	2026-04-25	Gündüz	480	423	57	1000	828	37	2026-04-29 13:06:50.114+00	\N
1565	58	2026-04-24	Gündüz	480	434	46	1000	956	34	2026-04-29 13:06:50.125+00	\N
1566	58	2026-04-23	Gündüz	480	473	7	1000	813	21	2026-04-29 13:06:50.134+00	\N
1567	58	2026-04-22	Gündüz	480	442	38	1000	811	39	2026-04-29 13:06:50.146+00	\N
1568	58	2026-04-21	Gündüz	480	426	54	1000	824	26	2026-04-29 13:06:50.156+00	\N
1569	58	2026-04-20	Gündüz	480	437	43	1000	935	33	2026-04-29 13:06:50.166+00	\N
1570	58	2026-04-19	Gündüz	480	438	42	1000	889	36	2026-04-29 13:06:50.177+00	\N
1571	58	2026-04-18	Gündüz	480	461	19	1000	883	17	2026-04-29 13:06:50.189+00	\N
1572	58	2026-04-17	Gündüz	480	480	0	1000	901	40	2026-04-29 13:06:50.203+00	\N
1573	58	2026-04-16	Gündüz	480	441	39	1000	907	41	2026-04-29 13:06:50.215+00	\N
1574	58	2026-04-15	Gündüz	480	454	26	1000	905	19	2026-04-29 13:06:50.229+00	\N
1575	58	2026-04-14	Gündüz	480	463	17	1000	803	8	2026-04-29 13:06:50.241+00	\N
1576	58	2026-04-13	Gündüz	480	448	32	1000	897	27	2026-04-29 13:06:50.253+00	\N
1577	58	2026-04-12	Gündüz	480	454	26	1000	975	43	2026-04-29 13:06:50.264+00	\N
1578	58	2026-04-11	Gündüz	480	445	35	1000	951	26	2026-04-29 13:06:50.275+00	\N
1579	58	2026-04-10	Gündüz	480	439	41	1000	931	42	2026-04-29 13:06:50.286+00	\N
1580	58	2026-04-09	Gündüz	480	479	1	1000	927	39	2026-04-29 13:06:50.298+00	\N
1581	58	2026-04-08	Gündüz	480	475	5	1000	948	28	2026-04-29 13:06:50.31+00	\N
1582	58	2026-04-07	Gündüz	480	457	23	1000	805	35	2026-04-29 13:06:50.327+00	\N
1583	58	2026-04-06	Gündüz	480	442	38	1000	821	22	2026-04-29 13:06:50.343+00	\N
1584	58	2026-04-05	Gündüz	480	475	5	1000	922	44	2026-04-29 13:06:50.355+00	\N
1585	58	2026-04-04	Gündüz	480	454	26	1000	877	21	2026-04-29 13:06:50.37+00	\N
1586	58	2026-04-03	Gündüz	480	469	11	1000	910	45	2026-04-29 13:06:50.384+00	\N
1587	58	2026-04-02	Gündüz	480	466	14	1000	843	13	2026-04-29 13:06:50.397+00	\N
1588	58	2026-04-01	Gündüz	480	435	45	1000	839	37	2026-04-29 13:06:50.412+00	\N
1589	58	2026-03-31	Gündüz	480	478	2	1000	898	13	2026-04-29 13:06:50.428+00	\N
1590	58	2026-03-30	Gündüz	480	435	45	1000	889	24	2026-04-29 13:06:50.445+00	\N
1591	59	2026-04-28	Gündüz	480	431	49	1000	913	20	2026-04-29 13:06:50.46+00	\N
1592	59	2026-04-27	Gündüz	480	420	60	1000	806	8	2026-04-29 13:06:50.478+00	\N
1593	59	2026-04-26	Gündüz	480	456	24	1000	897	19	2026-04-29 13:06:50.496+00	\N
1594	59	2026-04-25	Gündüz	480	438	42	1000	828	8	2026-04-29 13:06:50.513+00	\N
1595	59	2026-04-24	Gündüz	480	478	2	1000	893	35	2026-04-29 13:06:50.532+00	\N
1596	59	2026-04-23	Gündüz	480	450	30	1000	871	13	2026-04-29 13:06:50.548+00	\N
1597	59	2026-04-22	Gündüz	480	459	21	1000	882	38	2026-04-29 13:06:50.563+00	\N
1598	59	2026-04-21	Gündüz	480	422	58	1000	966	26	2026-04-29 13:06:50.577+00	\N
1599	59	2026-04-20	Gündüz	480	478	2	1000	965	39	2026-04-29 13:06:50.588+00	\N
1600	59	2026-04-19	Gündüz	480	472	8	1000	974	9	2026-04-29 13:06:50.601+00	\N
1601	59	2026-04-18	Gündüz	480	430	50	1000	962	13	2026-04-29 13:06:50.613+00	\N
1602	59	2026-04-17	Gündüz	480	471	9	1000	905	32	2026-04-29 13:06:50.626+00	\N
1603	59	2026-04-16	Gündüz	480	472	8	1000	952	10	2026-04-29 13:06:50.641+00	\N
1604	59	2026-04-15	Gündüz	480	436	44	1000	851	27	2026-04-29 13:06:50.655+00	\N
1605	59	2026-04-14	Gündüz	480	425	55	1000	960	39	2026-04-29 13:06:50.669+00	\N
1606	59	2026-04-13	Gündüz	480	420	60	1000	916	20	2026-04-29 13:06:50.684+00	\N
1607	59	2026-04-12	Gündüz	480	423	57	1000	905	22	2026-04-29 13:06:50.697+00	\N
1608	59	2026-04-11	Gündüz	480	465	15	1000	878	36	2026-04-29 13:06:50.711+00	\N
1609	59	2026-04-10	Gündüz	480	444	36	1000	933	27	2026-04-29 13:06:50.724+00	\N
1610	59	2026-04-09	Gündüz	480	445	35	1000	979	29	2026-04-29 13:06:50.738+00	\N
1611	59	2026-04-08	Gündüz	480	438	42	1000	865	16	2026-04-29 13:06:50.756+00	\N
1612	59	2026-04-07	Gündüz	480	445	35	1000	962	32	2026-04-29 13:06:50.771+00	\N
1613	59	2026-04-06	Gündüz	480	445	35	1000	826	11	2026-04-29 13:06:50.785+00	\N
1614	59	2026-04-05	Gündüz	480	426	54	1000	943	41	2026-04-29 13:06:50.799+00	\N
1615	59	2026-04-04	Gündüz	480	422	58	1000	963	10	2026-04-29 13:06:50.813+00	\N
1616	59	2026-04-03	Gündüz	480	439	41	1000	802	26	2026-04-29 13:06:50.828+00	\N
1617	59	2026-04-02	Gündüz	480	457	23	1000	851	29	2026-04-29 13:06:50.842+00	\N
1618	59	2026-04-01	Gündüz	480	469	11	1000	918	33	2026-04-29 13:06:50.854+00	\N
1619	59	2026-03-31	Gündüz	480	477	3	1000	953	38	2026-04-29 13:06:50.869+00	\N
1620	59	2026-03-30	Gündüz	480	458	22	1000	883	15	2026-04-29 13:06:50.883+00	\N
1621	60	2026-04-28	Gündüz	480	448	32	1000	878	11	2026-04-29 13:06:50.9+00	\N
1622	60	2026-04-27	Gündüz	480	449	31	1000	867	10	2026-04-29 13:06:50.918+00	\N
1623	60	2026-04-26	Gündüz	480	439	41	1000	913	45	2026-04-29 13:06:50.934+00	\N
1624	60	2026-04-25	Gündüz	480	454	26	1000	856	42	2026-04-29 13:06:50.949+00	\N
1625	60	2026-04-24	Gündüz	480	477	3	1000	845	21	2026-04-29 13:06:50.969+00	\N
1626	60	2026-04-23	Gündüz	480	423	57	1000	920	12	2026-04-29 13:06:50.982+00	\N
1627	60	2026-04-22	Gündüz	480	429	51	1000	964	41	2026-04-29 13:06:50.991+00	\N
1628	60	2026-04-21	Gündüz	480	432	48	1000	940	45	2026-04-29 13:06:51.002+00	\N
1629	60	2026-04-20	Gündüz	480	424	56	1000	935	9	2026-04-29 13:06:51.012+00	\N
1630	60	2026-04-19	Gündüz	480	471	9	1000	807	18	2026-04-29 13:06:51.026+00	\N
1631	60	2026-04-18	Gündüz	480	473	7	1000	815	20	2026-04-29 13:06:51.038+00	\N
1632	60	2026-04-17	Gündüz	480	471	9	1000	816	23	2026-04-29 13:06:51.05+00	\N
1633	60	2026-04-16	Gündüz	480	450	30	1000	917	22	2026-04-29 13:06:51.065+00	\N
1634	60	2026-04-15	Gündüz	480	444	36	1000	949	21	2026-04-29 13:06:51.082+00	\N
1635	60	2026-04-14	Gündüz	480	436	44	1000	816	19	2026-04-29 13:06:51.099+00	\N
1636	60	2026-04-13	Gündüz	480	449	31	1000	975	21	2026-04-29 13:06:51.115+00	\N
1637	60	2026-04-12	Gündüz	480	445	35	1000	944	16	2026-04-29 13:06:51.134+00	\N
1638	60	2026-04-11	Gündüz	480	473	7	1000	964	25	2026-04-29 13:06:51.151+00	\N
1639	60	2026-04-10	Gündüz	480	440	40	1000	834	25	2026-04-29 13:06:51.168+00	\N
1640	60	2026-04-09	Gündüz	480	438	42	1000	893	11	2026-04-29 13:06:51.186+00	\N
1641	60	2026-04-08	Gündüz	480	425	55	1000	842	35	2026-04-29 13:06:51.201+00	\N
1642	60	2026-04-07	Gündüz	480	453	27	1000	807	23	2026-04-29 13:06:51.217+00	\N
1643	60	2026-04-06	Gündüz	480	446	34	1000	934	43	2026-04-29 13:06:51.234+00	\N
1644	60	2026-04-05	Gündüz	480	423	57	1000	828	18	2026-04-29 13:06:51.249+00	\N
1645	60	2026-04-04	Gündüz	480	420	60	1000	864	20	2026-04-29 13:06:51.263+00	\N
1646	60	2026-04-03	Gündüz	480	475	5	1000	822	10	2026-04-29 13:06:51.278+00	\N
1647	60	2026-04-02	Gündüz	480	423	57	1000	874	23	2026-04-29 13:06:51.291+00	\N
1648	60	2026-04-01	Gündüz	480	454	26	1000	880	32	2026-04-29 13:06:51.307+00	\N
1649	60	2026-03-31	Gündüz	480	480	0	1000	947	43	2026-04-29 13:06:51.32+00	\N
1650	60	2026-03-30	Gündüz	480	422	58	1000	939	12	2026-04-29 13:06:51.328+00	\N
1651	61	2026-04-28	Gündüz	480	423	57	1000	814	33	2026-04-29 13:06:51.339+00	\N
1652	61	2026-04-27	Gündüz	480	453	27	1000	930	28	2026-04-29 13:06:51.351+00	\N
1653	61	2026-04-26	Gündüz	480	477	3	1000	947	12	2026-04-29 13:06:51.365+00	\N
1654	61	2026-04-25	Gündüz	480	425	55	1000	964	16	2026-04-29 13:06:51.379+00	\N
1655	61	2026-04-24	Gündüz	480	452	28	1000	950	19	2026-04-29 13:06:51.393+00	\N
1656	61	2026-04-23	Gündüz	480	470	10	1000	936	44	2026-04-29 13:06:51.406+00	\N
1657	61	2026-04-22	Gündüz	480	459	21	1000	946	34	2026-04-29 13:06:51.419+00	\N
1658	61	2026-04-21	Gündüz	480	466	14	1000	926	33	2026-04-29 13:06:51.433+00	\N
1659	61	2026-04-20	Gündüz	480	459	21	1000	844	30	2026-04-29 13:06:51.449+00	\N
1660	61	2026-04-19	Gündüz	480	424	56	1000	934	28	2026-04-29 13:06:51.466+00	\N
1661	61	2026-04-18	Gündüz	480	465	15	1000	911	16	2026-04-29 13:06:51.487+00	\N
1662	61	2026-04-17	Gündüz	480	469	11	1000	817	19	2026-04-29 13:06:51.507+00	\N
1663	61	2026-04-16	Gündüz	480	464	16	1000	829	13	2026-04-29 13:06:51.528+00	\N
1664	61	2026-04-15	Gündüz	480	463	17	1000	836	34	2026-04-29 13:06:51.546+00	\N
1665	61	2026-04-14	Gündüz	480	447	33	1000	965	28	2026-04-29 13:06:51.565+00	\N
1666	61	2026-04-13	Gündüz	480	447	33	1000	897	32	2026-04-29 13:06:51.582+00	\N
1667	61	2026-04-12	Gündüz	480	438	42	1000	855	25	2026-04-29 13:06:51.601+00	\N
1668	61	2026-04-11	Gündüz	480	433	47	1000	897	28	2026-04-29 13:06:51.622+00	\N
1669	61	2026-04-10	Gündüz	480	442	38	1000	826	34	2026-04-29 13:06:51.642+00	\N
1670	61	2026-04-09	Gündüz	480	476	4	1000	889	13	2026-04-29 13:06:51.661+00	\N
1671	61	2026-04-08	Gündüz	480	425	55	1000	837	29	2026-04-29 13:06:51.68+00	\N
1672	61	2026-04-07	Gündüz	480	454	26	1000	881	16	2026-04-29 13:06:51.697+00	\N
1673	61	2026-04-06	Gündüz	480	457	23	1000	937	19	2026-04-29 13:06:51.715+00	\N
1674	61	2026-04-05	Gündüz	480	462	18	1000	896	33	2026-04-29 13:06:51.733+00	\N
1675	61	2026-04-04	Gündüz	480	445	35	1000	954	41	2026-04-29 13:06:51.75+00	\N
1676	61	2026-04-03	Gündüz	480	451	29	1000	832	29	2026-04-29 13:06:51.767+00	\N
1677	61	2026-04-02	Gündüz	480	456	24	1000	915	23	2026-04-29 13:06:51.783+00	\N
1678	61	2026-04-01	Gündüz	480	425	55	1000	868	28	2026-04-29 13:06:51.799+00	\N
1679	61	2026-03-31	Gündüz	480	449	31	1000	974	15	2026-04-29 13:06:51.812+00	\N
1680	61	2026-03-30	Gündüz	480	458	22	1000	973	45	2026-04-29 13:06:51.824+00	\N
1681	62	2026-04-28	Gündüz	480	469	11	1000	969	17	2026-04-29 13:06:51.836+00	\N
1682	62	2026-04-27	Gündüz	480	451	29	1000	867	34	2026-04-29 13:06:51.847+00	\N
1683	62	2026-04-26	Gündüz	480	436	44	1000	865	38	2026-04-29 13:06:51.858+00	\N
1684	62	2026-04-25	Gündüz	480	465	15	1000	940	42	2026-04-29 13:06:51.868+00	\N
1685	62	2026-04-24	Gündüz	480	424	56	1000	909	33	2026-04-29 13:06:51.878+00	\N
1686	62	2026-04-23	Gündüz	480	480	0	1000	866	20	2026-04-29 13:06:51.886+00	\N
1687	62	2026-04-22	Gündüz	480	446	34	1000	807	33	2026-04-29 13:06:51.892+00	\N
1688	62	2026-04-21	Gündüz	480	451	29	1000	826	20	2026-04-29 13:06:51.901+00	\N
1689	62	2026-04-20	Gündüz	480	434	46	1000	855	27	2026-04-29 13:06:51.91+00	\N
1690	62	2026-04-19	Gündüz	480	428	52	1000	813	12	2026-04-29 13:06:51.919+00	\N
1691	62	2026-04-18	Gündüz	480	421	59	1000	899	18	2026-04-29 13:06:51.93+00	\N
1692	62	2026-04-17	Gündüz	480	454	26	1000	963	22	2026-04-29 13:06:51.94+00	\N
1693	62	2026-04-16	Gündüz	480	458	22	1000	954	25	2026-04-29 13:06:51.953+00	\N
1694	62	2026-04-15	Gündüz	480	475	5	1000	927	28	2026-04-29 13:06:51.965+00	\N
1695	62	2026-04-14	Gündüz	480	452	28	1000	962	29	2026-04-29 13:06:51.979+00	\N
1696	62	2026-04-13	Gündüz	480	476	4	1000	899	21	2026-04-29 13:06:51.994+00	\N
1697	62	2026-04-12	Gündüz	480	479	1	1000	826	21	2026-04-29 13:06:52.008+00	\N
1698	62	2026-04-11	Gündüz	480	464	16	1000	920	16	2026-04-29 13:06:52.023+00	\N
1699	62	2026-04-10	Gündüz	480	432	48	1000	904	27	2026-04-29 13:06:52.04+00	\N
1700	62	2026-04-09	Gündüz	480	471	9	1000	895	33	2026-04-29 13:06:52.055+00	\N
1701	62	2026-04-08	Gündüz	480	480	0	1000	838	10	2026-04-29 13:06:52.069+00	\N
1702	62	2026-04-07	Gündüz	480	462	18	1000	964	26	2026-04-29 13:06:52.078+00	\N
1703	62	2026-04-06	Gündüz	480	466	14	1000	920	11	2026-04-29 13:06:52.093+00	\N
1704	62	2026-04-05	Gündüz	480	430	50	1000	946	43	2026-04-29 13:06:52.106+00	\N
1705	62	2026-04-04	Gündüz	480	434	46	1000	826	8	2026-04-29 13:06:52.118+00	\N
1706	62	2026-04-03	Gündüz	480	458	22	1000	892	22	2026-04-29 13:06:52.131+00	\N
1707	62	2026-04-02	Gündüz	480	453	27	1000	963	36	2026-04-29 13:06:52.143+00	\N
1708	62	2026-04-01	Gündüz	480	479	1	1000	967	39	2026-04-29 13:06:52.155+00	\N
1709	62	2026-03-31	Gündüz	480	430	50	1000	854	25	2026-04-29 13:06:52.167+00	\N
1710	62	2026-03-30	Gündüz	480	446	34	1000	953	12	2026-04-29 13:06:52.178+00	\N
1711	63	2026-04-28	Gündüz	480	452	28	1000	932	10	2026-04-29 13:06:52.19+00	\N
1712	63	2026-04-27	Gündüz	480	442	38	1000	913	17	2026-04-29 13:06:52.203+00	\N
1713	63	2026-04-26	Gündüz	480	423	57	1000	906	26	2026-04-29 13:06:52.215+00	\N
1714	63	2026-04-25	Gündüz	480	425	55	1000	927	45	2026-04-29 13:06:52.228+00	\N
1715	63	2026-04-24	Gündüz	480	457	23	1000	824	40	2026-04-29 13:06:52.241+00	\N
1716	63	2026-04-23	Gündüz	480	467	13	1000	835	40	2026-04-29 13:06:52.256+00	\N
1717	63	2026-04-22	Gündüz	480	456	24	1000	912	24	2026-04-29 13:06:52.27+00	\N
1718	63	2026-04-21	Gündüz	480	433	47	1000	838	39	2026-04-29 13:06:52.283+00	\N
1719	63	2026-04-20	Gündüz	480	428	52	1000	910	35	2026-04-29 13:06:52.295+00	\N
1720	63	2026-04-19	Gündüz	480	425	55	1000	805	19	2026-04-29 13:06:52.307+00	\N
1721	63	2026-04-18	Gündüz	480	422	58	1000	902	32	2026-04-29 13:06:52.319+00	\N
1722	63	2026-04-17	Gündüz	480	420	60	1000	842	29	2026-04-29 13:06:52.329+00	\N
1723	63	2026-04-16	Gündüz	480	471	9	1000	801	15	2026-04-29 13:06:52.339+00	\N
1724	63	2026-04-15	Gündüz	480	441	39	1000	946	17	2026-04-29 13:06:52.35+00	\N
1725	63	2026-04-14	Gündüz	480	467	13	1000	976	42	2026-04-29 13:06:52.36+00	\N
1726	63	2026-04-13	Gündüz	480	451	29	1000	880	37	2026-04-29 13:06:52.37+00	\N
1727	63	2026-04-12	Gündüz	480	426	54	1000	957	38	2026-04-29 13:06:52.381+00	\N
1728	63	2026-04-11	Gündüz	480	432	48	1000	856	15	2026-04-29 13:06:52.391+00	\N
1729	63	2026-04-10	Gündüz	480	453	27	1000	954	25	2026-04-29 13:06:52.402+00	\N
1730	63	2026-04-09	Gündüz	480	430	50	1000	946	40	2026-04-29 13:06:52.416+00	\N
1731	63	2026-04-08	Gündüz	480	470	10	1000	803	25	2026-04-29 13:06:52.427+00	\N
1732	63	2026-04-07	Gündüz	480	451	29	1000	894	20	2026-04-29 13:06:52.437+00	\N
1733	63	2026-04-06	Gündüz	480	476	4	1000	829	26	2026-04-29 13:06:52.447+00	\N
1734	63	2026-04-05	Gündüz	480	460	20	1000	947	11	2026-04-29 13:06:52.458+00	\N
1735	63	2026-04-04	Gündüz	480	438	42	1000	909	16	2026-04-29 13:06:52.471+00	\N
1736	63	2026-04-03	Gündüz	480	432	48	1000	954	35	2026-04-29 13:06:52.482+00	\N
1737	63	2026-04-02	Gündüz	480	445	35	1000	900	21	2026-04-29 13:06:52.493+00	\N
1738	63	2026-04-01	Gündüz	480	453	27	1000	900	41	2026-04-29 13:06:52.506+00	\N
1739	63	2026-03-31	Gündüz	480	430	50	1000	913	32	2026-04-29 13:06:52.518+00	\N
1740	63	2026-03-30	Gündüz	480	429	51	1000	969	10	2026-04-29 13:06:52.529+00	\N
1741	64	2026-04-28	Gündüz	480	421	59	1000	810	29	2026-04-29 13:06:52.54+00	\N
1742	64	2026-04-27	Gündüz	480	478	2	1000	962	28	2026-04-29 13:06:52.551+00	\N
1743	64	2026-04-26	Gündüz	480	463	17	1000	890	9	2026-04-29 13:06:52.561+00	\N
1744	64	2026-04-25	Gündüz	480	431	49	1000	848	41	2026-04-29 13:06:52.571+00	\N
1745	64	2026-04-24	Gündüz	480	443	37	1000	863	33	2026-04-29 13:06:52.582+00	\N
1746	64	2026-04-23	Gündüz	480	456	24	1000	933	21	2026-04-29 13:06:52.591+00	\N
1747	64	2026-04-22	Gündüz	480	427	53	1000	866	9	2026-04-29 13:06:52.601+00	\N
1748	64	2026-04-21	Gündüz	480	480	0	1000	960	30	2026-04-29 13:06:52.611+00	\N
1749	64	2026-04-20	Gündüz	480	470	10	1000	912	39	2026-04-29 13:06:52.617+00	\N
1750	64	2026-04-19	Gündüz	480	453	27	1000	848	31	2026-04-29 13:06:52.627+00	\N
1751	64	2026-04-18	Gündüz	480	455	25	1000	887	12	2026-04-29 13:06:52.639+00	\N
1752	64	2026-04-17	Gündüz	480	466	14	1000	970	36	2026-04-29 13:06:52.651+00	\N
1753	64	2026-04-16	Gündüz	480	423	57	1000	820	15	2026-04-29 13:06:52.662+00	\N
1754	64	2026-04-15	Gündüz	480	429	51	1000	823	18	2026-04-29 13:06:52.673+00	\N
1755	64	2026-04-14	Gündüz	480	421	59	1000	862	27	2026-04-29 13:06:52.682+00	\N
1756	64	2026-04-13	Gündüz	480	438	42	1000	851	17	2026-04-29 13:06:52.693+00	\N
1757	64	2026-04-12	Gündüz	480	457	23	1000	870	33	2026-04-29 13:06:52.704+00	\N
1758	64	2026-04-11	Gündüz	480	456	24	1000	929	22	2026-04-29 13:06:52.716+00	\N
1759	64	2026-04-10	Gündüz	480	449	31	1000	815	37	2026-04-29 13:06:52.729+00	\N
1760	64	2026-04-09	Gündüz	480	427	53	1000	851	29	2026-04-29 13:06:52.741+00	\N
1761	64	2026-04-08	Gündüz	480	429	51	1000	838	17	2026-04-29 13:06:52.753+00	\N
1762	64	2026-04-07	Gündüz	480	445	35	1000	823	13	2026-04-29 13:06:52.767+00	\N
1763	64	2026-04-06	Gündüz	480	438	42	1000	801	36	2026-04-29 13:06:52.779+00	\N
1764	64	2026-04-05	Gündüz	480	466	14	1000	896	16	2026-04-29 13:06:52.79+00	\N
1765	64	2026-04-04	Gündüz	480	455	25	1000	895	35	2026-04-29 13:06:52.802+00	\N
1766	64	2026-04-03	Gündüz	480	454	26	1000	809	28	2026-04-29 13:06:52.815+00	\N
1767	64	2026-04-02	Gündüz	480	454	26	1000	936	16	2026-04-29 13:06:52.832+00	\N
1768	64	2026-04-01	Gündüz	480	442	38	1000	807	21	2026-04-29 13:06:52.844+00	\N
1769	64	2026-03-31	Gündüz	480	449	31	1000	969	37	2026-04-29 13:06:52.857+00	\N
1770	64	2026-03-30	Gündüz	480	459	21	1000	808	23	2026-04-29 13:06:52.872+00	\N
1771	65	2026-04-28	Gündüz	480	463	17	1000	885	12	2026-04-29 13:06:52.887+00	\N
1772	65	2026-04-27	Gündüz	480	446	34	1000	963	44	2026-04-29 13:06:52.899+00	\N
1773	65	2026-04-26	Gündüz	480	456	24	1000	848	41	2026-04-29 13:06:52.91+00	\N
1774	65	2026-04-25	Gündüz	480	428	52	1000	883	27	2026-04-29 13:06:52.921+00	\N
1775	65	2026-04-24	Gündüz	480	463	17	1000	814	26	2026-04-29 13:06:52.933+00	\N
1776	65	2026-04-23	Gündüz	480	476	4	1000	964	18	2026-04-29 13:06:52.943+00	\N
1777	65	2026-04-22	Gündüz	480	435	45	1000	978	20	2026-04-29 13:06:52.952+00	\N
1778	65	2026-04-21	Gündüz	480	466	14	1000	911	12	2026-04-29 13:06:52.962+00	\N
1779	65	2026-04-20	Gündüz	480	468	12	1000	902	21	2026-04-29 13:06:52.971+00	\N
1780	65	2026-04-19	Gündüz	480	449	31	1000	830	28	2026-04-29 13:06:52.981+00	\N
1781	65	2026-04-18	Gündüz	480	451	29	1000	818	27	2026-04-29 13:06:52.99+00	\N
1782	65	2026-04-17	Gündüz	480	457	23	1000	964	46	2026-04-29 13:06:53+00	\N
1783	65	2026-04-16	Gündüz	480	470	10	1000	937	16	2026-04-29 13:06:53.01+00	\N
1784	65	2026-04-15	Gündüz	480	432	48	1000	920	37	2026-04-29 13:06:53.018+00	\N
1785	65	2026-04-14	Gündüz	480	466	14	1000	927	18	2026-04-29 13:06:53.027+00	\N
1786	65	2026-04-13	Gündüz	480	466	14	1000	863	35	2026-04-29 13:06:53.036+00	\N
1787	65	2026-04-12	Gündüz	480	475	5	1000	935	21	2026-04-29 13:06:53.044+00	\N
1788	65	2026-04-11	Gündüz	480	442	38	1000	972	25	2026-04-29 13:06:53.053+00	\N
1789	65	2026-04-10	Gündüz	480	480	0	1000	869	9	2026-04-29 13:06:53.063+00	\N
1790	65	2026-04-09	Gündüz	480	471	9	1000	813	9	2026-04-29 13:06:53.069+00	\N
1791	65	2026-04-08	Gündüz	480	425	55	1000	805	31	2026-04-29 13:06:53.077+00	\N
1792	65	2026-04-07	Gündüz	480	463	17	1000	825	12	2026-04-29 13:06:53.086+00	\N
1793	65	2026-04-06	Gündüz	480	439	41	1000	937	19	2026-04-29 13:06:53.096+00	\N
1794	65	2026-04-05	Gündüz	480	439	41	1000	872	16	2026-04-29 13:06:53.105+00	\N
1795	65	2026-04-04	Gündüz	480	467	13	1000	863	37	2026-04-29 13:06:53.114+00	\N
1796	65	2026-04-03	Gündüz	480	469	11	1000	865	35	2026-04-29 13:06:53.122+00	\N
1797	65	2026-04-02	Gündüz	480	433	47	1000	950	36	2026-04-29 13:06:53.131+00	\N
1798	65	2026-04-01	Gündüz	480	441	39	1000	956	13	2026-04-29 13:06:53.139+00	\N
1799	65	2026-03-31	Gündüz	480	458	22	1000	964	19	2026-04-29 13:06:53.149+00	\N
1800	65	2026-03-30	Gündüz	480	424	56	1000	913	9	2026-04-29 13:06:53.159+00	\N
1801	66	2026-04-28	Gündüz	480	422	58	1000	934	19	2026-04-29 13:06:53.17+00	\N
1802	66	2026-04-27	Gündüz	480	479	1	1000	949	36	2026-04-29 13:06:53.182+00	\N
1803	66	2026-04-26	Gündüz	480	458	22	1000	959	17	2026-04-29 13:06:53.194+00	\N
1804	66	2026-04-25	Gündüz	480	421	59	1000	826	8	2026-04-29 13:06:53.205+00	\N
1805	66	2026-04-24	Gündüz	480	466	14	1000	878	39	2026-04-29 13:06:53.217+00	\N
1806	66	2026-04-23	Gündüz	480	472	8	1000	960	39	2026-04-29 13:06:53.229+00	\N
1807	66	2026-04-22	Gündüz	480	463	17	1000	852	11	2026-04-29 13:06:53.243+00	\N
1808	66	2026-04-21	Gündüz	480	468	12	1000	816	40	2026-04-29 13:06:53.255+00	\N
1809	66	2026-04-20	Gündüz	480	465	15	1000	924	29	2026-04-29 13:06:53.266+00	\N
1810	66	2026-04-19	Gündüz	480	457	23	1000	917	9	2026-04-29 13:06:53.276+00	\N
1811	66	2026-04-18	Gündüz	480	462	18	1000	865	26	2026-04-29 13:06:53.289+00	\N
1812	66	2026-04-17	Gündüz	480	440	40	1000	954	22	2026-04-29 13:06:53.3+00	\N
1813	66	2026-04-16	Gündüz	480	474	6	1000	973	23	2026-04-29 13:06:53.311+00	\N
1814	66	2026-04-15	Gündüz	480	468	12	1000	977	46	2026-04-29 13:06:53.323+00	\N
1815	66	2026-04-14	Gündüz	480	455	25	1000	943	19	2026-04-29 13:06:53.334+00	\N
1816	66	2026-04-13	Gündüz	480	463	17	1000	851	23	2026-04-29 13:06:53.346+00	\N
1817	66	2026-04-12	Gündüz	480	478	2	1000	953	16	2026-04-29 13:06:53.358+00	\N
1818	66	2026-04-11	Gündüz	480	425	55	1000	826	29	2026-04-29 13:06:53.369+00	\N
1819	66	2026-04-10	Gündüz	480	428	52	1000	869	18	2026-04-29 13:06:53.38+00	\N
1820	66	2026-04-09	Gündüz	480	426	54	1000	871	31	2026-04-29 13:06:53.391+00	\N
1821	66	2026-04-08	Gündüz	480	444	36	1000	806	32	2026-04-29 13:06:53.404+00	\N
1822	66	2026-04-07	Gündüz	480	446	34	1000	824	13	2026-04-29 13:06:53.417+00	\N
1823	66	2026-04-06	Gündüz	480	454	26	1000	902	39	2026-04-29 13:06:53.433+00	\N
1824	66	2026-04-05	Gündüz	480	447	33	1000	814	36	2026-04-29 13:06:53.448+00	\N
1825	66	2026-04-04	Gündüz	480	464	16	1000	919	21	2026-04-29 13:06:53.462+00	\N
1826	66	2026-04-03	Gündüz	480	462	18	1000	952	44	2026-04-29 13:06:53.476+00	\N
1827	66	2026-04-02	Gündüz	480	433	47	1000	935	12	2026-04-29 13:06:53.491+00	\N
1828	66	2026-04-01	Gündüz	480	472	8	1000	907	23	2026-04-29 13:06:53.505+00	\N
1829	66	2026-03-31	Gündüz	480	475	5	1000	895	29	2026-04-29 13:06:53.519+00	\N
1830	66	2026-03-30	Gündüz	480	446	34	1000	967	41	2026-04-29 13:06:53.535+00	\N
1831	67	2026-04-28	Gündüz	480	466	14	1000	812	33	2026-04-29 13:06:53.548+00	\N
1832	67	2026-04-27	Gündüz	480	466	14	1000	913	19	2026-04-29 13:06:53.557+00	\N
1833	67	2026-04-26	Gündüz	480	464	16	1000	942	44	2026-04-29 13:06:53.569+00	\N
1834	67	2026-04-25	Gündüz	480	464	16	1000	855	32	2026-04-29 13:06:53.579+00	\N
1835	67	2026-04-24	Gündüz	480	428	52	1000	928	40	2026-04-29 13:06:53.588+00	\N
1836	67	2026-04-23	Gündüz	480	452	28	1000	908	38	2026-04-29 13:06:53.596+00	\N
1837	67	2026-04-22	Gündüz	480	454	26	1000	901	39	2026-04-29 13:06:53.606+00	\N
1838	67	2026-04-21	Gündüz	480	451	29	1000	862	31	2026-04-29 13:06:53.617+00	\N
1839	67	2026-04-20	Gündüz	480	429	51	1000	819	15	2026-04-29 13:06:53.628+00	\N
1840	67	2026-04-19	Gündüz	480	441	39	1000	869	14	2026-04-29 13:06:53.643+00	\N
1841	67	2026-04-18	Gündüz	480	422	58	1000	957	29	2026-04-29 13:06:53.655+00	\N
1842	67	2026-04-17	Gündüz	480	473	7	1000	908	38	2026-04-29 13:06:53.667+00	\N
1843	67	2026-04-16	Gündüz	480	470	10	1000	977	31	2026-04-29 13:06:53.679+00	\N
1844	67	2026-04-15	Gündüz	480	472	8	1000	954	14	2026-04-29 13:06:53.69+00	\N
1845	67	2026-04-14	Gündüz	480	433	47	1000	889	25	2026-04-29 13:06:53.701+00	\N
1846	67	2026-04-13	Gündüz	480	436	44	1000	930	26	2026-04-29 13:06:53.713+00	\N
1847	67	2026-04-12	Gündüz	480	425	55	1000	943	36	2026-04-29 13:06:53.725+00	\N
1848	67	2026-04-11	Gündüz	480	473	7	1000	849	26	2026-04-29 13:06:53.737+00	\N
1849	67	2026-04-10	Gündüz	480	464	16	1000	898	26	2026-04-29 13:06:53.752+00	\N
1850	67	2026-04-09	Gündüz	480	480	0	1000	851	20	2026-04-29 13:06:53.763+00	\N
1851	67	2026-04-08	Gündüz	480	461	19	1000	921	13	2026-04-29 13:06:53.771+00	\N
1852	67	2026-04-07	Gündüz	480	439	41	1000	868	26	2026-04-29 13:06:53.782+00	\N
1853	67	2026-04-06	Gündüz	480	470	10	1000	958	31	2026-04-29 13:06:53.797+00	\N
1854	67	2026-04-05	Gündüz	480	439	41	1000	820	29	2026-04-29 13:06:53.812+00	\N
1855	67	2026-04-04	Gündüz	480	437	43	1000	893	43	2026-04-29 13:06:53.831+00	\N
1856	67	2026-04-03	Gündüz	480	435	45	1000	849	32	2026-04-29 13:06:53.845+00	\N
1857	67	2026-04-02	Gündüz	480	435	45	1000	955	30	2026-04-29 13:06:53.858+00	\N
1858	67	2026-04-01	Gündüz	480	442	38	1000	874	18	2026-04-29 13:06:53.87+00	\N
1859	67	2026-03-31	Gündüz	480	469	11	1000	842	15	2026-04-29 13:06:53.88+00	\N
1860	67	2026-03-30	Gündüz	480	426	54	1000	929	28	2026-04-29 13:06:53.891+00	\N
1861	68	2026-04-28	Gündüz	480	479	1	1000	933	45	2026-04-29 13:06:53.904+00	\N
1862	68	2026-04-27	Gündüz	480	456	24	1000	914	24	2026-04-29 13:06:53.918+00	\N
1863	68	2026-04-26	Gündüz	480	420	60	1000	927	30	2026-04-29 13:06:53.93+00	\N
1864	68	2026-04-25	Gündüz	480	436	44	1000	893	26	2026-04-29 13:06:53.942+00	\N
1865	68	2026-04-24	Gündüz	480	436	44	1000	844	14	2026-04-29 13:06:53.954+00	\N
1866	68	2026-04-23	Gündüz	480	425	55	1000	936	31	2026-04-29 13:06:53.965+00	\N
1867	68	2026-04-22	Gündüz	480	430	50	1000	901	21	2026-04-29 13:06:53.977+00	\N
1868	68	2026-04-21	Gündüz	480	470	10	1000	954	30	2026-04-29 13:06:53.988+00	\N
1869	68	2026-04-20	Gündüz	480	459	21	1000	946	47	2026-04-29 13:06:54+00	\N
1870	68	2026-04-19	Gündüz	480	421	59	1000	906	41	2026-04-29 13:06:54.012+00	\N
1871	68	2026-04-18	Gündüz	480	478	2	1000	867	28	2026-04-29 13:06:54.024+00	\N
1872	68	2026-04-17	Gündüz	480	445	35	1000	937	10	2026-04-29 13:06:54.035+00	\N
1873	68	2026-04-16	Gündüz	480	471	9	1000	937	42	2026-04-29 13:06:54.05+00	\N
1874	68	2026-04-15	Gündüz	480	424	56	1000	931	12	2026-04-29 13:06:54.063+00	\N
1875	68	2026-04-14	Gündüz	480	470	10	1000	855	11	2026-04-29 13:06:54.077+00	\N
1876	68	2026-04-13	Gündüz	480	442	38	1000	930	46	2026-04-29 13:06:54.09+00	\N
1877	68	2026-04-12	Gündüz	480	427	53	1000	816	11	2026-04-29 13:06:54.103+00	\N
1878	68	2026-04-11	Gündüz	480	445	35	1000	812	34	2026-04-29 13:06:54.116+00	\N
1879	68	2026-04-10	Gündüz	480	427	53	1000	904	41	2026-04-29 13:06:54.126+00	\N
1880	68	2026-04-09	Gündüz	480	437	43	1000	804	33	2026-04-29 13:06:54.137+00	\N
1881	68	2026-04-08	Gündüz	480	473	7	1000	834	17	2026-04-29 13:06:54.148+00	\N
1882	68	2026-04-07	Gündüz	480	480	0	1000	869	18	2026-04-29 13:06:54.159+00	\N
1883	68	2026-04-06	Gündüz	480	454	26	1000	863	9	2026-04-29 13:06:54.167+00	\N
1884	68	2026-04-05	Gündüz	480	447	33	1000	963	22	2026-04-29 13:06:54.184+00	\N
1885	68	2026-04-04	Gündüz	480	430	50	1000	802	38	2026-04-29 13:06:54.195+00	\N
1886	68	2026-04-03	Gündüz	480	444	36	1000	838	27	2026-04-29 13:06:54.207+00	\N
1887	68	2026-04-02	Gündüz	480	474	6	1000	901	36	2026-04-29 13:06:54.22+00	\N
1888	68	2026-04-01	Gündüz	480	439	41	1000	873	25	2026-04-29 13:06:54.233+00	\N
1889	68	2026-03-31	Gündüz	480	424	56	1000	828	40	2026-04-29 13:06:54.245+00	\N
1890	68	2026-03-30	Gündüz	480	456	24	1000	935	39	2026-04-29 13:06:54.258+00	\N
1891	69	2026-04-28	Gündüz	480	441	39	1000	921	40	2026-04-29 13:06:54.27+00	\N
1892	69	2026-04-27	Gündüz	480	469	11	1000	915	22	2026-04-29 13:06:54.283+00	\N
1893	69	2026-04-26	Gündüz	480	456	24	1000	898	26	2026-04-29 13:06:54.295+00	\N
1894	69	2026-04-25	Gündüz	480	475	5	1000	816	16	2026-04-29 13:06:54.307+00	\N
1895	69	2026-04-24	Gündüz	480	463	17	1000	972	39	2026-04-29 13:06:54.32+00	\N
1896	69	2026-04-23	Gündüz	480	426	54	1000	831	34	2026-04-29 13:06:54.331+00	\N
1897	69	2026-04-22	Gündüz	480	429	51	1000	861	17	2026-04-29 13:06:54.345+00	\N
1898	69	2026-04-21	Gündüz	480	447	33	1000	945	43	2026-04-29 13:06:54.356+00	\N
1899	69	2026-04-20	Gündüz	480	479	1	1000	884	12	2026-04-29 13:06:54.37+00	\N
1900	69	2026-04-19	Gündüz	480	445	35	1000	963	11	2026-04-29 13:06:54.381+00	\N
1901	69	2026-04-18	Gündüz	480	426	54	1000	860	27	2026-04-29 13:06:54.393+00	\N
1902	69	2026-04-17	Gündüz	480	460	20	1000	896	19	2026-04-29 13:06:54.405+00	\N
1903	69	2026-04-16	Gündüz	480	421	59	1000	813	29	2026-04-29 13:06:54.417+00	\N
1904	69	2026-04-15	Gündüz	480	464	16	1000	947	11	2026-04-29 13:06:54.431+00	\N
1905	69	2026-04-14	Gündüz	480	480	0	1000	890	23	2026-04-29 13:06:54.443+00	\N
1906	69	2026-04-13	Gündüz	480	462	18	1000	955	26	2026-04-29 13:06:54.451+00	\N
1907	69	2026-04-12	Gündüz	480	454	26	1000	957	37	2026-04-29 13:06:54.463+00	\N
1908	69	2026-04-11	Gündüz	480	425	55	1000	820	27	2026-04-29 13:06:54.475+00	\N
1909	69	2026-04-10	Gündüz	480	430	50	1000	831	22	2026-04-29 13:06:54.546+00	\N
1910	69	2026-04-09	Gündüz	480	467	13	1000	964	37	2026-04-29 13:06:54.574+00	\N
1911	69	2026-04-08	Gündüz	480	473	7	1000	841	12	2026-04-29 13:06:54.589+00	\N
1912	69	2026-04-07	Gündüz	480	425	55	1000	945	41	2026-04-29 13:06:54.602+00	\N
1913	69	2026-04-06	Gündüz	480	455	25	1000	968	16	2026-04-29 13:06:54.613+00	\N
1914	69	2026-04-05	Gündüz	480	464	16	1000	832	9	2026-04-29 13:06:54.624+00	\N
1915	69	2026-04-04	Gündüz	480	451	29	1000	864	9	2026-04-29 13:06:54.638+00	\N
1916	69	2026-04-03	Gündüz	480	453	27	1000	971	20	2026-04-29 13:06:54.65+00	\N
1917	69	2026-04-02	Gündüz	480	470	10	1000	824	22	2026-04-29 13:06:54.666+00	\N
1918	69	2026-04-01	Gündüz	480	421	59	1000	927	45	2026-04-29 13:06:54.686+00	\N
1919	69	2026-03-31	Gündüz	480	431	49	1000	853	34	2026-04-29 13:06:54.707+00	\N
1920	69	2026-03-30	Gündüz	480	466	14	1000	941	16	2026-04-29 13:06:54.728+00	\N
1921	70	2026-04-28	Gündüz	480	437	43	1000	856	39	2026-04-29 13:06:54.746+00	\N
1922	70	2026-04-27	Gündüz	480	460	20	1000	917	35	2026-04-29 13:06:54.765+00	\N
1923	70	2026-04-26	Gündüz	480	459	21	1000	890	43	2026-04-29 13:06:54.792+00	\N
1924	70	2026-04-25	Gündüz	480	461	19	1000	804	9	2026-04-29 13:06:54.811+00	\N
1925	70	2026-04-24	Gündüz	480	451	29	1000	942	11	2026-04-29 13:06:54.828+00	\N
1926	70	2026-04-23	Gündüz	480	458	22	1000	928	17	2026-04-29 13:06:54.842+00	\N
1927	70	2026-04-22	Gündüz	480	462	18	1000	970	30	2026-04-29 13:06:54.853+00	\N
1928	70	2026-04-21	Gündüz	480	442	38	1000	973	43	2026-04-29 13:06:54.867+00	\N
1929	70	2026-04-20	Gündüz	480	430	50	1000	974	44	2026-04-29 13:06:54.877+00	\N
1930	70	2026-04-19	Gündüz	480	434	46	1000	853	40	2026-04-29 13:06:54.89+00	\N
1931	70	2026-04-18	Gündüz	480	428	52	1000	920	36	2026-04-29 13:06:54.906+00	\N
1932	70	2026-04-17	Gündüz	480	469	11	1000	879	36	2026-04-29 13:06:54.922+00	\N
1933	70	2026-04-16	Gündüz	480	480	0	1000	895	20	2026-04-29 13:06:54.938+00	\N
1934	70	2026-04-15	Gündüz	480	432	48	1000	812	19	2026-04-29 13:06:54.95+00	\N
1935	70	2026-04-14	Gündüz	480	469	11	1000	808	15	2026-04-29 13:06:54.966+00	\N
1936	70	2026-04-13	Gündüz	480	434	46	1000	853	33	2026-04-29 13:06:54.988+00	\N
1937	70	2026-04-12	Gündüz	480	454	26	1000	828	12	2026-04-29 13:06:55.005+00	\N
1938	70	2026-04-11	Gündüz	480	446	34	1000	912	21	2026-04-29 13:06:55.022+00	\N
1939	70	2026-04-10	Gündüz	480	479	1	1000	850	16	2026-04-29 13:06:55.039+00	\N
1940	70	2026-04-09	Gündüz	480	430	50	1000	943	42	2026-04-29 13:06:55.055+00	\N
1941	70	2026-04-08	Gündüz	480	449	31	1000	873	22	2026-04-29 13:06:55.072+00	\N
1942	70	2026-04-07	Gündüz	480	430	50	1000	829	11	2026-04-29 13:06:55.09+00	\N
1943	70	2026-04-06	Gündüz	480	451	29	1000	803	35	2026-04-29 13:06:55.108+00	\N
1944	70	2026-04-05	Gündüz	480	427	53	1000	940	32	2026-04-29 13:06:55.126+00	\N
1945	70	2026-04-04	Gündüz	480	471	9	1000	935	33	2026-04-29 13:06:55.143+00	\N
1946	70	2026-04-03	Gündüz	480	427	53	1000	928	23	2026-04-29 13:06:55.16+00	\N
1947	70	2026-04-02	Gündüz	480	443	37	1000	955	46	2026-04-29 13:06:55.178+00	\N
1948	70	2026-04-01	Gündüz	480	466	14	1000	801	17	2026-04-29 13:06:55.197+00	\N
1949	70	2026-03-31	Gündüz	480	430	50	1000	894	9	2026-04-29 13:06:55.218+00	\N
1950	70	2026-03-30	Gündüz	480	479	1	1000	808	32	2026-04-29 13:06:55.238+00	\N
1951	71	2026-04-28	Gündüz	480	467	13	1000	819	22	2026-04-29 13:06:55.258+00	\N
1952	71	2026-04-27	Gündüz	480	428	52	1000	859	25	2026-04-29 13:06:55.276+00	\N
1953	71	2026-04-26	Gündüz	480	433	47	1000	936	35	2026-04-29 13:06:55.292+00	\N
1954	71	2026-04-25	Gündüz	480	456	24	1000	810	40	2026-04-29 13:06:55.309+00	\N
1955	71	2026-04-24	Gündüz	480	458	22	1000	834	29	2026-04-29 13:06:55.326+00	\N
1956	71	2026-04-23	Gündüz	480	453	27	1000	873	12	2026-04-29 13:06:55.344+00	\N
1957	71	2026-04-22	Gündüz	480	446	34	1000	917	18	2026-04-29 13:06:55.362+00	\N
1958	71	2026-04-21	Gündüz	480	459	21	1000	867	8	2026-04-29 13:06:55.381+00	\N
1959	71	2026-04-20	Gündüz	480	468	12	1000	917	27	2026-04-29 13:06:55.399+00	\N
1960	71	2026-04-19	Gündüz	480	437	43	1000	951	38	2026-04-29 13:06:55.417+00	\N
1961	71	2026-04-18	Gündüz	480	448	32	1000	840	39	2026-04-29 13:06:55.434+00	\N
1962	71	2026-04-17	Gündüz	480	424	56	1000	935	32	2026-04-29 13:06:55.451+00	\N
1963	71	2026-04-16	Gündüz	480	458	22	1000	888	25	2026-04-29 13:06:55.468+00	\N
1964	71	2026-04-15	Gündüz	480	451	29	1000	884	34	2026-04-29 13:06:55.492+00	\N
1965	71	2026-04-14	Gündüz	480	478	2	1000	948	39	2026-04-29 13:06:55.512+00	\N
1966	71	2026-04-13	Gündüz	480	422	58	1000	979	43	2026-04-29 13:06:55.535+00	\N
1967	71	2026-04-12	Gündüz	480	467	13	1000	852	40	2026-04-29 13:06:55.557+00	\N
1968	71	2026-04-11	Gündüz	480	446	34	1000	961	31	2026-04-29 13:06:55.579+00	\N
1969	71	2026-04-10	Gündüz	480	457	23	1000	896	39	2026-04-29 13:06:55.6+00	\N
1970	71	2026-04-09	Gündüz	480	465	15	1000	835	25	2026-04-29 13:06:55.622+00	\N
1971	71	2026-04-08	Gündüz	480	431	49	1000	803	19	2026-04-29 13:06:55.64+00	\N
1972	71	2026-04-07	Gündüz	480	443	37	1000	928	9	2026-04-29 13:06:55.656+00	\N
1973	71	2026-04-06	Gündüz	480	420	60	1000	855	26	2026-04-29 13:06:55.676+00	\N
1974	71	2026-04-05	Gündüz	480	455	25	1000	888	9	2026-04-29 13:06:55.697+00	\N
1975	71	2026-04-04	Gündüz	480	474	6	1000	924	11	2026-04-29 13:06:55.719+00	\N
1976	71	2026-04-03	Gündüz	480	435	45	1000	949	9	2026-04-29 13:06:55.736+00	\N
1977	71	2026-04-02	Gündüz	480	462	18	1000	838	37	2026-04-29 13:06:55.749+00	\N
1978	71	2026-04-01	Gündüz	480	469	11	1000	820	21	2026-04-29 13:06:55.761+00	\N
1979	71	2026-03-31	Gündüz	480	440	40	1000	853	42	2026-04-29 13:06:55.772+00	\N
1980	71	2026-03-30	Gündüz	480	430	50	1000	902	18	2026-04-29 13:06:55.784+00	\N
1981	72	2026-04-28	Gündüz	480	476	4	1000	943	20	2026-04-29 13:06:55.796+00	\N
1982	72	2026-04-27	Gündüz	480	438	42	1000	877	22	2026-04-29 13:06:55.811+00	\N
1983	72	2026-04-26	Gündüz	480	432	48	1000	919	37	2026-04-29 13:06:55.828+00	\N
1984	72	2026-04-25	Gündüz	480	459	21	1000	964	47	2026-04-29 13:06:55.844+00	\N
1985	72	2026-04-24	Gündüz	480	472	8	1000	828	34	2026-04-29 13:06:55.861+00	\N
1986	72	2026-04-23	Gündüz	480	477	3	1000	922	16	2026-04-29 13:06:55.88+00	\N
1987	72	2026-04-22	Gündüz	480	478	2	1000	924	23	2026-04-29 13:06:55.896+00	\N
1988	72	2026-04-21	Gündüz	480	446	34	1000	944	14	2026-04-29 13:06:55.911+00	\N
1989	72	2026-04-20	Gündüz	480	472	8	1000	920	41	2026-04-29 13:06:55.925+00	\N
1990	72	2026-04-19	Gündüz	480	458	22	1000	839	39	2026-04-29 13:06:55.942+00	\N
1991	72	2026-04-18	Gündüz	480	451	29	1000	908	34	2026-04-29 13:06:55.961+00	\N
1992	72	2026-04-17	Gündüz	480	427	53	1000	840	21	2026-04-29 13:06:55.978+00	\N
1993	72	2026-04-16	Gündüz	480	435	45	1000	946	12	2026-04-29 13:06:55.995+00	\N
1994	72	2026-04-15	Gündüz	480	444	36	1000	894	14	2026-04-29 13:06:56.012+00	\N
1995	72	2026-04-14	Gündüz	480	432	48	1000	805	10	2026-04-29 13:06:56.034+00	\N
1996	72	2026-04-13	Gündüz	480	457	23	1000	926	30	2026-04-29 13:06:56.05+00	\N
1997	72	2026-04-12	Gündüz	480	428	52	1000	897	42	2026-04-29 13:06:56.066+00	\N
1998	72	2026-04-11	Gündüz	480	429	51	1000	907	16	2026-04-29 13:06:56.083+00	\N
1999	72	2026-04-10	Gündüz	480	446	34	1000	840	38	2026-04-29 13:06:56.098+00	\N
2000	72	2026-04-09	Gündüz	480	430	50	1000	944	40	2026-04-29 13:06:56.113+00	\N
2001	72	2026-04-08	Gündüz	480	447	33	1000	813	28	2026-04-29 13:06:56.13+00	\N
2002	72	2026-04-07	Gündüz	480	433	47	1000	977	41	2026-04-29 13:06:56.147+00	\N
2003	72	2026-04-06	Gündüz	480	460	20	1000	867	13	2026-04-29 13:06:56.164+00	\N
2004	72	2026-04-05	Gündüz	480	450	30	1000	807	38	2026-04-29 13:06:56.18+00	\N
2005	72	2026-04-04	Gündüz	480	445	35	1000	905	36	2026-04-29 13:06:56.196+00	\N
2006	72	2026-04-03	Gündüz	480	424	56	1000	922	10	2026-04-29 13:06:56.214+00	\N
2007	72	2026-04-02	Gündüz	480	424	56	1000	891	10	2026-04-29 13:06:56.23+00	\N
2008	72	2026-04-01	Gündüz	480	475	5	1000	907	20	2026-04-29 13:06:56.245+00	\N
2009	72	2026-03-31	Gündüz	480	425	55	1000	890	21	2026-04-29 13:06:56.257+00	\N
2010	72	2026-03-30	Gündüz	480	480	0	1000	897	42	2026-04-29 13:06:56.272+00	\N
2011	73	2026-04-28	Gündüz	480	426	54	1000	830	11	2026-04-29 13:06:56.282+00	\N
2012	73	2026-04-27	Gündüz	480	459	21	1000	872	23	2026-04-29 13:06:56.297+00	\N
2013	73	2026-04-26	Gündüz	480	433	47	1000	934	33	2026-04-29 13:06:56.311+00	\N
2014	73	2026-04-25	Gündüz	480	472	8	1000	829	21	2026-04-29 13:06:56.328+00	\N
2015	73	2026-04-24	Gündüz	480	477	3	1000	897	25	2026-04-29 13:06:56.344+00	\N
2016	73	2026-04-23	Gündüz	480	444	36	1000	935	39	2026-04-29 13:06:56.357+00	\N
2017	73	2026-04-22	Gündüz	480	422	58	1000	920	9	2026-04-29 13:06:56.372+00	\N
2018	73	2026-04-21	Gündüz	480	440	40	1000	804	9	2026-04-29 13:06:56.387+00	\N
2019	73	2026-04-20	Gündüz	480	444	36	1000	869	21	2026-04-29 13:06:56.402+00	\N
2020	73	2026-04-19	Gündüz	480	423	57	1000	937	32	2026-04-29 13:06:56.417+00	\N
2021	73	2026-04-18	Gündüz	480	452	28	1000	940	13	2026-04-29 13:06:56.43+00	\N
2022	73	2026-04-17	Gündüz	480	464	16	1000	898	20	2026-04-29 13:06:56.445+00	\N
2023	73	2026-04-16	Gündüz	480	455	25	1000	888	12	2026-04-29 13:06:56.458+00	\N
2024	73	2026-04-15	Gündüz	480	456	24	1000	808	13	2026-04-29 13:06:56.472+00	\N
2025	73	2026-04-14	Gündüz	480	438	42	1000	914	36	2026-04-29 13:06:56.484+00	\N
2026	73	2026-04-13	Gündüz	480	467	13	1000	831	25	2026-04-29 13:06:56.499+00	\N
2027	73	2026-04-12	Gündüz	480	480	0	1000	867	31	2026-04-29 13:06:56.512+00	\N
2028	73	2026-04-11	Gündüz	480	472	8	1000	958	41	2026-04-29 13:06:56.521+00	\N
2029	73	2026-04-10	Gündüz	480	441	39	1000	975	21	2026-04-29 13:06:56.535+00	\N
2030	73	2026-04-09	Gündüz	480	471	9	1000	937	21	2026-04-29 13:06:56.55+00	\N
2031	73	2026-04-08	Gündüz	480	424	56	1000	964	40	2026-04-29 13:06:56.566+00	\N
2032	73	2026-04-07	Gündüz	480	449	31	1000	803	31	2026-04-29 13:06:56.582+00	\N
2033	73	2026-04-06	Gündüz	480	480	0	1000	881	12	2026-04-29 13:06:56.598+00	\N
2034	73	2026-04-05	Gündüz	480	464	16	1000	884	41	2026-04-29 13:06:56.608+00	\N
2035	73	2026-04-04	Gündüz	480	426	54	1000	971	31	2026-04-29 13:06:56.623+00	\N
2036	73	2026-04-03	Gündüz	480	452	28	1000	844	23	2026-04-29 13:06:56.635+00	\N
2037	73	2026-04-02	Gündüz	480	452	28	1000	903	14	2026-04-29 13:06:56.651+00	\N
2038	73	2026-04-01	Gündüz	480	470	10	1000	886	35	2026-04-29 13:06:56.664+00	\N
2039	73	2026-03-31	Gündüz	480	450	30	1000	864	34	2026-04-29 13:06:56.677+00	\N
2040	73	2026-03-30	Gündüz	480	438	42	1000	830	29	2026-04-29 13:06:56.689+00	\N
2041	74	2026-04-28	Gündüz	480	478	2	1000	888	34	2026-04-29 13:06:56.701+00	\N
2042	74	2026-04-27	Gündüz	480	470	10	1000	855	29	2026-04-29 13:06:56.713+00	\N
2043	74	2026-04-26	Gündüz	480	437	43	1000	818	24	2026-04-29 13:06:56.725+00	\N
2044	74	2026-04-25	Gündüz	480	447	33	1000	950	31	2026-04-29 13:06:56.734+00	\N
2045	74	2026-04-24	Gündüz	480	426	54	1000	956	33	2026-04-29 13:06:56.743+00	\N
2046	74	2026-04-23	Gündüz	480	453	27	1000	832	11	2026-04-29 13:06:56.752+00	\N
2047	74	2026-04-22	Gündüz	480	477	3	1000	977	43	2026-04-29 13:06:56.762+00	\N
2048	74	2026-04-21	Gündüz	480	430	50	1000	813	24	2026-04-29 13:06:56.775+00	\N
2049	74	2026-04-20	Gündüz	480	422	58	1000	855	26	2026-04-29 13:06:56.79+00	\N
2050	74	2026-04-19	Gündüz	480	436	44	1000	920	33	2026-04-29 13:06:56.804+00	\N
2051	74	2026-04-18	Gündüz	480	439	41	1000	869	41	2026-04-29 13:06:56.82+00	\N
2052	74	2026-04-17	Gündüz	480	457	23	1000	817	15	2026-04-29 13:06:56.837+00	\N
2053	74	2026-04-16	Gündüz	480	444	36	1000	956	30	2026-04-29 13:06:56.85+00	\N
2054	74	2026-04-15	Gündüz	480	453	27	1000	885	35	2026-04-29 13:06:56.864+00	\N
2055	74	2026-04-14	Gündüz	480	448	32	1000	862	16	2026-04-29 13:06:56.877+00	\N
2056	74	2026-04-13	Gündüz	480	441	39	1000	856	13	2026-04-29 13:06:56.892+00	\N
2057	74	2026-04-12	Gündüz	480	435	45	1000	845	37	2026-04-29 13:06:56.908+00	\N
2058	74	2026-04-11	Gündüz	480	445	35	1000	853	12	2026-04-29 13:06:56.924+00	\N
2059	74	2026-04-10	Gündüz	480	479	1	1000	805	27	2026-04-29 13:06:56.938+00	\N
2060	74	2026-04-09	Gündüz	480	476	4	1000	901	11	2026-04-29 13:06:56.952+00	\N
2061	74	2026-04-08	Gündüz	480	447	33	1000	910	17	2026-04-29 13:06:56.966+00	\N
2062	74	2026-04-07	Gündüz	480	424	56	1000	836	35	2026-04-29 13:06:56.981+00	\N
2063	74	2026-04-06	Gündüz	480	472	8	1000	861	29	2026-04-29 13:06:56.996+00	\N
2064	74	2026-04-05	Gündüz	480	422	58	1000	861	42	2026-04-29 13:06:57.01+00	\N
2065	74	2026-04-04	Gündüz	480	454	26	1000	911	21	2026-04-29 13:06:57.024+00	\N
2066	74	2026-04-03	Gündüz	480	426	54	1000	878	14	2026-04-29 13:06:57.036+00	\N
2067	74	2026-04-02	Gündüz	480	434	46	1000	830	23	2026-04-29 13:06:57.05+00	\N
2068	74	2026-04-01	Gündüz	480	453	27	1000	871	11	2026-04-29 13:06:57.062+00	\N
2069	74	2026-03-31	Gündüz	480	479	1	1000	866	24	2026-04-29 13:06:57.074+00	\N
2070	74	2026-03-30	Gündüz	480	454	26	1000	875	34	2026-04-29 13:06:57.087+00	\N
2071	75	2026-04-28	Gündüz	480	445	35	1000	866	21	2026-04-29 13:06:57.098+00	\N
2072	75	2026-04-27	Gündüz	480	458	22	1000	816	31	2026-04-29 13:06:57.108+00	\N
2073	75	2026-04-26	Gündüz	480	457	23	1000	811	29	2026-04-29 13:06:57.12+00	\N
2074	75	2026-04-25	Gündüz	480	437	43	1000	800	9	2026-04-29 13:06:57.133+00	\N
2075	75	2026-04-24	Gündüz	480	447	33	1000	852	21	2026-04-29 13:06:57.145+00	\N
2076	75	2026-04-23	Gündüz	480	443	37	1000	958	30	2026-04-29 13:06:57.158+00	\N
2077	75	2026-04-22	Gündüz	480	434	46	1000	885	42	2026-04-29 13:06:57.167+00	\N
2078	75	2026-04-21	Gündüz	480	425	55	1000	942	43	2026-04-29 13:06:57.176+00	\N
2079	75	2026-04-20	Gündüz	480	430	50	1000	944	33	2026-04-29 13:06:57.187+00	\N
2080	75	2026-04-19	Gündüz	480	427	53	1000	922	26	2026-04-29 13:06:57.199+00	\N
2081	75	2026-04-18	Gündüz	480	463	17	1000	918	40	2026-04-29 13:06:57.211+00	\N
2082	75	2026-04-17	Gündüz	480	422	58	1000	888	42	2026-04-29 13:06:57.221+00	\N
2083	75	2026-04-16	Gündüz	480	471	9	1000	906	24	2026-04-29 13:06:57.231+00	\N
2084	75	2026-04-15	Gündüz	480	425	55	1000	930	25	2026-04-29 13:06:57.24+00	\N
2085	75	2026-04-14	Gündüz	480	465	15	1000	935	14	2026-04-29 13:06:57.251+00	\N
2086	75	2026-04-13	Gündüz	480	452	28	1000	874	42	2026-04-29 13:06:57.262+00	\N
2087	75	2026-04-12	Gündüz	480	448	32	1000	825	35	2026-04-29 13:06:57.276+00	\N
2088	75	2026-04-11	Gündüz	480	449	31	1000	874	21	2026-04-29 13:06:57.31+00	\N
2089	75	2026-04-10	Gündüz	480	435	45	1000	921	11	2026-04-29 13:06:57.324+00	\N
2090	75	2026-04-09	Gündüz	480	428	52	1000	853	30	2026-04-29 13:06:57.339+00	\N
2091	75	2026-04-08	Gündüz	480	478	2	1000	873	42	2026-04-29 13:06:57.353+00	\N
2092	75	2026-04-07	Gündüz	480	437	43	1000	831	34	2026-04-29 13:06:57.367+00	\N
2093	75	2026-04-06	Gündüz	480	423	57	1000	891	28	2026-04-29 13:06:57.38+00	\N
2094	75	2026-04-05	Gündüz	480	438	42	1000	832	29	2026-04-29 13:06:57.393+00	\N
2095	75	2026-04-04	Gündüz	480	443	37	1000	974	47	2026-04-29 13:06:57.405+00	\N
2096	75	2026-04-03	Gündüz	480	476	4	1000	872	20	2026-04-29 13:06:57.417+00	\N
2097	75	2026-04-02	Gündüz	480	473	7	1000	963	9	2026-04-29 13:06:57.431+00	\N
2098	75	2026-04-01	Gündüz	480	438	42	1000	821	18	2026-04-29 13:06:57.447+00	\N
2099	75	2026-03-31	Gündüz	480	474	6	1000	972	14	2026-04-29 13:06:57.461+00	\N
2100	75	2026-03-30	Gündüz	480	434	46	1000	837	35	2026-04-29 13:06:57.474+00	\N
2101	76	2026-04-28	Gündüz	480	467	13	1000	864	29	2026-04-29 13:06:57.488+00	\N
2102	76	2026-04-27	Gündüz	480	450	30	1000	852	17	2026-04-29 13:06:57.504+00	\N
2103	76	2026-04-26	Gündüz	480	447	33	1000	836	30	2026-04-29 13:06:57.516+00	\N
2104	76	2026-04-25	Gündüz	480	459	21	1000	977	22	2026-04-29 13:06:57.525+00	\N
2105	76	2026-04-24	Gündüz	480	438	42	1000	867	40	2026-04-29 13:06:57.536+00	\N
2106	76	2026-04-23	Gündüz	480	456	24	1000	930	44	2026-04-29 13:06:57.546+00	\N
2107	76	2026-04-22	Gündüz	480	479	1	1000	894	13	2026-04-29 13:06:57.558+00	\N
2108	76	2026-04-21	Gündüz	480	459	21	1000	942	17	2026-04-29 13:06:57.572+00	\N
2109	76	2026-04-20	Gündüz	480	421	59	1000	966	32	2026-04-29 13:06:57.586+00	\N
2110	76	2026-04-19	Gündüz	480	447	33	1000	880	43	2026-04-29 13:06:57.6+00	\N
2111	76	2026-04-18	Gündüz	480	478	2	1000	877	11	2026-04-29 13:06:57.616+00	\N
2112	76	2026-04-17	Gündüz	480	468	12	1000	871	15	2026-04-29 13:06:57.634+00	\N
2113	76	2026-04-16	Gündüz	480	440	40	1000	822	22	2026-04-29 13:06:57.651+00	\N
2114	76	2026-04-15	Gündüz	480	475	5	1000	885	37	2026-04-29 13:06:57.667+00	\N
2115	76	2026-04-14	Gündüz	480	454	26	1000	826	12	2026-04-29 13:06:57.684+00	\N
2116	76	2026-04-13	Gündüz	480	456	24	1000	896	25	2026-04-29 13:06:57.699+00	\N
2117	76	2026-04-12	Gündüz	480	457	23	1000	841	22	2026-04-29 13:06:57.715+00	\N
2118	76	2026-04-11	Gündüz	480	423	57	1000	804	15	2026-04-29 13:06:57.727+00	\N
2119	76	2026-04-10	Gündüz	480	450	30	1000	823	35	2026-04-29 13:06:57.739+00	\N
2120	76	2026-04-09	Gündüz	480	424	56	1000	822	25	2026-04-29 13:06:57.75+00	\N
2121	76	2026-04-08	Gündüz	480	433	47	1000	820	27	2026-04-29 13:06:57.761+00	\N
2122	76	2026-04-07	Gündüz	480	451	29	1000	939	38	2026-04-29 13:06:57.774+00	\N
2123	76	2026-04-06	Gündüz	480	459	21	1000	915	35	2026-04-29 13:06:57.786+00	\N
2124	76	2026-04-05	Gündüz	480	441	39	1000	977	21	2026-04-29 13:06:57.797+00	\N
2125	76	2026-04-04	Gündüz	480	453	27	1000	901	43	2026-04-29 13:06:57.808+00	\N
2126	76	2026-04-03	Gündüz	480	464	16	1000	861	10	2026-04-29 13:06:57.819+00	\N
2127	76	2026-04-02	Gündüz	480	471	9	1000	972	40	2026-04-29 13:06:57.833+00	\N
2128	76	2026-04-01	Gündüz	480	434	46	1000	958	19	2026-04-29 13:06:57.845+00	\N
2129	76	2026-03-31	Gündüz	480	465	15	1000	814	34	2026-04-29 13:06:57.859+00	\N
2130	76	2026-03-30	Gündüz	480	453	27	1000	930	21	2026-04-29 13:06:57.873+00	\N
2131	77	2026-04-28	Gündüz	480	473	7	1000	851	35	2026-04-29 13:06:57.887+00	\N
2132	77	2026-04-27	Gündüz	480	434	46	1000	905	30	2026-04-29 13:06:57.9+00	\N
2133	77	2026-04-26	Gündüz	480	443	37	1000	836	22	2026-04-29 13:06:57.914+00	\N
2134	77	2026-04-25	Gündüz	480	448	32	1000	872	37	2026-04-29 13:06:57.929+00	\N
2135	77	2026-04-24	Gündüz	480	473	7	1000	971	21	2026-04-29 13:06:57.945+00	\N
2136	77	2026-04-23	Gündüz	480	473	7	1000	922	18	2026-04-29 13:06:57.957+00	\N
2137	77	2026-04-22	Gündüz	480	451	29	1000	894	20	2026-04-29 13:06:57.967+00	\N
2138	77	2026-04-21	Gündüz	480	425	55	1000	979	48	2026-04-29 13:06:57.977+00	\N
2139	77	2026-04-20	Gündüz	480	453	27	1000	834	36	2026-04-29 13:06:57.987+00	\N
2140	77	2026-04-19	Gündüz	480	444	36	1000	804	30	2026-04-29 13:06:57.997+00	\N
2141	77	2026-04-18	Gündüz	480	433	47	1000	957	30	2026-04-29 13:06:58.007+00	\N
2142	77	2026-04-17	Gündüz	480	460	20	1000	809	25	2026-04-29 13:06:58.016+00	\N
2143	77	2026-04-16	Gündüz	480	422	58	1000	901	32	2026-04-29 13:06:58.026+00	\N
2144	77	2026-04-15	Gündüz	480	459	21	1000	858	28	2026-04-29 13:06:58.037+00	\N
2145	77	2026-04-14	Gündüz	480	473	7	1000	969	35	2026-04-29 13:06:58.048+00	\N
2146	77	2026-04-13	Gündüz	480	469	11	1000	958	44	2026-04-29 13:06:58.061+00	\N
2147	77	2026-04-12	Gündüz	480	444	36	1000	944	21	2026-04-29 13:06:58.074+00	\N
2148	77	2026-04-11	Gündüz	480	450	30	1000	885	26	2026-04-29 13:06:58.088+00	\N
2149	77	2026-04-10	Gündüz	480	462	18	1000	966	10	2026-04-29 13:06:58.101+00	\N
2150	77	2026-04-09	Gündüz	480	426	54	1000	890	21	2026-04-29 13:06:58.112+00	\N
2151	77	2026-04-08	Gündüz	480	431	49	1000	802	21	2026-04-29 13:06:58.123+00	\N
2152	77	2026-04-07	Gündüz	480	461	19	1000	911	38	2026-04-29 13:06:58.134+00	\N
2153	77	2026-04-06	Gündüz	480	421	59	1000	802	17	2026-04-29 13:06:58.147+00	\N
2154	77	2026-04-05	Gündüz	480	426	54	1000	826	26	2026-04-29 13:06:58.158+00	\N
2155	77	2026-04-04	Gündüz	480	427	53	1000	930	20	2026-04-29 13:06:58.171+00	\N
2156	77	2026-04-03	Gündüz	480	475	5	1000	943	26	2026-04-29 13:06:58.184+00	\N
2157	77	2026-04-02	Gündüz	480	420	60	1000	915	27	2026-04-29 13:06:58.197+00	\N
2158	77	2026-04-01	Gündüz	480	454	26	1000	898	38	2026-04-29 13:06:58.208+00	\N
2159	77	2026-03-31	Gündüz	480	447	33	1000	910	40	2026-04-29 13:06:58.219+00	\N
2160	77	2026-03-30	Gündüz	480	432	48	1000	880	26	2026-04-29 13:06:58.23+00	\N
2161	78	2026-04-28	Gündüz	480	467	13	1000	826	8	2026-04-29 13:06:58.243+00	\N
2162	78	2026-04-27	Gündüz	480	438	42	1000	827	17	2026-04-29 13:06:58.254+00	\N
2163	78	2026-04-26	Gündüz	480	471	9	1000	898	43	2026-04-29 13:06:58.265+00	\N
2164	78	2026-04-25	Gündüz	480	440	40	1000	880	36	2026-04-29 13:06:58.277+00	\N
2165	78	2026-04-24	Gündüz	480	439	41	1000	960	14	2026-04-29 13:06:58.288+00	\N
2166	78	2026-04-23	Gündüz	480	456	24	1000	925	14	2026-04-29 13:06:58.299+00	\N
2167	78	2026-04-22	Gündüz	480	455	25	1000	878	35	2026-04-29 13:06:58.312+00	\N
2168	78	2026-04-21	Gündüz	480	439	41	1000	804	38	2026-04-29 13:06:58.324+00	\N
2169	78	2026-04-20	Gündüz	480	445	35	1000	862	30	2026-04-29 13:06:58.337+00	\N
2170	78	2026-04-19	Gündüz	480	475	5	1000	803	19	2026-04-29 13:06:58.349+00	\N
2171	78	2026-04-18	Gündüz	480	464	16	1000	979	27	2026-04-29 13:06:58.362+00	\N
2172	78	2026-04-17	Gündüz	480	461	19	1000	835	11	2026-04-29 13:06:58.373+00	\N
2173	78	2026-04-16	Gündüz	480	435	45	1000	890	11	2026-04-29 13:06:58.386+00	\N
2174	78	2026-04-15	Gündüz	480	447	33	1000	813	38	2026-04-29 13:06:58.401+00	\N
2175	78	2026-04-14	Gündüz	480	435	45	1000	896	38	2026-04-29 13:06:58.414+00	\N
2176	78	2026-04-13	Gündüz	480	429	51	1000	908	18	2026-04-29 13:06:58.427+00	\N
2177	78	2026-04-12	Gündüz	480	466	14	1000	978	21	2026-04-29 13:06:58.44+00	\N
2178	78	2026-04-11	Gündüz	480	476	4	1000	968	31	2026-04-29 13:06:58.452+00	\N
2179	78	2026-04-10	Gündüz	480	445	35	1000	924	32	2026-04-29 13:06:58.466+00	\N
2180	78	2026-04-09	Gündüz	480	467	13	1000	966	39	2026-04-29 13:06:58.477+00	\N
2181	78	2026-04-08	Gündüz	480	432	48	1000	963	34	2026-04-29 13:06:58.491+00	\N
2182	78	2026-04-07	Gündüz	480	431	49	1000	892	21	2026-04-29 13:06:58.504+00	\N
2183	78	2026-04-06	Gündüz	480	433	47	1000	882	35	2026-04-29 13:06:58.515+00	\N
2184	78	2026-04-05	Gündüz	480	478	2	1000	859	16	2026-04-29 13:06:58.526+00	\N
2185	78	2026-04-04	Gündüz	480	454	26	1000	803	8	2026-04-29 13:06:58.537+00	\N
2186	78	2026-04-03	Gündüz	480	477	3	1000	904	22	2026-04-29 13:06:58.549+00	\N
2187	78	2026-04-02	Gündüz	480	459	21	1000	977	15	2026-04-29 13:06:58.561+00	\N
2188	78	2026-04-01	Gündüz	480	477	3	1000	802	28	2026-04-29 13:06:58.573+00	\N
2189	78	2026-03-31	Gündüz	480	478	2	1000	934	27	2026-04-29 13:06:58.584+00	\N
2190	78	2026-03-30	Gündüz	480	457	23	1000	894	16	2026-04-29 13:06:58.597+00	\N
2191	79	2026-04-28	Gündüz	480	457	23	1000	921	21	2026-04-29 13:06:58.608+00	\N
2192	79	2026-04-27	Gündüz	480	472	8	1000	963	16	2026-04-29 13:06:58.625+00	\N
2193	79	2026-04-26	Gündüz	480	454	26	1000	818	27	2026-04-29 13:06:58.639+00	\N
2194	79	2026-04-25	Gündüz	480	421	59	1000	891	21	2026-04-29 13:06:58.651+00	\N
2195	79	2026-04-24	Gündüz	480	438	42	1000	862	26	2026-04-29 13:06:58.663+00	\N
2196	79	2026-04-23	Gündüz	480	479	1	1000	923	28	2026-04-29 13:06:58.677+00	\N
2197	79	2026-04-22	Gündüz	480	477	3	1000	863	24	2026-04-29 13:06:58.689+00	\N
2198	79	2026-04-21	Gündüz	480	444	36	1000	843	16	2026-04-29 13:06:58.703+00	\N
2199	79	2026-04-20	Gündüz	480	425	55	1000	823	15	2026-04-29 13:06:58.717+00	\N
2200	79	2026-04-19	Gündüz	480	465	15	1000	814	24	2026-04-29 13:06:58.729+00	\N
2201	79	2026-04-18	Gündüz	480	430	50	1000	950	43	2026-04-29 13:06:58.74+00	\N
2202	79	2026-04-17	Gündüz	480	456	24	1000	824	22	2026-04-29 13:06:58.751+00	\N
2203	79	2026-04-16	Gündüz	480	453	27	1000	815	23	2026-04-29 13:06:58.762+00	\N
2204	79	2026-04-15	Gündüz	480	452	28	1000	882	43	2026-04-29 13:06:58.778+00	\N
2205	79	2026-04-14	Gündüz	480	430	50	1000	940	41	2026-04-29 13:06:58.795+00	\N
2206	79	2026-04-13	Gündüz	480	422	58	1000	865	15	2026-04-29 13:06:58.813+00	\N
2207	79	2026-04-12	Gündüz	480	447	33	1000	803	9	2026-04-29 13:06:58.834+00	\N
2208	79	2026-04-11	Gündüz	480	426	54	1000	890	35	2026-04-29 13:06:58.846+00	\N
2209	79	2026-04-10	Gündüz	480	437	43	1000	869	24	2026-04-29 13:06:58.862+00	\N
2210	79	2026-04-09	Gündüz	480	444	36	1000	908	12	2026-04-29 13:06:58.878+00	\N
2211	79	2026-04-08	Gündüz	480	444	36	1000	958	24	2026-04-29 13:06:58.896+00	\N
2212	79	2026-04-07	Gündüz	480	469	11	1000	806	31	2026-04-29 13:06:58.916+00	\N
2213	79	2026-04-06	Gündüz	480	436	44	1000	859	23	2026-04-29 13:06:58.935+00	\N
2214	79	2026-04-05	Gündüz	480	471	9	1000	852	32	2026-04-29 13:06:58.958+00	\N
2215	79	2026-04-04	Gündüz	480	466	14	1000	833	9	2026-04-29 13:06:58.97+00	\N
2216	79	2026-04-03	Gündüz	480	456	24	1000	812	19	2026-04-29 13:06:58.985+00	\N
2217	79	2026-04-02	Gündüz	480	446	34	1000	975	44	2026-04-29 13:06:58.998+00	\N
2218	79	2026-04-01	Gündüz	480	439	41	1000	843	25	2026-04-29 13:06:59.012+00	\N
2219	79	2026-03-31	Gündüz	480	456	24	1000	922	45	2026-04-29 13:06:59.025+00	\N
2220	79	2026-03-30	Gündüz	480	423	57	1000	853	35	2026-04-29 13:06:59.038+00	\N
2221	80	2026-04-28	Gündüz	480	442	38	1000	967	40	2026-04-29 13:06:59.05+00	\N
2222	80	2026-04-27	Gündüz	480	425	55	1000	899	27	2026-04-29 13:06:59.06+00	\N
2223	80	2026-04-26	Gündüz	480	458	22	1000	935	26	2026-04-29 13:06:59.071+00	\N
2224	80	2026-04-25	Gündüz	480	467	13	1000	816	40	2026-04-29 13:06:59.084+00	\N
2225	80	2026-04-24	Gündüz	480	472	8	1000	853	39	2026-04-29 13:06:59.099+00	\N
2226	80	2026-04-23	Gündüz	480	441	39	1000	861	25	2026-04-29 13:06:59.117+00	\N
2227	80	2026-04-22	Gündüz	480	438	42	1000	827	13	2026-04-29 13:06:59.136+00	\N
2228	80	2026-04-21	Gündüz	480	435	45	1000	848	39	2026-04-29 13:06:59.154+00	\N
2229	80	2026-04-20	Gündüz	480	447	33	1000	934	38	2026-04-29 13:06:59.173+00	\N
2230	80	2026-04-19	Gündüz	480	462	18	1000	838	8	2026-04-29 13:06:59.19+00	\N
2231	80	2026-04-18	Gündüz	480	445	35	1000	856	15	2026-04-29 13:06:59.208+00	\N
2232	80	2026-04-17	Gündüz	480	438	42	1000	811	11	2026-04-29 13:06:59.229+00	\N
2233	80	2026-04-16	Gündüz	480	462	18	1000	887	37	2026-04-29 13:06:59.249+00	\N
2234	80	2026-04-15	Gündüz	480	455	25	1000	838	26	2026-04-29 13:06:59.267+00	\N
2235	80	2026-04-14	Gündüz	480	437	43	1000	839	11	2026-04-29 13:06:59.287+00	\N
2236	80	2026-04-13	Gündüz	480	468	12	1000	829	35	2026-04-29 13:06:59.306+00	\N
2237	80	2026-04-12	Gündüz	480	436	44	1000	906	17	2026-04-29 13:06:59.326+00	\N
2238	80	2026-04-11	Gündüz	480	436	44	1000	850	19	2026-04-29 13:06:59.344+00	\N
2239	80	2026-04-10	Gündüz	480	466	14	1000	840	20	2026-04-29 13:06:59.359+00	\N
2240	80	2026-04-09	Gündüz	480	472	8	1000	878	15	2026-04-29 13:06:59.372+00	\N
2241	80	2026-04-08	Gündüz	480	439	41	1000	889	16	2026-04-29 13:06:59.385+00	\N
2242	80	2026-04-07	Gündüz	480	466	14	1000	906	23	2026-04-29 13:06:59.4+00	\N
2243	80	2026-04-06	Gündüz	480	445	35	1000	815	27	2026-04-29 13:06:59.416+00	\N
2244	80	2026-04-05	Gündüz	480	423	57	1000	896	18	2026-04-29 13:06:59.432+00	\N
2245	80	2026-04-04	Gündüz	480	423	57	1000	931	36	2026-04-29 13:06:59.448+00	\N
2246	80	2026-04-03	Gündüz	480	444	36	1000	838	15	2026-04-29 13:06:59.467+00	\N
2247	80	2026-04-02	Gündüz	480	450	30	1000	845	30	2026-04-29 13:06:59.484+00	\N
2248	80	2026-04-01	Gündüz	480	467	13	1000	957	40	2026-04-29 13:06:59.502+00	\N
2249	80	2026-03-31	Gündüz	480	437	43	1000	846	11	2026-04-29 13:06:59.522+00	\N
2250	80	2026-03-30	Gündüz	480	473	7	1000	825	29	2026-04-29 13:06:59.541+00	\N
2251	81	2026-04-28	Gündüz	480	480	0	1000	885	24	2026-04-29 13:06:59.56+00	\N
2252	81	2026-04-27	Gündüz	480	475	5	1000	861	39	2026-04-29 13:06:59.573+00	\N
2253	81	2026-04-26	Gündüz	480	466	14	1000	878	10	2026-04-29 13:06:59.591+00	\N
2254	81	2026-04-25	Gündüz	480	436	44	1000	910	33	2026-04-29 13:06:59.61+00	\N
2255	81	2026-04-24	Gündüz	480	450	30	1000	907	22	2026-04-29 13:06:59.627+00	\N
2256	81	2026-04-23	Gündüz	480	462	18	1000	822	38	2026-04-29 13:06:59.646+00	\N
2257	81	2026-04-22	Gündüz	480	441	39	1000	949	45	2026-04-29 13:06:59.664+00	\N
2258	81	2026-04-21	Gündüz	480	447	33	1000	946	41	2026-04-29 13:06:59.682+00	\N
2259	81	2026-04-20	Gündüz	480	461	19	1000	817	12	2026-04-29 13:06:59.7+00	\N
2260	81	2026-04-19	Gündüz	480	452	28	1000	915	25	2026-04-29 13:06:59.717+00	\N
2261	81	2026-04-18	Gündüz	480	462	18	1000	801	21	2026-04-29 13:06:59.737+00	\N
2262	81	2026-04-17	Gündüz	480	462	18	1000	823	31	2026-04-29 13:06:59.757+00	\N
2263	81	2026-04-16	Gündüz	480	420	60	1000	931	28	2026-04-29 13:06:59.775+00	\N
2264	81	2026-04-15	Gündüz	480	426	54	1000	820	35	2026-04-29 13:06:59.792+00	\N
2265	81	2026-04-14	Gündüz	480	453	27	1000	874	12	2026-04-29 13:06:59.808+00	\N
2266	81	2026-04-13	Gündüz	480	467	13	1000	858	38	2026-04-29 13:06:59.824+00	\N
2267	81	2026-04-12	Gündüz	480	446	34	1000	968	13	2026-04-29 13:06:59.841+00	\N
2268	81	2026-04-11	Gündüz	480	472	8	1000	873	32	2026-04-29 13:06:59.855+00	\N
2269	81	2026-04-10	Gündüz	480	479	1	1000	856	28	2026-04-29 13:06:59.869+00	\N
2270	81	2026-04-09	Gündüz	480	448	32	1000	834	9	2026-04-29 13:06:59.884+00	\N
2271	81	2026-04-08	Gündüz	480	431	49	1000	805	20	2026-04-29 13:06:59.899+00	\N
2272	81	2026-04-07	Gündüz	480	427	53	1000	908	28	2026-04-29 13:06:59.915+00	\N
2273	81	2026-04-06	Gündüz	480	479	1	1000	964	20	2026-04-29 13:06:59.931+00	\N
2274	81	2026-04-05	Gündüz	480	438	42	1000	846	30	2026-04-29 13:06:59.948+00	\N
2275	81	2026-04-04	Gündüz	480	441	39	1000	901	23	2026-04-29 13:06:59.963+00	\N
2276	81	2026-04-03	Gündüz	480	452	28	1000	968	33	2026-04-29 13:06:59.979+00	\N
2277	81	2026-04-02	Gündüz	480	453	27	1000	968	13	2026-04-29 13:06:59.995+00	\N
2278	81	2026-04-01	Gündüz	480	442	38	1000	867	20	2026-04-29 13:07:00.02+00	\N
2279	81	2026-03-31	Gündüz	480	431	49	1000	861	15	2026-04-29 13:07:00.032+00	\N
2280	81	2026-03-30	Gündüz	480	441	39	1000	972	27	2026-04-29 13:07:00.047+00	\N
2281	82	2026-04-28	Gündüz	480	451	29	1000	879	39	2026-04-29 13:07:00.064+00	\N
2282	82	2026-04-27	Gündüz	480	434	46	1000	866	33	2026-04-29 13:07:00.079+00	\N
2283	82	2026-04-26	Gündüz	480	475	5	1000	917	13	2026-04-29 13:07:00.094+00	\N
2284	82	2026-04-25	Gündüz	480	427	53	1000	899	13	2026-04-29 13:07:00.109+00	\N
2285	82	2026-04-24	Gündüz	480	453	27	1000	816	30	2026-04-29 13:07:00.125+00	\N
2286	82	2026-04-23	Gündüz	480	460	20	1000	883	31	2026-04-29 13:07:00.141+00	\N
2287	82	2026-04-22	Gündüz	480	426	54	1000	850	25	2026-04-29 13:07:00.155+00	\N
2288	82	2026-04-21	Gündüz	480	479	1	1000	835	39	2026-04-29 13:07:00.169+00	\N
2289	82	2026-04-20	Gündüz	480	420	60	1000	823	24	2026-04-29 13:07:00.184+00	\N
2290	82	2026-04-19	Gündüz	480	428	52	1000	832	13	2026-04-29 13:07:00.197+00	\N
2291	82	2026-04-18	Gündüz	480	427	53	1000	922	43	2026-04-29 13:07:00.208+00	\N
2292	82	2026-04-17	Gündüz	480	437	43	1000	884	12	2026-04-29 13:07:00.218+00	\N
2293	82	2026-04-16	Gündüz	480	477	3	1000	911	20	2026-04-29 13:07:00.233+00	\N
2294	82	2026-04-15	Gündüz	480	432	48	1000	926	15	2026-04-29 13:07:00.257+00	\N
2295	82	2026-04-14	Gündüz	480	435	45	1000	826	29	2026-04-29 13:07:00.268+00	\N
2296	82	2026-04-13	Gündüz	480	439	41	1000	968	22	2026-04-29 13:07:00.281+00	\N
2297	82	2026-04-12	Gündüz	480	475	5	1000	865	18	2026-04-29 13:07:00.293+00	\N
2298	82	2026-04-11	Gündüz	480	477	3	1000	919	14	2026-04-29 13:07:00.308+00	\N
2299	82	2026-04-10	Gündüz	480	423	57	1000	955	37	2026-04-29 13:07:00.327+00	\N
2300	82	2026-04-09	Gündüz	480	457	23	1000	939	35	2026-04-29 13:07:00.347+00	\N
2301	82	2026-04-08	Gündüz	480	441	39	1000	964	43	2026-04-29 13:07:00.365+00	\N
2302	82	2026-04-07	Gündüz	480	450	30	1000	896	32	2026-04-29 13:07:00.383+00	\N
2303	82	2026-04-06	Gündüz	480	439	41	1000	837	39	2026-04-29 13:07:00.401+00	\N
2304	82	2026-04-05	Gündüz	480	430	50	1000	884	19	2026-04-29 13:07:00.419+00	\N
2305	82	2026-04-04	Gündüz	480	453	27	1000	865	32	2026-04-29 13:07:00.437+00	\N
2306	82	2026-04-03	Gündüz	480	466	14	1000	800	26	2026-04-29 13:07:00.457+00	\N
2307	82	2026-04-02	Gündüz	480	437	43	1000	977	35	2026-04-29 13:07:00.475+00	\N
2308	82	2026-04-01	Gündüz	480	461	19	1000	949	29	2026-04-29 13:07:00.492+00	\N
2309	82	2026-03-31	Gündüz	480	451	29	1000	851	36	2026-04-29 13:07:00.51+00	\N
2310	82	2026-03-30	Gündüz	480	420	60	1000	803	15	2026-04-29 13:07:00.527+00	\N
2311	83	2026-04-28	Gündüz	480	444	36	1000	863	31	2026-04-29 13:07:00.544+00	\N
2312	83	2026-04-27	Gündüz	480	459	21	1000	865	9	2026-04-29 13:07:00.561+00	\N
2313	83	2026-04-26	Gündüz	480	448	32	1000	954	26	2026-04-29 13:07:00.577+00	\N
2314	83	2026-04-25	Gündüz	480	421	59	1000	897	29	2026-04-29 13:07:00.589+00	\N
2315	83	2026-04-24	Gündüz	480	445	35	1000	954	27	2026-04-29 13:07:00.604+00	\N
2316	83	2026-04-23	Gündüz	480	429	51	1000	966	43	2026-04-29 13:07:00.619+00	\N
2317	83	2026-04-22	Gündüz	480	441	39	1000	935	12	2026-04-29 13:07:00.632+00	\N
2318	83	2026-04-21	Gündüz	480	458	22	1000	951	33	2026-04-29 13:07:00.645+00	\N
2319	83	2026-04-20	Gündüz	480	463	17	1000	804	21	2026-04-29 13:07:00.656+00	\N
2320	83	2026-04-19	Gündüz	480	446	34	1000	831	40	2026-04-29 13:07:00.667+00	\N
2321	83	2026-04-18	Gündüz	480	430	50	1000	947	42	2026-04-29 13:07:00.678+00	\N
2322	83	2026-04-17	Gündüz	480	444	36	1000	944	46	2026-04-29 13:07:00.691+00	\N
2323	83	2026-04-16	Gündüz	480	421	59	1000	809	15	2026-04-29 13:07:00.705+00	\N
2324	83	2026-04-15	Gündüz	480	460	20	1000	959	12	2026-04-29 13:07:00.719+00	\N
2325	83	2026-04-14	Gündüz	480	474	6	1000	852	14	2026-04-29 13:07:00.733+00	\N
2326	83	2026-04-13	Gündüz	480	458	22	1000	969	10	2026-04-29 13:07:00.746+00	\N
2327	83	2026-04-12	Gündüz	480	433	47	1000	907	38	2026-04-29 13:07:00.76+00	\N
2328	83	2026-04-11	Gündüz	480	446	34	1000	836	25	2026-04-29 13:07:00.774+00	\N
2329	83	2026-04-10	Gündüz	480	431	49	1000	803	19	2026-04-29 13:07:00.787+00	\N
2330	83	2026-04-09	Gündüz	480	463	17	1000	848	9	2026-04-29 13:07:00.8+00	\N
2331	83	2026-04-08	Gündüz	480	476	4	1000	904	16	2026-04-29 13:07:00.815+00	\N
2332	83	2026-04-07	Gündüz	480	477	3	1000	887	30	2026-04-29 13:07:00.831+00	\N
2333	83	2026-04-06	Gündüz	480	458	22	1000	800	25	2026-04-29 13:07:00.846+00	\N
2334	83	2026-04-05	Gündüz	480	448	32	1000	944	20	2026-04-29 13:07:00.86+00	\N
2335	83	2026-04-04	Gündüz	480	459	21	1000	944	28	2026-04-29 13:07:00.873+00	\N
2336	83	2026-04-03	Gündüz	480	441	39	1000	970	37	2026-04-29 13:07:00.886+00	\N
2337	83	2026-04-02	Gündüz	480	428	52	1000	976	25	2026-04-29 13:07:00.9+00	\N
2338	83	2026-04-01	Gündüz	480	444	36	1000	898	10	2026-04-29 13:07:00.915+00	\N
2339	83	2026-03-31	Gündüz	480	455	25	1000	870	32	2026-04-29 13:07:00.928+00	\N
2340	83	2026-03-30	Gündüz	480	472	8	1000	895	43	2026-04-29 13:07:00.942+00	\N
2341	84	2026-04-28	Gündüz	480	469	11	1000	979	37	2026-04-29 13:07:00.955+00	\N
2342	84	2026-04-27	Gündüz	480	420	60	1000	877	19	2026-04-29 13:07:00.968+00	\N
2343	84	2026-04-26	Gündüz	480	474	6	1000	827	30	2026-04-29 13:07:00.983+00	\N
2344	84	2026-04-25	Gündüz	480	437	43	1000	892	23	2026-04-29 13:07:00.997+00	\N
2345	84	2026-04-24	Gündüz	480	459	21	1000	861	24	2026-04-29 13:07:01.013+00	\N
2346	84	2026-04-23	Gündüz	480	426	54	1000	810	31	2026-04-29 13:07:01.037+00	\N
2347	84	2026-04-22	Gündüz	480	466	14	1000	826	19	2026-04-29 13:07:01.051+00	\N
2348	84	2026-04-21	Gündüz	480	435	45	1000	805	23	2026-04-29 13:07:01.079+00	\N
2349	84	2026-04-20	Gündüz	480	420	60	1000	934	39	2026-04-29 13:07:01.093+00	\N
2350	84	2026-04-19	Gündüz	480	426	54	1000	895	10	2026-04-29 13:07:01.105+00	\N
2351	84	2026-04-18	Gündüz	480	464	16	1000	975	24	2026-04-29 13:07:01.119+00	\N
2352	84	2026-04-17	Gündüz	480	464	16	1000	804	9	2026-04-29 13:07:01.134+00	\N
2353	84	2026-04-16	Gündüz	480	424	56	1000	846	25	2026-04-29 13:07:01.15+00	\N
2354	84	2026-04-15	Gündüz	480	421	59	1000	821	26	2026-04-29 13:07:01.165+00	\N
2355	84	2026-04-14	Gündüz	480	472	8	1000	964	13	2026-04-29 13:07:01.183+00	\N
2356	84	2026-04-13	Gündüz	480	473	7	1000	855	9	2026-04-29 13:07:01.201+00	\N
2357	84	2026-04-12	Gündüz	480	444	36	1000	805	32	2026-04-29 13:07:01.218+00	\N
2358	84	2026-04-11	Gündüz	480	444	36	1000	951	41	2026-04-29 13:07:01.233+00	\N
2359	84	2026-04-10	Gündüz	480	476	4	1000	824	11	2026-04-29 13:07:01.247+00	\N
2360	84	2026-04-09	Gündüz	480	454	26	1000	907	29	2026-04-29 13:07:01.26+00	\N
2361	84	2026-04-08	Gündüz	480	427	53	1000	814	27	2026-04-29 13:07:01.276+00	\N
2362	84	2026-04-07	Gündüz	480	449	31	1000	967	39	2026-04-29 13:07:01.291+00	\N
2363	84	2026-04-06	Gündüz	480	429	51	1000	853	34	2026-04-29 13:07:01.306+00	\N
2364	84	2026-04-05	Gündüz	480	447	33	1000	840	41	2026-04-29 13:07:01.321+00	\N
2365	84	2026-04-04	Gündüz	480	434	46	1000	801	24	2026-04-29 13:07:01.34+00	\N
2366	84	2026-04-03	Gündüz	480	457	23	1000	971	42	2026-04-29 13:07:01.354+00	\N
2367	84	2026-04-02	Gündüz	480	472	8	1000	924	40	2026-04-29 13:07:01.368+00	\N
2368	84	2026-04-01	Gündüz	480	431	49	1000	863	11	2026-04-29 13:07:01.384+00	\N
2369	84	2026-03-31	Gündüz	480	453	27	1000	856	30	2026-04-29 13:07:01.398+00	\N
2370	84	2026-03-30	Gündüz	480	466	14	1000	961	21	2026-04-29 13:07:01.413+00	\N
2371	85	2026-04-28	Gündüz	480	437	43	1000	805	23	2026-04-29 13:07:01.43+00	\N
2372	85	2026-04-27	Gündüz	480	426	54	1000	941	29	2026-04-29 13:07:01.446+00	\N
2373	85	2026-04-26	Gündüz	480	421	59	1000	939	39	2026-04-29 13:07:01.464+00	\N
2374	85	2026-04-25	Gündüz	480	445	35	1000	834	12	2026-04-29 13:07:01.481+00	\N
2375	85	2026-04-24	Gündüz	480	479	1	1000	924	44	2026-04-29 13:07:01.497+00	\N
2376	85	2026-04-23	Gündüz	480	460	20	1000	940	25	2026-04-29 13:07:01.513+00	\N
2377	85	2026-04-22	Gündüz	480	442	38	1000	806	32	2026-04-29 13:07:01.529+00	\N
2378	85	2026-04-21	Gündüz	480	434	46	1000	831	38	2026-04-29 13:07:01.546+00	\N
2379	85	2026-04-20	Gündüz	480	453	27	1000	865	36	2026-04-29 13:07:01.562+00	\N
2380	85	2026-04-19	Gündüz	480	445	35	1000	949	33	2026-04-29 13:07:01.579+00	\N
2381	85	2026-04-18	Gündüz	480	450	30	1000	925	11	2026-04-29 13:07:01.596+00	\N
2382	85	2026-04-17	Gündüz	480	456	24	1000	824	33	2026-04-29 13:07:01.613+00	\N
2383	85	2026-04-16	Gündüz	480	480	0	1000	846	27	2026-04-29 13:07:01.63+00	\N
2384	85	2026-04-15	Gündüz	480	458	22	1000	853	8	2026-04-29 13:07:01.641+00	\N
2385	85	2026-04-14	Gündüz	480	443	37	1000	906	10	2026-04-29 13:07:01.657+00	\N
2386	85	2026-04-13	Gündüz	480	457	23	1000	858	27	2026-04-29 13:07:01.673+00	\N
2387	85	2026-04-12	Gündüz	480	438	42	1000	914	26	2026-04-29 13:07:01.691+00	\N
2388	85	2026-04-11	Gündüz	480	470	10	1000	842	20	2026-04-29 13:07:01.708+00	\N
2389	85	2026-04-10	Gündüz	480	439	41	1000	850	34	2026-04-29 13:07:01.723+00	\N
2390	85	2026-04-09	Gündüz	480	423	57	1000	864	11	2026-04-29 13:07:01.736+00	\N
2391	85	2026-04-08	Gündüz	480	452	28	1000	929	11	2026-04-29 13:07:01.749+00	\N
2392	85	2026-04-07	Gündüz	480	466	14	1000	944	39	2026-04-29 13:07:01.763+00	\N
2393	85	2026-04-06	Gündüz	480	472	8	1000	861	36	2026-04-29 13:07:01.777+00	\N
2394	85	2026-04-05	Gündüz	480	473	7	1000	901	12	2026-04-29 13:07:01.793+00	\N
2395	85	2026-04-04	Gündüz	480	440	40	1000	884	22	2026-04-29 13:07:01.807+00	\N
2396	85	2026-04-03	Gündüz	480	455	25	1000	891	30	2026-04-29 13:07:01.822+00	\N
2397	85	2026-04-02	Gündüz	480	474	6	1000	978	13	2026-04-29 13:07:01.839+00	\N
2398	85	2026-04-01	Gündüz	480	466	14	1000	822	28	2026-04-29 13:07:01.855+00	\N
2399	85	2026-03-31	Gündüz	480	445	35	1000	913	14	2026-04-29 13:07:01.869+00	\N
2400	85	2026-03-30	Gündüz	480	426	54	1000	884	17	2026-04-29 13:07:01.883+00	\N
2401	86	2026-04-28	Gündüz	480	455	25	1000	962	16	2026-04-29 13:07:01.896+00	\N
2402	86	2026-04-27	Gündüz	480	422	58	1000	903	25	2026-04-29 13:07:01.911+00	\N
2403	86	2026-04-26	Gündüz	480	439	41	1000	916	16	2026-04-29 13:07:01.926+00	\N
2404	86	2026-04-25	Gündüz	480	436	44	1000	895	29	2026-04-29 13:07:01.941+00	\N
2405	86	2026-04-24	Gündüz	480	429	51	1000	910	18	2026-04-29 13:07:01.956+00	\N
2406	86	2026-04-23	Gündüz	480	433	47	1000	817	14	2026-04-29 13:07:01.971+00	\N
2407	86	2026-04-22	Gündüz	480	434	46	1000	918	32	2026-04-29 13:07:02.002+00	\N
2408	86	2026-04-21	Gündüz	480	429	51	1000	920	16	2026-04-29 13:07:02.016+00	\N
2409	86	2026-04-20	Gündüz	480	439	41	1000	846	16	2026-04-29 13:07:02.029+00	\N
2410	86	2026-04-19	Gündüz	480	459	21	1000	847	30	2026-04-29 13:07:02.044+00	\N
2411	86	2026-04-18	Gündüz	480	467	13	1000	805	16	2026-04-29 13:07:02.068+00	\N
2412	86	2026-04-17	Gündüz	480	442	38	1000	874	18	2026-04-29 13:07:02.084+00	\N
2413	86	2026-04-16	Gündüz	480	455	25	1000	890	25	2026-04-29 13:07:02.101+00	\N
2414	86	2026-04-15	Gündüz	480	465	15	1000	899	11	2026-04-29 13:07:02.12+00	\N
2415	86	2026-04-14	Gündüz	480	420	60	1000	807	19	2026-04-29 13:07:02.141+00	\N
2416	86	2026-04-13	Gündüz	480	427	53	1000	962	18	2026-04-29 13:07:02.162+00	\N
2417	86	2026-04-12	Gündüz	480	477	3	1000	870	16	2026-04-29 13:07:02.183+00	\N
2418	86	2026-04-11	Gündüz	480	456	24	1000	925	32	2026-04-29 13:07:02.203+00	\N
2419	86	2026-04-10	Gündüz	480	427	53	1000	936	21	2026-04-29 13:07:02.223+00	\N
2420	86	2026-04-09	Gündüz	480	458	22	1000	911	27	2026-04-29 13:07:02.238+00	\N
2421	86	2026-04-08	Gündüz	480	421	59	1000	965	11	2026-04-29 13:07:02.254+00	\N
2422	86	2026-04-07	Gündüz	480	469	11	1000	909	10	2026-04-29 13:07:02.272+00	\N
2423	86	2026-04-06	Gündüz	480	438	42	1000	838	11	2026-04-29 13:07:02.291+00	\N
2424	86	2026-04-05	Gündüz	480	454	26	1000	951	45	2026-04-29 13:07:02.311+00	\N
2425	86	2026-04-04	Gündüz	480	473	7	1000	968	20	2026-04-29 13:07:02.332+00	\N
2426	86	2026-04-03	Gündüz	480	469	11	1000	865	23	2026-04-29 13:07:02.347+00	\N
2427	86	2026-04-02	Gündüz	480	468	12	1000	927	43	2026-04-29 13:07:02.362+00	\N
2428	86	2026-04-01	Gündüz	480	461	19	1000	819	31	2026-04-29 13:07:02.378+00	\N
2429	86	2026-03-31	Gündüz	480	474	6	1000	927	39	2026-04-29 13:07:02.398+00	\N
2430	86	2026-03-30	Gündüz	480	431	49	1000	955	43	2026-04-29 13:07:02.413+00	\N
2431	87	2026-04-28	Gündüz	480	463	17	1000	940	13	2026-04-29 13:07:02.427+00	\N
2432	87	2026-04-27	Gündüz	480	443	37	1000	932	23	2026-04-29 13:07:02.443+00	\N
2433	87	2026-04-26	Gündüz	480	456	24	1000	976	38	2026-04-29 13:07:02.459+00	\N
2434	87	2026-04-25	Gündüz	480	459	21	1000	850	26	2026-04-29 13:07:02.476+00	\N
2435	87	2026-04-24	Gündüz	480	463	17	1000	939	33	2026-04-29 13:07:02.494+00	\N
2436	87	2026-04-23	Gündüz	480	425	55	1000	863	18	2026-04-29 13:07:02.512+00	\N
2437	87	2026-04-22	Gündüz	480	431	49	1000	912	33	2026-04-29 13:07:02.531+00	\N
2438	87	2026-04-21	Gündüz	480	430	50	1000	856	15	2026-04-29 13:07:02.549+00	\N
2439	87	2026-04-20	Gündüz	480	470	10	1000	840	22	2026-04-29 13:07:02.568+00	\N
2440	87	2026-04-19	Gündüz	480	438	42	1000	807	32	2026-04-29 13:07:02.585+00	\N
2441	87	2026-04-18	Gündüz	480	423	57	1000	810	23	2026-04-29 13:07:02.603+00	\N
2442	87	2026-04-17	Gündüz	480	437	43	1000	847	19	2026-04-29 13:07:02.618+00	\N
2443	87	2026-04-16	Gündüz	480	449	31	1000	966	33	2026-04-29 13:07:02.635+00	\N
2444	87	2026-04-15	Gündüz	480	474	6	1000	930	14	2026-04-29 13:07:02.65+00	\N
2445	87	2026-04-14	Gündüz	480	455	25	1000	927	25	2026-04-29 13:07:02.663+00	\N
2446	87	2026-04-13	Gündüz	480	475	5	1000	974	16	2026-04-29 13:07:02.675+00	\N
2447	87	2026-04-12	Gündüz	480	438	42	1000	903	33	2026-04-29 13:07:02.688+00	\N
2448	87	2026-04-11	Gündüz	480	473	7	1000	846	18	2026-04-29 13:07:02.703+00	\N
2449	87	2026-04-10	Gündüz	480	479	1	1000	802	12	2026-04-29 13:07:02.718+00	\N
2450	87	2026-04-09	Gündüz	480	479	1	1000	978	46	2026-04-29 13:07:02.731+00	\N
2451	87	2026-04-08	Gündüz	480	465	15	1000	918	43	2026-04-29 13:07:02.742+00	\N
2452	87	2026-04-07	Gündüz	480	420	60	1000	889	11	2026-04-29 13:07:02.752+00	\N
2453	87	2026-04-06	Gündüz	480	475	5	1000	858	10	2026-04-29 13:07:02.764+00	\N
2454	87	2026-04-05	Gündüz	480	469	11	1000	924	21	2026-04-29 13:07:02.776+00	\N
2455	87	2026-04-04	Gündüz	480	429	51	1000	871	19	2026-04-29 13:07:02.79+00	\N
2456	87	2026-04-03	Gündüz	480	438	42	1000	851	15	2026-04-29 13:07:02.804+00	\N
2457	87	2026-04-02	Gündüz	480	446	34	1000	800	12	2026-04-29 13:07:02.819+00	\N
2458	87	2026-04-01	Gündüz	480	424	56	1000	942	18	2026-04-29 13:07:02.835+00	\N
2459	87	2026-03-31	Gündüz	480	457	23	1000	966	10	2026-04-29 13:07:02.852+00	\N
2460	87	2026-03-30	Gündüz	480	432	48	1000	888	34	2026-04-29 13:07:02.865+00	\N
2461	88	2026-04-28	Gündüz	480	477	3	1000	917	27	2026-04-29 13:07:02.878+00	\N
2462	88	2026-04-27	Gündüz	480	469	11	1000	915	36	2026-04-29 13:07:02.893+00	\N
2463	88	2026-04-26	Gündüz	480	472	8	1000	939	16	2026-04-29 13:07:02.909+00	\N
2464	88	2026-04-25	Gündüz	480	446	34	1000	917	34	2026-04-29 13:07:02.923+00	\N
2465	88	2026-04-24	Gündüz	480	467	13	1000	969	33	2026-04-29 13:07:02.939+00	\N
2466	88	2026-04-23	Gündüz	480	421	59	1000	901	27	2026-04-29 13:07:02.954+00	\N
2467	88	2026-04-22	Gündüz	480	466	14	1000	818	36	2026-04-29 13:07:02.968+00	\N
2468	88	2026-04-21	Gündüz	480	444	36	1000	955	47	2026-04-29 13:07:02.98+00	\N
2469	88	2026-04-20	Gündüz	480	449	31	1000	964	28	2026-04-29 13:07:02.992+00	\N
2470	88	2026-04-19	Gündüz	480	436	44	1000	808	26	2026-04-29 13:07:03.007+00	\N
2471	88	2026-04-18	Gündüz	480	430	50	1000	807	28	2026-04-29 13:07:03.021+00	\N
2472	88	2026-04-17	Gündüz	480	475	5	1000	942	14	2026-04-29 13:07:03.035+00	\N
2473	88	2026-04-16	Gündüz	480	442	38	1000	833	14	2026-04-29 13:07:03.047+00	\N
2474	88	2026-04-15	Gündüz	480	454	26	1000	812	24	2026-04-29 13:07:03.06+00	\N
2475	88	2026-04-14	Gündüz	480	465	15	1000	803	8	2026-04-29 13:07:03.074+00	\N
2476	88	2026-04-13	Gündüz	480	421	59	1000	923	26	2026-04-29 13:07:03.089+00	\N
2477	88	2026-04-12	Gündüz	480	446	34	1000	973	31	2026-04-29 13:07:03.103+00	\N
2478	88	2026-04-11	Gündüz	480	459	21	1000	897	11	2026-04-29 13:07:03.118+00	\N
2479	88	2026-04-10	Gündüz	480	450	30	1000	925	14	2026-04-29 13:07:03.134+00	\N
2480	88	2026-04-09	Gündüz	480	430	50	1000	847	27	2026-04-29 13:07:03.149+00	\N
2481	88	2026-04-08	Gündüz	480	452	28	1000	945	16	2026-04-29 13:07:03.164+00	\N
2482	88	2026-04-07	Gündüz	480	444	36	1000	908	32	2026-04-29 13:07:03.178+00	\N
2483	88	2026-04-06	Gündüz	480	478	2	1000	932	11	2026-04-29 13:07:03.194+00	\N
2484	88	2026-04-05	Gündüz	480	431	49	1000	914	19	2026-04-29 13:07:03.209+00	\N
2485	88	2026-04-04	Gündüz	480	440	40	1000	815	39	2026-04-29 13:07:03.223+00	\N
2486	88	2026-04-03	Gündüz	480	446	34	1000	889	36	2026-04-29 13:07:03.234+00	\N
2487	88	2026-04-02	Gündüz	480	467	13	1000	930	31	2026-04-29 13:07:03.244+00	\N
2488	88	2026-04-01	Gündüz	480	430	50	1000	962	17	2026-04-29 13:07:03.254+00	\N
2489	88	2026-03-31	Gündüz	480	422	58	1000	909	43	2026-04-29 13:07:03.266+00	\N
2490	88	2026-03-30	Gündüz	480	442	38	1000	898	10	2026-04-29 13:07:03.278+00	\N
2491	89	2026-04-28	Gündüz	480	428	52	1000	802	20	2026-04-29 13:07:03.292+00	\N
2492	89	2026-04-27	Gündüz	480	422	58	1000	814	28	2026-04-29 13:07:03.306+00	\N
2493	89	2026-04-26	Gündüz	480	473	7	1000	850	17	2026-04-29 13:07:03.32+00	\N
2494	89	2026-04-25	Gündüz	480	471	9	1000	826	23	2026-04-29 13:07:03.334+00	\N
2495	89	2026-04-24	Gündüz	480	461	19	1000	928	31	2026-04-29 13:07:03.348+00	\N
2496	89	2026-04-23	Gündüz	480	438	42	1000	957	16	2026-04-29 13:07:03.363+00	\N
2497	89	2026-04-22	Gündüz	480	466	14	1000	934	16	2026-04-29 13:07:03.377+00	\N
2498	89	2026-04-21	Gündüz	480	439	41	1000	812	22	2026-04-29 13:07:03.391+00	\N
2499	89	2026-04-20	Gündüz	480	432	48	1000	850	27	2026-04-29 13:07:03.403+00	\N
2500	89	2026-04-19	Gündüz	480	435	45	1000	814	34	2026-04-29 13:07:03.417+00	\N
2501	89	2026-04-18	Gündüz	480	429	51	1000	857	23	2026-04-29 13:07:03.43+00	\N
2502	89	2026-04-17	Gündüz	480	477	3	1000	887	33	2026-04-29 13:07:03.442+00	\N
2503	89	2026-04-16	Gündüz	480	455	25	1000	822	19	2026-04-29 13:07:03.456+00	\N
2504	89	2026-04-15	Gündüz	480	457	23	1000	893	33	2026-04-29 13:07:03.471+00	\N
2505	89	2026-04-14	Gündüz	480	466	14	1000	842	32	2026-04-29 13:07:03.485+00	\N
2506	89	2026-04-13	Gündüz	480	428	52	1000	866	20	2026-04-29 13:07:03.498+00	\N
2507	89	2026-04-12	Gündüz	480	445	35	1000	817	10	2026-04-29 13:07:03.514+00	\N
2508	89	2026-04-11	Gündüz	480	462	18	1000	954	36	2026-04-29 13:07:03.529+00	\N
2509	89	2026-04-10	Gündüz	480	467	13	1000	965	41	2026-04-29 13:07:03.544+00	\N
2510	89	2026-04-09	Gündüz	480	429	51	1000	848	28	2026-04-29 13:07:03.559+00	\N
2511	89	2026-04-08	Gündüz	480	435	45	1000	923	23	2026-04-29 13:07:03.571+00	\N
2512	89	2026-04-07	Gündüz	480	438	42	1000	820	25	2026-04-29 13:07:03.581+00	\N
2513	89	2026-04-06	Gündüz	480	426	54	1000	894	13	2026-04-29 13:07:03.591+00	\N
2514	89	2026-04-05	Gündüz	480	467	13	1000	827	31	2026-04-29 13:07:03.601+00	\N
2515	89	2026-04-04	Gündüz	480	428	52	1000	860	23	2026-04-29 13:07:03.611+00	\N
2516	89	2026-04-03	Gündüz	480	423	57	1000	859	13	2026-04-29 13:07:03.62+00	\N
2517	89	2026-04-02	Gündüz	480	438	42	1000	934	15	2026-04-29 13:07:03.63+00	\N
2518	89	2026-04-01	Gündüz	480	447	33	1000	848	24	2026-04-29 13:07:03.641+00	\N
2519	89	2026-03-31	Gündüz	480	452	28	1000	835	29	2026-04-29 13:07:03.654+00	\N
2520	89	2026-03-30	Gündüz	480	459	21	1000	848	25	2026-04-29 13:07:03.667+00	\N
2521	90	2026-04-28	Gündüz	480	455	25	1000	942	31	2026-04-29 13:07:03.681+00	\N
2522	90	2026-04-27	Gündüz	480	480	0	1000	808	32	2026-04-29 13:07:03.696+00	\N
2523	90	2026-04-26	Gündüz	480	440	40	1000	877	9	2026-04-29 13:07:03.706+00	\N
2524	90	2026-04-25	Gündüz	480	426	54	1000	817	29	2026-04-29 13:07:03.721+00	\N
2525	90	2026-04-24	Gündüz	480	451	29	1000	929	36	2026-04-29 13:07:03.739+00	\N
2526	90	2026-04-23	Gündüz	480	443	37	1000	873	10	2026-04-29 13:07:03.754+00	\N
2527	90	2026-04-22	Gündüz	480	452	28	1000	949	19	2026-04-29 13:07:03.767+00	\N
2528	90	2026-04-21	Gündüz	480	477	3	1000	960	20	2026-04-29 13:07:03.777+00	\N
2529	90	2026-04-20	Gündüz	480	461	19	1000	821	30	2026-04-29 13:07:03.787+00	\N
2530	90	2026-04-19	Gündüz	480	474	6	1000	802	19	2026-04-29 13:07:03.797+00	\N
2531	90	2026-04-18	Gündüz	480	457	23	1000	927	9	2026-04-29 13:07:03.807+00	\N
2532	90	2026-04-17	Gündüz	480	433	47	1000	847	20	2026-04-29 13:07:03.82+00	\N
2533	90	2026-04-16	Gündüz	480	473	7	1000	883	35	2026-04-29 13:07:03.833+00	\N
2534	90	2026-04-15	Gündüz	480	434	46	1000	819	8	2026-04-29 13:07:03.846+00	\N
2535	90	2026-04-14	Gündüz	480	470	10	1000	837	35	2026-04-29 13:07:03.859+00	\N
2536	90	2026-04-13	Gündüz	480	476	4	1000	917	41	2026-04-29 13:07:03.874+00	\N
2537	90	2026-04-12	Gündüz	480	468	12	1000	862	22	2026-04-29 13:07:03.886+00	\N
2538	90	2026-04-11	Gündüz	480	470	10	1000	872	34	2026-04-29 13:07:03.898+00	\N
2539	90	2026-04-10	Gündüz	480	444	36	1000	910	21	2026-04-29 13:07:03.913+00	\N
2540	90	2026-04-09	Gündüz	480	466	14	1000	821	34	2026-04-29 13:07:03.927+00	\N
2541	90	2026-04-08	Gündüz	480	471	9	1000	881	35	2026-04-29 13:07:03.943+00	\N
2542	90	2026-04-07	Gündüz	480	459	21	1000	938	25	2026-04-29 13:07:03.956+00	\N
2543	90	2026-04-06	Gündüz	480	422	58	1000	898	12	2026-04-29 13:07:03.965+00	\N
2544	90	2026-04-05	Gündüz	480	460	20	1000	906	18	2026-04-29 13:07:03.976+00	\N
2545	90	2026-04-04	Gündüz	480	451	29	1000	846	32	2026-04-29 13:07:03.987+00	\N
2546	90	2026-04-03	Gündüz	480	474	6	1000	891	41	2026-04-29 13:07:04+00	\N
2547	90	2026-04-02	Gündüz	480	473	7	1000	864	32	2026-04-29 13:07:04.013+00	\N
2548	90	2026-04-01	Gündüz	480	479	1	1000	885	9	2026-04-29 13:07:04.025+00	\N
2549	90	2026-03-31	Gündüz	480	458	22	1000	858	21	2026-04-29 13:07:04.038+00	\N
2550	90	2026-03-30	Gündüz	480	439	41	1000	925	35	2026-04-29 13:07:04.05+00	\N
2551	91	2026-04-28	Gündüz	480	471	9	1000	806	32	2026-04-29 13:07:04.062+00	\N
2552	91	2026-04-27	Gündüz	480	433	47	1000	927	37	2026-04-29 13:07:04.074+00	\N
2553	91	2026-04-26	Gündüz	480	464	16	1000	850	22	2026-04-29 13:07:04.088+00	\N
2554	91	2026-04-25	Gündüz	480	438	42	1000	943	17	2026-04-29 13:07:04.101+00	\N
2555	91	2026-04-24	Gündüz	480	424	56	1000	862	10	2026-04-29 13:07:04.113+00	\N
2556	91	2026-04-23	Gündüz	480	433	47	1000	897	39	2026-04-29 13:07:04.126+00	\N
2557	91	2026-04-22	Gündüz	480	478	2	1000	964	42	2026-04-29 13:07:04.138+00	\N
2558	91	2026-04-21	Gündüz	480	432	48	1000	871	21	2026-04-29 13:07:04.151+00	\N
2559	91	2026-04-20	Gündüz	480	470	10	1000	849	9	2026-04-29 13:07:04.164+00	\N
2560	91	2026-04-19	Gündüz	480	476	4	1000	967	36	2026-04-29 13:07:04.178+00	\N
2561	91	2026-04-18	Gündüz	480	440	40	1000	852	31	2026-04-29 13:07:04.193+00	\N
2562	91	2026-04-17	Gündüz	480	444	36	1000	834	21	2026-04-29 13:07:04.207+00	\N
2563	91	2026-04-16	Gündüz	480	454	26	1000	872	14	2026-04-29 13:07:04.223+00	\N
2564	91	2026-04-15	Gündüz	480	465	15	1000	951	43	2026-04-29 13:07:04.239+00	\N
2565	91	2026-04-14	Gündüz	480	435	45	1000	895	19	2026-04-29 13:07:04.252+00	\N
2566	91	2026-04-13	Gündüz	480	475	5	1000	812	24	2026-04-29 13:07:04.265+00	\N
2567	91	2026-04-12	Gündüz	480	427	53	1000	935	34	2026-04-29 13:07:04.279+00	\N
2568	91	2026-04-11	Gündüz	480	472	8	1000	939	12	2026-04-29 13:07:04.294+00	\N
2569	91	2026-04-10	Gündüz	480	463	17	1000	811	22	2026-04-29 13:07:04.312+00	\N
2570	91	2026-04-09	Gündüz	480	428	52	1000	853	10	2026-04-29 13:07:04.327+00	\N
2571	91	2026-04-08	Gündüz	480	471	9	1000	924	22	2026-04-29 13:07:04.341+00	\N
2572	91	2026-04-07	Gündüz	480	432	48	1000	842	29	2026-04-29 13:07:04.357+00	\N
2573	91	2026-04-06	Gündüz	480	459	21	1000	860	13	2026-04-29 13:07:04.374+00	\N
2574	91	2026-04-05	Gündüz	480	471	9	1000	837	16	2026-04-29 13:07:04.39+00	\N
2575	91	2026-04-04	Gündüz	480	458	22	1000	813	9	2026-04-29 13:07:04.405+00	\N
2576	91	2026-04-03	Gündüz	480	420	60	1000	834	24	2026-04-29 13:07:04.42+00	\N
2577	91	2026-04-02	Gündüz	480	458	22	1000	940	25	2026-04-29 13:07:04.434+00	\N
2578	91	2026-04-01	Gündüz	480	466	14	1000	827	20	2026-04-29 13:07:04.45+00	\N
2579	91	2026-03-31	Gündüz	480	437	43	1000	939	33	2026-04-29 13:07:04.464+00	\N
2580	91	2026-03-30	Gündüz	480	438	42	1000	906	38	2026-04-29 13:07:04.48+00	\N
2581	92	2026-04-28	Gündüz	480	428	52	1000	813	29	2026-04-29 13:07:04.495+00	\N
2582	92	2026-04-27	Gündüz	480	440	40	1000	893	20	2026-04-29 13:07:04.51+00	\N
2583	92	2026-04-26	Gündüz	480	430	50	1000	909	30	2026-04-29 13:07:04.524+00	\N
2584	92	2026-04-25	Gündüz	480	462	18	1000	941	36	2026-04-29 13:07:04.54+00	\N
2585	92	2026-04-24	Gündüz	480	460	20	1000	965	36	2026-04-29 13:07:04.554+00	\N
2586	92	2026-04-23	Gündüz	480	459	21	1000	908	19	2026-04-29 13:07:04.569+00	\N
2587	92	2026-04-22	Gündüz	480	455	25	1000	844	33	2026-04-29 13:07:04.584+00	\N
2588	92	2026-04-21	Gündüz	480	426	54	1000	819	25	2026-04-29 13:07:04.599+00	\N
2589	92	2026-04-20	Gündüz	480	444	36	1000	906	28	2026-04-29 13:07:04.615+00	\N
2590	92	2026-04-19	Gündüz	480	451	29	1000	816	14	2026-04-29 13:07:04.63+00	\N
2591	92	2026-04-18	Gündüz	480	444	36	1000	947	12	2026-04-29 13:07:04.645+00	\N
2592	92	2026-04-17	Gündüz	480	472	8	1000	868	30	2026-04-29 13:07:04.66+00	\N
2593	92	2026-04-16	Gündüz	480	434	46	1000	876	9	2026-04-29 13:07:04.674+00	\N
2594	92	2026-04-15	Gündüz	480	441	39	1000	924	15	2026-04-29 13:07:04.689+00	\N
2595	92	2026-04-14	Gündüz	480	451	29	1000	925	39	2026-04-29 13:07:04.705+00	\N
2596	92	2026-04-13	Gündüz	480	429	51	1000	898	36	2026-04-29 13:07:04.72+00	\N
2597	92	2026-04-12	Gündüz	480	424	56	1000	840	18	2026-04-29 13:07:04.736+00	\N
2598	92	2026-04-11	Gündüz	480	421	59	1000	824	27	2026-04-29 13:07:04.75+00	\N
2599	92	2026-04-10	Gündüz	480	446	34	1000	935	44	2026-04-29 13:07:04.762+00	\N
2600	92	2026-04-09	Gündüz	480	474	6	1000	804	20	2026-04-29 13:07:04.776+00	\N
2601	92	2026-04-08	Gündüz	480	439	41	1000	890	34	2026-04-29 13:07:04.79+00	\N
2602	92	2026-04-07	Gündüz	480	446	34	1000	858	39	2026-04-29 13:07:04.807+00	\N
2603	92	2026-04-06	Gündüz	480	465	15	1000	952	16	2026-04-29 13:07:04.822+00	\N
2604	92	2026-04-05	Gündüz	480	420	60	1000	882	34	2026-04-29 13:07:04.837+00	\N
2605	92	2026-04-04	Gündüz	480	423	57	1000	804	37	2026-04-29 13:07:04.858+00	\N
2606	92	2026-04-03	Gündüz	480	458	22	1000	875	14	2026-04-29 13:07:04.875+00	\N
2607	92	2026-04-02	Gündüz	480	474	6	1000	969	18	2026-04-29 13:07:04.891+00	\N
2608	92	2026-04-01	Gündüz	480	426	54	1000	899	21	2026-04-29 13:07:04.908+00	\N
2609	92	2026-03-31	Gündüz	480	473	7	1000	811	18	2026-04-29 13:07:04.923+00	\N
2610	92	2026-03-30	Gündüz	480	468	12	1000	872	20	2026-04-29 13:07:04.939+00	\N
2611	93	2026-04-28	Gündüz	480	467	13	1000	940	45	2026-04-29 13:07:04.955+00	\N
2612	93	2026-04-27	Gündüz	480	466	14	1000	859	33	2026-04-29 13:07:04.973+00	\N
2613	93	2026-04-26	Gündüz	480	422	58	1000	936	13	2026-04-29 13:07:04.996+00	\N
2614	93	2026-04-25	Gündüz	480	462	18	1000	831	24	2026-04-29 13:07:05.011+00	\N
2615	93	2026-04-24	Gündüz	480	455	25	1000	815	12	2026-04-29 13:07:05.025+00	\N
2616	93	2026-04-23	Gündüz	480	474	6	1000	890	28	2026-04-29 13:07:05.041+00	\N
2617	93	2026-04-22	Gündüz	480	477	3	1000	940	31	2026-04-29 13:07:05.054+00	\N
2618	93	2026-04-21	Gündüz	480	472	8	1000	926	24	2026-04-29 13:07:05.067+00	\N
2619	93	2026-04-20	Gündüz	480	448	32	1000	944	44	2026-04-29 13:07:05.079+00	\N
2620	93	2026-04-19	Gündüz	480	458	22	1000	915	25	2026-04-29 13:07:05.092+00	\N
2621	93	2026-04-18	Gündüz	480	460	20	1000	878	38	2026-04-29 13:07:05.105+00	\N
2622	93	2026-04-17	Gündüz	480	444	36	1000	858	12	2026-04-29 13:07:05.118+00	\N
2623	93	2026-04-16	Gündüz	480	451	29	1000	871	27	2026-04-29 13:07:05.129+00	\N
2624	93	2026-04-15	Gündüz	480	442	38	1000	911	22	2026-04-29 13:07:05.139+00	\N
2625	93	2026-04-14	Gündüz	480	434	46	1000	953	30	2026-04-29 13:07:05.151+00	\N
2626	93	2026-04-13	Gündüz	480	475	5	1000	964	22	2026-04-29 13:07:05.165+00	\N
2627	93	2026-04-12	Gündüz	480	421	59	1000	933	39	2026-04-29 13:07:05.188+00	\N
2628	93	2026-04-11	Gündüz	480	478	2	1000	934	24	2026-04-29 13:07:05.2+00	\N
2629	93	2026-04-10	Gündüz	480	472	8	1000	979	30	2026-04-29 13:07:05.224+00	\N
2630	93	2026-04-09	Gündüz	480	479	1	1000	896	10	2026-04-29 13:07:05.247+00	\N
2631	93	2026-04-08	Gündüz	480	434	46	1000	950	14	2026-04-29 13:07:05.261+00	\N
2632	93	2026-04-07	Gündüz	480	463	17	1000	871	22	2026-04-29 13:07:05.274+00	\N
2633	93	2026-04-06	Gündüz	480	451	29	1000	964	24	2026-04-29 13:07:05.289+00	\N
2634	93	2026-04-05	Gündüz	480	440	40	1000	963	45	2026-04-29 13:07:05.304+00	\N
2635	93	2026-04-04	Gündüz	480	424	56	1000	842	37	2026-04-29 13:07:05.323+00	\N
2636	93	2026-04-03	Gündüz	480	454	26	1000	856	26	2026-04-29 13:07:05.339+00	\N
2637	93	2026-04-02	Gündüz	480	440	40	1000	967	30	2026-04-29 13:07:05.357+00	\N
2638	93	2026-04-01	Gündüz	480	441	39	1000	820	32	2026-04-29 13:07:05.375+00	\N
2639	93	2026-03-31	Gündüz	480	434	46	1000	940	25	2026-04-29 13:07:05.39+00	\N
2640	93	2026-03-30	Gündüz	480	436	44	1000	811	29	2026-04-29 13:07:05.408+00	\N
2641	94	2026-04-28	Gündüz	480	421	59	1000	812	19	2026-04-29 13:07:05.426+00	\N
2642	94	2026-04-27	Gündüz	480	457	23	1000	804	34	2026-04-29 13:07:05.444+00	\N
2643	94	2026-04-26	Gündüz	480	439	41	1000	969	43	2026-04-29 13:07:05.461+00	\N
2644	94	2026-04-25	Gündüz	480	425	55	1000	816	14	2026-04-29 13:07:05.477+00	\N
2645	94	2026-04-24	Gündüz	480	456	24	1000	860	34	2026-04-29 13:07:05.495+00	\N
2646	94	2026-04-23	Gündüz	480	446	34	1000	958	22	2026-04-29 13:07:05.512+00	\N
2647	94	2026-04-22	Gündüz	480	443	37	1000	917	21	2026-04-29 13:07:05.528+00	\N
2648	94	2026-04-21	Gündüz	480	426	54	1000	941	41	2026-04-29 13:07:05.544+00	\N
2649	94	2026-04-20	Gündüz	480	477	3	1000	908	33	2026-04-29 13:07:05.563+00	\N
2650	94	2026-04-19	Gündüz	480	440	40	1000	948	27	2026-04-29 13:07:05.583+00	\N
2651	94	2026-04-18	Gündüz	480	445	35	1000	881	21	2026-04-29 13:07:05.602+00	\N
2652	94	2026-04-17	Gündüz	480	463	17	1000	977	30	2026-04-29 13:07:05.622+00	\N
2653	94	2026-04-16	Gündüz	480	454	26	1000	840	37	2026-04-29 13:07:05.643+00	\N
2654	94	2026-04-15	Gündüz	480	457	23	1000	800	14	2026-04-29 13:07:05.665+00	\N
2655	94	2026-04-14	Gündüz	480	460	20	1000	952	19	2026-04-29 13:07:05.685+00	\N
2656	94	2026-04-13	Gündüz	480	456	24	1000	835	26	2026-04-29 13:07:05.706+00	\N
2657	94	2026-04-12	Gündüz	480	429	51	1000	979	43	2026-04-29 13:07:05.727+00	\N
2658	94	2026-04-11	Gündüz	480	466	14	1000	862	38	2026-04-29 13:07:05.744+00	\N
2659	94	2026-04-10	Gündüz	480	439	41	1000	882	34	2026-04-29 13:07:05.761+00	\N
2660	94	2026-04-09	Gündüz	480	446	34	1000	836	39	2026-04-29 13:07:05.78+00	\N
2661	94	2026-04-08	Gündüz	480	467	13	1000	858	27	2026-04-29 13:07:05.797+00	\N
2662	94	2026-04-07	Gündüz	480	464	16	1000	812	23	2026-04-29 13:07:05.817+00	\N
2663	94	2026-04-06	Gündüz	480	457	23	1000	820	34	2026-04-29 13:07:05.837+00	\N
2664	94	2026-04-05	Gündüz	480	458	22	1000	827	19	2026-04-29 13:07:05.855+00	\N
2665	94	2026-04-04	Gündüz	480	448	32	1000	913	15	2026-04-29 13:07:05.875+00	\N
2666	94	2026-04-03	Gündüz	480	460	20	1000	879	41	2026-04-29 13:07:05.894+00	\N
2667	94	2026-04-02	Gündüz	480	463	17	1000	811	12	2026-04-29 13:07:05.914+00	\N
2668	94	2026-04-01	Gündüz	480	472	8	1000	974	38	2026-04-29 13:07:05.934+00	\N
2669	94	2026-03-31	Gündüz	480	455	25	1000	964	12	2026-04-29 13:07:05.954+00	\N
2670	94	2026-03-30	Gündüz	480	437	43	1000	849	34	2026-04-29 13:07:05.973+00	\N
2671	95	2026-04-28	Gündüz	480	480	0	1000	800	15	2026-04-29 13:07:05.992+00	\N
2672	95	2026-04-27	Gündüz	480	466	14	1000	830	26	2026-04-29 13:07:06.004+00	\N
2673	95	2026-04-26	Gündüz	480	425	55	1000	902	30	2026-04-29 13:07:06.025+00	\N
2674	95	2026-04-25	Gündüz	480	457	23	1000	949	39	2026-04-29 13:07:06.046+00	\N
2675	95	2026-04-24	Gündüz	480	461	19	1000	818	23	2026-04-29 13:07:06.065+00	\N
2676	95	2026-04-23	Gündüz	480	421	59	1000	900	11	2026-04-29 13:07:06.084+00	\N
2677	95	2026-04-22	Gündüz	480	429	51	1000	815	11	2026-04-29 13:07:06.105+00	\N
2678	95	2026-04-21	Gündüz	480	425	55	1000	832	11	2026-04-29 13:07:06.125+00	\N
2679	95	2026-04-20	Gündüz	480	448	32	1000	840	36	2026-04-29 13:07:06.144+00	\N
2680	95	2026-04-19	Gündüz	480	439	41	1000	851	11	2026-04-29 13:07:06.164+00	\N
2681	95	2026-04-18	Gündüz	480	426	54	1000	876	14	2026-04-29 13:07:06.184+00	\N
2682	95	2026-04-17	Gündüz	480	474	6	1000	951	9	2026-04-29 13:07:06.203+00	\N
2683	95	2026-04-16	Gündüz	480	473	7	1000	907	41	2026-04-29 13:07:06.222+00	\N
2684	95	2026-04-15	Gündüz	480	476	4	1000	820	15	2026-04-29 13:07:06.241+00	\N
2685	95	2026-04-14	Gündüz	480	435	45	1000	854	13	2026-04-29 13:07:06.256+00	\N
2686	95	2026-04-13	Gündüz	480	455	25	1000	884	13	2026-04-29 13:07:06.275+00	\N
2687	95	2026-04-12	Gündüz	480	425	55	1000	869	38	2026-04-29 13:07:06.293+00	\N
2688	95	2026-04-11	Gündüz	480	477	3	1000	923	9	2026-04-29 13:07:06.309+00	\N
2689	95	2026-04-10	Gündüz	480	422	58	1000	875	11	2026-04-29 13:07:06.327+00	\N
2690	95	2026-04-09	Gündüz	480	480	0	1000	838	12	2026-04-29 13:07:06.345+00	\N
2691	95	2026-04-08	Gündüz	480	452	28	1000	853	18	2026-04-29 13:07:06.358+00	\N
2692	95	2026-04-07	Gündüz	480	426	54	1000	806	14	2026-04-29 13:07:06.378+00	\N
2693	95	2026-04-06	Gündüz	480	459	21	1000	932	23	2026-04-29 13:07:06.398+00	\N
2694	95	2026-04-05	Gündüz	480	460	20	1000	827	17	2026-04-29 13:07:06.416+00	\N
2695	95	2026-04-04	Gündüz	480	449	31	1000	884	39	2026-04-29 13:07:06.437+00	\N
2696	95	2026-04-03	Gündüz	480	436	44	1000	832	37	2026-04-29 13:07:06.456+00	\N
2697	95	2026-04-02	Gündüz	480	436	44	1000	803	10	2026-04-29 13:07:06.477+00	\N
2698	95	2026-04-01	Gündüz	480	462	18	1000	809	22	2026-04-29 13:07:06.498+00	\N
2699	95	2026-03-31	Gündüz	480	431	49	1000	900	11	2026-04-29 13:07:06.518+00	\N
2700	95	2026-03-30	Gündüz	480	471	9	1000	974	19	2026-04-29 13:07:06.538+00	\N
2701	96	2026-04-28	Gündüz	480	442	38	1000	830	36	2026-04-29 13:07:06.558+00	\N
2702	96	2026-04-27	Gündüz	480	451	29	1000	905	13	2026-04-29 13:07:06.577+00	\N
2703	96	2026-04-26	Gündüz	480	478	2	1000	960	33	2026-04-29 13:07:06.595+00	\N
2704	96	2026-04-25	Gündüz	480	451	29	1000	880	19	2026-04-29 13:07:06.618+00	\N
2705	96	2026-04-24	Gündüz	480	423	57	1000	839	11	2026-04-29 13:07:06.643+00	\N
2706	96	2026-04-23	Gündüz	480	476	4	1000	934	33	2026-04-29 13:07:06.662+00	\N
2707	96	2026-04-22	Gündüz	480	467	13	1000	811	28	2026-04-29 13:07:06.681+00	\N
2708	96	2026-04-21	Gündüz	480	474	6	1000	896	23	2026-04-29 13:07:06.779+00	\N
2709	96	2026-04-20	Gündüz	480	458	22	1000	857	38	2026-04-29 13:07:06.806+00	\N
2710	96	2026-04-19	Gündüz	480	456	24	1000	957	16	2026-04-29 13:07:06.82+00	\N
2711	96	2026-04-18	Gündüz	480	474	6	1000	894	17	2026-04-29 13:07:06.834+00	\N
2712	96	2026-04-17	Gündüz	480	439	41	1000	856	12	2026-04-29 13:07:06.848+00	\N
2713	96	2026-04-16	Gündüz	480	437	43	1000	862	17	2026-04-29 13:07:06.866+00	\N
2714	96	2026-04-15	Gündüz	480	436	44	1000	881	17	2026-04-29 13:07:06.884+00	\N
2715	96	2026-04-14	Gündüz	480	474	6	1000	829	20	2026-04-29 13:07:06.901+00	\N
2716	96	2026-04-13	Gündüz	480	442	38	1000	948	39	2026-04-29 13:07:06.918+00	\N
2717	96	2026-04-12	Gündüz	480	433	47	1000	836	14	2026-04-29 13:07:06.937+00	\N
2718	96	2026-04-11	Gündüz	480	456	24	1000	882	28	2026-04-29 13:07:06.954+00	\N
2719	96	2026-04-10	Gündüz	480	447	33	1000	885	44	2026-04-29 13:07:06.971+00	\N
2720	96	2026-04-09	Gündüz	480	463	17	1000	886	37	2026-04-29 13:07:06.988+00	\N
2721	96	2026-04-08	Gündüz	480	451	29	1000	800	32	2026-04-29 13:07:07.004+00	\N
2722	96	2026-04-07	Gündüz	480	445	35	1000	922	27	2026-04-29 13:07:07.021+00	\N
2723	96	2026-04-06	Gündüz	480	436	44	1000	955	39	2026-04-29 13:07:07.037+00	\N
2724	96	2026-04-05	Gündüz	480	438	42	1000	919	28	2026-04-29 13:07:07.052+00	\N
2725	96	2026-04-04	Gündüz	480	450	30	1000	814	26	2026-04-29 13:07:07.067+00	\N
2726	96	2026-04-03	Gündüz	480	478	2	1000	841	9	2026-04-29 13:07:07.082+00	\N
2727	96	2026-04-02	Gündüz	480	480	0	1000	849	14	2026-04-29 13:07:07.098+00	\N
2728	96	2026-04-01	Gündüz	480	458	22	1000	875	17	2026-04-29 13:07:07.111+00	\N
2729	96	2026-03-31	Gündüz	480	466	14	1000	837	25	2026-04-29 13:07:07.127+00	\N
2730	96	2026-03-30	Gündüz	480	473	7	1000	939	27	2026-04-29 13:07:07.145+00	\N
2731	97	2026-04-28	Gündüz	480	455	25	1000	816	12	2026-04-29 13:07:07.16+00	\N
2732	97	2026-04-27	Gündüz	480	473	7	1000	884	43	2026-04-29 13:07:07.176+00	\N
2733	97	2026-04-26	Gündüz	480	429	51	1000	891	37	2026-04-29 13:07:07.194+00	\N
2734	97	2026-04-25	Gündüz	480	479	1	1000	915	28	2026-04-29 13:07:07.212+00	\N
2735	97	2026-04-24	Gündüz	480	449	31	1000	841	33	2026-04-29 13:07:07.229+00	\N
2736	97	2026-04-23	Gündüz	480	447	33	1000	831	11	2026-04-29 13:07:07.245+00	\N
2737	97	2026-04-22	Gündüz	480	433	47	1000	942	32	2026-04-29 13:07:07.26+00	\N
2738	97	2026-04-21	Gündüz	480	451	29	1000	805	14	2026-04-29 13:07:07.298+00	\N
2739	97	2026-04-20	Gündüz	480	440	40	1000	935	42	2026-04-29 13:07:07.319+00	\N
2740	97	2026-04-19	Gündüz	480	437	43	1000	800	17	2026-04-29 13:07:07.339+00	\N
2741	97	2026-04-18	Gündüz	480	472	8	1000	856	8	2026-04-29 13:07:07.359+00	\N
2742	97	2026-04-17	Gündüz	480	450	30	1000	880	36	2026-04-29 13:07:07.379+00	\N
2743	97	2026-04-16	Gündüz	480	469	11	1000	853	42	2026-04-29 13:07:07.399+00	\N
2744	97	2026-04-15	Gündüz	480	449	31	1000	972	11	2026-04-29 13:07:07.418+00	\N
2745	97	2026-04-14	Gündüz	480	449	31	1000	881	30	2026-04-29 13:07:07.437+00	\N
2746	97	2026-04-13	Gündüz	480	428	52	1000	882	33	2026-04-29 13:07:07.457+00	\N
2747	97	2026-04-12	Gündüz	480	460	20	1000	940	43	2026-04-29 13:07:07.476+00	\N
2748	97	2026-04-11	Gündüz	480	444	36	1000	849	16	2026-04-29 13:07:07.497+00	\N
2749	97	2026-04-10	Gündüz	480	439	41	1000	873	9	2026-04-29 13:07:07.517+00	\N
2750	97	2026-04-09	Gündüz	480	464	16	1000	874	40	2026-04-29 13:07:07.537+00	\N
2751	97	2026-04-08	Gündüz	480	438	42	1000	888	15	2026-04-29 13:07:07.556+00	\N
2752	97	2026-04-07	Gündüz	480	462	18	1000	835	19	2026-04-29 13:07:07.575+00	\N
2753	97	2026-04-06	Gündüz	480	434	46	1000	811	8	2026-04-29 13:07:07.594+00	\N
2754	97	2026-04-05	Gündüz	480	465	15	1000	815	8	2026-04-29 13:07:07.615+00	\N
2755	97	2026-04-04	Gündüz	480	467	13	1000	977	27	2026-04-29 13:07:07.636+00	\N
2756	97	2026-04-03	Gündüz	480	475	5	1000	895	23	2026-04-29 13:07:07.657+00	\N
2757	97	2026-04-02	Gündüz	480	460	20	1000	856	34	2026-04-29 13:07:07.678+00	\N
2758	97	2026-04-01	Gündüz	480	455	25	1000	811	26	2026-04-29 13:07:07.698+00	\N
2759	97	2026-03-31	Gündüz	480	420	60	1000	892	36	2026-04-29 13:07:07.718+00	\N
2760	97	2026-03-30	Gündüz	480	468	12	1000	921	14	2026-04-29 13:07:07.736+00	\N
2761	98	2026-04-28	Gündüz	480	459	21	1000	811	34	2026-04-29 13:07:07.75+00	\N
2762	98	2026-04-27	Gündüz	480	469	11	1000	864	22	2026-04-29 13:07:07.763+00	\N
2763	98	2026-04-26	Gündüz	480	422	58	1000	876	37	2026-04-29 13:07:07.779+00	\N
2764	98	2026-04-25	Gündüz	480	426	54	1000	873	28	2026-04-29 13:07:07.796+00	\N
2765	98	2026-04-24	Gündüz	480	474	6	1000	893	34	2026-04-29 13:07:07.813+00	\N
2766	98	2026-04-23	Gündüz	480	426	54	1000	942	32	2026-04-29 13:07:07.83+00	\N
2767	98	2026-04-22	Gündüz	480	470	10	1000	926	9	2026-04-29 13:07:07.846+00	\N
2768	98	2026-04-21	Gündüz	480	443	37	1000	939	35	2026-04-29 13:07:07.858+00	\N
2769	98	2026-04-20	Gündüz	480	467	13	1000	900	41	2026-04-29 13:07:07.869+00	\N
2770	98	2026-04-19	Gündüz	480	469	11	1000	818	29	2026-04-29 13:07:07.883+00	\N
2771	98	2026-04-18	Gündüz	480	441	39	1000	925	9	2026-04-29 13:07:07.899+00	\N
2772	98	2026-04-17	Gündüz	480	433	47	1000	969	13	2026-04-29 13:07:07.915+00	\N
2773	98	2026-04-16	Gündüz	480	429	51	1000	898	44	2026-04-29 13:07:07.931+00	\N
2774	98	2026-04-15	Gündüz	480	442	38	1000	923	38	2026-04-29 13:07:07.946+00	\N
2775	98	2026-04-14	Gündüz	480	477	3	1000	959	19	2026-04-29 13:07:07.959+00	\N
2776	98	2026-04-13	Gündüz	480	480	0	1000	908	25	2026-04-29 13:07:07.971+00	\N
2777	98	2026-04-12	Gündüz	480	428	52	1000	882	29	2026-04-29 13:07:07.979+00	\N
2778	98	2026-04-11	Gündüz	480	456	24	1000	818	12	2026-04-29 13:07:07.99+00	\N
2779	98	2026-04-10	Gündüz	480	438	42	1000	870	32	2026-04-29 13:07:08.001+00	\N
2780	98	2026-04-09	Gündüz	480	477	3	1000	824	19	2026-04-29 13:07:08.012+00	\N
2781	98	2026-04-08	Gündüz	480	452	28	1000	903	34	2026-04-29 13:07:08.024+00	\N
2782	98	2026-04-07	Gündüz	480	437	43	1000	954	20	2026-04-29 13:07:08.037+00	\N
2783	98	2026-04-06	Gündüz	480	453	27	1000	829	34	2026-04-29 13:07:08.05+00	\N
2784	98	2026-04-05	Gündüz	480	462	18	1000	836	22	2026-04-29 13:07:08.068+00	\N
2785	98	2026-04-04	Gündüz	480	438	42	1000	862	31	2026-04-29 13:07:08.087+00	\N
2786	98	2026-04-03	Gündüz	480	428	52	1000	971	15	2026-04-29 13:07:08.108+00	\N
2787	98	2026-04-02	Gündüz	480	458	22	1000	918	21	2026-04-29 13:07:08.129+00	\N
2788	98	2026-04-01	Gündüz	480	450	30	1000	862	10	2026-04-29 13:07:08.15+00	\N
2789	98	2026-03-31	Gündüz	480	423	57	1000	847	30	2026-04-29 13:07:08.168+00	\N
2790	98	2026-03-30	Gündüz	480	469	11	1000	964	23	2026-04-29 13:07:08.182+00	\N
2791	99	2026-04-28	Gündüz	480	435	45	1000	939	18	2026-04-29 13:07:08.195+00	\N
2792	99	2026-04-27	Gündüz	480	434	46	1000	849	29	2026-04-29 13:07:08.208+00	\N
2793	99	2026-04-26	Gündüz	480	464	16	1000	888	43	2026-04-29 13:07:08.221+00	\N
2794	99	2026-04-25	Gündüz	480	435	45	1000	941	43	2026-04-29 13:07:08.235+00	\N
2795	99	2026-04-24	Gündüz	480	446	34	1000	956	36	2026-04-29 13:07:08.246+00	\N
2796	99	2026-04-23	Gündüz	480	447	33	1000	883	41	2026-04-29 13:07:08.257+00	\N
2797	99	2026-04-22	Gündüz	480	468	12	1000	921	21	2026-04-29 13:07:08.27+00	\N
2798	99	2026-04-21	Gündüz	480	444	36	1000	910	43	2026-04-29 13:07:08.279+00	\N
2799	99	2026-04-20	Gündüz	480	478	2	1000	965	38	2026-04-29 13:07:08.289+00	\N
2800	99	2026-04-19	Gündüz	480	471	9	1000	972	35	2026-04-29 13:07:08.299+00	\N
2801	99	2026-04-18	Gündüz	480	465	15	1000	820	8	2026-04-29 13:07:08.308+00	\N
2802	99	2026-04-17	Gündüz	480	434	46	1000	894	13	2026-04-29 13:07:08.317+00	\N
2803	99	2026-04-16	Gündüz	480	451	29	1000	897	41	2026-04-29 13:07:08.326+00	\N
2804	99	2026-04-15	Gündüz	480	480	0	1000	932	33	2026-04-29 13:07:08.335+00	\N
2805	99	2026-04-14	Gündüz	480	427	53	1000	965	36	2026-04-29 13:07:08.341+00	\N
2806	99	2026-04-13	Gündüz	480	467	13	1000	924	31	2026-04-29 13:07:08.35+00	\N
2807	99	2026-04-12	Gündüz	480	466	14	1000	880	17	2026-04-29 13:07:08.359+00	\N
2808	99	2026-04-11	Gündüz	480	441	39	1000	802	13	2026-04-29 13:07:08.369+00	\N
2809	99	2026-04-10	Gündüz	480	467	13	1000	827	18	2026-04-29 13:07:08.378+00	\N
2810	99	2026-04-09	Gündüz	480	439	41	1000	960	27	2026-04-29 13:07:08.387+00	\N
2811	99	2026-04-08	Gündüz	480	475	5	1000	922	17	2026-04-29 13:07:08.396+00	\N
2812	99	2026-04-07	Gündüz	480	460	20	1000	912	16	2026-04-29 13:07:08.405+00	\N
2813	99	2026-04-06	Gündüz	480	441	39	1000	930	18	2026-04-29 13:07:08.415+00	\N
2814	99	2026-04-05	Gündüz	480	466	14	1000	871	23	2026-04-29 13:07:08.424+00	\N
2815	99	2026-04-04	Gündüz	480	471	9	1000	850	36	2026-04-29 13:07:08.433+00	\N
2816	99	2026-04-03	Gündüz	480	434	46	1000	882	40	2026-04-29 13:07:08.443+00	\N
2817	99	2026-04-02	Gündüz	480	441	39	1000	917	19	2026-04-29 13:07:08.452+00	\N
2818	99	2026-04-01	Gündüz	480	438	42	1000	867	31	2026-04-29 13:07:08.461+00	\N
2819	99	2026-03-31	Gündüz	480	460	20	1000	835	14	2026-04-29 13:07:08.47+00	\N
2820	99	2026-03-30	Gündüz	480	476	4	1000	819	16	2026-04-29 13:07:08.479+00	\N
2821	100	2026-04-28	Gündüz	480	439	41	1000	964	32	2026-04-29 13:07:08.489+00	\N
2822	100	2026-04-27	Gündüz	480	439	41	1000	954	26	2026-04-29 13:07:08.498+00	\N
2823	100	2026-04-26	Gündüz	480	471	9	1000	938	38	2026-04-29 13:07:08.507+00	\N
2824	100	2026-04-25	Gündüz	480	454	26	1000	969	43	2026-04-29 13:07:08.515+00	\N
2825	100	2026-04-24	Gündüz	480	448	32	1000	820	19	2026-04-29 13:07:08.524+00	\N
2826	100	2026-04-23	Gündüz	480	452	28	1000	843	21	2026-04-29 13:07:08.533+00	\N
2827	100	2026-04-22	Gündüz	480	480	0	1000	896	43	2026-04-29 13:07:08.542+00	\N
2828	100	2026-04-21	Gündüz	480	447	33	1000	953	32	2026-04-29 13:07:08.549+00	\N
2829	100	2026-04-20	Gündüz	480	460	20	1000	840	11	2026-04-29 13:07:08.559+00	\N
2830	100	2026-04-19	Gündüz	480	469	11	1000	803	8	2026-04-29 13:07:08.572+00	\N
2831	100	2026-04-18	Gündüz	480	435	45	1000	841	20	2026-04-29 13:07:08.584+00	\N
2832	100	2026-04-17	Gündüz	480	441	39	1000	836	38	2026-04-29 13:07:08.598+00	\N
2833	100	2026-04-16	Gündüz	480	463	17	1000	944	31	2026-04-29 13:07:08.609+00	\N
2834	100	2026-04-15	Gündüz	480	439	41	1000	879	17	2026-04-29 13:07:08.622+00	\N
2835	100	2026-04-14	Gündüz	480	433	47	1000	811	36	2026-04-29 13:07:08.637+00	\N
2836	100	2026-04-13	Gündüz	480	479	1	1000	948	10	2026-04-29 13:07:08.651+00	\N
2837	100	2026-04-12	Gündüz	480	470	10	1000	975	16	2026-04-29 13:07:08.664+00	\N
2838	100	2026-04-11	Gündüz	480	433	47	1000	962	27	2026-04-29 13:07:08.677+00	\N
2839	100	2026-04-10	Gündüz	480	446	34	1000	809	25	2026-04-29 13:07:08.689+00	\N
2840	100	2026-04-09	Gündüz	480	470	10	1000	925	24	2026-04-29 13:07:08.702+00	\N
2841	100	2026-04-08	Gündüz	480	451	29	1000	828	23	2026-04-29 13:07:08.713+00	\N
2842	100	2026-04-07	Gündüz	480	442	38	1000	855	41	2026-04-29 13:07:08.724+00	\N
2843	100	2026-04-06	Gündüz	480	432	48	1000	844	39	2026-04-29 13:07:08.735+00	\N
2844	100	2026-04-05	Gündüz	480	421	59	1000	861	32	2026-04-29 13:07:08.747+00	\N
2845	100	2026-04-04	Gündüz	480	465	15	1000	881	29	2026-04-29 13:07:08.759+00	\N
2846	100	2026-04-03	Gündüz	480	430	50	1000	813	31	2026-04-29 13:07:08.777+00	\N
2847	100	2026-04-02	Gündüz	480	457	23	1000	916	16	2026-04-29 13:07:08.792+00	\N
2848	100	2026-04-01	Gündüz	480	435	45	1000	900	9	2026-04-29 13:07:08.804+00	\N
2849	100	2026-03-31	Gündüz	480	464	16	1000	865	30	2026-04-29 13:07:08.816+00	\N
2850	100	2026-03-30	Gündüz	480	466	14	1000	910	28	2026-04-29 13:07:08.829+00	\N
2851	101	2026-04-28	Gündüz	480	427	53	1000	824	39	2026-04-29 13:07:08.845+00	\N
2852	101	2026-04-27	Gündüz	480	447	33	1000	926	40	2026-04-29 13:07:08.86+00	\N
2853	101	2026-04-26	Gündüz	480	438	42	1000	968	25	2026-04-29 13:07:08.873+00	\N
2854	101	2026-04-25	Gündüz	480	439	41	1000	863	19	2026-04-29 13:07:08.886+00	\N
2855	101	2026-04-24	Gündüz	480	450	30	1000	801	16	2026-04-29 13:07:08.898+00	\N
2856	101	2026-04-23	Gündüz	480	427	53	1000	838	14	2026-04-29 13:07:08.91+00	\N
2857	101	2026-04-22	Gündüz	480	431	49	1000	918	42	2026-04-29 13:07:08.929+00	\N
2858	101	2026-04-21	Gündüz	480	459	21	1000	948	38	2026-04-29 13:07:08.942+00	\N
2859	101	2026-04-20	Gündüz	480	445	35	1000	969	10	2026-04-29 13:07:08.953+00	\N
2860	101	2026-04-19	Gündüz	480	443	37	1000	854	17	2026-04-29 13:07:08.965+00	\N
2861	101	2026-04-18	Gündüz	480	421	59	1000	801	20	2026-04-29 13:07:08.976+00	\N
2862	101	2026-04-17	Gündüz	480	440	40	1000	875	28	2026-04-29 13:07:08.986+00	\N
2863	101	2026-04-16	Gündüz	480	443	37	1000	873	27	2026-04-29 13:07:08.997+00	\N
2864	101	2026-04-15	Gündüz	480	457	23	1000	917	43	2026-04-29 13:07:09.008+00	\N
2865	101	2026-04-14	Gündüz	480	453	27	1000	869	33	2026-04-29 13:07:09.019+00	\N
2866	101	2026-04-13	Gündüz	480	428	52	1000	818	35	2026-04-29 13:07:09.033+00	\N
2867	101	2026-04-12	Gündüz	480	432	48	1000	861	36	2026-04-29 13:07:09.05+00	\N
2868	101	2026-04-11	Gündüz	480	435	45	1000	835	28	2026-04-29 13:07:09.067+00	\N
2869	101	2026-04-10	Gündüz	480	466	14	1000	931	33	2026-04-29 13:07:09.085+00	\N
2870	101	2026-04-09	Gündüz	480	438	42	1000	929	26	2026-04-29 13:07:09.103+00	\N
2871	101	2026-04-08	Gündüz	480	444	36	1000	931	25	2026-04-29 13:07:09.121+00	\N
2872	101	2026-04-07	Gündüz	480	436	44	1000	851	26	2026-04-29 13:07:09.138+00	\N
2873	101	2026-04-06	Gündüz	480	457	23	1000	841	19	2026-04-29 13:07:09.157+00	\N
2874	101	2026-04-05	Gündüz	480	471	9	1000	922	20	2026-04-29 13:07:09.174+00	\N
2875	101	2026-04-04	Gündüz	480	424	56	1000	844	16	2026-04-29 13:07:09.191+00	\N
2876	101	2026-04-03	Gündüz	480	466	14	1000	892	38	2026-04-29 13:07:09.205+00	\N
2877	101	2026-04-02	Gündüz	480	421	59	1000	958	22	2026-04-29 13:07:09.216+00	\N
2878	101	2026-04-01	Gündüz	480	431	49	1000	857	12	2026-04-29 13:07:09.227+00	\N
2879	101	2026-03-31	Gündüz	480	445	35	1000	921	42	2026-04-29 13:07:09.237+00	\N
2880	101	2026-03-30	Gündüz	480	480	0	1000	840	38	2026-04-29 13:07:09.247+00	\N
2881	102	2026-04-28	Gündüz	480	478	2	1000	917	10	2026-04-29 13:07:09.253+00	\N
2882	102	2026-04-27	Gündüz	480	422	58	1000	875	30	2026-04-29 13:07:09.262+00	\N
2883	102	2026-04-26	Gündüz	480	465	15	1000	934	31	2026-04-29 13:07:09.271+00	\N
2884	102	2026-04-25	Gündüz	480	431	49	1000	852	8	2026-04-29 13:07:09.28+00	\N
2885	102	2026-04-24	Gündüz	480	449	31	1000	832	26	2026-04-29 13:07:09.29+00	\N
2886	102	2026-04-23	Gündüz	480	428	52	1000	929	31	2026-04-29 13:07:09.299+00	\N
2887	102	2026-04-22	Gündüz	480	454	26	1000	840	36	2026-04-29 13:07:09.311+00	\N
2888	102	2026-04-21	Gündüz	480	454	26	1000	837	32	2026-04-29 13:07:09.324+00	\N
2889	102	2026-04-20	Gündüz	480	438	42	1000	917	11	2026-04-29 13:07:09.339+00	\N
2890	102	2026-04-19	Gündüz	480	430	50	1000	906	29	2026-04-29 13:07:09.355+00	\N
2891	102	2026-04-18	Gündüz	480	457	23	1000	843	41	2026-04-29 13:07:09.375+00	\N
2892	102	2026-04-17	Gündüz	480	473	7	1000	866	18	2026-04-29 13:07:09.394+00	\N
2893	102	2026-04-16	Gündüz	480	471	9	1000	924	44	2026-04-29 13:07:09.414+00	\N
2894	102	2026-04-15	Gündüz	480	447	33	1000	918	33	2026-04-29 13:07:09.434+00	\N
2895	102	2026-04-14	Gündüz	480	480	0	1000	979	45	2026-04-29 13:07:09.453+00	\N
2896	102	2026-04-13	Gündüz	480	453	27	1000	827	19	2026-04-29 13:07:09.467+00	\N
2897	102	2026-04-12	Gündüz	480	459	21	1000	964	45	2026-04-29 13:07:09.486+00	\N
2898	102	2026-04-11	Gündüz	480	445	35	1000	898	29	2026-04-29 13:07:09.506+00	\N
2899	102	2026-04-10	Gündüz	480	454	26	1000	967	11	2026-04-29 13:07:09.524+00	\N
2900	102	2026-04-09	Gündüz	480	422	58	1000	919	32	2026-04-29 13:07:09.544+00	\N
2901	102	2026-04-08	Gündüz	480	429	51	1000	941	21	2026-04-29 13:07:09.566+00	\N
2902	102	2026-04-07	Gündüz	480	439	41	1000	939	43	2026-04-29 13:07:09.587+00	\N
2903	102	2026-04-06	Gündüz	480	436	44	1000	925	20	2026-04-29 13:07:09.607+00	\N
2904	102	2026-04-05	Gündüz	480	420	60	1000	853	14	2026-04-29 13:07:09.628+00	\N
2905	102	2026-04-04	Gündüz	480	469	11	1000	816	23	2026-04-29 13:07:09.647+00	\N
2906	102	2026-04-03	Gündüz	480	439	41	1000	800	27	2026-04-29 13:07:09.668+00	\N
2907	102	2026-04-02	Gündüz	480	423	57	1000	960	36	2026-04-29 13:07:09.687+00	\N
2908	102	2026-04-01	Gündüz	480	437	43	1000	930	32	2026-04-29 13:07:09.706+00	\N
2909	102	2026-03-31	Gündüz	480	467	13	1000	844	22	2026-04-29 13:07:09.725+00	\N
2910	102	2026-03-30	Gündüz	480	473	7	1000	859	18	2026-04-29 13:07:09.743+00	\N
2911	103	2026-04-28	Gündüz	480	438	42	1000	929	24	2026-04-29 13:07:09.758+00	\N
2912	103	2026-04-27	Gündüz	480	432	48	1000	883	17	2026-04-29 13:07:09.776+00	\N
2913	103	2026-04-26	Gündüz	480	436	44	1000	838	18	2026-04-29 13:07:09.795+00	\N
2914	103	2026-04-25	Gündüz	480	439	41	1000	855	38	2026-04-29 13:07:09.815+00	\N
2915	103	2026-04-24	Gündüz	480	432	48	1000	828	29	2026-04-29 13:07:09.833+00	\N
2916	103	2026-04-23	Gündüz	480	451	29	1000	917	27	2026-04-29 13:07:09.851+00	\N
2917	103	2026-04-22	Gündüz	480	436	44	1000	850	31	2026-04-29 13:07:09.87+00	\N
2918	103	2026-04-21	Gündüz	480	450	30	1000	867	10	2026-04-29 13:07:09.889+00	\N
2919	103	2026-04-20	Gündüz	480	435	45	1000	967	47	2026-04-29 13:07:09.907+00	\N
2920	103	2026-04-19	Gündüz	480	451	29	1000	801	34	2026-04-29 13:07:09.926+00	\N
2921	103	2026-04-18	Gündüz	480	451	29	1000	868	25	2026-04-29 13:07:09.945+00	\N
2922	103	2026-04-17	Gündüz	480	454	26	1000	866	10	2026-04-29 13:07:09.972+00	\N
2923	103	2026-04-16	Gündüz	480	436	44	1000	878	19	2026-04-29 13:07:09.989+00	\N
2924	103	2026-04-15	Gündüz	480	475	5	1000	889	34	2026-04-29 13:07:10.003+00	\N
2925	103	2026-04-14	Gündüz	480	438	42	1000	889	43	2026-04-29 13:07:10.016+00	\N
2926	103	2026-04-13	Gündüz	480	468	12	1000	851	10	2026-04-29 13:07:10.028+00	\N
2927	103	2026-04-12	Gündüz	480	463	17	1000	965	25	2026-04-29 13:07:10.041+00	\N
2928	103	2026-04-11	Gündüz	480	423	57	1000	832	24	2026-04-29 13:07:10.054+00	\N
2929	103	2026-04-10	Gündüz	480	473	7	1000	870	42	2026-04-29 13:07:10.073+00	\N
2930	103	2026-04-09	Gündüz	480	460	20	1000	942	9	2026-04-29 13:07:10.088+00	\N
2931	103	2026-04-08	Gündüz	480	436	44	1000	956	45	2026-04-29 13:07:10.103+00	\N
2932	103	2026-04-07	Gündüz	480	453	27	1000	903	21	2026-04-29 13:07:10.118+00	\N
2933	103	2026-04-06	Gündüz	480	462	18	1000	865	11	2026-04-29 13:07:10.133+00	\N
2934	103	2026-04-05	Gündüz	480	472	8	1000	921	30	2026-04-29 13:07:10.149+00	\N
2935	103	2026-04-04	Gündüz	480	457	23	1000	920	29	2026-04-29 13:07:10.165+00	\N
2936	103	2026-04-03	Gündüz	480	454	26	1000	959	37	2026-04-29 13:07:10.18+00	\N
2937	103	2026-04-02	Gündüz	480	453	27	1000	845	22	2026-04-29 13:07:10.196+00	\N
2938	103	2026-04-01	Gündüz	480	469	11	1000	858	25	2026-04-29 13:07:10.212+00	\N
2939	103	2026-03-31	Gündüz	480	439	41	1000	825	30	2026-04-29 13:07:10.232+00	\N
2940	103	2026-03-30	Gündüz	480	439	41	1000	942	18	2026-04-29 13:07:10.248+00	\N
2941	104	2026-04-28	Gündüz	480	464	16	1000	862	13	2026-04-29 13:07:10.263+00	\N
2942	104	2026-04-27	Gündüz	480	438	42	1000	814	33	2026-04-29 13:07:10.279+00	\N
2943	104	2026-04-26	Gündüz	480	447	33	1000	823	13	2026-04-29 13:07:10.296+00	\N
2944	104	2026-04-25	Gündüz	480	433	47	1000	881	41	2026-04-29 13:07:10.312+00	\N
2945	104	2026-04-24	Gündüz	480	461	19	1000	937	19	2026-04-29 13:07:10.328+00	\N
2946	104	2026-04-23	Gündüz	480	453	27	1000	855	27	2026-04-29 13:07:10.344+00	\N
2947	104	2026-04-22	Gündüz	480	427	53	1000	884	39	2026-04-29 13:07:10.36+00	\N
2948	104	2026-04-21	Gündüz	480	442	38	1000	907	36	2026-04-29 13:07:10.378+00	\N
2949	104	2026-04-20	Gündüz	480	480	0	1000	977	45	2026-04-29 13:07:10.399+00	\N
2950	104	2026-04-19	Gündüz	480	468	12	1000	828	29	2026-04-29 13:07:10.41+00	\N
2951	104	2026-04-18	Gündüz	480	445	35	1000	909	20	2026-04-29 13:07:10.427+00	\N
2952	104	2026-04-17	Gündüz	480	430	50	1000	854	34	2026-04-29 13:07:10.442+00	\N
2953	104	2026-04-16	Gündüz	480	460	20	1000	956	23	2026-04-29 13:07:10.459+00	\N
2954	104	2026-04-15	Gündüz	480	480	0	1000	909	28	2026-04-29 13:07:10.476+00	\N
2955	104	2026-04-14	Gündüz	480	459	21	1000	875	31	2026-04-29 13:07:10.487+00	\N
2956	104	2026-04-13	Gündüz	480	448	32	1000	871	26	2026-04-29 13:07:10.504+00	\N
2957	104	2026-04-12	Gündüz	480	451	29	1000	912	13	2026-04-29 13:07:10.52+00	\N
2958	104	2026-04-11	Gündüz	480	477	3	1000	870	27	2026-04-29 13:07:10.536+00	\N
2959	104	2026-04-10	Gündüz	480	451	29	1000	813	34	2026-04-29 13:07:10.552+00	\N
2960	104	2026-04-09	Gündüz	480	467	13	1000	894	37	2026-04-29 13:07:10.568+00	\N
2961	104	2026-04-08	Gündüz	480	451	29	1000	958	45	2026-04-29 13:07:10.585+00	\N
2962	104	2026-04-07	Gündüz	480	439	41	1000	932	11	2026-04-29 13:07:10.603+00	\N
2963	104	2026-04-06	Gündüz	480	478	2	1000	909	37	2026-04-29 13:07:10.62+00	\N
2964	104	2026-04-05	Gündüz	480	434	46	1000	957	17	2026-04-29 13:07:10.636+00	\N
2965	104	2026-04-04	Gündüz	480	441	39	1000	929	36	2026-04-29 13:07:10.652+00	\N
2966	104	2026-04-03	Gündüz	480	440	40	1000	822	13	2026-04-29 13:07:10.669+00	\N
2967	104	2026-04-02	Gündüz	480	443	37	1000	827	15	2026-04-29 13:07:10.684+00	\N
2968	104	2026-04-01	Gündüz	480	446	34	1000	896	42	2026-04-29 13:07:10.7+00	\N
2969	104	2026-03-31	Gündüz	480	475	5	1000	815	16	2026-04-29 13:07:10.719+00	\N
2970	104	2026-03-30	Gündüz	480	421	59	1000	834	26	2026-04-29 13:07:10.738+00	\N
2971	105	2026-04-28	Gündüz	480	463	17	1000	832	32	2026-04-29 13:07:10.755+00	\N
2972	105	2026-04-27	Gündüz	480	440	40	1000	849	22	2026-04-29 13:07:10.769+00	\N
2973	105	2026-04-26	Gündüz	480	457	23	1000	887	25	2026-04-29 13:07:10.784+00	\N
2974	105	2026-04-25	Gündüz	480	453	27	1000	880	12	2026-04-29 13:07:10.798+00	\N
2975	105	2026-04-24	Gündüz	480	440	40	1000	891	13	2026-04-29 13:07:10.813+00	\N
2976	105	2026-04-23	Gündüz	480	421	59	1000	930	37	2026-04-29 13:07:10.828+00	\N
2977	105	2026-04-22	Gündüz	480	476	4	1000	975	44	2026-04-29 13:07:10.845+00	\N
2978	105	2026-04-21	Gündüz	480	442	38	1000	905	30	2026-04-29 13:07:10.86+00	\N
2979	105	2026-04-20	Gündüz	480	478	2	1000	823	39	2026-04-29 13:07:10.875+00	\N
2980	105	2026-04-19	Gündüz	480	429	51	1000	869	39	2026-04-29 13:07:10.891+00	\N
2981	105	2026-04-18	Gündüz	480	450	30	1000	808	14	2026-04-29 13:07:10.907+00	\N
2982	105	2026-04-17	Gündüz	480	424	56	1000	811	29	2026-04-29 13:07:10.922+00	\N
2983	105	2026-04-16	Gündüz	480	452	28	1000	825	9	2026-04-29 13:07:10.938+00	\N
2984	105	2026-04-15	Gündüz	480	432	48	1000	904	30	2026-04-29 13:07:10.953+00	\N
2985	105	2026-04-14	Gündüz	480	468	12	1000	841	41	2026-04-29 13:07:10.969+00	\N
2986	105	2026-04-13	Gündüz	480	434	46	1000	817	28	2026-04-29 13:07:10.986+00	\N
2987	105	2026-04-12	Gündüz	480	452	28	1000	857	30	2026-04-29 13:07:11.002+00	\N
2988	105	2026-04-11	Gündüz	480	465	15	1000	894	44	2026-04-29 13:07:11.018+00	\N
2989	105	2026-04-10	Gündüz	480	427	53	1000	898	19	2026-04-29 13:07:11.035+00	\N
2990	105	2026-04-09	Gündüz	480	446	34	1000	800	19	2026-04-29 13:07:11.052+00	\N
2991	105	2026-04-08	Gündüz	480	459	21	1000	830	15	2026-04-29 13:07:11.067+00	\N
2992	105	2026-04-07	Gündüz	480	480	0	1000	834	37	2026-04-29 13:07:11.083+00	\N
2993	105	2026-04-06	Gündüz	480	440	40	1000	952	42	2026-04-29 13:07:11.093+00	\N
2994	105	2026-04-05	Gündüz	480	433	47	1000	888	12	2026-04-29 13:07:11.11+00	\N
2995	105	2026-04-04	Gündüz	480	465	15	1000	951	21	2026-04-29 13:07:11.124+00	\N
2996	105	2026-04-03	Gündüz	480	471	9	1000	852	40	2026-04-29 13:07:11.139+00	\N
2997	105	2026-04-02	Gündüz	480	460	20	1000	941	31	2026-04-29 13:07:11.154+00	\N
2998	105	2026-04-01	Gündüz	480	479	1	1000	930	41	2026-04-29 13:07:11.17+00	\N
2999	105	2026-03-31	Gündüz	480	452	28	1000	865	29	2026-04-29 13:07:11.183+00	\N
3000	105	2026-03-30	Gündüz	480	467	13	1000	957	20	2026-04-29 13:07:11.199+00	\N
\.


--
-- TOC entry 4037 (class 0 OID 0)
-- Dependencies: 270
-- Name: abonelik_tipi_abonelik_tip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.abonelik_tipi_abonelik_tip_id_seq', 1, false);


--
-- TOC entry 4038 (class 0 OID 0)
-- Dependencies: 218
-- Name: ai_ariza_tespit_tespit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ai_ariza_tespit_tespit_id_seq', 1, false);


--
-- TOC entry 4039 (class 0 OID 0)
-- Dependencies: 220
-- Name: ai_model_log_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ai_model_log_log_id_seq', 1, false);


--
-- TOC entry 4040 (class 0 OID 0)
-- Dependencies: 222
-- Name: ariza_kaydi_ariza_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ariza_kaydi_ariza_id_seq', 5, true);


--
-- TOC entry 4041 (class 0 OID 0)
-- Dependencies: 258
-- Name: ariza_turu_ariza_tur_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ariza_turu_ariza_tur_id_seq', 1, true);


--
-- TOC entry 4042 (class 0 OID 0)
-- Dependencies: 224
-- Name: arizayi_tetikleyen_form_tetik_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.arizayi_tetikleyen_form_tetik_id_seq', 1, false);


--
-- TOC entry 4043 (class 0 OID 0)
-- Dependencies: 226
-- Name: bakim_kaydi_bakim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bakim_kaydi_bakim_id_seq', 130, true);


--
-- TOC entry 4044 (class 0 OID 0)
-- Dependencies: 272
-- Name: bakim_turu_bakim_tur_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bakim_turu_bakim_tur_id_seq', 13, true);


--
-- TOC entry 4045 (class 0 OID 0)
-- Dependencies: 299
-- Name: durus_kaydi_durus_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.durus_kaydi_durus_id_seq', 2940, true);


--
-- TOC entry 4046 (class 0 OID 0)
-- Dependencies: 228
-- Name: firma_firma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.firma_firma_id_seq', 1, true);


--
-- TOC entry 4047 (class 0 OID 0)
-- Dependencies: 230
-- Name: form_madde_cevap_cevap_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.form_madde_cevap_cevap_id_seq', 2361, true);


--
-- TOC entry 4048 (class 0 OID 0)
-- Dependencies: 260
-- Name: garanti_firma_garanti_firma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.garanti_firma_garanti_firma_id_seq', 1, true);


--
-- TOC entry 4049 (class 0 OID 0)
-- Dependencies: 262
-- Name: genel_sorular_genel_soru_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.genel_sorular_genel_soru_id_seq', 1, false);


--
-- TOC entry 4050 (class 0 OID 0)
-- Dependencies: 232
-- Name: gunluk_kontrol_formu_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.gunluk_kontrol_formu_form_id_seq', 177, true);


--
-- TOC entry 4051 (class 0 OID 0)
-- Dependencies: 274
-- Name: iletisim_iletisim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.iletisim_iletisim_id_seq', 4, true);


--
-- TOC entry 4052 (class 0 OID 0)
-- Dependencies: 234
-- Name: kontrol_maddesi_madde_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.kontrol_maddesi_madde_id_seq', 40, true);


--
-- TOC entry 4053 (class 0 OID 0)
-- Dependencies: 236
-- Name: kontrol_sablonu_sablon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.kontrol_sablonu_sablon_id_seq', 3, true);


--
-- TOC entry 4054 (class 0 OID 0)
-- Dependencies: 216
-- Name: kullanici_kullanici_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.kullanici_kullanici_id_seq', 8, true);


--
-- TOC entry 4055 (class 0 OID 0)
-- Dependencies: 238
-- Name: lokasyon_lokasyon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lokasyon_lokasyon_id_seq', 1, false);


--
-- TOC entry 4056 (class 0 OID 0)
-- Dependencies: 242
-- Name: makine_kullanim_kullanim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_kullanim_kullanim_id_seq', 1, false);


--
-- TOC entry 4057 (class 0 OID 0)
-- Dependencies: 240
-- Name: makine_makine_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_makine_id_seq', 105, true);


--
-- TOC entry 4058 (class 0 OID 0)
-- Dependencies: 264
-- Name: makine_ozellikleri_ozellik_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_ozellikleri_ozellik_id_seq', 103, true);


--
-- TOC entry 4059 (class 0 OID 0)
-- Dependencies: 244
-- Name: makine_turu_makine_tur_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.makine_turu_makine_tur_id_seq', 4, true);


--
-- TOC entry 4060 (class 0 OID 0)
-- Dependencies: 295
-- Name: oee_raporlari_rapor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.oee_raporlari_rapor_id_seq', 3000, true);


--
-- TOC entry 4061 (class 0 OID 0)
-- Dependencies: 248
-- Name: parca_degisim_parca_degisim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parca_degisim_parca_degisim_id_seq', 4, true);


--
-- TOC entry 4062 (class 0 OID 0)
-- Dependencies: 276
-- Name: parca_kategori_kategori_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parca_kategori_kategori_id_seq', 4, true);


--
-- TOC entry 4063 (class 0 OID 0)
-- Dependencies: 246
-- Name: parca_parca_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parca_parca_id_seq', 13, true);


--
-- TOC entry 4064 (class 0 OID 0)
-- Dependencies: 301
-- Name: parca_stok_hareketleri_hareket_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.parca_stok_hareketleri_hareket_id_seq', 2, true);


--
-- TOC entry 4065 (class 0 OID 0)
-- Dependencies: 250
-- Name: risk_skoru_risk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.risk_skoru_risk_id_seq', 101, true);


--
-- TOC entry 4066 (class 0 OID 0)
-- Dependencies: 252
-- Name: rol_rol_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.rol_rol_id_seq', 6, true);


--
-- TOC entry 4067 (class 0 OID 0)
-- Dependencies: 278
-- Name: sektor_sektor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.sektor_sektor_id_seq', 1, false);


--
-- TOC entry 4068 (class 0 OID 0)
-- Dependencies: 254
-- Name: servis_firma_servis_firma_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.servis_firma_servis_firma_id_seq', 12, true);


--
-- TOC entry 4069 (class 0 OID 0)
-- Dependencies: 266
-- Name: servis_puan_puan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.servis_puan_puan_id_seq', 40, true);


--
-- TOC entry 4070 (class 0 OID 0)
-- Dependencies: 268
-- Name: servis_sorumlusu_sorumlu_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.servis_sorumlusu_sorumlu_id_seq', 1, false);


--
-- TOC entry 4071 (class 0 OID 0)
-- Dependencies: 281
-- Name: tedarikci_parca_tedarikci_parca_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tedarikci_parca_tedarikci_parca_id_seq', 1, false);


--
-- TOC entry 4072 (class 0 OID 0)
-- Dependencies: 283
-- Name: tedarikci_puan_puan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tedarikci_puan_puan_id_seq', 1, false);


--
-- TOC entry 4073 (class 0 OID 0)
-- Dependencies: 256
-- Name: tedarikci_tedarikci_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tedarikci_tedarikci_id_seq', 2, true);


--
-- TOC entry 4074 (class 0 OID 0)
-- Dependencies: 297
-- Name: uretim_kaydi_uretim_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.uretim_kaydi_uretim_id_seq', 3000, true);


--
-- TOC entry 3568 (class 2606 OID 89536)
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- TOC entry 3667 (class 2606 OID 89768)
-- Name: abonelik_tipi abonelik_tipi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.abonelik_tipi
    ADD CONSTRAINT abonelik_tipi_pkey PRIMARY KEY (abonelik_tip_id);


--
-- TOC entry 3579 (class 2606 OID 89560)
-- Name: ai_ariza_tespit ai_ariza_tespit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT ai_ariza_tespit_pkey PRIMARY KEY (tespit_id);


--
-- TOC entry 3584 (class 2606 OID 89567)
-- Name: ai_model_log ai_model_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT ai_model_log_pkey PRIMARY KEY (log_id);


--
-- TOC entry 3586 (class 2606 OID 89576)
-- Name: ariza_kaydi ariza_kaydi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi
    ADD CONSTRAINT ariza_kaydi_pkey PRIMARY KEY (ariza_id);


--
-- TOC entry 3652 (class 2606 OID 89719)
-- Name: ariza_turu ariza_turu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_turu
    ADD CONSTRAINT ariza_turu_pkey PRIMARY KEY (ariza_tur_id);


--
-- TOC entry 3590 (class 2606 OID 89585)
-- Name: arizayi_tetikleyen_form arizayi_tetikleyen_form_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT arizayi_tetikleyen_form_pkey PRIMARY KEY (tetik_id);


--
-- TOC entry 3595 (class 2606 OID 89595)
-- Name: bakim_kaydi bakim_kaydi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT bakim_kaydi_pkey PRIMARY KEY (bakim_id);


--
-- TOC entry 3669 (class 2606 OID 89775)
-- Name: bakim_turu bakim_turu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_turu
    ADD CONSTRAINT bakim_turu_pkey PRIMARY KEY (bakim_tur_id);


--
-- TOC entry 3695 (class 2606 OID 105998)
-- Name: durus_kaydi durus_kaydi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.durus_kaydi
    ADD CONSTRAINT durus_kaydi_pkey PRIMARY KEY (durus_id);


--
-- TOC entry 3600 (class 2606 OID 89602)
-- Name: firma firma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT firma_pkey PRIMARY KEY (firma_id);


--
-- TOC entry 3603 (class 2606 OID 89611)
-- Name: form_madde_cevap form_madde_cevap_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap
    ADD CONSTRAINT form_madde_cevap_pkey PRIMARY KEY (cevap_id);


--
-- TOC entry 3654 (class 2606 OID 89726)
-- Name: garanti_firma garanti_firma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.garanti_firma
    ADD CONSTRAINT garanti_firma_pkey PRIMARY KEY (garanti_firma_id);


--
-- TOC entry 3656 (class 2606 OID 89733)
-- Name: genel_sorular genel_sorular_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.genel_sorular
    ADD CONSTRAINT genel_sorular_pkey PRIMARY KEY (genel_soru_id);


--
-- TOC entry 3607 (class 2606 OID 89620)
-- Name: gunluk_kontrol_formu gunluk_kontrol_formu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT gunluk_kontrol_formu_pkey PRIMARY KEY (form_id);


--
-- TOC entry 3671 (class 2606 OID 89784)
-- Name: iletisim iletisim_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iletisim
    ADD CONSTRAINT iletisim_pkey PRIMARY KEY (iletisim_id);


--
-- TOC entry 3615 (class 2606 OID 89627)
-- Name: kontrol_maddesi kontrol_maddesi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_maddesi
    ADD CONSTRAINT kontrol_maddesi_pkey PRIMARY KEY (madde_id);


--
-- TOC entry 3618 (class 2606 OID 89636)
-- Name: kontrol_sablonu kontrol_sablonu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_sablonu
    ADD CONSTRAINT kontrol_sablonu_pkey PRIMARY KEY (sablon_id);


--
-- TOC entry 3574 (class 2606 OID 97763)
-- Name: kullanici kullanici_adi; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT kullanici_adi UNIQUE (kullanici_adi);


--
-- TOC entry 3576 (class 2606 OID 89553)
-- Name: kullanici kullanici_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT kullanici_pkey PRIMARY KEY (kullanici_id);


--
-- TOC entry 3620 (class 2606 OID 89645)
-- Name: lokasyon lokasyon_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon
    ADD CONSTRAINT lokasyon_pkey PRIMARY KEY (lokasyon_id);


--
-- TOC entry 3659 (class 2606 OID 89743)
-- Name: makine_ozellikleri makine_ozellikleri_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_ozellikleri
    ADD CONSTRAINT makine_ozellikleri_pkey PRIMARY KEY (ozellik_id);


--
-- TOC entry 3625 (class 2606 OID 89653)
-- Name: makine makine_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT makine_pkey PRIMARY KEY (makine_id);


--
-- TOC entry 3634 (class 2606 OID 89668)
-- Name: makine_turu makine_turu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_turu
    ADD CONSTRAINT makine_turu_pkey PRIMARY KEY (makine_tur_id);


--
-- TOC entry 3686 (class 2606 OID 105962)
-- Name: oee_raporlari oee_raporlari_makine_id_tarih_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oee_raporlari
    ADD CONSTRAINT oee_raporlari_makine_id_tarih_key UNIQUE (makine_id, tarih);


--
-- TOC entry 3688 (class 2606 OID 105960)
-- Name: oee_raporlari oee_raporlari_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oee_raporlari
    ADD CONSTRAINT oee_raporlari_pkey PRIMARY KEY (rapor_id);


--
-- TOC entry 3632 (class 2606 OID 89661)
-- Name: makine_kullanim operator_makine_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim
    ADD CONSTRAINT operator_makine_pkey PRIMARY KEY (kullanim_id);


--
-- TOC entry 3640 (class 2606 OID 89682)
-- Name: parca_degisim parca_degisim_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT parca_degisim_pkey PRIMARY KEY (parca_degisim_id);


--
-- TOC entry 3674 (class 2606 OID 89791)
-- Name: parca_kategori parca_kategori_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_kategori
    ADD CONSTRAINT parca_kategori_pkey PRIMARY KEY (kategori_id);


--
-- TOC entry 3637 (class 2606 OID 89675)
-- Name: parca parca_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT parca_pkey PRIMARY KEY (parca_id);


--
-- TOC entry 3700 (class 2606 OID 114155)
-- Name: parca_stok_hareketleri parca_stok_hareketleri_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_stok_hareketleri
    ADD CONSTRAINT parca_stok_hareketleri_pkey PRIMARY KEY (hareket_id);


--
-- TOC entry 3644 (class 2606 OID 89689)
-- Name: risk_skoru risk_skoru_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_skoru
    ADD CONSTRAINT risk_skoru_pkey PRIMARY KEY (risk_id);


--
-- TOC entry 3646 (class 2606 OID 89698)
-- Name: rol rol_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (rol_id);


--
-- TOC entry 3677 (class 2606 OID 89798)
-- Name: sektor sektor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sektor
    ADD CONSTRAINT sektor_pkey PRIMARY KEY (sektor_id);


--
-- TOC entry 3648 (class 2606 OID 89705)
-- Name: servis_firma servis_firma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma
    ADD CONSTRAINT servis_firma_pkey PRIMARY KEY (servis_firma_id);


--
-- TOC entry 3679 (class 2606 OID 89805)
-- Name: servis_firma_uzmanlik servis_firma_uzmanlik_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma_uzmanlik
    ADD CONSTRAINT servis_firma_uzmanlik_pkey PRIMARY KEY (servis_firma_id);


--
-- TOC entry 3663 (class 2606 OID 89752)
-- Name: servis_puan servis_puan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan
    ADD CONSTRAINT servis_puan_pkey PRIMARY KEY (puan_id);


--
-- TOC entry 3665 (class 2606 OID 89761)
-- Name: servis_sorumlusu servis_sorumlusu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_sorumlusu
    ADD CONSTRAINT servis_sorumlusu_pkey PRIMARY KEY (sorumlu_id);


--
-- TOC entry 3684 (class 2606 OID 89821)
-- Name: tedarikci_puan tedarakci_puan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan
    ADD CONSTRAINT tedarakci_puan_pkey PRIMARY KEY (puan_id);


--
-- TOC entry 3681 (class 2606 OID 89812)
-- Name: tedarikci_parca tedarikci_parca_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca
    ADD CONSTRAINT tedarikci_parca_pkey PRIMARY KEY (tedarikci_parca_id);


--
-- TOC entry 3650 (class 2606 OID 89712)
-- Name: tedarikci tedarikci_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci
    ADD CONSTRAINT tedarikci_pkey PRIMARY KEY (tedarikci_id);


--
-- TOC entry 3693 (class 2606 OID 105977)
-- Name: uretim_kaydi uretim_kaydi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uretim_kaydi
    ADD CONSTRAINT uretim_kaydi_pkey PRIMARY KEY (uretim_id);


--
-- TOC entry 3587 (class 1259 OID 89831)
-- Name: idx_ariza_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ariza_tarih ON public.ariza_kaydi USING btree (baslangic_zamani);


--
-- TOC entry 3596 (class 1259 OID 89835)
-- Name: idx_bakim_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bakim_makine ON public.bakim_kaydi USING btree (makine_id);


--
-- TOC entry 3597 (class 1259 OID 89836)
-- Name: idx_bakim_servis; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bakim_servis ON public.bakim_kaydi USING btree (servis_firma_id);


--
-- TOC entry 3598 (class 1259 OID 89837)
-- Name: idx_bakim_teknisyen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bakim_teknisyen ON public.bakim_kaydi USING btree (sorumlu_id);


--
-- TOC entry 3604 (class 1259 OID 89839)
-- Name: idx_cevap_form; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cevap_form ON public.form_madde_cevap USING btree (form_id);


--
-- TOC entry 3605 (class 1259 OID 89840)
-- Name: idx_cevap_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cevap_madde ON public.form_madde_cevap USING btree (soru_referans_id);


--
-- TOC entry 3638 (class 1259 OID 89857)
-- Name: idx_degisim_bakim; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_degisim_bakim ON public.parca_degisim USING btree (bakim_id);


--
-- TOC entry 3696 (class 1259 OID 106009)
-- Name: idx_durus_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_durus_makine ON public.durus_kaydi USING btree (makine_id);


--
-- TOC entry 3697 (class 1259 OID 106011)
-- Name: idx_durus_makine_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_durus_makine_tarih ON public.durus_kaydi USING btree (makine_id, vardiya_tarihi);


--
-- TOC entry 3698 (class 1259 OID 106010)
-- Name: idx_durus_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_durus_tarih ON public.durus_kaydi USING btree (vardiya_tarihi);


--
-- TOC entry 3612 (class 1259 OID 89846)
-- Name: idx_kontrol_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kontrol_madde ON public.kontrol_maddesi USING btree (madde_id);


--
-- TOC entry 3613 (class 1259 OID 89845)
-- Name: idx_kontrol_sablon; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kontrol_sablon ON public.kontrol_maddesi USING btree (sablon_id);


--
-- TOC entry 3569 (class 1259 OID 89826)
-- Name: idx_kullanici_adi; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kullanici_adi ON public.kullanici USING btree (kullanici_adi);


--
-- TOC entry 3570 (class 1259 OID 89822)
-- Name: idx_kullanici_eposta; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_kullanici_eposta ON public.kullanici USING btree (eposta);


--
-- TOC entry 3571 (class 1259 OID 89824)
-- Name: idx_kullanici_firma_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kullanici_firma_id ON public.kullanici USING btree (firma_id);


--
-- TOC entry 3572 (class 1259 OID 89825)
-- Name: idx_kullanici_rol_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kullanici_rol_id ON public.kullanici USING btree (rol_id);


--
-- TOC entry 3588 (class 1259 OID 89830)
-- Name: idx_m_ariza; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_m_ariza ON public.ariza_kaydi USING btree (makine_id);


--
-- TOC entry 3621 (class 1259 OID 89852)
-- Name: idx_m_qr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_m_qr ON public.makine USING btree (makine_qr);


--
-- TOC entry 3622 (class 1259 OID 89850)
-- Name: idx_makine_firma; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_firma ON public.makine USING btree (firma_id);


--
-- TOC entry 3608 (class 1259 OID 89841)
-- Name: idx_makine_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_id ON public.gunluk_kontrol_formu USING btree (makine_id);


--
-- TOC entry 3628 (class 1259 OID 89854)
-- Name: idx_makine_kullanim_baslangic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_kullanim_baslangic ON public.makine_kullanim USING btree (baslangic_zamani);


--
-- TOC entry 3629 (class 1259 OID 89853)
-- Name: idx_makine_kullanim_kullanici_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_kullanim_kullanici_id ON public.makine_kullanim USING btree (kullanici_id);


--
-- TOC entry 3623 (class 1259 OID 89851)
-- Name: idx_makine_turu; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_makine_turu ON public.makine USING btree (makine_tur_id);


--
-- TOC entry 3630 (class 1259 OID 89855)
-- Name: idx_mkullanim_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mkullanim_makine ON public.makine_kullanim USING btree (makine_id);


--
-- TOC entry 3609 (class 1259 OID 89842)
-- Name: idx_operator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operator_id ON public.gunluk_kontrol_formu USING btree (kullanici_id);


--
-- TOC entry 3641 (class 1259 OID 89858)
-- Name: idx_risk_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_risk_makine ON public.risk_skoru USING btree (makine_id);


--
-- TOC entry 3642 (class 1259 OID 89859)
-- Name: idx_risk_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_risk_tarih ON public.risk_skoru USING btree (hesaplama_tarihi);


--
-- TOC entry 3610 (class 1259 OID 89843)
-- Name: idx_sablon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sablon_id ON public.gunluk_kontrol_formu USING btree (sablon_id);


--
-- TOC entry 3616 (class 1259 OID 89847)
-- Name: idx_sablon_m_turu; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sablon_m_turu ON public.kontrol_sablonu USING btree (makine_tur_id);


--
-- TOC entry 3660 (class 1259 OID 89861)
-- Name: idx_spuan_firma; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_spuan_firma ON public.servis_puan USING btree (servis_firma_id);


--
-- TOC entry 3661 (class 1259 OID 89862)
-- Name: idx_spuan_kullanici; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_spuan_kullanici ON public.servis_puan USING btree (puanlayan_kullanici_id);


--
-- TOC entry 3611 (class 1259 OID 89844)
-- Name: idx_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tarih ON public.gunluk_kontrol_formu USING btree (kontrol_tarihi);


--
-- TOC entry 3580 (class 1259 OID 89827)
-- Name: idx_tespit_form; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tespit_form ON public.ai_ariza_tespit USING btree (form_id);


--
-- TOC entry 3581 (class 1259 OID 89828)
-- Name: idx_tespit_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tespit_madde ON public.ai_ariza_tespit USING btree (madde_id);


--
-- TOC entry 3582 (class 1259 OID 89829)
-- Name: idx_tespit_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tespit_makine ON public.ai_ariza_tespit USING btree (makine_id);


--
-- TOC entry 3591 (class 1259 OID 89832)
-- Name: idx_tetik_form; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tetik_form ON public.arizayi_tetikleyen_form USING btree (form_id);


--
-- TOC entry 3592 (class 1259 OID 89833)
-- Name: idx_tetik_madde; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tetik_madde ON public.arizayi_tetikleyen_form USING btree (madde_id);


--
-- TOC entry 3593 (class 1259 OID 89834)
-- Name: idx_tetik_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tetik_tarih ON public.arizayi_tetikleyen_form USING btree (tespit_tarihi);


--
-- TOC entry 3682 (class 1259 OID 89865)
-- Name: idx_tpuan_tedarikci; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tpuan_tedarikci ON public.tedarikci_puan USING btree (tedarikci_id);


--
-- TOC entry 3689 (class 1259 OID 105988)
-- Name: idx_uretim_makine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_uretim_makine ON public.uretim_kaydi USING btree (makine_id);


--
-- TOC entry 3690 (class 1259 OID 105990)
-- Name: idx_uretim_makine_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_uretim_makine_tarih ON public.uretim_kaydi USING btree (makine_id, vardiya_tarihi);


--
-- TOC entry 3691 (class 1259 OID 105989)
-- Name: idx_uretim_tarih; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_uretim_tarih ON public.uretim_kaydi USING btree (vardiya_tarihi);


--
-- TOC entry 3657 (class 1259 OID 89860)
-- Name: makine_ozellikleri_makine_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX makine_ozellikleri_makine_id_key ON public.makine_ozellikleri USING btree (makine_id);


--
-- TOC entry 3635 (class 1259 OID 89856)
-- Name: parca_adi; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX parca_adi ON public.parca USING btree (parca_adi);


--
-- TOC entry 3675 (class 1259 OID 89864)
-- Name: unique_kategori_adi; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_kategori_adi ON public.parca_kategori USING btree (kategori_adi);


--
-- TOC entry 3577 (class 1259 OID 89823)
-- Name: unique_kullanici; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_kullanici ON public.kullanici USING btree (kullanici_adi);


--
-- TOC entry 3672 (class 1259 OID 89863)
-- Name: unique_telefon; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_telefon ON public.iletisim USING btree (telefon);


--
-- TOC entry 3626 (class 1259 OID 89848)
-- Name: uq_makine_qr; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_makine_qr ON public.makine USING btree (makine_qr);


--
-- TOC entry 3627 (class 1259 OID 89849)
-- Name: uq_seri_no; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_seri_no ON public.makine USING btree (seri_no);


--
-- TOC entry 3601 (class 1259 OID 89838)
-- Name: uq_vergi_no; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_vergi_no ON public.firma USING btree (vergi_no);


--
-- TOC entry 3759 (class 2620 OID 90177)
-- Name: bakim_kaydi trg_bakim_ariza_kapat; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_bakim_ariza_kapat AFTER INSERT ON public.bakim_kaydi FOR EACH ROW WHEN ((new.ariza_id IS NOT NULL)) EXECUTE FUNCTION public.fn_bakim_girince_arizayi_kapat();


--
-- TOC entry 3760 (class 2620 OID 114157)
-- Name: parca trg_stok_degisim_takip; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_stok_degisim_takip AFTER INSERT OR UPDATE ON public.parca FOR EACH ROW EXECUTE FUNCTION public.fnk_stok_hareket_kaydet();


--
-- TOC entry 3746 (class 2606 OID 90076)
-- Name: servis_puan firma_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan
    ADD CONSTRAINT firma_fk FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3720 (class 2606 OID 89951)
-- Name: firma fk_abonelik; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT fk_abonelik FOREIGN KEY (abonelik_tip_id) REFERENCES public.abonelik_tipi(abonelik_tip_id);


--
-- TOC entry 3706 (class 2606 OID 89891)
-- Name: ai_model_log fk_ai_log; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT fk_ai_log FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3711 (class 2606 OID 89916)
-- Name: arizayi_tetikleyen_form fk_ariza; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT fk_ariza FOREIGN KEY (ariza_id) REFERENCES public.ariza_kaydi(ariza_id);


--
-- TOC entry 3714 (class 2606 OID 89931)
-- Name: bakim_kaydi fk_ariza; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_ariza FOREIGN KEY (ariza_id) REFERENCES public.ariza_kaydi(ariza_id);


--
-- TOC entry 3709 (class 2606 OID 89906)
-- Name: ariza_kaydi fk_ariza_tur; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi
    ADD CONSTRAINT fk_ariza_tur FOREIGN KEY (ariza_tur_id) REFERENCES public.ariza_turu(ariza_tur_id);


--
-- TOC entry 3715 (class 2606 OID 89936)
-- Name: bakim_kaydi fk_bakim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_bakim FOREIGN KEY (bakim_tur_id) REFERENCES public.bakim_turu(bakim_tur_id);


--
-- TOC entry 3738 (class 2606 OID 90041)
-- Name: parca_degisim fk_bakim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT fk_bakim FOREIGN KEY (bakim_id) REFERENCES public.bakim_kaydi(bakim_id);


--
-- TOC entry 3739 (class 2606 OID 97719)
-- Name: parca_degisim fk_bakim_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT fk_bakim_id FOREIGN KEY (bakim_kaydi_id) REFERENCES public.bakim_kaydi(bakim_id) NOT VALID;


--
-- TOC entry 3757 (class 2606 OID 106004)
-- Name: durus_kaydi fk_durus_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.durus_kaydi
    ADD CONSTRAINT fk_durus_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3758 (class 2606 OID 105999)
-- Name: durus_kaydi fk_durus_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.durus_kaydi
    ADD CONSTRAINT fk_durus_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3701 (class 2606 OID 89866)
-- Name: kullanici fk_firma; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT fk_firma FOREIGN KEY (firma_id) REFERENCES public.firma(firma_id);


--
-- TOC entry 3731 (class 2606 OID 90006)
-- Name: makine fk_firma; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT fk_firma FOREIGN KEY (firma_id) REFERENCES public.firma(firma_id);


--
-- TOC entry 3703 (class 2606 OID 89876)
-- Name: ai_ariza_tespit fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3707 (class 2606 OID 89896)
-- Name: ai_model_log fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3712 (class 2606 OID 89921)
-- Name: arizayi_tetikleyen_form fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3723 (class 2606 OID 89966)
-- Name: form_madde_cevap fk_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap
    ADD CONSTRAINT fk_form FOREIGN KEY (form_id) REFERENCES public.gunluk_kontrol_formu(form_id);


--
-- TOC entry 3732 (class 2606 OID 90011)
-- Name: makine fk_garanti_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT fk_garanti_id FOREIGN KEY (garanti_firma_id) REFERENCES public.garanti_firma(garanti_firma_id);


--
-- TOC entry 3721 (class 2606 OID 89956)
-- Name: firma fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id);


--
-- TOC entry 3744 (class 2606 OID 90066)
-- Name: garanti_firma fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.garanti_firma
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id);


--
-- TOC entry 3742 (class 2606 OID 90056)
-- Name: servis_firma fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id);


--
-- TOC entry 3743 (class 2606 OID 90061)
-- Name: tedarikci fk_iletisim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci
    ADD CONSTRAINT fk_iletisim FOREIGN KEY (iletisim_id) REFERENCES public.iletisim(iletisim_id);


--
-- TOC entry 3736 (class 2606 OID 90031)
-- Name: parca fk_kategori; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT fk_kategori FOREIGN KEY (kategori_id) REFERENCES public.parca_kategori(kategori_id);


--
-- TOC entry 3708 (class 2606 OID 89901)
-- Name: ai_model_log fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_log
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3716 (class 2606 OID 97747)
-- Name: bakim_kaydi fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id) NOT VALID;


--
-- TOC entry 3725 (class 2606 OID 89976)
-- Name: gunluk_kontrol_formu fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3734 (class 2606 OID 90021)
-- Name: makine_kullanim fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3752 (class 2606 OID 90106)
-- Name: tedarikci_puan fk_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan
    ADD CONSTRAINT fk_kullanici FOREIGN KEY (puanlayan_kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3704 (class 2606 OID 89881)
-- Name: ai_ariza_tespit fk_madde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT fk_madde FOREIGN KEY (madde_id) REFERENCES public.kontrol_maddesi(madde_id);


--
-- TOC entry 3713 (class 2606 OID 89926)
-- Name: arizayi_tetikleyen_form fk_madde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.arizayi_tetikleyen_form
    ADD CONSTRAINT fk_madde FOREIGN KEY (madde_id) REFERENCES public.kontrol_maddesi(madde_id);


--
-- TOC entry 3724 (class 2606 OID 89971)
-- Name: form_madde_cevap fk_madde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_madde_cevap
    ADD CONSTRAINT fk_madde FOREIGN KEY (soru_referans_id) REFERENCES public.kontrol_maddesi(madde_id);


--
-- TOC entry 3705 (class 2606 OID 89886)
-- Name: ai_ariza_tespit fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_ariza_tespit
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3710 (class 2606 OID 89911)
-- Name: ariza_kaydi fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ariza_kaydi
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3717 (class 2606 OID 89941)
-- Name: bakim_kaydi fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3726 (class 2606 OID 89981)
-- Name: gunluk_kontrol_formu fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3729 (class 2606 OID 89996)
-- Name: lokasyon fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3735 (class 2606 OID 90026)
-- Name: makine_kullanim fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_kullanim
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3745 (class 2606 OID 90071)
-- Name: makine_ozellikleri fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine_ozellikleri
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id) ON DELETE CASCADE;


--
-- TOC entry 3741 (class 2606 OID 90051)
-- Name: risk_skoru fk_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.risk_skoru
    ADD CONSTRAINT fk_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3733 (class 2606 OID 90016)
-- Name: makine fk_makine_turu; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.makine
    ADD CONSTRAINT fk_makine_turu FOREIGN KEY (makine_tur_id) REFERENCES public.makine_turu(makine_tur_id);


--
-- TOC entry 3740 (class 2606 OID 90046)
-- Name: parca_degisim fk_parca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca_degisim
    ADD CONSTRAINT fk_parca FOREIGN KEY (parca_id) REFERENCES public.parca(parca_id);


--
-- TOC entry 3750 (class 2606 OID 90096)
-- Name: tedarikci_parca fk_parca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca
    ADD CONSTRAINT fk_parca FOREIGN KEY (parca_id) REFERENCES public.parca(parca_id);


--
-- TOC entry 3702 (class 2606 OID 89871)
-- Name: kullanici fk_rol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kullanici
    ADD CONSTRAINT fk_rol FOREIGN KEY (rol_id) REFERENCES public.rol(rol_id);


--
-- TOC entry 3727 (class 2606 OID 89986)
-- Name: gunluk_kontrol_formu fk_sablon; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gunluk_kontrol_formu
    ADD CONSTRAINT fk_sablon FOREIGN KEY (sablon_id) REFERENCES public.kontrol_sablonu(sablon_id);


--
-- TOC entry 3728 (class 2606 OID 89991)
-- Name: kontrol_sablonu fk_sablon_kontrol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kontrol_sablonu
    ADD CONSTRAINT fk_sablon_kontrol FOREIGN KEY (makine_tur_id) REFERENCES public.makine_turu(makine_tur_id);


--
-- TOC entry 3722 (class 2606 OID 89961)
-- Name: firma fk_sektor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firma
    ADD CONSTRAINT fk_sektor FOREIGN KEY (sektor_id) REFERENCES public.sektor(sektor_id);


--
-- TOC entry 3718 (class 2606 OID 89946)
-- Name: bakim_kaydi fk_servis; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_servis FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3719 (class 2606 OID 90179)
-- Name: bakim_kaydi fk_servis_sorumlu; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bakim_kaydi
    ADD CONSTRAINT fk_servis_sorumlu FOREIGN KEY (sorumlu_id) REFERENCES public.servis_sorumlusu(sorumlu_id);


--
-- TOC entry 3748 (class 2606 OID 90086)
-- Name: servis_sorumlusu fk_sorumlusu; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_sorumlusu
    ADD CONSTRAINT fk_sorumlusu FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3737 (class 2606 OID 90036)
-- Name: parca fk_tedarikci; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parca
    ADD CONSTRAINT fk_tedarikci FOREIGN KEY (tedarikci_id) REFERENCES public.tedarikci(tedarikci_id);


--
-- TOC entry 3751 (class 2606 OID 90101)
-- Name: tedarikci_parca fk_tedarikci; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_parca
    ADD CONSTRAINT fk_tedarikci FOREIGN KEY (tedarik_id) REFERENCES public.tedarikci(tedarikci_id);


--
-- TOC entry 3755 (class 2606 OID 105983)
-- Name: uretim_kaydi fk_uretim_kullanici; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uretim_kaydi
    ADD CONSTRAINT fk_uretim_kullanici FOREIGN KEY (kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3756 (class 2606 OID 105978)
-- Name: uretim_kaydi fk_uretim_makine; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uretim_kaydi
    ADD CONSTRAINT fk_uretim_makine FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id);


--
-- TOC entry 3747 (class 2606 OID 90081)
-- Name: servis_puan kullanici_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_puan
    ADD CONSTRAINT kullanici_fk FOREIGN KEY (puanlayan_kullanici_id) REFERENCES public.kullanici(kullanici_id);


--
-- TOC entry 3730 (class 2606 OID 90001)
-- Name: lokasyon lokasyon_firma_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lokasyon
    ADD CONSTRAINT lokasyon_firma_id_fkey FOREIGN KEY (firma_id) REFERENCES public.firma(firma_id);


--
-- TOC entry 3754 (class 2606 OID 105963)
-- Name: oee_raporlari oee_raporlari_makine_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oee_raporlari
    ADD CONSTRAINT oee_raporlari_makine_id_fkey FOREIGN KEY (makine_id) REFERENCES public.makine(makine_id) ON DELETE CASCADE;


--
-- TOC entry 3749 (class 2606 OID 90091)
-- Name: servis_firma_uzmanlik servis_firma_uzmanlik_servis_firma_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servis_firma_uzmanlik
    ADD CONSTRAINT servis_firma_uzmanlik_servis_firma_id_fkey FOREIGN KEY (servis_firma_id) REFERENCES public.servis_firma(servis_firma_id);


--
-- TOC entry 3753 (class 2606 OID 90111)
-- Name: tedarikci_puan tk_tedarikci; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tedarikci_puan
    ADD CONSTRAINT tk_tedarikci FOREIGN KEY (tedarikci_id) REFERENCES public.tedarikci(tedarikci_id);


--
-- TOC entry 3998 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


-- Completed on 2026-05-01 15:15:50

--
-- PostgreSQL database dump complete
--

\unrestrict 95Q7seZddgXjUnEphSaDEljTYym7FqErcoS9os4wAAc4xSpXknX37YxJCnAdrvr

