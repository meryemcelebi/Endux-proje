Veri Sözlüğü ve Makine Parametreleri
Bu doküman, KB-V4 projesi kapsamında operatörlerin sisteme gireceği TPM (Toplam Verimli Bakım) tabanlı makine özelliklerini, bu özelliklerin karşılık geldiği arıza türlerini ve kritik parçaların teorik ömürlerini içermektedir. Tüm veri girişleri 0 (Normal), 1 (Uyarı) ve 2 (Kritik) formatında tasarlanmıştır.
1. ORTAK OPERATÖR GİRDİLERİ (Tüm Makinelerde Zorunlu)
Aşağıdaki parametreler, makine türünden bağımsız olarak tüm sistemlerde temel (base) şema içerisinde yer almalıdır:
•	sicaklik: Sıcaklık anomalisi veya aşırı ısınma durumu.
•	titresim: Normal dışı sarsıntı veya mekanik titreşim.
•	ses_anomalisi: Anormal gürültü, uğultu veya vuruntu sesi.
•	yag_durumu: Makine gövdesinde sızıntı veya yağ kirliliği durumu.
•	form_doldurma_suresi_sn: Yapay zekanın sahte veri (fake data) girişini tespit edebilmesi için arka planda saniye cinsinden tutulan süre.
2. CNC MAKİNESİ
Operatör Girdi Parametreleri:
•	is_mili_ses_ve_titresim: İş milinin dönerken çıkardığı ses ve sarsıntı (0: Stabil, 1: İnce uğultu/çınlama, 2: Şiddetli vuruntu).
•	eksen_olcu_sapmasi: İşlenen parçadaki ölçü/tolerans kaçıklığı (0: Kusursuz, 1: Tolerans sınırında, 2: Hatalı/Bozuk ölçü).
•	takim_zorlanma_durumu: Kesici takımın körlenmesi veya motorun zorlanması (0: Rahat kesim, 1: Zorlanma/kıvılcım, 2: Kırık takım/kilitlenme).
•	islenen_yuzey_kalitesi: Parça yüzeyindeki işleme izleri (0: Pürüzsüz/Ayna gibi, 1: Matlaşma/İz var, 2: Derin çizik/Çapak).
•	is_mili_govde_sicakligi: Rulman/gövde ısınması (0: Normal/Oda sıcaklığı, 1: Sıcak, 2: El değmeyecek kadar sıcak).
•	bor_yagi_ve_sogutma: Soğutma sıvısının durumu (0: Basınçlı/Temiz, 1: Azalmış/Kirlenmiş, 2: Akmıyor/Buharlaşıyor).
•	pnomatik_hava_basinci: Sistem hava basıncı manometre kontrolü (0: 6-8 Bar arası, 1: Dalgalı/Tıslama var, 2: Basınç çok düşük).
•	kizak_yag_seviyesi: Eksen kızak yağlama seviyesi (0: Normal/Kızaklar ıslak, 1: Yağ tankı azalmış, 2: Tank boş/Kızaklar kuru).
Hedef Arızalar, Parçalar ve Teorik Ömürleri:
•	Kesici Takım / İş Mili (Spindle) Rulmanları: Titreşim ve ses ile kendini belli eder. Teorik ömrü: 8.000 Saat.
•	X-Y-Z Eksen Motorları ve Sürücüleri: Aşırı ısınma ve eksen sapması ile tespit edilir. Teorik ömrü: 15.000 Saat.
•	Pnömatik Mengene Valfi: Hava basıncı düşüşü ve sızıntı ile anlaşılır. Teorik ömrü: 12.000 Saat.
•	Bor Yağı Pompası: Seviye düşüklüğü ve ısınma yapar. Teorik ömrü: 10.000 Saat.
3. PRES MAKİNESİ (Metal Şekillendirme)
Operatör Girdi Parametreleri:
•	hidrolik_basinc_seviyesi: Ana basınç saatindeki değer (0: Normal, 1: Dalgalı, 2: Düşük/Yetersiz).
•	hidrolik_yag_sicakligi: Yağ tankının ısısı (0: Normal, 1: Isınmış, 2: Aşırı Sıcak/Uyarı Veriyor).
•	yag_kacak_durumu: Makine gövdesinde hidrolik yağ kaçağı (0: Yok, 1: Terleme/Hafif Sızıntı, 2: Göllenme/Damlatma).
•	koc_vuruntu_sesi: Pres inerken çıkan mekanik ses (0: Normal, 1: Hafif Tıkırtı, 2: Şiddetli Çarpma/Metal Sesi).
•	koc_kilavuz_boslugu: Pres inerken sağa sola yalpalaması (0: Sabit/Sıkı, 1: Hafif Boşluk, 2: Gözle Görülür Kayma).
•	kavrama_fren_hava_basinci: Kavramayı sağlayan havanın durumu (0: Normal, 1: Düşük, 2: Sistem Devreye Girmiyor).
•	tonaj_sapmasi: Presin vurucu gücündeki kayıp (0: Normal, 1: Sınırda, 2: Yetersiz Güç).
•	basilan_parca_kalitesi: Çıkan ürünün durumu (0: Kusursuz, 1: Çapaklı/Çizik, 2: Yırtık/Eksik Baskı).
Hedef Arızalar, Parçalar ve Teorik Ömürleri:
•	Ana Hidrolik Pompa: Aşırı ısınma ve ses yapar. Teorik ömrü: 15.000 Saat.
•	Hidrolik Yön Valfleri ve Keçeler: Sızıntı ve basınç kaybı ile tespit edilir. Teorik ömrü: 10.000 Saat.
•	Mekanik Gövde / Kılavuz Yatakları: Aşırı titreşim ve tonaj sapması yaratır (Mekanik yorulma). Teorik ömrü: 30.000 Saat.
4. PLASTİK ENJEKSİYON MAKİNESİ
Operatör Girdi Parametreleri:
•	kovan_rezistans_sicakligi: Isıtıcı bölge sıcaklık sapması (0: Hedefte, 1: Dalgalı/Geç Isınıyor, 2: Hedefe Ulaşamıyor/Aşırı Sıcak).
•	eriyik_plastik_kokusu: Isı veya sürtünme kaynaklı koku (0: Normal, 1: Hafif Yanık Kokusu, 2: Ağır Yanık/Duman).
•	vida_donus_sesi: Malzemeyi süren vidanın sürtünme sesi (0: Normal, 1: Uğultu/Sürtünme, 2: Kilitlenme/Metal Metale Çarpma).
•	enjeksiyon_baski_basinci: Kalıba basan hidrolik basınç (0: Normal, 1: Dalgalı, 2: Basınç Düşük).
•	mengene_kapanma_basinci: Kalıbı kilitli tutan basınç (0: Normal, 1: Düşük, 2: Kalıp Aralığından Kaçak/Açılma Var).
•	kalip_sogutma_suyu_debisi: Eşanjör su akış hızı (0: Normal Akış, 1: Yavaşlamış, 2: Akış Yok).
•	sogutma_suyu_sicakligi: Kalıbı soğutan suyun çıkış ısısı (0: Soğuk/Ilık, 1: Sıcak, 2: Aşırı Sıcak/Buhar).
•	eksik_baski_durumu: Çıkan ürünün yarım/eksik basılması (0: Yok, 1: Ufak Hatalar, 2: Ürün Yarım Çıkıyor).
•	capakli_baski_durumu: Ürün kenarlarından malzeme taşması (0: Yok, 1: İnce Çapak, 2: Kalın/Kabul Edilemez Çapak).
Hedef Arızalar, Parçalar ve Teorik Ömürleri:
•	Isıtıcı Rezistans Bantları: Sıcaklık düşüşü veya aşırı ısınma ile anlaşılır (Elektriksel arıza). Teorik ömrü: 8.000 Saat.
•	Enjeksiyon Vidası ve Kovan (Barel): Titreşim, anormal ses ve baskı basıncında düşüş yapar (Aşınma arızası). Teorik ömrü: 20.000 Saat.
•	Kalıp Soğutma Valfleri (Eşanjör): Sıcaklık artışı ve su sızıntısıyla tespit edilir. Teorik ömrü: 12.000 Saat.
