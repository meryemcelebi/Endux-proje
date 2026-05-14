Projemizin (React + Node.js + Prisma) "Teknik Servis ve Bakım Yönetimi" iş akışında, form kayıtları ve veritabanı ilişkileri (foreign keys) arasında üç adet kritik uyumsuzluk yaşıyoruz. Lütfen aşağıdaki üç sorunu inceleyerek backend controller ve frontend fetch kodlarında gerekli düzeltmeleri yapın.

📌 Sorun 1: Misafir vs. Dahili Teknisyen Durum Güncelleme Hatası (Backend)

Durum: Dışarıdan gelen "Misafir Servis" bakım formunu doldurduğunda bakim_kaydi tablosunda durum "TAMAMLANDI" oluyor, ancak makine tablosunda o makinenin aktiflik_durumu true (Aktif) olmuyor. Fakat fabrika içi "Dahili Teknisyen" formu doldurduğunda makine başarıyla aktife dönüyor.

Beklenen Çözüm: Bakım kaydını tamamlayan fonksiyonun (örn: completeMaintenance) içinde, formu kimin doldurduğundan (misafir veya dahili) bağımsız olarak, Prisma $transaction bloğu içerisinde makine.update({ data: { aktiflik_durumu: true } }) işleminin standart ve eksiksiz çalışmasını sağlayın.

📌 Sorun 2: Raporda Yanlış Teknisyen Adı Gösterimi (Frontend / Backend Include)

Durum: Dahili teknisyen bakım kaydını başarıyla kapatsa bile, oluşan bakım raporu modalında "Teknisyen" kısmında sürekli "Misafir Teknik Servis Sorumlusu" yazıyor.

Beklenen Çözüm: Backend'deki getTeknikServisIsleri veya ilgili GET metodunda, Prisma include bloğunu kontrol edin. sorumlu_id (dahili teknisyen) ve misafir teknisyen verisi birbiriyle çakışıyor olabilir. Frontend tarafında da modalı besleyen veride, eğer kullanici_id (dahili) doluysa onun adını, boşsa misafir verisini ekrana basacak bir koşul (if/else veya ternary) yazın.

📌 Sorun 3: Sabit (Hardcoded) Servis Firması Hatası (Frontend / Backend İlişkisi)

Durum: Makine detay sayfasındaki "Servis Geçmişi", Bakım Raporu modalı ve Dış Servis Puanlama ekranlarının hepsinde Servis Firması adı "Güvenilir Servis A.Ş." olarak sabit geliyor. Misafir giriş formunda seçilen gerçek firma kaydedilmiyor veya okunmuyor.

Beklenen Çözüm:

Misafir formunu kaydeden POST metodunu kontrol edin. Formdan gelen servis_firma_id değerinin Prisma create veya update metodunda bakim_kaydi tablosuna doğru kaydedildiğinden emin olun.

Geçmişi ve Puanlamayı listeleyen GET metodlarında, include: { servis_firma: { select: { firma_adi: true } } } ilişkisinin doğru çekildiğinden emin olun.

Frontend map fonksiyonlarında sabit bir string ("Güvenilir Servis A.Ş.") kalmışsa bunu item.servis_firma?.firma_adi ile değiştirin.

Lütfen bu üç sorunu çözecek Prisma controller fonksiyonlarını (POST ve GET) ve ilgili React state eşleştirmelerini verin.