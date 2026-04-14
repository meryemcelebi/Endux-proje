Sen "Endux Kestirimci Bakım (TPM)" projesinde çalışan Kıdemli bir Backend Mimarıısın. Node.js, Express.js, TypeScript ve Prisma ORM (PostgreSQL) kullanarak geliştirme yapıyoruz. Sistemimizde JWT tabanlı bir yetkilendirme mevcut ve standart API yanıt formatımız şu şekildedir: `{ success: boolean, message: string, data?: any }`.

Frontend ekibi benden aşağıdaki tabloda yer alan endpoint'leri öncelik sırasına (P0'dan P3'e) göre hazırlamamı istedi. Senden bu endpoint'ler için Controller fonksiyonlarını ve Route bağlantılarını eksiksiz bir şekilde yazmanı bekliyorum.

Lütfen kodları yazarken her fonksiyonu 'try-catch' bloğuna al ve TypeScript tiplerini (Request, Response) kesinlikle kullan.

[ÖNCELİK P0: BAKIM İŞLEMLERİ VE ROTA DÜZELTMESİ]
1. `GET /api/bakimlar`: Belirli bir makinenin bakım geçmişini getiren endpoint.
   - Detay: 'makine_id' değeri 'req.query' üzerinden gelmeli (Örn: /api/bakimlar?makine_id=5).
   - Prisma İsteği: Bakım kayıtlarını çekerken, işlemi yapan teknisyenin adını ve değiştirilen parçaları (parca_degisim) 'include' ile dahil et.
2. Route Bağlantısı: Yazdığın bu controller'ı 'bakimRoutes' içine bağlayarak ana 'app.ts' (veya index.ts) dosyasına nasıl entegre edeceğimi göster.

[ÖNCELİK P1: LİSTELEME (GET) SERVİSLERİ]
1. `GET /api/kullanicilar`: Sistemdeki tüm kullanıcıları listeleyen endpoint. (DİKKAT: Prisma sorgusunda 'sifre' alanını kesinlikle 'select' ile dışarıda bırak / exclude et).
2. `GET /api/tedarikciler`: Sisteme kayıtlı yedek parça tedarikçilerini listeleyen endpoint.
3. `GET /api/servis-firmalari`: Dışarıdan destek alınan servis firmalarını listeleyen endpoint.

[ÖNCELİK P2: EKLEME VE PUANLAMA (POST) SERVİSLERİ]
1. `POST /api/tedarikciler`: Yeni tedarikçi ekleme (Payload: firma_adi, telefon, email, adres).
2. `POST /api/servis-firmalari`: Yeni servis firması ekleme (Payload: firma_adi, telefon, email, adres).
3. `POST /api/servis-puan` & `POST /api/tedarikci-puan`: İlgili firma veya tedarikçiye teknisyen/yönetici tarafından 1-5 arası puan verilmesini sağlayan endpoint'ler. (Veritabanında puan ortalamasını veya logunu tutacak mantığı Prisma ile kur).

[ÖNCELİK P3: ALTERNATİF GİRİŞ VE GÖREVLER]
1. `POST /api/auth/servis-giris`: Dışarıdan gelen servis elemanları için 'PIN + Telefon' ile giriş yapıp JWT Token dönen alternatif bir auth servisi. (Payload: telefon, pin_kodu).
2. `GET /api/gorevler`: Sisteme giriş yapmış teknisyenin (veya servisin) token'ından 'req.user.id' bilgisini alarak, sadece o kişiye atanmış aktif bakım görevlerini listeleyen endpoint.

Lütfen çıktıları mantıksal dosyalara (bakim.controller.ts, firma.controller.ts vb.) bölerek ve her birinin rotasını (Router) tanımlayarak ver.