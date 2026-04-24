/**
 * Dinamik Checklist Soru Açıklamaları
 * Her teknik_parametre anahtarı için 0/1/2 şiddet seviyelerinin açıklamalarını tanımlar.
 * Backend'den gelen kontrol_maddesi.teknik_parametre alanı ile eşleştirilir.
 */

// ═══════════════ ORTAK SİSTEM PARAMETRELERİ (Tüm Makineler) ═══════════════
export const ORTAK_PARAMETRELER = {
  sicaklik: {
    baslik: "Makine Genel Sıcaklığı",
    ikon: "🌡️",
    secenekler: {
      0: "Gövde, motor ve panolarda anormal bir ısınma yok.",
      1: "Makine gövdesinde veya panoda elle hissedilir normal dışı bir ısınma var.",
      2: "Dokunulamayacak kadar aşırı ısınma, yanık kablo veya boya kokusu var."
    }
  },
  titresim: {
    baslik: "Makine Genel Titreşimi",
    ikon: "📳",
    secenekler: {
      0: "Zeminde standart çalışma sarsıntısı var.",
      1: "Zemini normalden biraz daha fazla sarsan, farklı bir titreşim hissediliyor.",
      2: "Makine bağlantılarını gevşetecek boyutta tehlikeli ve şiddetli sarsıntı var."
    }
  },
  ses_anomalisi: {
    baslik: "Genel Ses Anomalisi",
    ikon: "🔊",
    secenekler: {
      0: "Fabrika ve makine standart çalışma gürültüsü.",
      1: "Nereden geldiği tam belli olmayan hafif sürtünme veya ıslık sesi duyuluyor.",
      2: "Rulman dağılması, metal sürtünmesi veya motor zorlanmasına benzer yüksek bağırtı var."
    }
  },
  yag_durumu: {
    baslik: "Genel Yağ Seviyesi ve Durumu",
    ikon: "🛢️",
    secenekler: {
      0: "Ana göstergelerde yağ seviyeleri tam ve yağ temiz.",
      1: "Yağ seviyesi alt sınıra yaklaşmış veya rengi oldukça kararmış.",
      2: "Yağ seviyesi sıfır (bitmiş) veya yağın içine yoğun su/pislik karışmış."
    }
  }
};

// ═══════════════ CNC MAKİNESİ ÖZEL PARAMETRELERİ ═══════════════
export const CNC_PARAMETRELERI = {
  is_mili_ses_ve_titresim: {
    baslik: "İş Mili Ses ve Titreşim",
    ikon: "⚙️",
    secenekler: {
      0: "Ses normal, spindle dönüşünde sarsıntı yok.",
      1: "Yüksek devirlerde ince uğultu veya hafif titreşim başlıyor.",
      2: "Belirgin vuruntu, rulman dağılma sesi ve anormal sarsıntı var."
    }
  },
  eksen_olcu_sapmasi: {
    baslik: "Eksen Ölçü Sapması",
    ikon: "📐",
    secenekler: {
      0: "Çıkan iş parçası ölçüleri tamamen tolerans aralığında.",
      1: "Ölçülerde mikron bazında tutarsızlıklar veya hafif kaçmalar başladı.",
      2: "Belirgin eksen kayması var veya makine parçaya fazla dalma yapıyor."
    }
  },
  takim_zorlanma_durumu: {
    baslik: "Takım Zorlanma Durumu",
    ikon: "🔧",
    secenekler: {
      0: "Takım rahat kesiyor, spindle yükü (Load) normal seviyelerde.",
      1: "İşleme sırasında mil yükü (Load) ara sıra anlık olarak yükseliyor.",
      2: "Takım çok zorlanıyor, bağırıyor veya sık sık uç kırıyor."
    }
  },
  islenen_yuzey_kalitesi: {
    baslik: "İşlenen Yüzey Kalitesi",
    ikon: "✨",
    secenekler: {
      0: "Yüzeyler pırıl pırıl ve istenen pürüzlülük değerinde.",
      1: "Yüzeyde yer yer hafif matlaşma veya ince kılcal çizikler var.",
      2: "Yüzey tamamen bozuk, tırlama (chatter) veya dalga izleri var."
    }
  },
  is_mili_govde_sicakligi: {
    baslik: "İş Mili Gövde Sıcaklığı",
    ikon: "🔥",
    secenekler: {
      0: "Spindle gövdesi normal çalışma sıcaklığında (Soğutma aktif).",
      1: "Gövde elle dokunulduğunda normalden daha sıcak hissediliyor.",
      2: "El değmeyecek kadar aşırı ısınmış, soğutma yetersiz."
    }
  },
  bor_yagi_ve_sogutma: {
    baslik: "Bor Yağı ve Soğutma",
    ikon: "💧",
    secenekler: {
      0: "Sıvı basıncı tam, debisi iyi ve sıvı temiz.",
      1: "Sıvı seviyesi azalmış, basıncı düşmüş veya hafif koku başlamış.",
      2: "Sıvı gelmiyor, hortum tıkalı veya bakteriden dolayı çok ağır/pis koku var."
    }
  },
  pnomatik_hava_basinci: {
    baslik: "Pnömatik Hava Basıncı",
    ikon: "🌬️",
    secenekler: {
      0: "Hava saati stabil, sistemde basınç sorunu yok.",
      1: "Saatte dalgalanma var veya şartlandırıcıda hafif su birikmesi var.",
      2: "Sisteme hava yetmiyor, belirgin kaçak (tıslama) sesi duyuluyor."
    }
  },
  kizak_yag_seviyesi: {
    baslik: "Kızak Yağ Seviyesi",
    ikon: "🛢️",
    secenekler: {
      0: "Hazne dolu, sistem kızaklara düzenli yağ basıyor.",
      1: "Yağ seviyesi minimum sınırda, ekleme uyarısı (alarmı) veriyor.",
      2: "Yağ haznesi tamamen boş, kızaklar kuru çalışıyor."
    }
  }
};

// ═══════════════ PRES MAKİNESİ ÖZEL PARAMETRELERİ ═══════════════
export const PRES_PARAMETRELERI = {
  hidrolik_basinc_seviyesi: {
    baslik: "Hidrolik Basınç Seviyesi",
    ikon: "🔴",
    secenekler: {
      0: "Basınç saatinde ibre yeşil bölgede, stabil.",
      1: "Basınçta anlık düşüşler veya dalgalanmalar gözleniyor.",
      2: "Basınç aşırı düşük/yüksek veya sistem hiç basınç üretmiyor."
    }
  },
  hidrolik_yag_sicakligi: {
    baslik: "Hidrolik Yağ Sıcaklığı",
    ikon: "🌡️",
    secenekler: {
      0: "Tank sıcaklığı standart seviyede, soğutucu devrede.",
      1: "Tank normalden sıcak, fan sürekli (hiç durmadan) çalışıyor.",
      2: "Yağ aşırı ısınmış, tehlikeli seviyede koku/duman yapıyor."
    }
  },
  yag_kacak_durumu: {
    baslik: "Yağ Kaçak Durumu",
    ikon: "💧",
    secenekler: {
      0: "Sistem tamamen kuru, hiçbir bölgede sızıntı yok.",
      1: "Valflerde veya hortum rekorlarında hafif terleme / yağlanma var.",
      2: "Yere belirgin şekilde yağ damlıyor veya basınçlı hortum patlak."
    }
  },
  koc_vuruntu_sesi: {
    baslik: "Koç Vuruntu Sesi",
    ikon: "🔨",
    secenekler: {
      0: "Koçun inip kalkması standart ve sarsıntısız.",
      1: "İniş kalkışlarda alışılmadık ince bir sürtünme sesi duyuluyor.",
      2: "Koç çok sert vuruyor, şiddetli bir mekanik çarpma/çatlama sesi var."
    }
  },
  koc_kilavuz_boslugu: {
    baslik: "Koç Kılavuz Boşluğu",
    ikon: "📏",
    secenekler: {
      0: "Koç yataklarında boşluk yok, hareket milimetrik.",
      1: "Koç inerken sağa/sola çok hafif yanal esneme yapıyor.",
      2: "Yataklarda gözle görülür boşluk var, aşırı kayma veya çizilme mevcut."
    }
  },
  kavrama_fren_hava_basinci: {
    baslik: "Kavrama Fren Hava Basıncı",
    ikon: "🛑",
    secenekler: {
      0: "Fren anında tutuyor, koç milimetrik duruyor.",
      1: "Fren pedalı/butonu tepkisinde veya duruşta hafif gecikme var.",
      2: "Fren kaçırıyor, koç üst ölü noktada (TDC) durmuyor, kayıyor."
    }
  },
  tonaj_sapmasi: {
    baslik: "Tonaj Sapması",
    ikon: "⚖️",
    secenekler: {
      0: "Vuruş tonajı normal, makine rahat basıyor.",
      1: "Makine bazen kalın/sert parçada hafif zorlanıyor, tonaj sınırda.",
      2: "Makine sık sık aşırı yüke (overload) giriyor, emniyet valfi açıyor."
    }
  },
  basilan_parca_kalitesi: {
    baslik: "Basılan Parça Kalitesi",
    ikon: "🏭",
    secenekler: {
      0: "Çıkan saç parçalarda hata, çapak veya ölçü sorunu yok.",
      1: "Parça kenarlarında hafif çapaklanmalar veya form bozuklukları başladı.",
      2: "Parçalar tamamen bozuk, yırtık veya katlanmış çıkıyor."
    }
  }
};

// ═══════════════ PLASTİK ENJEKSİYON MAKİNESİ ÖZEL PARAMETRELERİ ═══════════════
export const ENJEKSIYON_PARAMETRELERI = {
  kovan_rezistans_sicakligi: {
    baslik: "Kovan Rezistans Sıcaklığı",
    ikon: "🔥",
    secenekler: {
      0: "Bölgelerin (Zone) sıcaklıkları ayarlanan set değerlerinde stabil.",
      1: "Sıcaklıklarda ±5 dereceyi aşan dalgalanmalar var, geç ısınıyor.",
      2: "Bir veya birden fazla bölge hiç ısınmıyor (Rezistans kopuk) veya aşırı ısınıyor."
    }
  },
  eriyik_plastik_kokusu: {
    baslik: "Eriyik Plastik Kokusu",
    ikon: "👃",
    secenekler: {
      0: "Sadece hammaddeye ait standart plastik kokusu var.",
      1: "Zaman zaman hafifçe yanık/kavrulmuş plastik kokusu geliyor.",
      2: "Sürekli ve genzi yakan ağır yanık/kömürleşmiş plastik kokusu var."
    }
  },
  vida_donus_sesi: {
    baslik: "Vida Dönüş Sesi",
    ikon: "🔩",
    secenekler: {
      0: "Mal alma işlemi sırasında vida dönüşü sessiz ve stabil.",
      1: "Vida dönerken ara sıra hafif mekanik gıcırtılar duyuluyor.",
      2: "Vida zorlanarak dönüyor, metal metale sürtünme veya çatırtı sesi var."
    }
  },
  enjeksiyon_baski_basinci: {
    baslik: "Enjeksiyon Baskı Basıncı",
    ikon: "💉",
    secenekler: {
      0: "Malı basarken hidrolik basınç grafiği ve değeri normal.",
      1: "Basınç bazen yetersiz kalıyor, limitleri zorluyor.",
      2: "Basınç hiç oluşmuyor veya aniden tepe yapıp hidroliği kesiyor."
    }
  },
  mengene_kapanma_basinci: {
    baslik: "Mengene Kapanma Basıncı",
    ikon: "🔒",
    secenekler: {
      0: "Kalıp kilitleme işlemi sarsıntısız ve tam tonajda yapılıyor.",
      1: "Mengene kapanırken son anda hafif kasılma veya vuruntu yapıyor.",
      2: "Mengene tam kilitlenmiyor, basınç kaçırıyor veya aşırı şiddetli çarpıyor."
    }
  },
  kalip_sogutma_suyu_debisi: {
    baslik: "Kalıp Soğutma Suyu Debisi",
    ikon: "🌊",
    secenekler: {
      0: "Debimetrelerdeki şamandıralar normal seviyede, akış güçlü.",
      1: "Bazı kanallarda akış azalmış (şamandıralar aşağıda), kireçlenme belirtisi var.",
      2: "Kanallarda su akışı hiç yok veya kalıbın dışına su fışkırıyor (patlak)."
    }
  },
  sogutma_suyu_sicakligi: {
    baslik: "Soğutma Suyu Sıcaklığı",
    ikon: "❄️",
    secenekler: {
      0: "Gidiş ve dönüş suyu sıcaklıkları arasındaki fark normal.",
      1: "Chiller/Kule suyu sisteme biraz ılık geliyor.",
      2: "Su çok sıcak, kalıbı veya yağı soğutamıyor."
    }
  },
  eksik_baski_durumu: {
    baslik: "Eksik Baskı Durumu",
    ikon: "⚠️",
    secenekler: {
      0: "Ürün kalıbı tamamen dolduruyor, parça tam çıkıyor.",
      1: "Ürünün uç noktalarında çok hafif boşluklar (kısa baskı) görülmeye başlandı.",
      2: "Ürünlerin yarısı basılmıyor, kalıp dolmuyor (Sürekli fire)."
    }
  },
  capakli_baski_durumu: {
    baslik: "Çapaklı Baskı Durumu",
    ikon: "🔪",
    secenekler: {
      0: "Ürün kenarlarında hiçbir taşma veya çapak yok.",
      1: "Birleşim yerlerinde ince zar şeklinde hafif çapaklanmalar var.",
      2: "Kalıp ayırıcı yüzeylerinden ciddi miktarda kalın çapak (plastik taşması) çıkıyor."
    }
  }
};

/**
 * Tüm parametreleri tek bir objede birleştiren yardımcı.
 * teknik_parametre anahtarına göre ilgili açıklama objesini döner.
 */
export const TUM_PARAMETRELER = {
  ...ORTAK_PARAMETRELER,
  ...CNC_PARAMETRELERI,
  ...PRES_PARAMETRELERI,
  ...ENJEKSIYON_PARAMETRELERI
};

/**
 * Verilen bir teknik_parametre anahtarı için severity açıklamalarını döner.
 * @param {string} teknikParametre - Backend'den gelen kontrol_maddesi.teknik_parametre değeri
 * @returns {{ baslik: string, ikon: string, secenekler: {0: string, 1: string, 2: string} } | null}
 */
export function getSoruDetay(teknikParametre) {
  return TUM_PARAMETRELER[teknikParametre] || null;
}
