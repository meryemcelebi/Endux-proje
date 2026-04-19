import pandas as pd
import random

print("⚙️ KB-V4: Plastik Enjeksiyon Makinesi İçin Veri Seti Üretiliyor...\n")

veri_enj = []
for _ in range(5000):
    form_suresi = random.randint(2, 120)
    
    ortak = {"sicaklik": 0, "titresim": 0, "ses_anomalisi": 0, "yag_durumu": 0}
    ozel = {
        "kovan_rezistans_sicakligi": 0, "eriyik_plastik_kokusu": 0, "vida_donus_sesi": 0,
        "enjeksiyon_baski_basinci": 0, "mengene_kapanma_basinci": 0, "kalip_sogutma_suyu_debisi": 0,
        "sogutma_suyu_sicakligi": 0, "eksik_baski_durumu": 0, "capakli_baski_durumu": 0
    }
    
    ariza_kodu = "YOK"
    rnd = random.random()
    
    # ENJEKSİYON ENDÜSTRİ STANDARTLARI (Mock Korelasyonlar)
    if rnd < 0.30:
        ariza_kodu = "ISITICI_REZISTANS_ARIZASI"
        ortak["sicaklik"] = 2
        ozel["kovan_rezistans_sicakligi"] = 2
        ozel["eriyik_plastik_kokusu"] = random.choice([1, 2])
        ozel["eksik_baski_durumu"] = 2
    elif rnd < 0.50:
        ariza_kodu = "VIDA_KOVAN_ASINMASI"
        ortak["titresim"], ortak["ses_anomalisi"] = 2, 2
        ozel["vida_donus_sesi"] = 2
        ozel["enjeksiyon_baski_basinci"] = 2
        ozel["eksik_baski_durumu"] = 1
    elif rnd < 0.65:
        ariza_kodu = "KALIP_SOGUTMA_VALFI_ARIZASI"
        ortak["yag_durumu"] = 1 # Su sızıntısı
        ozel["kalip_sogutma_suyu_debisi"] = 2
        ozel["sogutma_suyu_sicakligi"] = 2
        ozel["capakli_baski_durumu"] = random.choice([1, 2])

    # GÜVEN KALKANI
    if form_suresi < 10 and ariza_kodu != "YOK":
        for k in ortak.keys(): ortak[k] = 0
        for k in ozel.keys(): ozel[k] = 0

    satir = {"makine_turu": "ENJEKSIYON", "form_doldurma_suresi_sn": form_suresi, "HEDEF_ARIZA": ariza_kodu}
    satir.update(ortak)
    satir.update(ozel)
    veri_enj.append(satir)

pd.DataFrame(veri_enj).to_csv("kb_v4_enjeksiyon_egitim_verisi.csv", index=False)
print("✅ ENJEKSİYON veriseti oluşturuldu: kb_v4_enjeksiyon_egitim_verisi.csv")