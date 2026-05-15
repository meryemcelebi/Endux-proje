Projemizdeki React tabanlı Dashboard ekranında, sağ tarafta bulunan dikey "Maliyet Analizi" bileşenini (component) yeniden tasarlamak istiyorum. En önemli kural: Bu kolonun mevcut genişliğini (width) kesinlikle değiştirmeyin/genişletmeyin, çünkü sol tarafındaki fabrika haritası alanını daraltmamalı. Mevcut dikey alanı daha modern ve SaaS standartlarında, kompakt bir şekilde kullanacağız.

Lütfen bileşeni şu 4 adıma göre baştan yazın:

Başlık ve Toplam Tutar (Kompakt Üst Kısım):

En üste "MALİYET ANALİZİ" başlığını koyun. Başlığın hemen sağ köşesine ufak bir zaman seçici dropdown (örn: "Mayıs 2026") yerleştirin.

Altına büyük ve belirgin bir font ile Toplam Maliyeti (örn: "₺833.466") yazın.

Donut Grafiği İptali ve Stacked Bar (Yatay Çubuk):

Mevcut Donut (Halka) grafiğini tamamen koddan silin.

Yerine tek bir satırda uzanan, renklerle yüzdelik dilimlere bölünmüş ince bir yatay "Stacked Progress Bar" ekleyin.

Dağılım: Planlı Bakım (Yeşil), Arıza Bakım (Kırmızı), Dış Servis (Mor), Yedek Parça (Turuncu).

Minimalist Veri Listesi (Kartları Kaldırın):

Mevcut 4 büyük kartı ve içlerindeki "Planlı ve önleyici bakım kayıtlarından oluşan..." gibi uzun açıklama metinlerini tamamen silin.

Bunun yerine bar grafiğinin altına alt alta 4 satırlık temiz bir liste (flex ve justify-between kullanarak) kurun.

Her satırda sırasıyla: [Renk Noktası] + [Kategori Adı] sol tarafta; [Tutar (₺)] ve [Yüzde (%)] sağ tarafta hizalansın.

Mini Trend Grafiği (Alt Boşluk İçin):

Donut grafiğini sildiğimiz için en altta açılan boşluğa, son 6 aylık toplam maliyet trendini gösteren çok minimalist, axes (eksen) çizgileri olmayan ufak bir Area Chart (Alan Grafiği) veya Sparkline ekleyin (Projede kullanılan grafik kütüphanesini tercih edebilirsiniz).

Lütfen CSS yapılandırmasında grid/flex kullanarak dikey (vertical) yerleşimi kusursuz ve ferah hale getirin.