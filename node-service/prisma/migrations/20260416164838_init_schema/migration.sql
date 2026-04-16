-- CreateEnum
CREATE TYPE "du_ort_yuk" AS ENUM ('DUSUK', 'ORTA', 'YUKSEK');

-- CreateTable
CREATE TABLE "kullanici" (
    "kullanici_id" SERIAL NOT NULL,
    "firma_id" INTEGER NOT NULL,
    "rol_id" INTEGER NOT NULL,
    "ad" VARCHAR(50) NOT NULL,
    "soyad" VARCHAR(50) NOT NULL,
    "telefon" VARCHAR(20) NOT NULL,
    "eposta" VARCHAR(100),
    "sifre" VARCHAR(255) NOT NULL,
    "aktiflik" BOOLEAN,
    "baslama_tarihi" DATE,
    "kullanici_adi" VARCHAR NOT NULL,

    CONSTRAINT "kullanici_pkey" PRIMARY KEY ("kullanici_id")
);

-- CreateTable
CREATE TABLE "ai_ariza_tespit" (
    "tespit_id" SERIAL NOT NULL,
    "makine_id" INTEGER NOT NULL,
    "form_id" INTEGER NOT NULL,
    "madde_id" INTEGER NOT NULL,
    "tahmin_edilen_ariza" VARCHAR(200),
    "risk_skoru" DECIMAL(3,2),
    "tespit_tarihi" TIMESTAMPTZ(6),
    "model_versiyon" VARCHAR(100),
    "tahmini_durus_suresi" DECIMAL(6,2),
    "tahmini_maliyet" DECIMAL(12,2),

    CONSTRAINT "ai_ariza_tespit_pkey" PRIMARY KEY ("tespit_id")
);

-- CreateTable
CREATE TABLE "ai_model_log" (
    "log_id" SERIAL NOT NULL,
    "makine_id" INTEGER NOT NULL,
    "model_versiyon" VARCHAR(100),
    "kullanilan_veri_sayisi" INTEGER,
    "tahmin_risk" DECIMAL(5,2),
    "tahmin_tarihi" TIMESTAMPTZ(6),
    "kullanici_id" INTEGER NOT NULL,
    "form_id" INTEGER,

    CONSTRAINT "ai_model_log_pkey" PRIMARY KEY ("log_id")
);

-- CreateTable
CREATE TABLE "ariza_kaydi" (
    "ariza_id" SERIAL NOT NULL,
    "makine_id" INTEGER NOT NULL,
    "ariza_tespit_kaynagi" VARCHAR(100) NOT NULL,
    "ariza_aciklama" TEXT,
    "baslangic_zamani" TIMESTAMPTZ(6),
    "bitis_zamani" TIMESTAMPTZ(6),
    "olusturma_tarihi" TIMESTAMPTZ(6),
    "ariza_tur_id" INTEGER NOT NULL,
    "makine_adi" VARCHAR(50),

    CONSTRAINT "ariza_kaydi_pkey" PRIMARY KEY ("ariza_id")
);

-- CreateTable
CREATE TABLE "arizayi_tetikleyen_form" (
    "tetik_id" SERIAL NOT NULL,
    "ariza_id" INTEGER NOT NULL,
    "form_id" INTEGER NOT NULL,
    "madde_id" INTEGER NOT NULL,
    "tetikleyici_deger" VARCHAR(100),
    "sapma_orani" DECIMAL(3,2),
    "ai_tespit_mi" BOOLEAN,
    "tespit_tarihi" TIMESTAMPTZ(6),
    "aciklama" TEXT,

    CONSTRAINT "arizayi_tetikleyen_form_pkey" PRIMARY KEY ("tetik_id")
);

-- CreateTable
CREATE TABLE "bakim_kaydi" (
    "bakim_id" SERIAL NOT NULL,
    "makine_id" INTEGER NOT NULL,
    "sorumlu_id" INTEGER,
    "servis_firma_id" INTEGER NOT NULL,
    "bakim_tarihi" TIMESTAMPTZ(6) DEFAULT CURRENT_TIMESTAMP,
    "bakim_maliyet" DECIMAL NOT NULL,
    "aciklama" TEXT,
    "ariza_id" INTEGER,
    "bakim_tur_id" INTEGER,
    "durus_suresi" DECIMAL(15,2),
    "kullanici_id" INTEGER,

    CONSTRAINT "bakim_kaydi_pkey" PRIMARY KEY ("bakim_id")
);

-- CreateTable
CREATE TABLE "firma" (
    "firma_id" SERIAL NOT NULL,
    "firma_adi" VARCHAR(255) NOT NULL,
    "vergi_no" VARCHAR(30),
    "aktif_mi" BOOLEAN,
    "abonelik_tip_id" INTEGER,
    "iletisim_id" INTEGER,
    "sektor_id" INTEGER,

    CONSTRAINT "firma_pkey" PRIMARY KEY ("firma_id")
);

-- CreateTable
CREATE TABLE "form_madde_cevap" (
    "cevap_id" SERIAL NOT NULL,
    "form_id" INTEGER NOT NULL,
    "soru_referans_id" INTEGER NOT NULL,
    "durum" VARCHAR(100),
    "aciklama" TEXT,
    "girilen_deger" VARCHAR(50),

    CONSTRAINT "form_madde_cevap_pkey" PRIMARY KEY ("cevap_id")
);

-- CreateTable
CREATE TABLE "gunluk_kontrol_formu" (
    "form_id" SERIAL NOT NULL,
    "makine_id" INTEGER NOT NULL,
    "kullanici_id" INTEGER NOT NULL,
    "sablon_id" INTEGER NOT NULL,
    "kontrol_tarihi" DATE NOT NULL,
    "genel_not" TEXT,
    "ai_on_risk_durumu" DECIMAL(5,2),

    CONSTRAINT "gunluk_kontrol_formu_pkey" PRIMARY KEY ("form_id")
);

-- CreateTable
CREATE TABLE "kontrol_maddesi" (
    "madde_id" SERIAL NOT NULL,
    "sablon_id" INTEGER NOT NULL,
    "madde_adi" VARCHAR(150),
    "teknik_parametre" VARCHAR(150),
    "kritiklik_durumu" BOOLEAN,

    CONSTRAINT "kontrol_maddesi_pkey" PRIMARY KEY ("madde_id")
);

-- CreateTable
CREATE TABLE "kontrol_sablonu" (
    "sablon_id" SERIAL NOT NULL,
    "makine_tur_id" INTEGER NOT NULL,
    "sablon_adi" VARCHAR(150),
    "aciklama" TEXT,
    "aktiflik" BOOLEAN NOT NULL,

    CONSTRAINT "kontrol_sablonu_pkey" PRIMARY KEY ("sablon_id")
);

-- CreateTable
CREATE TABLE "lokasyon" (
    "lokasyon_id" SERIAL NOT NULL,
    "fabrika_alani" VARCHAR(150) NOT NULL,
    "kat" VARCHAR(5) NOT NULL,
    "x_koor" DECIMAL NOT NULL,
    "y_koor" DECIMAL NOT NULL,
    "guncelleme_tarihi" TIMESTAMPTZ(6),
    "firma_id" INTEGER,
    "makine_id" INTEGER,

    CONSTRAINT "lokasyon_pkey" PRIMARY KEY ("lokasyon_id")
);

-- CreateTable
CREATE TABLE "makine" (
    "makine_id" SERIAL NOT NULL,
    "firma_id" INTEGER NOT NULL,
    "makine_tur_id" INTEGER NOT NULL,
    "makine_qr" VARCHAR(100),
    "makine_adi" VARCHAR(100),
    "satin_alma_tarihi" DATE,
    "satin_alma_maliyeti" DECIMAL(15,4),
    "aktiflik_durumu" BOOLEAN,
    "seri_no" VARCHAR(150),
    "garanti_suresi" INTEGER,
    "garanti_firma_id" INTEGER,
    "servis_pin" INTEGER,
    "toplam_calisma_saati" DECIMAL(10,2) DEFAULT 0,

    CONSTRAINT "makine_pkey" PRIMARY KEY ("makine_id")
);

-- CreateTable
CREATE TABLE "makine_kullanim" (
    "kullanim_id" SERIAL NOT NULL,
    "kullanici_id" INTEGER NOT NULL,
    "makine_id" INTEGER NOT NULL,
    "baslangic_zamani" TIMESTAMPTZ(6) NOT NULL,
    "bitis_zamani" TIMESTAMPTZ(6) NOT NULL,
    "gunluk_top_calisma_saati" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "operator_makine_pkey" PRIMARY KEY ("kullanim_id")
);

-- CreateTable
CREATE TABLE "makine_turu" (
    "makine_tur_id" SERIAL NOT NULL,
    "makine_tur_adi" VARCHAR(50) NOT NULL,
    "risk_katsayisi" DECIMAL(5,2),

    CONSTRAINT "makine_turu_pkey" PRIMARY KEY ("makine_tur_id")
);

-- CreateTable
CREATE TABLE "parca" (
    "parca_id" SERIAL NOT NULL,
    "parca_adi" VARCHAR(100) NOT NULL,
    "tahmini_omur_saati" DECIMAL(8,2) NOT NULL,
    "parca_maliyeti" INTEGER NOT NULL,
    "tedarik_gun_suresi" INTEGER NOT NULL,
    "kategori_id" INTEGER,
    "tedarikci_id" INTEGER NOT NULL,

    CONSTRAINT "parca_pkey" PRIMARY KEY ("parca_id")
);

-- CreateTable
CREATE TABLE "parca_degisim" (
    "parca_degisim_id" SERIAL NOT NULL,
    "bakim_id" INTEGER NOT NULL,
    "parca_id" INTEGER,

    CONSTRAINT "parca_degisim_pkey" PRIMARY KEY ("parca_degisim_id")
);

-- CreateTable
CREATE TABLE "risk_skoru" (
    "risk_id" SERIAL NOT NULL,
    "makine_id" INTEGER NOT NULL,
    "risk_skoru" DECIMAL(5,2),
    "risk_seviyesi" "du_ort_yuk" NOT NULL,
    "hesaplama_tarihi" TIMESTAMPTZ(6),

    CONSTRAINT "risk_skoru_pkey" PRIMARY KEY ("risk_id")
);

-- CreateTable
CREATE TABLE "rol" (
    "rol_id" SERIAL NOT NULL,
    "rol_adi" VARCHAR NOT NULL,

    CONSTRAINT "rol_pkey" PRIMARY KEY ("rol_id")
);

-- CreateTable
CREATE TABLE "servis_firma" (
    "servis_firma_id" SERIAL NOT NULL,
    "firma_adi" VARCHAR(100) NOT NULL,
    "aktiflik" BOOLEAN NOT NULL,
    "iletisim_id" INTEGER,

    CONSTRAINT "servis_firma_pkey" PRIMARY KEY ("servis_firma_id")
);

-- CreateTable
CREATE TABLE "tedarikci" (
    "tedarikci_id" SERIAL NOT NULL,
    "firma_adi" VARCHAR(200) NOT NULL,
    "aktiflik" BOOLEAN NOT NULL,
    "guvenilirlik_skoru" DECIMAL(5,2),
    "vergi_no" VARCHAR(155),
    "yetkili_kisi" VARCHAR(100),
    "kayit_tarihi" TIMESTAMPTZ(6),
    "iletisim_id" INTEGER,

    CONSTRAINT "tedarikci_pkey" PRIMARY KEY ("tedarikci_id")
);

-- CreateTable
CREATE TABLE "ariza_turu" (
    "ariza_tur_id" SERIAL NOT NULL,
    "ariza_tur" VARCHAR(150) NOT NULL,

    CONSTRAINT "ariza_turu_pkey" PRIMARY KEY ("ariza_tur_id")
);

-- CreateTable
CREATE TABLE "garanti_firma" (
    "garanti_firma_id" SERIAL NOT NULL,
    "firma_adi" VARCHAR(150),
    "iletisim_id" INTEGER,

    CONSTRAINT "garanti_firma_pkey" PRIMARY KEY ("garanti_firma_id")
);

-- CreateTable
CREATE TABLE "genel_sorular" (
    "genel_soru_id" SERIAL NOT NULL,
    "madde_adi" VARCHAR(255),
    "teknik_parametre" VARCHAR(200),
    "aktiflik" BOOLEAN,
    "kritiklik_durumu" BOOLEAN,

    CONSTRAINT "genel_sorular_pkey" PRIMARY KEY ("genel_soru_id")
);

-- CreateTable
CREATE TABLE "makine_ozellikleri" (
    "ozellik_id" SERIAL NOT NULL,
    "makine_id" INTEGER NOT NULL,
    "teknik_ozellikler" JSONB,
    "guncelleme_tarihi" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "makine_ozellikleri_pkey" PRIMARY KEY ("ozellik_id")
);

-- CreateTable
CREATE TABLE "servis_puan" (
    "puan_id" SERIAL NOT NULL,
    "servis_firma_id" INTEGER NOT NULL,
    "puanlayan_kullanici_id" INTEGER NOT NULL,
    "puan" INTEGER NOT NULL,
    "yorum" TEXT,
    "tarih" DATE,

    CONSTRAINT "servis_puan_pkey" PRIMARY KEY ("puan_id")
);

-- CreateTable
CREATE TABLE "servis_sorumlusu" (
    "sorumlu_id" SERIAL NOT NULL,
    "servis_firma_id" INTEGER NOT NULL,
    "ad" VARCHAR(55) NOT NULL,
    "soyad" VARCHAR(55) NOT NULL,
    "telefon" VARCHAR(20) NOT NULL,
    "aktiflik" BOOLEAN,
    "unvan" VARCHAR,
    "sorumlu_adi" VARCHAR(100),

    CONSTRAINT "servis_sorumlusu_pkey" PRIMARY KEY ("sorumlu_id")
);

-- CreateTable
CREATE TABLE "abonelik_tipi" (
    "abonelik_tip_id" SERIAL NOT NULL,
    "abonelik_adi" VARCHAR(50) NOT NULL,

    CONSTRAINT "abonelik_tipi_pkey" PRIMARY KEY ("abonelik_tip_id")
);

-- CreateTable
CREATE TABLE "bakim_turu" (
    "bakim_tur_id" SERIAL NOT NULL,
    "bakim_tur_adi" VARCHAR(55) NOT NULL,

    CONSTRAINT "bakim_turu_pkey" PRIMARY KEY ("bakim_tur_id")
);

-- CreateTable
CREATE TABLE "iletisim" (
    "iletisim_id" SERIAL NOT NULL,
    "telefon" VARCHAR(20),
    "mail" VARCHAR(200),
    "il" VARCHAR(50),
    "ilce" VARCHAR(100),
    "acik_adres" TEXT,

    CONSTRAINT "iletisim_pkey" PRIMARY KEY ("iletisim_id")
);

-- CreateTable
CREATE TABLE "parca_kategori" (
    "kategori_id" SERIAL NOT NULL,
    "kategori_adi" VARCHAR(155),

    CONSTRAINT "parca_kategori_pkey" PRIMARY KEY ("kategori_id")
);

-- CreateTable
CREATE TABLE "sektor" (
    "sektor_id" SERIAL NOT NULL,
    "sektor_adi" VARCHAR(150) NOT NULL,

    CONSTRAINT "sektor_pkey" PRIMARY KEY ("sektor_id")
);

-- CreateTable
CREATE TABLE "servis_firma_uzmanlik" (
    "servis_firma_id" INTEGER NOT NULL,
    "uzmanlik_adi" VARCHAR NOT NULL,

    CONSTRAINT "servis_firma_uzmanlik_pkey" PRIMARY KEY ("servis_firma_id")
);

-- CreateTable
CREATE TABLE "tedarikci_parca" (
    "tedarikci_parca_id" SERIAL NOT NULL,
    "tedarik_id" INTEGER NOT NULL,
    "parca_id" INTEGER NOT NULL,
    "tedarik_maliyeti" DECIMAL(15,3) NOT NULL,

    CONSTRAINT "tedarikci_parca_pkey" PRIMARY KEY ("tedarikci_parca_id")
);

-- CreateTable
CREATE TABLE "tedarikci_puan" (
    "puan_id" SERIAL NOT NULL,
    "tedarikci_id" INTEGER NOT NULL,
    "puanlayan_kullanici_id" INTEGER NOT NULL,
    "puan" INTEGER,
    "yorum" TEXT,
    "tarih" DATE,

    CONSTRAINT "tedarakci_puan_pkey" PRIMARY KEY ("puan_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "idx_kullanici_eposta" ON "kullanici"("eposta");

-- CreateIndex
CREATE UNIQUE INDEX "unique_kullanici" ON "kullanici"("kullanici_adi");

-- CreateIndex
CREATE INDEX "idx_kullanici_firma_id" ON "kullanici"("firma_id");

-- CreateIndex
CREATE INDEX "idx_kullanici_rol_id" ON "kullanici"("rol_id");

-- CreateIndex
CREATE INDEX "idx_kullanici_adi" ON "kullanici"("kullanici_adi");

-- CreateIndex
CREATE INDEX "idx_tespit_form" ON "ai_ariza_tespit"("form_id");

-- CreateIndex
CREATE INDEX "idx_tespit_madde" ON "ai_ariza_tespit"("madde_id");

-- CreateIndex
CREATE INDEX "idx_tespit_makine" ON "ai_ariza_tespit"("makine_id");

-- CreateIndex
CREATE INDEX "idx_m_ariza" ON "ariza_kaydi"("makine_id");

-- CreateIndex
CREATE INDEX "idx_ariza_tarih" ON "ariza_kaydi"("baslangic_zamani");

-- CreateIndex
CREATE INDEX "idx_tetik_form" ON "arizayi_tetikleyen_form"("form_id");

-- CreateIndex
CREATE INDEX "idx_tetik_madde" ON "arizayi_tetikleyen_form"("madde_id");

-- CreateIndex
CREATE INDEX "idx_tetik_tarih" ON "arizayi_tetikleyen_form"("tespit_tarihi");

-- CreateIndex
CREATE INDEX "idx_bakim_makine" ON "bakim_kaydi"("makine_id");

-- CreateIndex
CREATE INDEX "idx_bakim_servis" ON "bakim_kaydi"("servis_firma_id");

-- CreateIndex
CREATE INDEX "idx_bakim_teknisyen" ON "bakim_kaydi"("sorumlu_id");

-- CreateIndex
CREATE UNIQUE INDEX "uq_vergi_no" ON "firma"("vergi_no");

-- CreateIndex
CREATE INDEX "idx_cevap_form" ON "form_madde_cevap"("form_id");

-- CreateIndex
CREATE INDEX "idx_cevap_madde" ON "form_madde_cevap"("soru_referans_id");

-- CreateIndex
CREATE INDEX "idx_makine_id" ON "gunluk_kontrol_formu"("makine_id");

-- CreateIndex
CREATE INDEX "idx_operator_id" ON "gunluk_kontrol_formu"("kullanici_id");

-- CreateIndex
CREATE INDEX "idx_sablon_id" ON "gunluk_kontrol_formu"("sablon_id");

-- CreateIndex
CREATE INDEX "idx_tarih" ON "gunluk_kontrol_formu"("kontrol_tarihi");

-- CreateIndex
CREATE INDEX "idx_kontrol_sablon" ON "kontrol_maddesi"("sablon_id");

-- CreateIndex
CREATE INDEX "idx_kontrol_madde" ON "kontrol_maddesi"("madde_id");

-- CreateIndex
CREATE INDEX "idx_sablon_m_turu" ON "kontrol_sablonu"("makine_tur_id");

-- CreateIndex
CREATE UNIQUE INDEX "uq_makine_qr" ON "makine"("makine_qr");

-- CreateIndex
CREATE UNIQUE INDEX "uq_seri_no" ON "makine"("seri_no");

-- CreateIndex
CREATE INDEX "idx_makine_firma" ON "makine"("firma_id");

-- CreateIndex
CREATE INDEX "idx_makine_turu" ON "makine"("makine_tur_id");

-- CreateIndex
CREATE INDEX "idx_m_qr" ON "makine"("makine_qr");

-- CreateIndex
CREATE INDEX "idx_makine_kullanim_kullanici_id" ON "makine_kullanim"("kullanici_id");

-- CreateIndex
CREATE INDEX "idx_makine_kullanim_baslangic" ON "makine_kullanim"("baslangic_zamani");

-- CreateIndex
CREATE INDEX "idx_mkullanim_makine" ON "makine_kullanim"("makine_id");

-- CreateIndex
CREATE UNIQUE INDEX "parca_adi" ON "parca"("parca_adi");

-- CreateIndex
CREATE INDEX "idx_degisim_bakim" ON "parca_degisim"("bakim_id");

-- CreateIndex
CREATE INDEX "idx_risk_makine" ON "risk_skoru"("makine_id");

-- CreateIndex
CREATE INDEX "idx_risk_tarih" ON "risk_skoru"("hesaplama_tarihi");

-- CreateIndex
CREATE UNIQUE INDEX "makine_ozellikleri_makine_id_key" ON "makine_ozellikleri"("makine_id");

-- CreateIndex
CREATE INDEX "idx_spuan_firma" ON "servis_puan"("servis_firma_id");

-- CreateIndex
CREATE INDEX "idx_spuan_kullanici" ON "servis_puan"("puanlayan_kullanici_id");

-- CreateIndex
CREATE UNIQUE INDEX "unique_telefon" ON "iletisim"("telefon");

-- CreateIndex
CREATE UNIQUE INDEX "unique_kategori_adi" ON "parca_kategori"("kategori_adi");

-- CreateIndex
CREATE INDEX "idx_tpuan_tedarikci" ON "tedarikci_puan"("tedarikci_id");

-- AddForeignKey
ALTER TABLE "kullanici" ADD CONSTRAINT "fk_firma" FOREIGN KEY ("firma_id") REFERENCES "firma"("firma_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "kullanici" ADD CONSTRAINT "fk_rol" FOREIGN KEY ("rol_id") REFERENCES "rol"("rol_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "ai_ariza_tespit" ADD CONSTRAINT "fk_form" FOREIGN KEY ("form_id") REFERENCES "gunluk_kontrol_formu"("form_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "ai_ariza_tespit" ADD CONSTRAINT "fk_madde" FOREIGN KEY ("madde_id") REFERENCES "kontrol_maddesi"("madde_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "ai_ariza_tespit" ADD CONSTRAINT "fk_makine" FOREIGN KEY ("makine_id") REFERENCES "makine"("makine_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "ai_model_log" ADD CONSTRAINT "fk_ai_log" FOREIGN KEY ("makine_id") REFERENCES "makine"("makine_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "ai_model_log" ADD CONSTRAINT "fk_form" FOREIGN KEY ("form_id") REFERENCES "gunluk_kontrol_formu"("form_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "ai_model_log" ADD CONSTRAINT "fk_kullanici" FOREIGN KEY ("kullanici_id") REFERENCES "kullanici"("kullanici_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "ariza_kaydi" ADD CONSTRAINT "fk_ariza_tur" FOREIGN KEY ("ariza_tur_id") REFERENCES "ariza_turu"("ariza_tur_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "ariza_kaydi" ADD CONSTRAINT "fk_makine" FOREIGN KEY ("makine_id") REFERENCES "makine"("makine_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "arizayi_tetikleyen_form" ADD CONSTRAINT "fk_ariza" FOREIGN KEY ("ariza_id") REFERENCES "ariza_kaydi"("ariza_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "arizayi_tetikleyen_form" ADD CONSTRAINT "fk_form" FOREIGN KEY ("form_id") REFERENCES "gunluk_kontrol_formu"("form_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "arizayi_tetikleyen_form" ADD CONSTRAINT "fk_madde" FOREIGN KEY ("madde_id") REFERENCES "kontrol_maddesi"("madde_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "bakim_kaydi" ADD CONSTRAINT "fk_ariza" FOREIGN KEY ("ariza_id") REFERENCES "ariza_kaydi"("ariza_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "bakim_kaydi" ADD CONSTRAINT "fk_bakim" FOREIGN KEY ("bakim_tur_id") REFERENCES "bakim_turu"("bakim_tur_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "bakim_kaydi" ADD CONSTRAINT "fk_makine" FOREIGN KEY ("makine_id") REFERENCES "makine"("makine_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "bakim_kaydi" ADD CONSTRAINT "fk_servis" FOREIGN KEY ("servis_firma_id") REFERENCES "servis_firma"("servis_firma_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "firma" ADD CONSTRAINT "fk_abonelik" FOREIGN KEY ("abonelik_tip_id") REFERENCES "abonelik_tipi"("abonelik_tip_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "firma" ADD CONSTRAINT "fk_iletisim" FOREIGN KEY ("iletisim_id") REFERENCES "iletisim"("iletisim_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "firma" ADD CONSTRAINT "fk_sektor" FOREIGN KEY ("sektor_id") REFERENCES "sektor"("sektor_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "form_madde_cevap" ADD CONSTRAINT "fk_form" FOREIGN KEY ("form_id") REFERENCES "gunluk_kontrol_formu"("form_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "form_madde_cevap" ADD CONSTRAINT "fk_madde" FOREIGN KEY ("soru_referans_id") REFERENCES "kontrol_maddesi"("madde_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "gunluk_kontrol_formu" ADD CONSTRAINT "fk_kullanici" FOREIGN KEY ("kullanici_id") REFERENCES "kullanici"("kullanici_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "gunluk_kontrol_formu" ADD CONSTRAINT "fk_makine" FOREIGN KEY ("makine_id") REFERENCES "makine"("makine_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "gunluk_kontrol_formu" ADD CONSTRAINT "fk_sablon" FOREIGN KEY ("sablon_id") REFERENCES "kontrol_sablonu"("sablon_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "kontrol_sablonu" ADD CONSTRAINT "fk_sablon_kontrol" FOREIGN KEY ("makine_tur_id") REFERENCES "makine_turu"("makine_tur_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "lokasyon" ADD CONSTRAINT "fk_makine" FOREIGN KEY ("makine_id") REFERENCES "makine"("makine_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "lokasyon" ADD CONSTRAINT "lokasyon_firma_id_fkey" FOREIGN KEY ("firma_id") REFERENCES "firma"("firma_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "makine" ADD CONSTRAINT "fk_firma" FOREIGN KEY ("firma_id") REFERENCES "firma"("firma_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "makine" ADD CONSTRAINT "fk_garanti_id" FOREIGN KEY ("garanti_firma_id") REFERENCES "garanti_firma"("garanti_firma_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "makine" ADD CONSTRAINT "fk_makine_turu" FOREIGN KEY ("makine_tur_id") REFERENCES "makine_turu"("makine_tur_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "makine_kullanim" ADD CONSTRAINT "fk_kullanici" FOREIGN KEY ("kullanici_id") REFERENCES "kullanici"("kullanici_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "makine_kullanim" ADD CONSTRAINT "fk_makine" FOREIGN KEY ("makine_id") REFERENCES "makine"("makine_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "parca" ADD CONSTRAINT "fk_kategori" FOREIGN KEY ("kategori_id") REFERENCES "parca_kategori"("kategori_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "parca" ADD CONSTRAINT "fk_tedarikci" FOREIGN KEY ("tedarikci_id") REFERENCES "tedarikci"("tedarikci_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "parca_degisim" ADD CONSTRAINT "fk_bakim" FOREIGN KEY ("bakim_id") REFERENCES "bakim_kaydi"("bakim_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "parca_degisim" ADD CONSTRAINT "fk_parca" FOREIGN KEY ("parca_id") REFERENCES "parca"("parca_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "risk_skoru" ADD CONSTRAINT "fk_makine" FOREIGN KEY ("makine_id") REFERENCES "makine"("makine_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "servis_firma" ADD CONSTRAINT "fk_iletisim" FOREIGN KEY ("iletisim_id") REFERENCES "iletisim"("iletisim_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "tedarikci" ADD CONSTRAINT "fk_iletisim" FOREIGN KEY ("iletisim_id") REFERENCES "iletisim"("iletisim_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "garanti_firma" ADD CONSTRAINT "fk_iletisim" FOREIGN KEY ("iletisim_id") REFERENCES "iletisim"("iletisim_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "makine_ozellikleri" ADD CONSTRAINT "fk_makine" FOREIGN KEY ("makine_id") REFERENCES "makine"("makine_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "servis_puan" ADD CONSTRAINT "firma_fk" FOREIGN KEY ("servis_firma_id") REFERENCES "servis_firma"("servis_firma_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "servis_puan" ADD CONSTRAINT "kullanici_fk" FOREIGN KEY ("puanlayan_kullanici_id") REFERENCES "kullanici"("kullanici_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "servis_sorumlusu" ADD CONSTRAINT "fk_sorumlusu" FOREIGN KEY ("servis_firma_id") REFERENCES "servis_firma"("servis_firma_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "servis_firma_uzmanlik" ADD CONSTRAINT "servis_firma_uzmanlik_servis_firma_id_fkey" FOREIGN KEY ("servis_firma_id") REFERENCES "servis_firma"("servis_firma_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "tedarikci_parca" ADD CONSTRAINT "fk_parca" FOREIGN KEY ("parca_id") REFERENCES "parca"("parca_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "tedarikci_parca" ADD CONSTRAINT "fk_tedarikci" FOREIGN KEY ("tedarik_id") REFERENCES "tedarikci"("tedarikci_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "tedarikci_puan" ADD CONSTRAINT "fk_kullanici" FOREIGN KEY ("puanlayan_kullanici_id") REFERENCES "kullanici"("kullanici_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "tedarikci_puan" ADD CONSTRAINT "tk_tedarikci" FOREIGN KEY ("tedarikci_id") REFERENCES "tedarikci"("tedarikci_id") ON DELETE NO ACTION ON UPDATE NO ACTION;
