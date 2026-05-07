🌉 Veri Akışı Köprüsü ve Form Hata Ayıklama (Bug Fix) Talebi
Maintfy projemizde arayüzler oturdu ancak iki kritik veri akışı hatası yaşıyoruz. Lütfen aşağıdaki iki sorunu çözmek için gerekli Backend (Node.js/Prisma) ve Frontend (React) kodlarını eksiksiz, try-catch blokları ve tip dönüşümleri (type casting) ile birlikte sağlayın.

🔴 Sorun 1: Pasife Çekilen Makinenin "Onay Bekleyenler"e Düşmemesi
Senaryo: Makine Yönetimi ekranından bir makine "Pasif" veya "Arızalı" duruma getirildiğinde, sadece makinenin durumu değişiyor ancak bakim_kaydi tablosunda otomatik bir iş emri oluşmadığı için Dashboard'daki "Onay Bekleyenler" sayacı 0 kalıyor.
Çözüm Beklentisi: * Makine durumunu güncelleyen API (örn: updateMachineStatus), makineyi "Pasif" yaptığında Prisma transaction kullanarak aynı anda bakim_kaydi tablosuna durum: 'BEKLEYEN' ve ariza_notu: 'Sistem tarafından otomatik oluşturuldu' şeklinde yeni bir satır eklemelidir. Lütfen bu güncellenmiş Controller kodunu yazın.

Dashboard API'nizin (getDashboardOzet), "Onay Bekleyen" sayısını bakim_kaydi tablosundaki durum: 'BEKLEYEN' olanları sayarak getirdiğinden emin olun.

🔴 Sorun 2: "Bakımı Kaydet" Formunun Çalışmaması (QR Mobil Ekran)
Senaryo: Teknisyen sahada QR okutup bakım formunu doldurduğunda "Bakımı Kaydet" butonuna basıyor ancak hiçbir tepki yok veya backend kaydetmiyor.
Çözüm Beklentisi: * Frontend'de (React) formun onSubmit veya butonun onClick fonksiyonunu yeniden yazın. Verilerin backend'e gitmeden önce doğru tiplere (Number(), String()) çevrildiğinden ve e.preventDefault() kullanıldığından emin olun.

Backend tarafında bu formu karşılayacak olan POST /api/bakimlar/qr-tamamla API kodunu yazın. Bu API, gelen bakım ID'sine ait kaydı güncellemeli (durum: 'TAMAMLANDI', maliyet, değişen parçalar) ve ardından o makineyi (makine_id) bulup aktiflik_durumu: true yapmalıdır. Lütfen backend'de olası hataları konsola detaylıca basan (console.log(req.body)) bir kod verin.