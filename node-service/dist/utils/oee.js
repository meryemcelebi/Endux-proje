"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.oeeYuvarla = oeeYuvarla;
exports.oeeSkoruHesapla = oeeSkoruHesapla;
exports.oeeKomponentOrtalamasi = oeeKomponentOrtalamasi;
function oeeYuvarla(deger, basamak = 2) {
    const carpan = 10 ** basamak;
    return Math.round(deger * carpan) / carpan;
}
function oeeSkoruHesapla(kullanilabilirlik, performans, kalite, basamak = 2) {
    if (kullanilabilirlik == null || performans == null || kalite == null) {
        return null;
    }
    return oeeYuvarla((kullanilabilirlik * performans * kalite) / 10000, basamak);
}
function oeeKomponentOrtalamasi(kayitlar, seciciler) {
    const toplamlar = kayitlar.reduce((birikim, kayit) => {
        const kullanilabilirlik = seciciler.kullanilabilirlik(kayit);
        const performans = seciciler.performans(kayit);
        const kalite = seciciler.kalite(kayit);
        if (kullanilabilirlik != null) {
            birikim.kullanilabilirlik += kullanilabilirlik;
            birikim.kullanilabilirlikSayisi += 1;
        }
        if (performans != null) {
            birikim.performans += performans;
            birikim.performansSayisi += 1;
        }
        if (kalite != null) {
            birikim.kalite += kalite;
            birikim.kaliteSayisi += 1;
        }
        return birikim;
    }, {
        kullanilabilirlik: 0,
        kullanilabilirlikSayisi: 0,
        performans: 0,
        performansSayisi: 0,
        kalite: 0,
        kaliteSayisi: 0,
    });
    const kullanilabilirlik = toplamlar.kullanilabilirlikSayisi
        ? oeeYuvarla(toplamlar.kullanilabilirlik / toplamlar.kullanilabilirlikSayisi)
        : 0;
    const performans = toplamlar.performansSayisi
        ? oeeYuvarla(toplamlar.performans / toplamlar.performansSayisi)
        : 0;
    const kalite = toplamlar.kaliteSayisi
        ? oeeYuvarla(toplamlar.kalite / toplamlar.kaliteSayisi)
        : 0;
    return {
        kullanilabilirlik,
        performans,
        kalite,
        oee: oeeSkoruHesapla(kullanilabilirlik, performans, kalite) ?? 0,
    };
}
