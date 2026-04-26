Bir sanayi tesisindeki makinelerin dijital ikizini oluşturmak ve TPM (Toplam Verimli Bakım) süreçlerini yönetmek için kapsamlı bir veri modeli tasarlamanı istiyorum. Şu anki basit özellik listesi yetersiz kalıyor.

Yeni yapıda şu kategorilerde detaylı alanlar (fields) bulunmalı:

Kimlik Bilgileri: Makine ID, Model, Seri No, Üretici, Üretim Yılı.

Teknik Spesifikasyonlar: Güç tüketimi (kW), Çalışma gerilimi, Kapasite (birim/saat), Ağırlık ve Boyutlar.

Operasyonel Durum: Kritiklik seviyesi (A/B/C), Bulunduğu departman/hat, Sorumlu operatör.

Bakım Verileri: Son periyodik bakım tarihi, Toplam çalışma saati (sayaç), Garanti bitiş süresi.

Dokümantasyon: PDF kılavuz linkleri, ISO standart uygunlukları.

Bu verileri hem bir JSON objesi yapısında hem de Prisma schema formatında hazırlar mısın? Ayrıca, bu özelliklerin kullanıcı arayüzünde (React) 'Teknik Kart' şeklinde daha profesyonel görünmesi için tasarım önerileri sunar mısın?"