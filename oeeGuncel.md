Sen "Endux Kestirimci Bakım (TPM)" projesinde çalışan Kıdemli bir Backend Geliştiricisisin. Node.js, TypeScript ve Prisma ORM kullanıyoruz.

Sistemimize TPM'in en kritik metriği olan OEE modülünü ekledik ve veritabanı şemamızı 3 farklı tabloya ('uretim_kaydi', 'durus_kaydi', 'oee_raporlari') böldük. Senden beklentim, aşağıda paylaştığım şemalara uygun olarak Seed dosyamızı güncellemen, mevcut 'oeeKontrol.ts' dosyamızı iyileştirmen ve 'api.js' (yönlendirme) bağlantılarını kurmandır.

[1. KULLANILACAK PRISMA ŞEMALARI]
(Lütfen sistemindeki güncel uretim_kaydi, durus_kaydi ve oee_raporlari şemalarını baz al.)

[GÖREV 1: SEED.TS MANTIĞI (Mock Data Generator)]
`seed.ts` dosyamızda bulunan 100 adet makinemiz için son 30 günün her gününe 1 vardiya gelecek şekilde veri üretmelisin:
1. uretim_kaydi: planlanan_sure_dk sabit 480. durus_sure_dk 0-60 arası rastgele. fiili_sure_dk (planlanan - durus). teorik_uretim 1000. gercek_uretim (teorik'in %80-%98'i). hatali_uretim (gercek_uretim'in %1-%5'i).
2. durus_kaydi: Eğer uretim_kaydi'nda durus var ise, bu tabloya o gün için ("Mekanik Arıza", "Ayar", "Parça Bekleme" gibi) rastgele nedenlerle aynı süreyi içeren kayıt/kayıtlar ekle.
3. oee_raporlari: Aynı döngüde o günün Kullanılabilirlik (fiili/planlanan), Performans (gercek/teorik) ve Kalite ((gercek-hatali)/gercek) oranlarını bulup OEE skorunu oluşturarak bu tabloya kaydet.

[GÖREV 2: OEE KONTROL SERVİSİNİ İYİLEŞTİRME (oeeKontrol.ts Refactor)]
Lütfen çalışma alanındaki mevcut `oeeKontrol.ts` dosyasını incele. İçindeki kodları bu yeni 3 tablolu yapıya tam uyumlu hale getir ve varsa hataları gider. Fonksiyonun (örn: `getMakineOee`) şu işlevleri eksiksiz yerine getirmesini sağla:
- Parametre olarak `makine_id` ve tarih aralığı (`baslangic`, `bitis`) alsın.
- Prisma kullanarak `oee_raporlari` tablosundan bu tarih aralığındaki günlük OEE trend verilerini (tarih ve skorlar) çeksin. (Frontend'de çizgi grafik için kullanılacak).
- Prisma kullanarak `durus_kaydi` tablosundan ilgili tarihlerdeki duruşları `durus_nedeni` bazında gruplayarak (Örn: Mekanik Arıza: Toplam 45 dk) toplam sürelerini dönsün. (Frontend'de pasta grafik için kullanılacak).

[GÖREV 3: ENDPOINT BAĞLANTISI (api.js / Routes)]
Yazdığın bu yeni Controller fonksiyonunu Frontend'in tüketebilmesi için Express.js yönlendirme (router) tarafına eklememiz gerekiyor. Projemizdeki `api.js` (veya ilgili routes dosyan) içerisine eklemem gereken `router.get(...)` kod bloğunu, doğru URL yapısı (RESTful standartlarına uygun) ve parametre alımıyla birlikte bana ver.

Lütfen seed döngüsünü üret, `oeeKontrol.ts` dosyasının hatasız son halini ver ve `api.js` eklentisini göster.