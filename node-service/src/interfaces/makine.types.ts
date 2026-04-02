//Makineye ait özel alt parçaların ayrı ayrı arıza/ömür takibi
export interface IParcaBakimKurali {
    parca_adi: string;
    tetikleyici_metrik: 'SAAT' | 'VURUS_SAYISI' | 'AY';
    esik_degeri: number;
    uyari_marji: number;
}

//Gözlemsel (IoT Olmayan) Dinamik Form Maddesi
export interface IOtonomFormMaddesi {
    alan: string;
    tip: 'number' | 'select' | 'boolean' | 'textarea';
    etiket: string;
    secenekler?: string[];
    zorunlu: boolean;
}

//"makine_ozellikleri" JSONB kolonunu şekillendiren Ana Tip
export interface IMakineOzellikleri {
    teknik_spesifikasyonlar: Record<string, string | number | boolean>;
    genel_bakim_periyodu_saat: number;
    ai_genel_bakim_uyari_marji_saat: number;
    parca_bakim_kurallari: IParcaBakimKurali[];
    otonom_bakim_kriterleri: IOtonomFormMaddesi[];
}