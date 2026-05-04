"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.turkceKarakterTemizle = turkceKarakterTemizle;
exports.rol_on_eki_getir = rol_on_eki_getir;
function turkceKarakterTemizle(metin) {
    const karakterHaritasi = {
        ğ: "g",
        ü: "u",
        ş: "s",
        ı: "i",
        ö: "o",
        ç: "c",
        Ğ: "G",
        Ü: "U",
        Ş: "S",
        İ: "I",
        Ö: "O",
        Ç: "C",
    };
    return metin
        .toLowerCase()
        .replace(/[ğüşiöçĞÜŞİÖÇ]/g, (harf) => karakterHaritasi[harf] || harf)
        .replace(/\s+/g, ""); // Boşlukları kaldır
}
function rol_on_eki_getir(rol) {
    const on_ek_haritasi = {
        OPERATOR: "OP_",
        TEKNISYEN: "TS_",
        YONETICI: "YON_",
        SERVIS: "SRV_",
    };
    return on_ek_haritasi[rol] || "";
}
