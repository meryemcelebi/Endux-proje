Sen "Endux Kestirimci Bakım (TPM)" projesinde çalışan Kıdemli bir Backend Mimarı (Senior Backend Architect) rolündesin. Projemiz Node.js, Express.js, TypeScript ve Prisma ORM (PostgreSQL) kullanılarak geliştiriliyor. 

Sistemimizde "Zero Trust" (Sıfır Güven) prensibi ve kapalı devre RBAC (Role Based Access Control) mimarisi uygulanacaktır. Dışarıya açık bir "Kayıt Ol" (Register) sayfası KESİNLİKLE OLMAYACAKTIR. Giriş işlemleri e-posta ile değil, benzersiz 'kullanici_adi' üzerinden yapılacaktır.

Aşağıdaki spesifikasyonlara göre gerekli Controller, Route ve Middleware kodlarını, TypeScript tipleriyle birlikte eksiksiz olarak yazmanı istiyorum.

[1. VERİTABANI BAĞLAMI (PRISMA MODELİ)]
kullanici tablomuz şu şekildedir: id (Int), kullanici_adi (String, Unique), ad (String), soyad (String), email (String, Nullable), sifre_hash (String), rol (Enum: 'YONETICI', 'OPERATOR', 'TEKNISYEN').

[2. GÖREV 1: YÖNETİCİ PERSONEL EKLEME API'Sİ (POST /api/kullanicilar)]
- SADECE JWT token'ındaki rolü 'YONETICI' olanların erişebileceği bir endpoint yaz. (Bunun için authMiddleware ve roleMiddleware kullanıldığını varsay).
- Payload: { ad, soyad, rol, sifre }
- İŞ MANTIĞI (Çok Kritik): Gelen ad ve soyad bilgisini al, küçük harfe çevir, Türkçe karakterleri (ğ,ü,ş,ı,ö,ç) İngilizce karşılıklarına çevir ve boşlukları sil (örn: "Ahmet Yılmaz" -> "ahmetyilmaz").
- ROL ÖNEKİ (Prefix): Seçilen role göre bu ismin başına otomatik önek ekle. OPERATOR ise "op_", TEKNISYEN ise "tkn_", YONETICI ise "yon_" ekle. (Nihai sonuç: "op_ahmetyilmaz" olmalı ve veritabanına 'kullanici_adi' olarak bu kaydedilmeli).
- Şifreyi bcrypt ile hashle ve veritabanına Prisma ile kaydet.

[3. GÖREV 2: TEK MERKEZLİ GİRİŞ API'Sİ (POST /api/auth/login)]
- Payload: { kullanici_adi, sifre }
- Veritabanından kullanici_adi'na göre kişiyi bul, bcrypt ile şifreyi doğrula.
- Başarılıysa JWT (jsonwebtoken) üret. Token Payload'u kesinlikle şu verileri içermeli: { id, kullanici_adi, rol }. 
- Frontend'e token'ı ve kullanıcının temel bilgilerini dön.

[4. GÖREV 3: QR KOD TRAFİK POLİSİ (GET /api/makineler/qr/:qr_uuid)]
- Bu rota JWT ile korunmalıdır (Sadece giriş yapmış personeller okutabilir).
- Gelen req.params.qr_uuid değerine göre makineyi Prisma'dan bul.
- req.user.rol (JWT'den gelen rol) değerine göre Switch-Case yapısı kur:
  -> Case 'OPERATOR': Makine temel bilgilerini ve operatörün doldurması gereken 'gunluk_kontrol_formu' şablonunu (JSONB veya ilişkili tablo) JSON olarak dön.
  -> Case 'TEKNISYEN': Makine temel bilgilerini, 'ariza_kaydi' geçmişini ve bakım formunu JSON dön.
  -> Case 'YONETICI': Makinenin tüm envanter kartını (maliyet, satın alma tarihi vb.) JSON dön.

[5. GÖREV 4: FRONTEND İÇİN ENTEGRASYON REHBERİ (Açıklama Olarak Yazılacak)]
Yazdığın kodların sonuna, Frontend geliştiricisi (React/Vue) için şu akışı anlatan teknik bir rehber (MD formatında) ekle:
- Sistemde tek bir /login ekranı olacağı,
- QR kod okutulduğunda (/qr/:uuid) token yoksa kullanıcının /login?redirect=/qr/:uuid adresine nasıl atılacağı,
- Login olduktan sonra frontend'in JWT'deki role göre değil, Backend'in QR API'sinden (Görev 3) dönen JSON yapısına göre (içinde form mu var, log mu var?) aynı ekranı nasıl dinamik olarak render etmesi (çizmesi) gerektiği.

Lütfen kodları modüler (Controller ve Route ayrı) temiz ve açıklayıcı yorum satırlarıyla birlikte yaz.