export function turkceKarakterTemizle(metin: string): string {
    const karakterHaritasi: Record<string, string> = {
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
    .replace(/\s+/g, "") // Boşlukları kaldır
    }


    export function rol_on_eki_getir(rol: string): string {
        const on_ek_haritasi: Record<string, string> = {
            OPERATOR: "OP_",
            TEKNISYEN: "TS_",
            YONETICI: "YON_",
        };
        return on_ek_haritasi[rol] || "";
    }