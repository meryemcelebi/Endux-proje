import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";



/**
 * Ana Kontrol Paneli (Dashboard)
 * Fabrikanın dijital ikizi niteliğindedir. Makine durumlarını, 
 * bakım onaylarını, kritik riskleri ve maliyet analizlerini 
 * özetleyerek tek bir ekrandan yönetim imkanı sunar.
 */
export default function Dashboard() {
  const navigate = useNavigate(); // Sayfalar arası yönlendirme için React Router hook'u

  // --- STATE TANIMLAMALARI (Uygulamanın Hafızası) ---
  const [machinesList, setMachinesList] = useState([]); // API'den gelen ve zenginleştirilen tüm makinelerin listesi
  const [, setIsLoading] = useState(true); // Veriler yüklenirken gösterilen yükleme durumu
  const [pendingApprovals, setPendingApprovals] = useState(0); // Servis firması tarafından tamamlanmış, kullanıcı puanı bekleyen kayıtlar
  const [pendingTasks, setPendingTasks] = useState([]); // Arıza kaydı açılmış ancak henüz teknisyen ataması bekleyen görevler
  const [allHistory] = useState([]); // Grafikler için kullanılan geçmiş servis verileri
  const [isOeeModalOpen, setIsOeeModalOpen] = useState(false); // Verimlilik (OEE) detaylarını gösteren pencerenin durumu
  const [isApprovalModalOpen, setIsApprovalModalOpen] = useState(false); // Bakım/Onay detaylarını yöneten ana modalin durumu
  const [selectedTaskIds, setSelectedTaskIds] = useState([]); // Toplu onaylama işlemi için seçilen görevlerin ID'leri
  const [activeDetailTab, setActiveDetailTab] = useState(null); // Modalde hangi sekmenin (Bakımda, Bekleyen vs.) aktif olduğunu tutar
  //const [firmsMetadata, setFirmsMetadata] = useState([]); // Servis firmalarının değerlendirme ve iletişim bilgileri
  const [isAlertModalOpen, setIsAlertModalOpen] = useState(false);
  const [activeBreakdownId, setActiveBreakdownId] = useState(null);
  const [breakdownDesc, setBreakdownDesc] = useState("");
  const [activeFloor, setActiveFloor] = useState(0); // Fabrika haritası kat kontrolü
  const [isMapExpanded, setIsMapExpanded] = useState(false); // Harita büyütme durumu

  // --- OEE ANALİZ VERİLERİ (Haftalık Verimlilik Değerleri) ---
  // --- OEE ANALİZ VERİLERİ (Haftalık Verimlilik Değerleri) ---
  //const [oeeWeeklyData, setOeeWeeklyData] = useState([]); // Sabit dizi yerine state
  const [fabrikaOee, setFabrikaOee] = useState(0); // Ana OEE skorunu tutmak için

  const getMachineStatus = (machine) => String(machine?.aktiflik_durumu || "").trim().toLowerCase();
  const pendingMachines = machinesList.filter((machine) => {
    const status = getMachineStatus(machine);
    return status.includes("onay") && status.includes("bek");
  });
  const bakimdaMachines = machinesList.filter((machine) => getMachineStatus(machine) === "bakımda");
  const yaklasanMachines = machinesList.filter((machine) => getMachineStatus(machine) === "bakımı yaklaşan");
  const activeMachines = machinesList.filter((machine) => {
    const status = getMachineStatus(machine);
    return status === "aktif" || status === "normal" || status === "çalışıyor";
  });


  // --- VERİ ÇEKME VE ZENGİNLEŞTİRME SÜRECİ ---
  React.useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        setIsLoading(true);

        // 1. ADIM: Tüm ağır işi backend'de yapan o tek fonksiyonu çağır!
        const dashboardOzet = await api.getDashboardOzet(); // Backend'deki zengin veri
        const operasyonelPerformans = dashboardOzet?.operasyonel_performans ?? {};
        const acilAksiyonlar = dashboardOzet?.acil_aksiyonlar ?? {};

        // Backend'den gelen hazır özetleri state'lere dağıt
        setFabrikaOee(Number(operasyonelPerformans.ortalama_oee ?? 0));
        setPendingApprovals(Number(acilAksiyonlar.onay_bekleyen_is ?? 0));
        // ... diğer set işlemleri

        // 2. ADIM: Sadece liste için gereken veriyi çek
        const machinesData = await api.getMachines();
        setMachinesList(machinesData);

      } catch (err) {
        console.error("Dashboard yükleme hatası:", err);
      } finally {
        setIsLoading(false);
      }
    };
    fetchDashboardData();
  }, []);

  // --- KRİTİK ALARMLARI BELİRLE ---
  // Sadece Yüksek Riskli olanları "Risky Machines" olarak al
  const riskyMachines = machinesList.filter(m =>
    m.kategori === "Yüksek Riskli"
  );

  // Sayısal özet verileri
  const yRCount = riskyMachines.length;


  // --- MALİYET VE BÜTÇE ANALİZİ (Tamamen Canlı Veri) ---
  const toplamMakineAlim = machinesList.reduce((sum, m) => sum + Number(m.satin_alma_maaliyeti || m.satin_alma_maliyeti || 0), 0);
  const toplamServisUcreti = allHistory.reduce((sum, h) => sum + Number(h.bakim_maliyet || 0), 0);

  // Parça masrafı: Bakım geçmişindeki parça değişim kayıtlarından gerçek toplamı hesapla
  const toplamParcaMasrafi = allHistory.reduce((sum, h) => {
    const parcaToplami = (h.parca_degisim || []).reduce((pSum, p) => pSum + (Number(p.parca?.parca_maliyeti || 0) * (p.adet || 1)), 0);
    return sum + parcaToplami;
  }, 0);

  // Grafik ölçeklendirmesi için en yüksek maliyeti bul
  const maxMaliyet = Math.max(toplamMakineAlim, toplamServisUcreti, toplamParcaMasrafi, 1);

  // Maliyet Grafiği (Bar Chart) için veri objesi
  const maliyetVerileri = [
    { label: "Makine Alımı", value: toplamMakineAlim, color: "#3498db", gradient: "linear-gradient(to top, #2980b9, #3498db)" },
    { label: "Parça Masrafı", value: toplamParcaMasrafi, color: "#e67e22", gradient: "linear-gradient(to top, #d35400, #e67e22)" },
    { label: "Servis Ücreti", value: toplamServisUcreti, color: "#9b59b6", gradient: "linear-gradient(to top, #8e44ad, #9b59b6)" },
  ];

  // --- HANDLERS (Olay Yakalayıcılar) ---

  // Yeni bir arıza kaydı oluşturma işlemi (Bildirim simülasyonu)
  const handleCreateBreakdown = (mach) => {
    alert(mach.ad + " için arıza kaydı başarıyla oluşturuldu!" + (breakdownDesc ? "\nNot: " + breakdownDesc : ""));
    setActiveBreakdownId(null);
    setBreakdownDesc("");
  };


  // Toplu Yoksayma İşlemi (Sadece listeden kaldırır)
  const handleBulkIgnore = () => {
    if (selectedTaskIds.length === 0) return;
    const confirmBulk = window.confirm(`${selectedTaskIds.length} adet görevi listeden kaldırmak istediğinize emin misiniz?`);
    if (confirmBulk) {
      setPendingTasks(prev => prev.filter(t => !selectedTaskIds.includes(t.id)));
      setSelectedTaskIds([]); // Seçimleri temizle
    }
  };

  // İkon yardımcı fonksiyonu: Kategoriye göre emoji döndürür
  const getCategoryIcon = (kat) => {
    if (kat.includes("Riskli")) return "⚠️";
    if (kat.includes("Yaklaşan")) return "⏳";
    return "🔧";
  };

  // Dinamik renk yardımcı fonksiyonu: Duruma göre HEX renk kodu döndürür
  const getCategoryColor = (kat, gar) => {
    if (kat === "Yüksek Riskli") return "#444444";
    if (gar === "Kritik") return "#008080";
    if (kat === "Bakımı Yaklaşan") return "#4682B4";
    return "#7f8c8d";
  };

  // --- TOPLU İŞLEM VE MODAL YÖNETİMİ ---

  // Seçili tüm bakım görevlerini tek seferde onaylayan fonksiyon
  const handleBulkApprove = async () => {
    if (selectedTaskIds.length === 0) return;

    try {
      if (selectedTaskIds.length > 0) {
        await Promise.all(selectedTaskIds.map(id => api.updateTaskStatus(id, "ONAYLANDI")));
      }

      const count = selectedTaskIds.length;
      alert(`${count} Adet bakım görevi onaylandı ve teknik servis listesine aktarıldı!`);

      // Onaylananları listeden çıkar ve seçimleri sıfırla
      setPendingTasks(prev => prev.filter(t => !selectedTaskIds.includes(t.id)));
      setSelectedTaskIds([]);
      setIsApprovalModalOpen(false);
    } catch (err) {
      console.error("Görevler onaylanırken hata oluştu", err);
      alert("Görevler onaylanırken bir hata oluştu!");
    }
  };

  // Bir görevi onay listesine ekleme veya listeden çıkarma
  const toggleTaskSelection = (id) => {
    setSelectedTaskIds(prev =>
      prev.includes(id) ? prev.filter(tid => tid !== id) : [...prev, id]
    );
  };

  // Bakım yönetim modalini açar ve hangi sekmenin (tab) gösterileceğini ayarlar
  const openApprovalModal = (tab = null) => {
    setActiveDetailTab(tab);
    setIsApprovalModalOpen(true);
  };

  // --- GRAFİKSEL HESAPLAMALAR VE ORANLAR ---

  // Hiçbir sorunu olmayan, normal çalışan aktif makine sayısını bul
  const totalMachinesCount = machinesList.length || 0;
  const bakimdaMakineCount = bakimdaMachines.length;
  const activeMachinesCount = activeMachines.length;
  const onayBekleyenCount = pendingMachines.length; // Makine durumuna göre onay bekleyenler
  const bakimiYaklasanCount = yaklasanMachines.length; // Takvimi yaklaşanlar

  // Grafik paydası: Tüm kalemlerin toplamı (Grafiğin %100 tam daire görünmesi için)
  const chartTotal = (onayBekleyenCount + bakimdaMakineCount + bakimiYaklasanCount + activeMachinesCount) || 1;

  // Fabrika OEE Hesaplaması (Availability temelli)
  const factoryOee = totalMachinesCount > 0 ? ((activeMachinesCount / totalMachinesCount) * 100).toFixed(1) : 0;

  // 8 Haftalık OEE Geçmişi Hazırlığı (7 Hafta Boş + Mevcut Hafta)
  const oeeHistory = [
    { week: "H-7", oee: 0 }, { week: "H-6", oee: 0 }, { week: "H-5", oee: 0 },
    { week: "H-4", oee: 0 }, { week: "H-3", oee: 0 }, { week: "H-2", oee: 0 },
    { week: "Geçen H.", oee: 0 },
    { week: "Bu Hafta", oee: Number(factoryOee) }
  ];

  // Doughnut grafiği dilimlerinin yüzde (%) oranları
  const bakimdaRatio = (bakimdaMakineCount / chartTotal) * 100;
  const onayBekleyenRatio = (onayBekleyenCount / chartTotal) * 100;
  const yaklasanRatio = (bakimiYaklasanCount / chartTotal) * 100;
  const activeRatio = (activeMachinesCount / chartTotal) * 100;

  // --- FABRİKA YERLEŞİM PLANI (HARİTA) ÇİZİMİ ---
  const renderFloorPlan = (isLarge = false) => {
    // 1. Makineleri Kat ve Bloklara Grupla
    const groupedMachines = machinesList.reduce((acc, m, index) => {
      // Maliyet Analizini Hesapla (Bakım Masrafı / Satın Alma Maliyeti) % olarak
      const makineMaliyeti = m.satin_alma_maliyeti ? Number(m.satin_alma_maliyeti) : 100000;
      const toplamBakimGideri = (m.bakim_kaydi || []).reduce((sum, kayit) => sum + Number(kayit.bakim_maliyet || 0), 0);
      let gercekMaliyetYuzdesi = (toplamBakimGideri / makineMaliyeti) * 100;
      gercekMaliyetYuzdesi = parseFloat(gercekMaliyetYuzdesi.toFixed(1));

      // 3 Renk Mantığı (İdeal, Dikkat, Kritik) - Kullanıcı Talebi: %5 Uyarı, %10 Kritik
      let renkCode = "#22C55E";
      let kRit = "İdeal";
      if (gercekMaliyetYuzdesi >= 10) { renkCode = "#EF4444"; kRit = "Kritik Kayıp"; }
      else if (gercekMaliyetYuzdesi >= 5) { renkCode = "#F59E0B"; kRit = "Uyarı / Risk"; }
      else { renkCode = "#22C55E"; kRit = "İdeal"; }

      const loc = m.lokasyon?.[0];
      const targetKat = loc?.kat || "Zemin";
      const targetBlock = loc?.fabrika_alani || "BÖLGE 1";

      if (!acc[targetKat]) acc[targetKat] = {};
      if (!acc[targetKat][targetBlock]) acc[targetKat][targetBlock] = [];

      const displayNo = index + 1;
      acc[targetKat][targetBlock].push({
        ...m,
        gercekMaliyetYuzdesi,
        renkCode,
        kRit,
        displayNo,
        x: loc?.x_koor != null ? Number(loc.x_koor) : undefined,
        y: loc?.y_koor != null ? Number(loc.y_koor) : undefined
      });
      return acc;
    }, {});

    const renderMachinesInZone = (machines) => {
      // Makineleri bölgenin kenarlarına (duvar diplerine) dizmek için özel mantık
      return (
        <div style={{
          position: 'relative',
          width: '100%',
          height: '100%',
          minHeight: isLarge ? '120px' : '80px',
          padding: '10px'
        }}>
          {machines.map((m, i) => {
            // Makineleri kutunun çevresine (kenarlarına) sırayla diz
            const count = machines.length;
            const boxSize = isLarge ? 24 : 18;
            const padding = 8;
            // Her kenara kaç makine düşeceğini hesapla
            const perSide = Math.max(1, Math.ceil(count / 4));
            let pos = {};

            if (i < perSide) {
              // ÜST KENAR: soldan sağa
              const step = (100 - padding * 2) / Math.max(perSide, 1);
              pos = { top: `${padding}%`, left: `${padding + i * step}%` };
            } else if (i < perSide * 2) {
              // SAĞ KENAR: yukarıdan aşağıya
              const idx = i - perSide;
              const step = (100 - padding * 2) / Math.max(perSide, 1);
              pos = { top: `${padding + idx * step}%`, right: `${padding}%` };
            } else if (i < perSide * 3) {
              // ALT KENAR: sağdan sola
              const idx = i - perSide * 2;
              const step = (100 - padding * 2) / Math.max(perSide, 1);
              pos = { bottom: `${padding}%`, right: `${padding + idx * step}%` };
            } else {
              // SOL KENAR: aşağıdan yukarıya
              const idx = i - perSide * 3;
              const step = (100 - padding * 2) / Math.max(perSide, 1);
              pos = { bottom: `${padding + idx * step}%`, left: `${padding}%` };
            }

            return (
              <div
                key={m.id}
                onClick={(e) => { e.stopPropagation(); navigate(`/makine/${m.id}`); }}
                style={{
                  position: 'absolute',
                  ...pos,
                  width: isLarge ? '24px' : '18px',
                  height: isLarge ? '24px' : '18px',
                  borderRadius: '4px',
                  backgroundColor: m.renkCode,
                  cursor: 'pointer',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: '#fff', fontSize: isLarge ? '10px' : '8px', fontWeight: '950',
                  boxShadow: `0 2px 4px rgba(0,0,0,0.15)`,
                  border: "1.5px solid #fff",
                  zIndex: 5,
                  transition: 'all 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
                }}
                onMouseOver={(e) => { e.currentTarget.style.transform = 'scale(1.3) rotate(5deg)'; e.currentTarget.style.zIndex = 20; }}
                onMouseOut={(e) => { e.currentTarget.style.transform = 'scale(1) rotate(0deg)'; e.currentTarget.style.zIndex = 5; }}
                title={`${m.makine_adi || m.ad}\nRisk: %${m.gercekMaliyetYuzdesi}`}
              >
                {m.displayNo}
              </div>
            );
          })}
          {/* Bölge ortasında teknik bir boşluk hissi */}
          <div style={{
            position: 'absolute',
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
            fontSize: '9px',
            fontWeight: '900',
            color: '#f1f5f9',
            opacity: 0.5,
            pointerEvents: 'none',
            textTransform: 'uppercase',
            letterSpacing: '2px'
          }}>
            İŞLEM ALANI
          </div>
        </div>
      );
    }

    const gridZoneStyle = {
      background: "#fff",
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      padding: "8px",
      position: "relative",
      border: "2px solid #e2e8f0",
      borderRadius: "12px",
      boxShadow: "0 2px 4px rgba(0,0,0,0.02)",
      zIndex: 2,
      overflow: "hidden"
    };
    const aisleStyleV = {
      background: "#f8fafc",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: "10px",
      fontWeight: "950",
      color: "#cbd5e1",
      writingMode: "vertical-rl",
      letterSpacing: "4px",
      borderLeft: "1px dashed #e2e8f0",
      borderRight: "1px dashed #e2e8f0"
    };
    const aisleStyleH = {
      background: "#f8fafc",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: "10px",
      fontWeight: "950",
      color: "#cbd5e1",
      letterSpacing: "8px",
      borderTop: "1px dashed #e2e8f0",
      borderBottom: "1px dashed #e2e8f0",
      height: "30px"
    };
    const zoneLabelStyle = {
      fontSize: "10px",
      fontWeight: "950",
      color: "#1e293b",
      marginBottom: "6px",
      borderBottom: "2px solid #3498db",
      paddingBottom: "2px",
      width: "100%",
      textAlign: "center",
      textTransform: "uppercase"
    };

    return (
      <div style={{
        width: "100%",
        height: "100%",
        padding: isLarge ? "20px" : "10px",
        display: "flex",
        flexDirection: "column",
        backgroundColor: "#ffffff",
        borderRadius: "20px",
        position: "relative",
        overflow: "hidden",
        border: "1px solid #e2e8f0",
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "15px", zIndex: 10 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
              <span style={{ fontSize: isLarge ? "20px" : "16px", fontWeight: "950", color: "#1e293b", letterSpacing: "1px" }}>
                FABRİKA YERLEŞİM ALANI
              </span>
              <div style={{ padding: "3px 8px", background: "#f1f5f9", color: "#1e293b", border: "1px solid #e2e8f0", borderRadius: "5px", fontSize: "10px", fontWeight: "900" }}>
                {activeFloor === 0 ? "ZEMİN KAT" : "1. KAT"}
              </div>
            </div>
            <div style={{ display: "flex", gap: "10px", fontSize: "10px", fontWeight: "950" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "5px", color: "#22c55e" }}>● İDEAL (%0-5)</div>
              <div style={{ display: "flex", alignItems: "center", gap: "5px", color: "#f59e0b" }}>● UYARI (%5-10)</div>
              <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "#ef4444" }}>● KRİTİK (%10+)</div>
            </div>
          </div>
        </div>

        <div style={{
          flex: 1,
          display: "grid",
          gridTemplateColumns: "1fr 30px 1fr 30px 1fr",
          gridTemplateRows: "1fr 30px 1fr",
          gap: "0",
          borderRadius: "12px",
          position: "relative",
          overflow: "hidden",
          border: "2px solid #e2e8f0",
          boxShadow: "0 5px 15px rgba(0,0,0,0.03)"
        }}>
          {activeFloor === 0 ? (
            <>
              <div style={gridZoneStyle}>
                <span style={zoneLabelStyle}>BÖLGE 1 </span>
                {renderMachinesInZone(groupedMachines["Zemin"]?.["BÖLGE 1"] || [])}
              </div>
              <div style={aisleStyleV}>YOL</div>
              <div style={gridZoneStyle}>
                <span style={zoneLabelStyle}>BÖLGE 2 </span>
                {renderMachinesInZone(groupedMachines["Zemin"]?.["BÖLGE 2"] || [])}
              </div>
              <div style={aisleStyleV}>YOL</div>
              <div style={gridZoneStyle}>
                <span style={zoneLabelStyle}>BÖLGE 3 </span>
                {renderMachinesInZone(groupedMachines["Zemin"]?.["BÖLGE 3"] || [])}
              </div>
              <div style={{ ...aisleStyleH, gridColumn: "span 5" }}>ANA LOJİSTİK AKSI</div>
              <div style={{ ...gridZoneStyle, gridColumn: "span 5" }}>
                <span style={zoneLabelStyle}>DEPO VE SEVKİYAT MERKEZİ</span>
                {renderMachinesInZone(groupedMachines["Zemin"]?.["DEPO"] || [])}
              </div>
            </>
          ) : (
            <>
              <div style={gridZoneStyle}>
                <span style={zoneLabelStyle}>BÖLGE 4 </span>
                {renderMachinesInZone(groupedMachines["1.Kat"]?.["BÖLGE D"] || [])}
              </div>
              <div style={aisleStyleV}>YOL</div>
              <div style={gridZoneStyle}>
                <span style={zoneLabelStyle}>TEKNİK SERVİS</span>
                {renderMachinesInZone(groupedMachines["1.Kat"]?.["TEKNİK"] || [])}
              </div>
              <div style={aisleStyleV}>YOL</div>
              <div style={gridZoneStyle}>
                <span style={zoneLabelStyle}>PERSONEL ALANI </span>
                {renderMachinesInZone(groupedMachines["1.Kat"]?.["OFİS"] || [])}
              </div>
              <div style={{ ...aisleStyleH, gridColumn: "span 5" }}>YÖNETİM KORİDORU</div>
              <div style={gridZoneStyle}>
                <span style={zoneLabelStyle}>İDARİ OFİSLER</span>
                {renderMachinesInZone([])}
              </div>
              <div style={aisleStyleV}>YOL</div>
              <div style={{ ...gridZoneStyle, gridColumn: "span 3" }}>
                <span style={zoneLabelStyle}>BÖLGE 5</span>
                {renderMachinesInZone(groupedMachines["1.Kat"]?.["KALİTE"] || [])}
              </div>
            </>
          )}
        </div>
      </div>
    );
  };

  // --- ANA RENDER SÜRECİ (Görünüm) ---
  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      {/* SOL MENÜ (Sidebar): Tüm sayfalara erişim sağlayan sabit yan panel */}
      <Sidebar />

      {/* SAĞ TARAF (Navigasyon ve İçerik): Sayfanın üst barı ve ana panel verilerini içerir */}
      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        {/* ÜST BİLGİ ÇUBUĞU (Navbar): Kullanıcı bilgileri ve sayfa başlığını barındırır */}
        <Navbar />

        {/* ANA PANEL İÇERİK YÜZEYİ: Tüm KPI kartları ve grafiklerin listelendiği kaydırılabilir alan */}
        <div style={{ padding: "30px", flex: 1, overflowY: "auto", display: "flex", flexDirection: "column", gap: "25px" }}>

          {/* KPI KUTULARI (DİNAMİK + SADE BAŞLIKLAR) */}
          <div style={{ display: "flex", gap: "20px", width: "100%", flex: "0 0 160px" }}>
            {/* KPI 1: TEKNİK UYARILAR */}
            {/* KPI 1: GÜNLÜK KRİTİK UYARILAR (Riskli Makineler ve Garanti Sorunları) */}
            <div
              style={{ ...kpiBox, flex: 1.2, flexDirection: "column", alignItems: "flex-start", transition: "all 0.2s", position: "relative", overflow: "hidden" }}
              onMouseOver={(e) => { e.currentTarget.style.transform = "scale(1.02)"; e.currentTarget.style.boxShadow = "0 8px 16px rgba(0,0,0,0.1)"; }}
              onMouseOut={(e) => { e.currentTarget.style.transform = "scale(1)"; e.currentTarget.style.boxShadow = "0 4px 12px rgba(0,0,0,0.05)"; }}
            >
              {/* Kart Başlığı */}
              <div style={{ fontWeight: "800", fontSize: "15px", marginBottom: "12px", borderBottom: "2px solid #f1f2f6", paddingBottom: "8px", width: "100%", textAlign: "left", color: "#e74c3c", display: "flex", alignItems: "center", gap: "8px" }}>
                Kritik Uyarılar
              </div>
              <div style={{ fontSize: "14px", fontWeight: "600", display: "flex", flexDirection: "column", gap: "8px", width: "100%" }}>

                {/* Yüksek Riskli Rozeti: Risk skoru yüksek makineleri açar */}
                <div
                  onClick={() => setIsAlertModalOpen(true)}
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    cursor: "pointer",
                    padding: "8px 12px",
                    background: "#f8fafc",
                    borderRadius: "8px",
                    border: "1px solid #e2e8f0",
                    transition: "all 0.2s"
                  }}
                  onMouseOver={(e) => { e.currentTarget.style.background = "#fff"; e.currentTarget.style.borderColor = "#f87171"; }}
                  onMouseOut={(e) => { e.currentTarget.style.background = "#f8fafc"; e.currentTarget.style.borderColor = "#e2e8f0"; }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                    <span style={{ fontSize: "16px" }}>🚩</span>
                    <div style={{ display: "flex", flexDirection: "column" }}>
                      <span style={{ fontSize: "11px", fontWeight: "700", color: "#334155", textTransform: "uppercase" }}>Yüksek Riskli</span>
                      <span style={{ fontSize: "10px", color: "#64748b" }}>Acil Müdahale</span>
                    </div>
                  </div>
                  <strong style={{ fontSize: "18px", color: "#e74c3c", fontWeight: "900" }}>{yRCount}</strong>
                </div>


              </div>
            </div>

            {/* KPI 2: BAKIM GÖREVLERİ (Modern Dairesel Grafik ve Durum Listesi) */}
            <div
              style={{ ...kpiBox, flex: 1.4, flexDirection: "row", alignItems: "center", transition: "all 0.3s cubic-bezier(0.4, 0, 0.2, 1)", gap: "20px", padding: "12px 20px" }}
              onMouseOver={(e) => { e.currentTarget.style.transform = "translateY(-4px)"; e.currentTarget.style.boxShadow = "0 12px 25px rgba(0,0,0,0.1)"; }}
              onMouseOut={(e) => { e.currentTarget.style.transform = "translateY(0)"; e.currentTarget.style.boxShadow = "0 4px 15px rgba(0,0,0,0.05)"; }}
            >
              {/* Sol: Ana Doughnut Grafik - Makine durumlarının oransal dağılımını gösterir */}
              <div
                style={{ position: "relative", width: "115px", height: "115px", flexShrink: 0, cursor: "pointer" }}
                onClick={() => openApprovalModal("total")}
              >
                <div style={{ position: "absolute", inset: "-6px", borderRadius: "50%", background: "rgba(241, 245, 249, 0.5)", zIndex: 0, border: "1px solid #e2e8f0" }}></div>
                <svg width="115" height="115" viewBox="0 0 42 42" style={{ transform: "rotate(-90deg)", position: "relative", zIndex: 1, filter: "drop-shadow(0 4px 6px rgba(0,0,0,0.1))" }}>
                  <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#f1f5f9" strokeWidth="6"></circle>
                  <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#2ecc71" strokeWidth="6" strokeDasharray={`${activeRatio} 100`} strokeDashoffset="0"></circle>
                  <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#3498db" strokeWidth="6" strokeDasharray={`${yaklasanRatio} 100`} strokeDashoffset={-activeRatio}></circle>
                  <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#f39c12" strokeWidth="6" strokeDasharray={`${bakimdaRatio} 100`} strokeDashoffset={-(activeRatio + yaklasanRatio)}></circle>
                  <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#e94560" strokeWidth="6" strokeDasharray={`${onayBekleyenRatio} 100`} strokeDashoffset={-(activeRatio + yaklasanRatio + bakimdaRatio)}></circle>
                </svg>
                {/* Grafiğin merkezindeki toplam sayı */}
                <div style={{ position: "absolute", top: 0, left: 0, width: "100%", height: "100%", display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", zIndex: 2 }}>
                  <span style={{ fontSize: "26px", fontWeight: "950", color: "#0f3460", lineHeight: 1 }}>{chartTotal}</span>
                </div>
              </div>

              {/* Sağ: Durum Legend'ı (Renkli göstergeli liste) */}
              <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: "6px" }}>
                <div style={{ fontWeight: "900", fontSize: "14px", color: "#1e293b", marginBottom: "4px", display: "flex", alignItems: "center", gap: "8px" }}>
                  Makine Durumları
                </div>
                {[
                  { label: "Onay Bekleyen", count: onayBekleyenCount, color: "#e94560", ratio: onayBekleyenRatio, tab: "pending" },
                  { label: "Şu An Bakımda", count: bakimdaMakineCount, color: "#f39c12", ratio: bakimdaRatio, tab: "maintenance" },
                  { label: "Bakımı Yaklaşan", count: bakimiYaklasanCount, color: "#3498db", ratio: yaklasanRatio, tab: "upcoming" }
                ].map((item, idx) => (
                  <div
                    key={idx}
                    onClick={() => openApprovalModal(item.tab)}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      padding: "6px 12px",
                      background: "linear-gradient(to right, #ffffff 0%, #f8f9fa 100%)",
                      borderRadius: "10px",
                      border: "1px solid #f1f5f9",
                      cursor: "pointer",
                      transition: "all 0.2s"
                    }}
                    onMouseOver={(e) => { e.currentTarget.style.borderColor = item.color; e.currentTarget.style.transform = "translateX(5px)"; }}
                    onMouseOut={(e) => { e.currentTarget.style.borderColor = "#f1f5f9"; e.currentTarget.style.transform = "translateX(0)"; }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                      {/* Küçük dairesel oran göstergesi */}
                      <svg width="20" height="20" viewBox="0 0 42 42">
                        <circle cx="21" cy="21" r="15.9" fill="transparent" stroke="#eee" strokeWidth="8"></circle>
                        <circle cx="21" cy="21" r="15.9" fill="transparent" stroke={item.color} strokeWidth="8" strokeDasharray={`${item.ratio} 100`} transform="rotate(-90 21 21)"></circle>
                      </svg>
                      <span style={{ fontSize: "11px", fontWeight: "700", color: "#475569" }}>{item.label}</span>
                    </div>
                    <div style={{ textAlign: "right" }}>
                      <div style={{ fontSize: "15px", fontWeight: "900", color: item.color, lineHeight: 1 }}>{item.count}</div>
                      <div style={{ fontSize: "9px", color: "#94a3b8", fontWeight: "bold" }}>%{item.ratio.toFixed(0)}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* KPI 3: OEE SKORU */}
            <div
              style={{ ...kpiBox, flex: 0.8, flexDirection: "column", alignItems: "center", justifyContent: "center", background: "white", cursor: "pointer", position: "relative", transition: "all 0.2s" }}
              onClick={() => setIsOeeModalOpen(true)}
              onMouseOver={(e) => { e.currentTarget.style.transform = "scale(1.02)"; e.currentTarget.style.boxShadow = "0 8px 16px rgba(0, 0, 0, 0.1)"; }}
              onMouseOut={(e) => { e.currentTarget.style.transform = "scale(1)"; e.currentTarget.style.boxShadow = "0 4px 15px rgba(0,0,0,0.05)"; }}
            >

              <div style={{ fontSize: "11px", color: "#2ecc71", fontWeight: "bold", background: "rgba(46, 204, 113, 0.1)", padding: "4px 8px", borderRadius: "15px", marginTop: "8px" }}>Canlı Verimlilik Analizi</div>
              <div style={{ fontSize: "42px", fontWeight: "900", color: "#27ae60", marginTop: "5px", textShadow: "0 2px 4px rgba(0,0,0,0.05)" }}>%{fabrikaOee}</div>
              <div style={{ fontSize: "12px", color: "#2ecc71", fontWeight: "bold", background: "rgba(46, 204, 113, 0.1)", padding: "4px 8px", borderRadius: "15px", marginTop: "8px" }}></div>
            </div >
          </div >

          {/* ALT ALAN (Geniş Kaplama) */}
          < div style={{ display: "flex", gap: "20px", width: "100%", flex: 1, minHeight: "450px" }
          }>
            {/* FABRİKA HARİTASI (Dinamik) */}
            < div
              onClick={() => setIsMapExpanded(true)}
              style={{ ...mapBox, flex: 1.8, position: "relative", padding: "20px", cursor: "zoom-in", transition: "transform 0.2s" }}
              onMouseOver={(e) => e.currentTarget.style.transform = "scale(1.005)"}
              onMouseOut={(e) => e.currentTarget.style.transform = "scale(1)"}
            >
              <div style={{ position: "absolute", top: "15px", right: "15px", display: "flex", gap: "10px", zIndex: 10 }} onClick={(e) => e.stopPropagation()}>
                <button
                  onClick={() => setActiveFloor(0)}
                  style={{ ...floorBtnStyle, background: activeFloor === 0 ? "#34495e" : "#f1f2f6", color: activeFloor === 0 ? "white" : "#333" }}
                >
                  Zemin Kat
                </button>
                <button
                  onClick={() => setActiveFloor(1)}
                  style={{ ...floorBtnStyle, background: activeFloor === 1 ? "#34495e" : "#f1f2f6", color: activeFloor === 1 ? "white" : "#333" }}
                >
                  1. Kat
                </button>
              </div>
              {renderFloorPlan(false)}
            </div >

            {/* MAKİNE BAKIM YÖNETİMİ (Maliyet Grafiği) */}
            < div style={{ flex: 1, display: "flex", flexDirection: "column", gap: "20px" }}>
              <div style={{ ...analizKartStil, flex: 1 }}>
                <div style={analizBaslikStil}>Maliyet Analizi</div>

                {/* Bar Chart */}
                <div style={{ flex: 1, display: "flex", alignItems: "flex-end", justifyContent: "space-around", padding: "15px 10px 0 10px", gap: "20px" }}>
                  {maliyetVerileri.map((item, i) => {
                    const heightPct = Math.max((item.value / maxMaliyet) * 100, 5);
                    return (
                      <div key={i} style={{ display: "flex", flexDirection: "column", alignItems: "center", flex: 1, height: "100%", justifyContent: "flex-end" }}>
                        {/* Değer */}
                        <div style={{ fontSize: "13px", fontWeight: "bold", color: item.color, marginBottom: "6px" }}>
                          {(item.value / 1000).toFixed(0)}K ₺
                        </div>
                        {/* Bar */}
                        <div style={{
                          width: "45px",
                          height: `${heightPct}%`,
                          minHeight: "20px",
                          background: item.gradient,
                          borderRadius: "6px 6px 0 0",
                          transition: "height 1.2s ease-out",
                          boxShadow: `0 4px 12px ${item.color}33`,
                          position: "relative"
                        }}>
                        </div>
                        {/* Label */}
                        <div style={{ fontSize: "11px", color: "#7f8c8d", marginTop: "8px", textAlign: "center", fontWeight: "600", lineHeight: "1.3" }}>
                          {item.label}
                        </div>
                      </div>
                    );
                  })}
                </div>

                {/* Alt legend */}
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: "15px", padding: "12px 15px", background: "#f8f9fa", borderRadius: "10px", border: "1px solid #f1f2f6" }}>
                  <div style={{ display: "flex", gap: "15px" }}>
                    {maliyetVerileri.map((item, i) => (
                      <div key={i} style={{ display: "flex", alignItems: "center", gap: "5px", fontSize: "11px", color: "#555" }}>
                        <div style={{ width: "8px", height: "8px", borderRadius: "2px", background: item.color }}></div>
                        {item.label}
                      </div>
                    ))}
                  </div>
                  <div style={{ fontSize: "12px", fontWeight: "bold", color: "#0f3460" }}>
                    Toplam: {((toplamMakineAlim + toplamParcaMasrafi + toplamServisUcreti) / 1000).toFixed(0)}K ₺
                  </div>
                </div>
              </div>
            </div >
          </div >

          {/* TAM EKRAN HARİTA MODAL */}
          {
            isMapExpanded && (
              <div style={modalOverlayStyle} onClick={() => setIsMapExpanded(false)}>
                <div style={{ ...modalContentStyle, maxWidth: "95%", width: "1300px", height: "90vh", position: "relative", padding: "0", background: "transparent", boxShadow: "none" }} onClick={(e) => e.stopPropagation()}>
                  <button onClick={() => setIsMapExpanded(false)} style={{ ...closeBtnStyle, position: "absolute", top: "20px", right: "20px", zIndex: 100, background: "#1e293b", color: "white", width: "40px", height: "40px", fontSize: "20px" }}>✕</button>

                  {renderFloorPlan(true)}

                  <div style={{ position: "absolute", top: "25px", right: "100px", display: "flex", gap: "10px", zIndex: 1100 }}>
                    <button
                      onClick={(e) => { e.stopPropagation(); setActiveFloor(0); }}
                      style={{ ...floorBtnStyle, padding: "10px 20px", background: activeFloor === 0 ? "#34495e" : "#f1f2f6", color: activeFloor === 0 ? "white" : "#333" }}
                    >
                      Zemin Kat
                    </button>
                    <button
                      onClick={(e) => { e.stopPropagation(); setActiveFloor(1); }}
                      style={{ ...floorBtnStyle, padding: "10px 20px", background: activeFloor === 1 ? "#34495e" : "#f1f2f6", color: activeFloor === 1 ? "white" : "#333" }}
                    >
                      1. Kat
                    </button>
                  </div>


                </div>
              </div>
            )
          }



          {
            isApprovalModalOpen && (
              <div style={modalOverlayStyle} onClick={() => setIsApprovalModalOpen(false)}>
                <div style={{ ...modalContentStyle, maxWidth: "900px" }} onClick={(e) => e.stopPropagation()}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px", borderBottom: "1px solid #eee", paddingBottom: "15px" }}>
                    <h3 style={{ margin: 0, color: "#0f3460", fontSize: "20px" }}>Makine Durumları</h3>
                    <button onClick={() => setIsApprovalModalOpen(false)} style={closeBtnStyle}>✕</button>
                  </div>

                  <div style={{ display: "flex", gap: "25px", alignItems: "flex-start" }}>
                    {/* LEFT COLUMN: Chart + Stats + Machine List */}
                    <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: "20px" }}>

                      {/* Modern Top Chart Section (KPI 2 ile Senkronize) */}
                      <div style={{ background: "#fff", padding: "20px", borderRadius: "12px", border: "1px solid #e2e8f0", display: "flex", alignItems: "center", gap: "25px", boxShadow: "0 4px 12px rgba(0,0,0,0.03)" }}>
                        <div style={{ position: "relative", width: "115px", height: "115px", flexShrink: 0 }}>
                          <div style={{ position: "absolute", inset: "-6px", borderRadius: "50%", background: "rgba(241, 245, 249, 0.4)", zIndex: 0, border: "1px solid #e2e8f0" }}></div>
                          <svg width="115" height="115" viewBox="0 0 42 42" style={{ transform: "rotate(-90deg)", position: "relative", zIndex: 1, filter: "drop-shadow(0 4px 6px rgba(0,0,0,0.08))" }}>
                            <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#f1f5f9" strokeWidth="6"></circle>
                            <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#2ecc71" strokeWidth="6" strokeDasharray={`${activeRatio} 100`} strokeDashoffset="0"></circle>
                            <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#3498db" strokeWidth="6" strokeDasharray={`${yaklasanRatio} 100`} strokeDashoffset={-activeRatio}></circle>
                            <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#f39c12" strokeWidth="6" strokeDasharray={`${bakimdaRatio} 100`} strokeDashoffset={-(activeRatio + yaklasanRatio)}></circle>
                            <circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#e94560" strokeWidth="6" strokeDasharray={`${onayBekleyenRatio} 100`} strokeDashoffset={-(activeRatio + yaklasanRatio + bakimdaRatio)}></circle>
                          </svg>
                          <div style={{ position: "absolute", top: 0, left: 0, width: "100%", height: "100%", display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", zIndex: 2 }}>
                            <div style={{ fontSize: "24px", fontWeight: "950", color: "#0f3460", lineHeight: 1 }}>{chartTotal}</div>
                            <div style={{ fontSize: "8px", color: "#64748b", fontWeight: "800", marginTop: "2px" }}>TOPLAM</div>
                          </div>
                        </div>

                        {/* Modal Stat Breakdown (Mini Daireler Eklenmiş Legend) */}
                        <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: "6px" }}>
                          {[
                            { id: "pending", label: "Onay Bekleyenler", count: onayBekleyenCount, color: "#e94560", ratio: onayBekleyenRatio },
                            { id: "maintenance", label: "Şu An Bakımda", count: bakimdaMakineCount, color: "#f39c12", ratio: bakimdaRatio },
                            { id: "upcoming", label: "Bakımı Yaklaşan", count: bakimiYaklasanCount, color: "#3498db", ratio: yaklasanRatio },
                            { id: "active", label: "Aktif / Normal", count: activeMachinesCount, color: "#2ecc71", ratio: activeRatio }
                          ].map(item => (
                            <div
                              key={item.id}
                              onClick={() => setActiveDetailTab(item.id)}
                              style={{
                                display: "flex",
                                justifyContent: "space-between",
                                alignItems: "center",
                                padding: "6px 12px",
                                background: activeDetailTab === item.id ? "#f8fafc" : "transparent",
                                borderRadius: "8px",
                                border: "1px solid",
                                borderColor: activeDetailTab === item.id ? item.color : "transparent",
                                cursor: "pointer",
                                transition: "all 0.2s"
                              }}
                            >
                              <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                                <svg width="14" height="14" viewBox="0 0 42 42">
                                  <circle cx="21" cy="21" r="15.9" fill="transparent" stroke="#eee" strokeWidth="8"></circle>
                                  <circle cx="21" cy="21" r="15.9" fill="transparent" stroke={item.color} strokeWidth="8" strokeDasharray={`${item.ratio} 100`} transform="rotate(-90 21 21)"></circle>
                                </svg>
                                <span style={{ fontWeight: "700", fontSize: "11px", color: "#475569" }}>{item.label}</span>
                              </div>
                              <span style={{ fontWeight: "900", fontSize: "13px", color: item.color }}>{item.count}</span>
                            </div>
                          ))}
                        </div>
                      </div>

                      {/* Machine Names List (Single Neutral Color, Clean) */}
                      <div style={{ background: "#fff", borderRadius: "12px", border: "1px solid #e2e8f0", display: "flex", flexDirection: "column", flex: 1, boxShadow: "0 1px 3px rgba(0,0,0,0.05)" }}>
                        <div style={{ padding: "14px 16px", borderBottom: "1px solid #e2e8f0", fontSize: "13px", fontWeight: "700", color: "#1e293b", background: "#f8fafc", borderTopLeftRadius: "12px", borderTopRightRadius: "12px" }}>
                          {activeDetailTab === "active" ? "Aktif Makineler" : activeDetailTab === "upcoming" ? "Yaklaşan Bakımlar" : activeDetailTab === "maintenance" ? "Bakımda Olanlar" : activeDetailTab === "pending" ? "Onay Bekleyen Makineler" : "Tüm Makineler"}
                        </div>
                        <div style={{ maxHeight: "250px", overflowY: "auto", padding: "8px" }}>
                          {(activeDetailTab === "active"
                            ? activeMachines
                            : activeDetailTab === "upcoming"
                              ? yaklasanMachines
                              : activeDetailTab === "maintenance"
                                ? bakimdaMachines
                                : activeDetailTab === "pending"
                                  ? pendingMachines
                                  : machinesList
                          ).map(m => (
                            <div key={m.id} style={{
                              padding: "10px 12px",
                              borderBottom: "1px solid #f1f5f9",
                              fontSize: "14px",
                              fontWeight: "800",
                              color: "#000" // Premium dark black
                            }}>
                              {m.makine_adi || m.makine_ad}
                            </div>
                          ))}
                          {((activeDetailTab === "active" && activeMachines.length === 0) ||
                            (activeDetailTab === "upcoming" && yaklasanMachines.length === 0) ||
                            (activeDetailTab === "maintenance" && bakimdaMachines.length === 0) ||
                            (activeDetailTab === "pending" && pendingMachines.length === 0)) && (
                              <div style={{ textAlign: "center", padding: "20px", color: "#94a3b8", fontSize: "13px" }}>Makine bulunmuyor.</div>
                            )}
                        </div>
                      </div>
                    </div>

                    {/* RIGHT COLUMN: Actionable Approval Box */}
                    <div style={{ flex: 1.2, background: "#fff", borderRadius: "16px", border: "2px solid #e94560", padding: "20px", boxShadow: "0 10px 25px rgba(233,69,96,0.1)" }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "15px" }}>
                        <h4 style={{ margin: 0, color: "#e94560", fontSize: "17px", fontWeight: "800" }}>Onay Bekleyen Görevler</h4>
                        <span style={{ fontSize: "11px", background: "#e94560", color: "#fff", padding: "2px 8px", borderRadius: "20px", fontWeight: "bold" }}>{pendingApprovals} GÖREV</span>
                      </div>

                      <div style={{ maxHeight: "380px", overflowY: "auto", paddingRight: "5px" }}>
                        {pendingTasks.length === 0 ? (
                          <div style={{ textAlign: "center", padding: "40px 20px", color: "#94a3b8", background: "#f8fafc", borderRadius: "12px", border: "1px dashed #cbd5e0" }}>
                            <span style={{ fontSize: "24px" }}>✅</span>
                            <div style={{ marginTop: "10px", fontSize: "13px", fontWeight: "bold" }}>Onay Bekleyen İş Yok</div>
                          </div>
                        ) : (
                          pendingTasks.map(t => {
                            const isSelected = selectedTaskIds.includes(t.id);
                            return (
                              <label key={t.id}
                                style={{
                                  padding: "12px",
                                  background: isSelected ? "#fff1f2" : "#fff",
                                  borderRadius: "12px",
                                  border: isSelected ? "1px solid #e94560" : "1px solid #f1f5f9",
                                  marginBottom: "10px",
                                  cursor: "pointer",
                                  transition: "all 0.2s",
                                  display: "flex",
                                  alignItems: "center",
                                  gap: "15px"
                                }}
                              >
                                <input
                                  type="checkbox"
                                  checked={isSelected}
                                  onChange={() => toggleTaskSelection(t.id)}
                                  style={{
                                    width: "20px",
                                    height: "20px",
                                    accentColor: "#e94560",
                                    cursor: "pointer"
                                  }}
                                />
                                <div style={{ flex: 1 }}>
                                  <div style={{ fontWeight: "700", color: "#1e293b", fontSize: "14px" }}>{t.makine_ad}</div>
                                  <div style={{ fontSize: "11px", color: "#64748b", marginTop: "2px" }}>{t.ariza_notu}</div>
                                </div>
                                <button
                                  onClick={(e) => {
                                    e.preventDefault();
                                    e.stopPropagation();
                                    const machine = machinesList.find(m => m.ad === t.makine_ad);
                                    if (machine) navigate(`/makine/${machine.id}`);
                                    else alert("Makine detay bilgisi bulunamadı.");
                                  }}
                                  style={{
                                    padding: "6px 12px",
                                    background: "#f1f5f9",
                                    color: "#475569",
                                    border: "1px solid #e2e8f0",
                                    borderRadius: "8px",
                                    fontSize: "11px",
                                    fontWeight: "800",
                                    cursor: "pointer",
                                    transition: "0.2s",
                                    whiteSpace: "nowrap"
                                  }}
                                  onMouseOver={(e) => { e.currentTarget.style.background = "#e2e8f0"; e.currentTarget.style.color = "#1e293b"; }}
                                  onMouseOut={(e) => { e.currentTarget.style.background = "#f1f5f9"; e.currentTarget.style.color = "#475569"; }}
                                >
                                  Detay Gör
                                </button>
                              </label>
                            );
                          })
                        )}
                      </div>

                      {selectedTaskIds.length > 0 && (
                        <div style={{ marginTop: "20px", display: "flex", gap: "10px" }}>
                          <button
                            onClick={handleBulkApprove}
                            style={{
                              flex: 2,
                              padding: "15px",
                              background: "linear-gradient(135deg, #2ecc71 0%, #27ae60 100%)",
                              color: "white",
                              border: "none",
                              borderRadius: "12px",
                              fontSize: "14px",
                              fontWeight: "900",
                              cursor: "pointer",
                              boxShadow: "0 6px 15px rgba(46, 204, 113, 0.3)",
                              transition: "all 0.2s"
                            }}
                          >
                            {selectedTaskIds.length}  BAKIMA GÖNDER
                          </button>
                          <button
                            onClick={handleBulkIgnore}
                            style={{
                              flex: 1,
                              padding: "15px",
                              background: "#94a3b8",
                              color: "white",
                              border: "none",
                              borderRadius: "12px",
                              fontSize: "14px",
                              fontWeight: "900",
                              cursor: "pointer",
                              transition: "all 0.2s"
                            }}
                          >
                            YOKSAY
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            )
          }

          {/* ONAYLAR VE ARIZA LİSTESİ MODAL (POP-UP) */}
          {
            isAlertModalOpen && (
              <div style={modalOverlayStyle}>
                <div style={modalContentStyle}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px", borderBottom: "1px solid #eee", paddingBottom: "15px" }}>
                    <h3 style={{ margin: 0, color: "#0f3460", fontSize: "20px" }}>Riskli Makineler Tablosu</h3>
                    <button onClick={() => { setIsAlertModalOpen(false); setActiveBreakdownId(null); }} style={closeBtnStyle}>✕</button>
                  </div>

                  <div style={{ maxHeight: "60vh", overflowY: "auto", display: "flex", flexDirection: "column", gap: "10px", paddingRight: "10px" }}>
                    {riskyMachines
                      .sort((a, b) => {
                        const priority = { "Yüksek Riskli": 3, "Bakımı Yaklaşan": 2, "Bakımda Olan": 1 };
                        return (priority[b.kategori] || 0) - (priority[a.kategori] || 0);
                      })
                      .map(m => (
                        <div key={m.id} style={{ position: "relative", padding: "20px", background: "white", borderRadius: "12px", border: "1px solid #e1e5eb", borderLeft: "6px solid #e74c3c", boxShadow: "0 2px 8px rgba(0,0,0,0.02)", overflow: "hidden" }}>
                          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                            <div>
                              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "18px", borderBottom: "1px solid #f1f5f9", transition: "0.2s" }}>
                                <div style={{ flex: 1 }}>
                                  <div style={{ display: "flex", alignItems: "center", gap: "12px", marginTop: "4px" }}>
                                    <strong style={{ fontSize: "19px", color: "#1e293b" }}>{m.ad}</strong>
                                  </div>
                                  <div style={{ display: "flex", gap: "8px", marginTop: "10px" }}>
                                    <span style={{ fontSize: "11px", fontWeight: "800", color: "#64748b", background: "#f1f5f9", padding: "4px 12px", borderRadius: "20px", display: "inline-flex", alignItems: "center", gap: "5px", border: "1px solid #e2e8f0" }}>
                                      🚩 Yüksek Riskli Makine
                                    </span>
                                  </div>
                                </div>
                                {/* Aksiyon Butonları: Detay, Arıza Kaydı ve Yoksay */}
                                <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "8px", minWidth: "360px" }}>
                                  <button
                                    onClick={() => navigate(`/makine/${m.id}`)}
                                    style={{ ...btnStyle, background: "#1e293b", width: "100%", minWidth: "0" }}
                                  >
                                    Detay Gör
                                  </button>
                                  <button
                                    onClick={() => setActiveBreakdownId(activeBreakdownId === m.id ? null : m.id)}
                                    style={{ ...btnStyle, background: "#e94560", width: "100%", minWidth: "0" }}
                                  >
                                    {activeBreakdownId === m.id ? "Gizle" : "Arıza Kaydı"}
                                  </button>
                                  <button
                                    onClick={() => handleIgnoreMachine(m.id, m.ad)}
                                    style={{ ...btnStyle, background: "#94a3b8", width: "100%", minWidth: "0" }}
                                  >
                                    Yoksay
                                  </button>
                                </div>
                              </div>

                              {/* ARIZA KAYDI FORMU */}
                              {activeBreakdownId === m.id && (
                                <div style={{ marginTop: "20px", padding: "20px", background: "white", borderRadius: "8px", border: "2px solid #e1e5eb" }}>
                                  <div style={{ marginBottom: "12px", fontWeight: "bold", fontSize: "16px", color: "#333" }}>Detaylı Arıza Açıklaması:</div>
                                  <textarea
                                    value={breakdownDesc}
                                    onChange={(e) => setBreakdownDesc(e.target.value)}
                                    placeholder="Açıklama..."
                                    style={{ width: "100%", padding: "15px", boxSizing: "border-box", borderRadius: "6px", border: "1px solid #ccc", outline: "none", minHeight: "100px", marginBottom: "15px", fontSize: "15px", resize: "vertical" }}
                                  />
                                  <div style={{ display: "flex", justifyContent: "flex-end" }}>
                                    <button onClick={() => handleCreateBreakdown(m)} style={saveBtnStyle}>Kaydet ve Bildir</button>
                                  </div>
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                  </div>
                </div>
              </div>
            )
          }

          {/* OEE HAFTALIK DETAY MODAL */}
          {
            isOeeModalOpen && (
              <div style={modalOverlayStyle} onClick={() => setIsOeeModalOpen(false)}>
                <div style={{ ...modalContentStyle, maxWidth: "800px" }} onClick={(e) => e.stopPropagation()}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px", borderBottom: "1px solid #eee", paddingBottom: "15px" }}>
                    <h3 style={{ margin: 0, color: "#27ae60", fontSize: "22px", display: "flex", alignItems: "center", gap: "10px" }}>
                      Fabrika OEE (Genel Ekipman Etkinliği) Gelişimi
                    </h3>
                    <button onClick={() => setIsOeeModalOpen(false)} style={closeBtnStyle}>✕</button>
                  </div>

                  <div style={{ padding: "15px", background: "rgba(46, 204, 113, 0.05)", borderRadius: "12px", marginBottom: "25px", border: "1px solid rgba(46, 204, 113, 0.2)" }}>
                    <p style={{ margin: 0, color: "#2c3e50", fontSize: "14px", lineHeight: "1.6" }}>
                      OEE skoru, fabrikadaki makinelerin <strong>Kullanılabilirlik (Availability)</strong>, Performans ve Kalite oranlarının bileşkesidir. Şu anki veriler canlı makine durumlarına dayanmaktadır.
                    </p>
                  </div>

                  <div style={{ height: "250px", display: "flex", alignItems: "flex-end", gap: "20px", padding: "20px 10px", borderBottom: "2px solid #ecf0f1", overflowX: "auto" }}>
                    {oeeHistory.map((d, i) => {
                      const isCurrent = i === oeeHistory.length - 1;
                      const barHeight = d.oee > 0 ? Math.max((d.oee - 50) * 3, 20) : 4; // Değer yoksa min 4px çizgi
                      return (
                        <div key={i} style={{ display: "flex", flexDirection: "column", alignItems: "center", flex: 1, minWidth: "40px", position: "relative" }}>
                          {d.oee > 0 && (
                            <div style={{
                              fontSize: "11px",
                              fontWeight: "bold",
                              marginBottom: "6px",
                              color: isCurrent ? "#27ae60" : "#94a3b8",
                              position: "absolute",
                              top: `-${barHeight + 22}px`,
                              width: "100%",
                              textAlign: "center"
                            }}>
                              %{d.oee}
                            </div>
                          )}
                          <div style={{
                            width: "35px",
                            height: `${barHeight}px`,
                            background: isCurrent
                              ? "linear-gradient(to top, #2ecc71, #27ae60)"
                              : (d.oee > 0 ? "#cbd5e0" : "#f1f5f9"),
                            borderRadius: "4px 4px 0 0",
                            boxShadow: isCurrent ? "0 4px 10px rgba(39, 174, 96, 0.3)" : "none",
                            border: d.oee > 0 ? "none" : "1px dashed #cbd5e0"
                          }}></div>
                          <div style={{ marginTop: "12px", fontSize: "10px", fontWeight: isCurrent ? "800" : "500", color: isCurrent ? "#27ae60" : "#94a3b8", whiteSpace: "nowrap" }}>
                            {d.week}
                          </div>
                        </div>
                      );
                    })}
                  </div>

                  <div style={{ marginTop: "30px" }}>
                    <h4 style={{ margin: "0 0 15px 0", color: "#34495e", fontSize: "15px" }}>OEE Bileşenleri (A x P x Q)</h4>
                    <div style={{ display: "flex", gap: "20px" }}>
                      <div style={{ flex: 1, padding: "15px", background: "#f8f9fa", borderRadius: "10px", textAlign: "center", border: "1px solid #e1e5eb" }}>
                        <div style={{ fontSize: "12px", color: "#7f8c8d", fontWeight: "bold", textTransform: "uppercase" }}>Kullanılabilirlik</div>
                        <div style={{ fontSize: "24px", fontWeight: "800", color: "#3498db", marginTop: "5px" }}>%{fabrikaOee}</div>
                        <div style={{ fontSize: "11px", color: "#95a5a6", marginTop: "4px" }}>Aktif Makine Oranı</div>
                      </div>
                      <div style={{ flex: 1, padding: "15px", background: "#f8f9fa", borderRadius: "10px", textAlign: "center", border: "1px solid #e1e5eb" }}>
                        <div style={{ fontSize: "12px", color: "#7f8c8d", fontWeight: "bold", textTransform: "uppercase" }}>Performans</div>
                        <div style={{ fontSize: "24px", fontWeight: "800", color: "#3498db", marginTop: "5px" }}>%{fabrikaOee}</div>
                        <div style={{ fontSize: "11px", color: "#95a5a6", marginTop: "4px" }}>Nominal hıza oranı</div>
                      </div>
                      <div style={{ flex: 1, padding: "15px", background: "#f8f9fa", borderRadius: "10px", textAlign: "center", border: "1px solid #e1e5eb" }}>
                        <div style={{ fontSize: "12px", color: "#7f8c8d", fontWeight: "bold", textTransform: "uppercase" }}>Kalite</div>
                        <div style={{ fontSize: "24px", fontWeight: "800", color: "#3498db", marginTop: "5px" }}>%{fabrikaOee}</div>
                        <div style={{ fontSize: "11px", color: "#95a5a6", marginTop: "4px" }}>Sağlam ürün oranı</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )
          }


        </div >
      </div >
    </div >
  );
}

/* 
  SABİT STİLLER (CSS-in-JS) 
  Bu bölümdeki objeler, sayfa içindeki bileşenlerin tasarımını (renk, kenarlık, gölge) belirler. 
*/

// KPI Kutularının temel tasarımı
const kpiBox = {
  flex: 1,
  background: "white",
  padding: "20px",
  textAlign: "center",
  borderRadius: "12px",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  boxSizing: "border-box",
  boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
  fontSize: "20px",
  fontWeight: "bold",
  color: "#34495e",
  border: "2px solid transparent"
};

// Modal arka plan (karartma) stili
const modalOverlayStyle = { position: "absolute", top: 0, left: 0, right: 0, bottom: 0, background: "rgba(0,0,0,0.6)", display: "flex", justifyContent: "center", alignItems: "flex-start", paddingTop: "50px", zIndex: 100, backdropFilter: "blur(4px)" };

// Modal içeriği (beyaz kutu) stili
const modalContentStyle = { background: "white", padding: "30px", borderRadius: "12px", width: "100%", maxWidth: "600px", boxShadow: "0 10px 40px rgba(0,0,0,0.2)" };

// Genel kapatma butonu (X)
const closeBtnStyle = {
  background: "#f1f5f9",
  border: "none",
  width: "36px",
  height: "36px",
  borderRadius: "50%",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  fontSize: "18px",
  cursor: "pointer",
  color: "#475569",
  transition: "all 0.2s",
  boxShadow: "0 2px 8px rgba(0,0,0,0.15)"
};

// Aksiyon butonları (e.g. Detay Gör, Yoksay)
const btnStyle = { minWidth: "115px", padding: "10px 5px", background: "#e94560", color: "white", border: "none", borderRadius: "6px", cursor: "pointer", fontWeight: "bold", fontSize: "13px", transition: "0.2s", textAlign: "center" };

// Kaydet/Onayla butonları
const saveBtnStyle = { padding: "10px 20px", background: "#2ecc71", color: "white", border: "none", borderRadius: "6px", cursor: "pointer", fontWeight: "bold" };

// Harita kutusu tasarımı
const mapBox = {
  flex: 2,
  background: "white",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  borderRadius: "12px",
  fontWeight: "bold",
  boxSizing: "border-box",
  boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
  fontSize: "24px",
  color: "#34495e"
};

// Alt analiz kartları (Maliyet ve OEE dağılımı için)
const analizKartStil = {
  background: "white",
  borderRadius: "12px",
  padding: "20px",
  boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
  display: "flex",
  flexDirection: "column"
};

// Kartların başlık tasarımı
const analizBaslikStil = {
  fontSize: "14px",
  fontWeight: "800",
  color: "#2c3e50",
  marginBottom: "15px",
  borderBottom: "1px solid #f1f2f6",
  paddingBottom: "10px",
  textTransform: "uppercase",
  letterSpacing: "0.5px"
};

// Kat değiştirme butonlarının tasarımı
const floorBtnStyle = {
  padding: "6px 12px",
  borderRadius: "6px",
  border: "none",
  fontSize: "12px",
  fontWeight: "bold",
  cursor: "pointer",
  transition: "0.2s"
};

// Fabrika haritasındaki blokların (A, B, C...) tasarımı
const blokStyle = {
  borderRadius: "8px",
  padding: "15px",
  display: "flex",
  flexDirection: "column",
  justifyContent: "center",
  alignItems: "center",
  boxShadow: "0 2px 8px rgba(0,0,0,0.04)",
  transition: "0.2s"
};

const blokTitleStyle = {
  fontSize: "14px",
  fontWeight: "bold",
  color: "#2c3e50"
};

const blokSubTitleStyle = {
  fontSize: "11px",
  color: "#7f8c8d",
  marginTop: "4px",
  textTransform: "uppercase"
};
