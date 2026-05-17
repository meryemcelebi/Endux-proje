import pandas as pd
import numpy as np

print("⚙️ KB-V6: FMEA Olasılıksal Motoru ile Veri Üretiliyor...\n")

# FMEA Ağırlıkları (Mühendislik Hata Türleri ve Etkileri Analizi)
FMEA = {
    # Ortak
    "sicaklik": 0.80, "titresim": 0.90, "ses_anomalisi": 0.70, "yag_durumu": 0.60,
    # CNC
    "is_mili_ses_ve_titresim": 0.90, "eksen_olcu_sapmasi": 0.90, "takim_zorlanma_durumu": 0.70,
    "islenen_yuzey_kalitesi": 0.80, "is_mili_govde_sicakligi": 0.80, "bor_yagi_ve_sogutma": 0.60,
    "pnomatik_hava_basinci": 0.50, "kizak_yag_seviyesi": 0.50,
    # PRES
    "hidrolik_basinc_seviyesi": 1.0, "hidrolik_yag_sicakligi": 0.80, "yag_kacak_durumu": 0.90,
    "koc_vuruntu_sesi": 0.70, "koc_kilavuz_boslugu": 0.80, "kavrama_fren_hava_basinci": 1.0,
    "tonaj_sapmasi": 0.90, "basilan_parca_kalitesi": 0.80,
    # ENJ
    "kovan_rezistans_sicakligi": 0.80, "eriyik_plastik_kokusu": 0.70, "vida_donus_sesi": 0.70,
    "enjeksiyon_baski_basinci": 0.90, "mengene_kapanma_basinci": 0.90, "kalip_sogutma_suyu_debisi": 0.60,
    "sogutma_suyu_sicakligi": 0.60, "eksik_baski_durumu": 0.80, "capakli_baski_durumu": 0.70
}

MAKINE_ARIZALARI = {
    "CNC": {
        "SPINDLE_RULMAN_ARIZASI": ["titresim", "ses_anomalisi", "is_mili_ses_ve_titresim", "islenen_yuzey_kalitesi", "is_mili_govde_sicakligi"],
        "EKSEN_MOTOR_ARIZASI": ["sicaklik", "eksen_olcu_sapmasi", "is_mili_govde_sicakligi", "kizak_yag_seviyesi"],
        "PNOMATIK_VALF_ARIZASI": ["pnomatik_hava_basinci", "ses_anomalisi"],
        "BOR_YAGI_POMPA_ARIZASI": ["sicaklik", "bor_yagi_ve_sogutma", "is_mili_govde_sicakligi"]
    },
    "PRES": {
        "ANA_HIDROLIK_POMPA_ARIZASI": ["sicaklik", "ses_anomalisi", "hidrolik_yag_sicakligi", "hidrolik_basinc_seviyesi"],
        "HIDROLIK_YON_VALFI_ARIZASI": ["yag_durumu", "yag_kacak_durumu", "hidrolik_basinc_seviyesi", "basilan_parca_kalitesi"],
        "MEKANIK_GOVDE_YORULMASI": ["titresim", "ses_anomalisi", "koc_kilavuz_boslugu", "koc_vuruntu_sesi", "tonaj_sapmasi"]
    },
    "ENJEKSIYON": {
        "ISITICI_REZISTANS_ARIZASI": ["sicaklik", "kovan_rezistans_sicakligi", "eriyik_plastik_kokusu", "eksik_baski_durumu"],
        "VIDA_KOVAN_ASINMASI": ["titresim", "ses_anomalisi", "vida_donus_sesi", "enjeksiyon_baski_basinci", "eksik_baski_durumu"],
        "KALIP_SOGUTMA_VALFI_ARIZASI": ["yag_durumu", "kalip_sogutma_suyu_debisi", "sogutma_suyu_sicakligi", "capakli_baski_durumu"]
    }
}

MAKINE_PARAMETRELERI = {
    "CNC": ["sicaklik", "titresim", "ses_anomalisi", "yag_durumu", "is_mili_ses_ve_titresim", "eksen_olcu_sapmasi", "takim_zorlanma_durumu", "islenen_yuzey_kalitesi", "is_mili_govde_sicakligi", "bor_yagi_ve_sogutma", "pnomatik_hava_basinci", "kizak_yag_seviyesi"],
    "PRES": ["sicaklik", "titresim", "ses_anomalisi", "yag_durumu", "hidrolik_basinc_seviyesi", "hidrolik_yag_sicakligi", "yag_kacak_durumu", "koc_vuruntu_sesi", "koc_kilavuz_boslugu", "kavrama_fren_hava_basinci", "tonaj_sapmasi", "basilan_parca_kalitesi"],
    "ENJEKSIYON": ["sicaklik", "titresim", "ses_anomalisi", "yag_durumu", "kovan_rezistans_sicakligi", "eriyik_plastik_kokusu", "vida_donus_sesi", "enjeksiyon_baski_basinci", "mengene_kapanma_basinci", "kalip_sogutma_suyu_debisi", "sogutma_suyu_sicakligi", "eksik_baski_durumu", "capakli_baski_durumu"]
}

def generate_value(is_relevant, fmea_weight):
    if is_relevant:

        p_critic = fmea_weight * 0.7  # Eğer FMEA 0.90 ise %63 ihtimalle 2 çıkar
        p_warn = 0.85 - p_critic      # Kalanı uyarıdır (1)
        p_normal = 0.15               # %15 ihtimalle arıza olmasına rağmen sensör/operatör normal (0) algılar
        probs = np.array([p_normal, p_warn, p_critic])
    else:

        probs = np.array([0.85, 0.12, 0.03])
        
    probs = probs / probs.sum()  # Toplamın 1 olduğundan emin ol
    return np.random.choice([0, 1, 2], p=probs)

for makine_turu, arizalar in MAKINE_ARIZALARI.items():
    veri = []
    parametreler = MAKINE_PARAMETRELERI[makine_turu]
    
    ariza_listesi = list(arizalar.keys()) + ["YOK", "YOK", "YOK", "YOK"] 
    
    for _ in range(15000): # Her makine için 15 bin satır!
        form_suresi = np.random.randint(15, 120)
        hedef_ariza = np.random.choice(ariza_listesi)
        
        satir = {"makine_turu": makine_turu, "form_doldurma_suresi_sn": form_suresi, "HEDEF_ARIZA": hedef_ariza}
        
        for param in parametreler:
            fmea = FMEA.get(param, 0.5)
            if hedef_ariza == "YOK":
                # Makine sağlıklıysa %92 ihtimalle sorunsuzdur, %8 ufak tefek pürüzler vardır.
                satir[param] = np.random.choice([0, 1, 2], p=[0.92, 0.07, 0.01])
            else:
                is_relevant = param in arizalar[hedef_ariza]
                satir[param] = generate_value(is_relevant, fmea)
                
        # DİKKATSİZ OPERATÖR SİMÜLASYONU (%5 İhtimal)
        if np.random.random() < 0.05: 
            satir["form_doldurma_suresi_sn"] = np.random.randint(2, 9)
            if satir["HEDEF_ARIZA"] != "YOK":
                # Makine bozuk ama operatör sallamış ve hepsine 0 girmiş!
                # AI'ın buradaki çelişkiyi (kısa süre + hepsine 0 + aslında bozuk) öğrenmesi lazım.
                for param in parametreler:
                    satir[param] = 0
                    
        veri.append(satir)
        
    df = pd.DataFrame(veri)
    dosya_adi = f"kb_v6_{makine_turu.lower()}_egitim_verisi.csv"
    df.to_csv(dosya_adi, index=False)
    print(f"✅ {makine_turu} V6 veri seti üretildi: {dosya_adi} (15.000 satır)")
