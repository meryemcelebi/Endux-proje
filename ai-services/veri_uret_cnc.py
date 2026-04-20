import pandas as pd
import random

print("⚙️ KB-V4: CNC İçin Veri Seti Üretiliyor...\n")

veri_cnc = []
for _ in range(5000):
    form_suresi = random.randint(2, 120)
    
    # 1. Ortak Parametreler (Word Dosyası Madde 1)
    ortak = {"sicaklik": 0, "titresim": 0, "ses_anomalisi": 0, "yag_durumu": 0}
    
    # 2. CNC Özel Parametreler (Word Dosyası Madde 2)
    ozel = {
        "is_mili_ses_ve_titresim": 0, "eksen_olcu_sapmasi": 0, "takim_zorlanma_durumu": 0, 
        "islenen_yuzey_kalitesi": 0, "is_mili_govde_sicakligi": 0, "bor_yagi_ve_sogutma": 0,
        "pnomatik_hava_basinci": 0, "kizak_yag_seviyesi": 0
    }
    
    ariza_kodu = "YOK"
    rnd = random.random()
    
    # MICHIGAN LABORATUVAR KORELASYONLARI
    if rnd < 0.25:
        ariza_kodu = "SPINDLE_RULMAN_ARIZASI" # Yüksek frekanslı titreşim -> Yüzey bozulur
        ortak["titresim"], ortak["ses_anomalisi"] = 2, 2
        ozel["is_mili_ses_ve_titresim"] = 2
        ozel["islenen_yuzey_kalitesi"] = 2
        ozel["takim_zorlanma_durumu"] = random.choice([1, 2])
    elif rnd < 0.45:
        ariza_kodu = "EKSEN_MOTOR_ARIZASI" # Akım artışı -> Isınma ve ölçü kaçıklığı
        ortak["sicaklik"] = 2
        ozel["eksen_olcu_sapmasi"] = 2
        ozel["is_mili_govde_sicakligi"] = 2
        ozel["kizak_yag_seviyesi"] = random.choice([1, 2])
    elif rnd < 0.60:
        ariza_kodu = "PNOMATIK_VALF_ARIZASI" # Hava basınç kaybı
        ozel["pnomatik_hava_basinci"] = 2
    elif rnd < 0.70:
        ariza_kodu = "BOR_YAGI_POMPA_ARIZASI" # Soğutma biterse sıcaklık fırlar
        ortak["sicaklik"] = 1
        ozel["bor_yagi_ve_sogutma"] = 2
        ozel["is_mili_govde_sicakligi"] = random.choice([1, 2])

    # GÜVEN KALKANI (10 Saniye Altı -> Tembel Operatör Tüm Verileri 0 Girer)
    if form_suresi < 10 and ariza_kodu != "YOK":
        for k in ortak.keys(): ortak[k] = 0
        for k in ozel.keys(): ozel[k] = 0

    satir = {"makine_turu": "CNC", "form_doldurma_suresi_sn": form_suresi, "HEDEF_ARIZA": ariza_kodu}
    satir.update(ortak)
    satir.update(ozel)
    veri_cnc.append(satir)

pd.DataFrame(veri_cnc).to_csv("kb_v4_cnc_egitim_verisi.csv", index=False)
print("✅ CNC veriseti oluşturuldu: kb_v4_cnc_egitim_verisi.csv")