"Bir endüstriyel makine bakım ve yönetim sistemi (TPM) projesi olan 'Endux' üzerinde çalışıyoruz. Sistem mimarimizde veritabanı olarak PostgreSQL, backend servisi olarak Node.js, veri analizi ve algoritmalar için ise Python kullanıyoruz.

Aşağıda sistemin 3 farklı bileşenine ait kodları/şemaları paylaşıyorum. Senden şu 4 ana başlıkta derinlemesine bir analiz yapmanı istiyorum:

1. SQL Servisleri Analizi: services/sql içerisinde yer alan sorguların doğruluğunu, güvenlik (SQL injection vb.) ve performans (indexing vb.) açısından eksikliklerini değerlendir.
2. Node.js ve Python Entegrasyonu Kontrolü: Node.js servisleri ile Python betikleri arasında veri iletimi (örneğin JSON formatları, API endpoint'leri veya mesaj kuyrukları) doğru kurgulanmış mı? İki tarafın beklediği veri tiplerinde uyuşmazlık (mismatch) var mı?
3. OEE (Genel Ekipman Etkinliği) Hesaplaması: Sistemde OEE (Kullanılabilirlik x Performans x Kalite) verisinin veritabanında nasıl tutulduğunu, Node.js üzerinden nasıl çekildiğini ve Python tarafında bu verinin nasıl işlendiğini incele. Mantıksal bir hata veya daha optimize bir veri tutma yöntemi (örneğin raw datayı tutup OEE'yi on-the-fly hesaplamak vs.) var mı?
4. Yapılması Gerekenler (Aksiyon Planı): Bulduğun hataları düzeltmek ve mimariyi daha sağlam hale getirmek için bana adım adım neler yapmam gerektiğini kod örnekleriyle sun.