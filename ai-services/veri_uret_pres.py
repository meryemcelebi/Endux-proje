import pandas as pd
import random

print("⚙️ KB-V4: Pres Makinesi İçin Veri Seti Üretiliyor...\n")

veri_pres = []
for _ in range(5000):
    form_suresi = random.randint(2, 120)
    
    ortak = {"sicaklik": 0, "titresim": 0, "ses_anomalisi": 0, "yag_durumu": 0}
    ozel = {
        "hidrolik_basinc_seviyesi": 0, "hidrolik_yag_sicakligi": 0, "yag_kacak_durumu": 0,
        "koc_vuruntu_sesi": 0, "koc_kilavuz_boslugu": 0, "kavrama_fren_hava_basinci": 0,
        "tonaj_sapmasi": 0, "basilan_parca_kalitesi": 0
    }
    
    ariza_kodu = "YOK"
    rnd = random.random()
    
    # PRES ENDÜSTRİ STANDARTLARI (Mock Korelasyonlar)
    if rnd < 0.25:
        ariza_kodu = "ANA_HIDROLIK_POMPA_ARIZASI"
        ortak["sicaklik"], ortak["ses_anomalisi"] = 2, 2
        ozel["hidrolik_yag_sicakligi"] = random.choice([1, 2])
        ozel["hidrolik_basinc_seviyesi"] = 2
    elif rnd < 0.50:
        ariza_kodu = "HIDROLIK_YON_VALFI_ARIZASI"
        ortak["yag_durumu"] = 2
        ozel["yag_kacak_durumu"] = 2
        ozel["hidrolik_basinc_seviyesi"] = 2
        ozel["basilan_parca_kalitesi"] = 1
    elif rnd < 0.65:
        ariza_kodu = "MEKANIK_GOVDE_YORULMASI"
        ortak["titresim"] = 2
        ozel["koc_kilavuz_boslugu"] = 2
        ozel["koc_vuruntu_sesi"] = 2
        ozel["tonaj_sapmasi"] = 2

    # GÜVEN KALKANI
    if form_suresi < 10 and ariza_kodu != "YOK":
        for k in ortak.keys(): ortak[k] = 0
        for k in ozel.keys(): ozel[k] = 0

    satir = {"makine_turu": "PRES", "form_doldurma_suresi_sn": form_suresi, "HEDEF_ARIZA": ariza_kodu}
    satir.update(ortak)
    satir.update(ozel)
    veri_pres.append(satir)

pd.DataFrame(veri_pres).to_csv("kb_v4_pres_egitim_verisi.csv", index=False)
print("✅ PRES veriseti oluşturuldu: kb_v4_pres_egitim_verisi.csv")