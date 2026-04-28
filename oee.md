Sen "Endux Kestirimci Bakım (TPM)" projesinde çalışan Kıdemli bir Backend Geliştiricisisin. Node.js, TypeScript ve Prisma ORM kullanıyoruz.

Sistemimize TPM'in en kritik metriği olan OEE (Toplam Ekipman Etkinliği) hesaplama servisini eklememiz gerekiyor. Senden `makineOEEHesapla(makine_id, baslangic_tarihi, bitis_tarihi)` adında bir fonksiyon yazmanı istiyorum.

[HESAPLAMA MANTIĞI VE PRISMA SORGULARI]
Lütfen fonksiyon içinde şu adımları simüle eden/hesaplayan kodu yaz:

1. KULLANILABİLİRLİK (Availability):
- İlgili makinenin belirtilen tarih aralığındaki toplam planlanan çalışma süresini al (Örn: Günde 8 saat).
- `bakim_kaydi` tablosundan (veya arıza loglarından) bu tarih aralığındaki toplam "Duruş Süresi"ni (downtime) topla.
- (Planlanan Süre - Duruş Süresi) / Planlanan Süre formülüyle % olarak hesapla.

2. PERFORMANS (Performance):
- Makinenin teorik hızına (Örn: Saatte 100 parça) karşılık, operatör girişlerinden veya günlük loglardan gerçekleşen üretim miktarını çek. 
- Gerçekleşen / Teorik formülüyle % olarak hesapla. (Eğer üretim adedi tablomuzda yoksa, şimdilik mock veri ile kurgula).

3. KALİTE (Quality):
- Makinenin ürettiği toplam parça sayısından, fire/hurda (veya checklist'lerdeki 'Çapaklı Baskı' vb. hatalı durum) sayısını çıkararak sağlam parça sayısını bul.
- Sağlam Parça / Toplam Parça formülüyle % olarak hesapla.

[BEKLENEN API ÇIKTISI (DTO)]
Fonksiyon, Frontend tarafındaki Recharts/Chart.js Gauge (Kadran) grafiklerinde kullanılmak üzere şu formatta bir JSON dönmelidir:

{
  "makine_id": 5,
  "donem": "Aylık",
  "detaylar": {
     "kullanilabilirlik_yuzdesi": 85.5,
     "performans_yuzdesi": 90.0,
     "kalite_yuzdesi": 95.2
  },
  "oee_skoru": 73.25  // (A x P x Q)
}

Lütfen hata yönetimi (try-catch) içeren modüler bir TypeScript fonksiyonu hazırla.