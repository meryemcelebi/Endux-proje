-- ============================================================
-- CUSTOM SQL OBJECTS: Functions, Procedures, Triggers
-- Bu migration Prisma şemasında tanımlanamayan özel
-- PostgreSQL nesnelerini oluşturur.
-- ============================================================

-- ============================================================
-- 1. FUNCTIONS
-- ============================================================

-- Bakım girince arızayı otomatik kapat
CREATE OR REPLACE FUNCTION public.fn_bakim_girince_arizayi_kapat() RETURNS trigger
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

-- Kontrol formu sonrası tetikleme fonksiyonu
CREATE OR REPLACE FUNCTION public.func_form_sonrasi_tetikle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  -- Not: pr_makine_operator prosedürü mevcut değilse bu trigger hata verir.
  -- Gerekirse bu satırı düzenleyin.
  return NEW;
end;
$$;

-- Sorular getirme fonksiyonu
CREATE OR REPLACE FUNCTION public.get_sorular(p_makine_id integer) RETURNS TABLE(soru_tipi text, id integer, madde_adi text, teknik_parametre text, kritiklik_durumu boolean)
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


-- ============================================================
-- 2. PROCEDURES
-- ============================================================

-- Arıza kayıt prosedürü
CREATE OR REPLACE PROCEDURE public.pr_ariza_kayit(
    IN p_makine_adi character varying, 
    IN p_ariza_tur_adi character varying, 
    IN p_tespit_kaynagi character varying, 
    IN p_aciklama text, 
    IN p_baslangic_zamani date
)
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


-- Kontrol kaydetme prosedürü
CREATE OR REPLACE PROCEDURE public.pr_kontrol_kaydet(
    IN p_makine_id integer, 
    IN p_kullanici_id integer, 
    IN p_sablon_id integer, 
    IN p_genel_not text, 
    IN p_cevaplar jsonb
)
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


-- Bakım ekleme prosedürü
CREATE OR REPLACE PROCEDURE public.sp_bakim_ekle(
    IN p_makine_adi character varying, 
    IN p_bakim_yapan_telefon character varying, 
    IN p_servis_firma_adi character varying, 
    IN p_bakim_maliyet numeric, 
    IN p_aciklama text, 
    IN p_ariza_tanimi character varying, 
    IN p_bakim_turu_adi character varying, 
    IN p_durus_suresi numeric, 
    IN p_firma_telefon character varying, 
    IN p_degisen_parcalar text[] DEFAULT '{}'::text[]
)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_clean_makine_adi varchar := UPPER(TRIM(p_makine_adi));
    v_clean_bakim_telefon varchar := TRIM(p_bakim_yapan_telefon);
    v_clean_firma_adi varchar := UPPER(TRIM(p_servis_firma_adi));
    v_clean_ariza_tanimi varchar := UPPER(TRIM(p_ariza_tanimi));
    v_clean_bakim_turu varchar := UPPER(TRIM(p_bakim_turu_adi));
    v_clean_parca_adi varchar; 

    v_makine_id integer;
    v_sorumlu_id integer;       
    v_servis_firma_id integer;  
    v_ariza_id integer;         
    v_bakim_tur_id integer;     
    v_yeni_bakim_id integer;
    v_iletisim_id integer; 
    v_parca_id integer;
    v_parca_adi text;
BEGIN
    -- 1. MAKİNE KONTROLÜ
    SELECT makine_id INTO v_makine_id FROM public.makine WHERE UPPER(TRIM(makine_adi)) = v_clean_makine_adi;
    IF v_makine_id IS NULL THEN
        RAISE EXCEPTION 'İşlem durduruldu: "%" adında bir makine bulunamadı!', v_clean_makine_adi;
    END IF;

    -- 2. BAKIM YAPAN KİŞİ KONTROLÜ
    SELECT kullanici_id INTO v_sorumlu_id FROM public.kullanici WHERE UPPER(TRIM(telefon)) = v_clean_bakim_telefon;
    IF v_sorumlu_id IS NULL THEN
        SELECT sorumlu_id INTO v_sorumlu_id FROM public.servis_sorumlusu WHERE UPPER(TRIM(telefon)) = v_clean_bakim_telefon;
        IF v_sorumlu_id IS NULL THEN
            RAISE EXCEPTION 'İşlem durduruldu! "%" telefon numaralı personel bulunamadı.', v_clean_bakim_telefon;
        END IF;
    END IF;
        
    -- 3. SERVİS FİRMASI VE İLETİŞİM KONTROLÜ
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

    -- 4. ARIZA KAYDI KONTROLÜ
    IF v_clean_ariza_tanimi IS NOT NULL AND v_clean_ariza_tanimi <> '' THEN
        SELECT ak.ariza_id INTO v_ariza_id 
        FROM public.ariza_kaydi ak
        INNER JOIN public.ariza_turu at2 ON at2.ariza_tur_id = ak.ariza_tur_id
        WHERE UPPER(TRIM(at2.ariza_tur)) = v_clean_ariza_tanimi
        LIMIT 1;
        IF v_ariza_id IS NULL THEN 
            RAISE NOTICE 'Girilen arıza tanımı sistemde bulunamadı, ariza_id boş geçiliyor.';
            v_ariza_id := NULL;
        END IF;
    ELSE
        v_ariza_id := NULL;
    END IF;

    -- 5. BAKIM TÜRÜ KONTROLÜ
    SELECT bakim_tur_id INTO v_bakim_tur_id FROM public.bakim_turu WHERE UPPER(TRIM(bakim_tur_adi)) = v_clean_bakim_turu;
    IF v_bakim_tur_id IS NULL THEN
        INSERT INTO public.bakim_turu (bakim_tur_adi) VALUES (v_clean_bakim_turu) RETURNING bakim_tur_id INTO v_bakim_tur_id;
    END IF;

    -- 6. BAKIM KAYDINI OLUŞTUR
    INSERT INTO public.bakim_kaydi (
        makine_id, sorumlu_id, servis_firma_id, bakim_tarihi,
        bakim_maliyet, aciklama, ariza_id, bakim_tur_id, durus_suresi
    ) VALUES (
        v_makine_id, v_sorumlu_id, v_servis_firma_id, CURRENT_TIMESTAMP, 
        p_bakim_maliyet, p_aciklama, v_ariza_id, v_bakim_tur_id, p_durus_suresi
    ) RETURNING bakim_id INTO v_yeni_bakim_id;

    -- 7. DEĞİŞEN PARÇALARI EKLE
    IF array_length(p_degisen_parcalar, 1) > 0 THEN
        FOREACH v_parca_adi IN ARRAY p_degisen_parcalar
        LOOP
            v_clean_parca_adi := UPPER(TRIM(v_parca_adi)); 
            SELECT parca_id INTO v_parca_id FROM public.parca
            WHERE UPPER(TRIM(parca_adi)) = v_clean_parca_adi LIMIT 1;

            IF v_parca_id IS NULL THEN
                RAISE EXCEPTION 'Kayıt Hatası: "%" isimli parça sistemde tanımlı değil!', v_clean_parca_adi;
            END IF;

            INSERT INTO public.parca_degisim (bakim_id, parca_id)
            VALUES (v_yeni_bakim_id, v_parca_id);
        END LOOP;
    END IF;
END;
$$;


-- Garanti firması kaydetme prosedürü
CREATE OR REPLACE PROCEDURE public.sp_garanti_firmasi_kaydet(
    IN p_garanti_firma_adi character varying, 
    IN p_telefon character varying, 
    IN p_email character varying, 
    IN p_il character varying, 
    IN p_ilce character varying, 
    IN p_acik_adres character varying, 
    INOUT p_out_garanti_firma_id integer DEFAULT NULL::integer
)
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


-- Makine temel kaydetme prosedürü
CREATE OR REPLACE PROCEDURE public.sp_makine_temel_kaydet(
    IN p_firma_adi character varying, 
    IN p_makine_tur_adi character varying, 
    IN p_makine_ad character varying, 
    IN p_makine_qr character varying, 
    IN p_seri_no character varying, 
    IN p_satin_alma_tarihi date, 
    IN p_satin_alma_maliyeti numeric, 
    IN p_garanti_suresi integer, 
    IN p_toplam_calisma_saati integer, 
    IN p_risk_katsayisi numeric, 
    IN p_servis_pin integer, 
    IN p_teknik_ozellikler jsonb, 
    IN p_telefon character varying DEFAULT NULL, 
    IN p_email character varying DEFAULT NULL, 
    IN p_il character varying DEFAULT NULL, 
    IN p_ilce character varying DEFAULT NULL, 
    IN p_acik_adres character varying DEFAULT NULL
)
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


-- Parça ekleme prosedürü
CREATE OR REPLACE PROCEDURE public.sp_parca_ekle(
    IN p_parca_adi text, 
    IN p_tahmini_omur_saati numeric, 
    IN p_parca_maliyeti integer, 
    IN p_parca_adeti integer, 
    IN p_tedarik_gun_suresi integer, 
    IN p_kategori_adi character varying, 
    IN p_tedarikci_firma_adi character varying
)
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
    IF EXISTS (SELECT 1 FROM public.parca WHERE UPPER(TRIM(parca_adi)) = v_clean_parca_adi) THEN
        RAISE EXCEPTION 'HATA: % isimli parça zaten mevcut!', v_clean_parca_adi;
    END IF;

    SELECT kategori_id INTO v_kategori_id FROM public.parca_kategori 
    WHERE UPPER(TRIM(kategori_adi)) = v_clean_kategori_adi;
    IF v_kategori_id IS NULL THEN
        INSERT INTO public.parca_kategori (kategori_adi) VALUES (v_clean_kategori_adi)
        RETURNING kategori_id INTO v_kategori_id;
    END IF;

    SELECT tedarikci_id INTO v_tedarikci_id FROM public.tedarikci 
    WHERE UPPER(TRIM(firma_adi)) = v_clean_tedarikci_adi;
    IF v_tedarikci_id IS NULL THEN
        RAISE EXCEPTION 'Kayıt Başarısız: "%" isimli tedarikçi sistemde kayıtlı değil!', v_clean_tedarikci_adi;
    END IF;

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


-- Tedarikçi ekleme prosedürü
CREATE OR REPLACE PROCEDURE public.sp_tedarikci_ekle(
    IN p_firma_adi character varying, 
    IN p_telefon character varying, 
    IN p_mail character varying, 
    IN p_il character varying, 
    IN p_ilce character varying, 
    IN p_acik_adres text, 
    IN p_vergi_no character varying, 
    IN p_yetkili_kisi character varying
)
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


-- ============================================================
-- 3. TRIGGERS
-- ============================================================

-- Bakım girişinde arızayı otomatik kapatma trigger'ı
CREATE OR REPLACE TRIGGER trg_bakim_ariza_kapat
    AFTER INSERT ON public.bakim_kaydi
    FOR EACH ROW
    WHEN (NEW.ariza_id IS NOT NULL)
    EXECUTE FUNCTION public.fn_bakim_girince_arizayi_kapat();
