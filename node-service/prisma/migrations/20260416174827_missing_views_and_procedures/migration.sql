-- ============================================================
-- MISSING VIEWS AND PROCEDURES
-- ============================================================

-- ============================================================
-- 1. PROCEDURE
-- ============================================================
CREATE OR REPLACE PROCEDURE public.pr_makine_operator(p_operator_id INT, p_makine_id INT)
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
$$ LANGUAGE plpgsql;

-- Trigger içerisinde çağrımı düzeltmek adına func_form_sonrasi_tetikle revizyonu:
CREATE OR REPLACE FUNCTION public.func_form_sonrasi_tetikle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  -- Yeni eklenen form_id, kullanim kaydına tekabül etmediğinden, prosedürü kullanici_id ile besliyoruz:
  call pr_makine_operator(NEW.kullanici_id, NEW.makine_id);
  
  update public.makine  
  set mevcut_risk_skoru = NEW.ai_on_risk_durumu
  where makine_id = NEW.makine_id;
  
  return NEW;
end;
$$;


-- ============================================================
-- 2. VIEWS (10 ADET)
-- ============================================================

CREATE OR REPLACE VIEW public.v_dashboard_bakim_rapor AS
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

CREATE OR REPLACE VIEW public.v_parca_detay_listesi AS
 SELECT p.parca_id,
    p.parca_adi AS "PARÇA ADI",
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

CREATE OR REPLACE VIEW public.view_dashboard_bakim_bekleyenler AS
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

CREATE OR REPLACE VIEW public.view_dashboard_kritik_uyarilar AS
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

CREATE OR REPLACE VIEW public.view_dashboard_makine_masraf_detayli AS
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

CREATE OR REPLACE VIEW public.view_dashboard_masraf_analizi AS
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

CREATE OR REPLACE VIEW public.view_garanti_firmalari AS
 SELECT gf.firma_adi AS "Garanti Firması Adı",
    i.telefon AS "Telefon",
    i.mail AS "E-posta",
    i.il AS "İl",
    i.ilce AS "İlçe",
    i.acik_adres AS "Açık Adres"
   FROM (public.garanti_firma gf
     LEFT JOIN public.iletisim i ON ((gf.iletisim_id = i.iletisim_id)));

CREATE OR REPLACE VIEW public.view_makineler AS
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

CREATE OR REPLACE VIEW public.view_operator_makine_ozeti AS
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

CREATE OR REPLACE VIEW public.view_teknisyen_bakim_ozeti AS
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