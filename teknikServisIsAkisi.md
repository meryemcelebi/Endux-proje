📱 Sahadan (QR) Yönetimli Teknik Servis İş Akışı ve Hata Düzeltme Talebi
Maintfy projemizde, Teknik Servis süreçlerinin gerçek bir endüstriyel fabrikaya uygun (TPM) olması için iş akışımızı değiştiriyoruz. Masaüstü web panelinden bakım girmek yerine, "QR Kod okutularak sahada bakım tamamlama" kurgusuna geçiyoruz. Bu akışı sağlamak için Backend ve Frontend taraflarında aşağıdaki geliştirmelere ve mevcut bir hatanın onarımına ihtiyacımız var:

🎯 Yeni İş Akışı (Senaryo):

Yönetici arızayı onaylar -> Görev durumu ONAYLANDI olur.

Web panelinde görevler listelenir ama teknisyen işlemi bilgisayardan kapatamaz.

Teknisyen fiziksel olarak makineye gider, QR kodunu okutur.

QR kodu okutulduğunda açılan ekranda "Bakım Formu" doldurulup kaydedilir.

Kayıt yapıldığı an; Makine durumu otomatik "Aktif" (true) olur ve görev durumu "TAMAMLANDI" olur.

Teknik Servis web panelinde ise bu işler "Tamamlandı" olarak listelenir ve yanına "Raporu Gör" butonu eklenir.

🐛 Çözülmesi Gereken Kritik Hata (Bug):

Çalışmayan "Bakımı Kaydet" Butonu: Şu an mevcut frontend kodumuzda formu kaydetmeye yarayan "Bakımı Kaydet" butonu çalışmıyor (tepki vermiyor veya hata fırlatıyor). Yeni QR onaylama formunu kurgularken, bu butonun onClick veya onSubmit event'lerini, form state'lerini ve API bağlantısını eksiksiz bir şekilde onarmanız/yeniden yazmanız gerekmektedir.

🛠️ Gerekli Kodlamalar ve Adımlar:

1. Backend - QR Bakım Formu Kaydetme API'si (Yeni Endpoint):
Teknisyenin QR okutup doldurduğu formu karşılayacak ve çalışmayan buton sorununu çözecek bir POST /api/bakimlar/qr-tamamla route'u yazın. Bu API Prisma transaction içinde şu 3 işlemi aynı anda yapmalıdır:

İlgili bakım kaydını güncelleyip form detaylarını (maliyet, değişen parça, açıklama) yazmalı ve durumunu TAMAMLANDI yapmalı.

İlgili makinenin (makine tablosu) aktiflik_durumu'nu true (Aktif) olarak güncellemelidir.

2. Frontend - Web Paneli Güncellemesi (ServisMerkezi.jsx):
Teknik servis listesini güncelleyin:

Sadece ONAYLANDI ve TAMAMLANDI olan görevleri listelesin.

Durumu ONAYLANDI olanların yanında işlem butonu olmasın, sadece durum kısmında bir rozet (badge) ile "📱 Sahada Müdahale Bekleniyor" yazsın.

Durumu TAMAMLANDI olanların yanında ise "📄 Raporu Gör" butonu olsun. Bu butona tıklanınca o bakımın detaylarını (maliyet, yapılan iş) gösteren sadece okuma amaçlı (read-only) bir Modal açılsın.

3. Frontend - Mobil QR Ekranı ve "Bakımı Kaydet" Butonunun Onarımı:
QR kodu okutulduğunda teknisyenin karşısına çıkan ekranda, eğer o makinenin ONAYLANDI durumunda bekleyen bir işi varsa, "Bakımı Tamamla" formunu açacak mantığı kurgulayın.

Formdaki input değerlerini (maliyet, parça, notlar vb.) tutacak React state'lerini yazın.

Çalışmayan "Bakımı Kaydet" butonunu, oluşturduğunuz POST /api/bakimlar/qr-tamamla API'sine bağlayarak çalışır ve hataları try-catch ile yakalar hale getirin.

Lütfen bu mimariye uygun Prisma Controller ve React JSX kodlarını adım adım detaylıca sağlayın.