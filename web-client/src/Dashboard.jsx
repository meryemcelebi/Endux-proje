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
  const [isLoading, setIsLoading] = useState(true); // Veriler yüklenirken gösterilen yükleme durumu
  const [ignoredIds, setIgnoredIds] = useState([]); // Kullanıcının listeden gizlemek istediği (yoksaydığı) makine ID'leri
  const [pendingApprovals, setPendingApprovals] = useState([]); // Servis firması tarafından tamamlanmış, kullanıcı puanı bekleyen kayıtlar
  const [pendingTasks, setPendingTasks] = useState([]); // Arıza kaydı açılmış ancak henüz teknisyen ataması bekleyen görevler
  const [allHistory, setAllHistory] = useState([]); // Grafikler için kullanılan geçmiş servis verileri
  const [isOeeModalOpen, setIsOeeModalOpen] = useState(false); // Verimlilik (OEE) detaylarını gösteren pencerenin durumu
  const [isApprovalModalOpen, setIsApprovalModalOpen] = useState(false); // Bakım/Onay detaylarını yöneten ana modalin durumu
  const [selectedTaskIds, setSelectedTaskIds] = useState([]); // Toplu onaylama işlemi için seçilen görevlerin ID'leri
  const [activeDetailTab, setActiveDetailTab] = useState(null); // Modalde hangi sekmenin (Bakımda, Bekleyen vs.) aktif olduğunu tutar
  const [firmsMetadata, setFirmsMetadata] = useState([]); // Servis firmalarının değerlendirme ve iletişim bilgileri

  // --- OEE ANALİZ VERİLERİ (Haftalık Verimlilik Değerleri) ---
  const oeeWeeklyData = [
    { week: "1. Hafta", oee: 82.5, a: 90, p: 95, q: 96.5 },
    { week: "2. Hafta", oee: 84.0, a: 91, p: 96, q: 96.2 },
    { week: "3. Hafta", oee: 83.2, a: 89, p: 95, q: 98.4 },
    { week: "4. Hafta", oee: 85.1, a: 92, p: 94, q: 98.3 },
    { week: "5. Hafta", oee: 86.5, a: 93, p: 95, q: 97.8 },
    { week: "6. Hafta", oee: 87.2, a: 94, p: 95, q: 97.6 },
    { week: "Geçen H.", oee: 87.2, a: 93, p: 96, q: 97.7 },
    { week: "Bu Hafta", oee: 88.4, a: 95, p: 95, q: 98.0 },
  ];

  // --- VERİ ÇEKME VE ZENGİNLEŞTİRME SÜRECİ ---
  React.useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        // 1. Tüm makineleri API'den al
        const machinesData = await api.getMachines();

        // Ham veriyi analiz ederek Dashboard'a uygun hale getir (Zenginleştirme)
        const enrichedData = machinesData.map(m => {
          let kategori = "Aktif";
          // Risk skoruna veya arıza durumuna göre kategorize et
          if (m.mevcut_risk_skoru > 0.5) kategori = "Yüksek Riskli";
          else if (m.aktiflik_durumu === "Bakımda") kategori = "Bakımda Olan";
          else if (m.aktiflik_durumu === "Bakımı Yaklaşan") kategori = "Bakımı Yaklaşan";
          else if (m.aktiflik_durumu === "Arızalı") kategori = "Yüksek Riskli";

          // --- Garanti Bitiş Kontrolü Mantığı ---
          let garantiDurumu = "Normal";
          if (m.satin_alma_tarihi && m.garanti_suresi) {
            const purchase = new Date(m.satin_alma_tarihi);
            // Satın alma tarihine süreyi ekleyerek bitiş tarihini bul
            const end = new Date(purchase.setMonth(purchase.getMonth() + m.garanti_suresi));
            // Kalan gün sayısını hesapla
            const diffDays = Math.ceil((end - new Date()) / (1000 * 60 * 60 * 24));

            if (diffDays <= 0) garantiDurumu = "Bitti";
            else if (diffDays <= 30) garantiDurumu = "Kritik";
          }

          // UI'da kullanılacak standart bir veri objesi döndür
          return { ...m, id: m.makine_id, ad: m.makine_ad, kategori, garantiDurumu };
        });
        setMachinesList(enrichedData);

        // 2. Bakım Onaylarını, Teknik Görevleri ve Firma Bilgilerini Paralel Çek
        const [serviceHistory, techTasks, firmsData] = await Promise.all([
          api.getAllServiceHistory(),
          api.getTechTasks(),
          api.getFirmsToRate()
        ]);

        setFirmsMetadata(firmsData);
        setAllHistory(serviceHistory);

        // Henüz puanlanmamış (tamamlanmış fakat değerlendirme bekleyen) servis kayıtlarını süz
        const pendingRating = serviceHistory.filter(s => s.puan === 0);
        setPendingApprovals(pendingRating);

        // Sisteme girilmiş ancak işlem görmemiş (BEKLEYEN) görevleri süz
        const pendingStart = techTasks.filter(t => t.durum === "BEKLEYEN");

        // Simüle edilmiş görevler (Sistemin dolu görünmesi için örnek veriler)
        const mockTasks = [
          { id: "mock-1", makine_ad: "CNC Lazer Kesim 02", ariza_notu: "Yüksek sıcaklık uyarısı - Soğutma kontrolü bekliyor.", durum: "BEKLEYEN" },
          { id: "mock-2", makine_ad: "Hidrolik Pres Hattı A", ariza_notu: "Periyodik yağ değişimi ve valf kontrolü onayı.", durum: "BEKLEYEN" },
          { id: "mock-3", makine_ad: "Montaj Robotu R-4", ariza_notu: "Servo motor ses şikayeti - Teknik inceleme talebi.", durum: "BEKLEYEN" }
        ];

        setPendingTasks([...pendingStart, ...mockTasks]);

      } catch (err) {
        console.error("Dashboard verileri yüklenemedi", err);
      } finally {
        setIsLoading(false); // Yükleme ekranını kapat
      }
    };
    fetchDashboardData();
  }, []);

  // --- KRİTİK ALARMLARI BELİRLE ---
  // Sadece Yüksek Riskli olanlar veya Garantisi bitmek üzere (Kritik) olanları "Risky Machines" olarak al
  const riskyMachines = machinesList.filter(m =>
    (m.kategori === "Yüksek Riskli" || m.garantiDurumu === "Kritik")
    && !ignoredIds.includes(m.id) // Kullanıcının 'Yoksay' dediklerini listeleme
  );

  // Sayısal özet verileri (Dashboard kartlarında gösterilecek rakamlar)
  const yRCount = riskyMachines.filter(m => m.kategori === "Yüksek Riskli").length;
  const gKCount = riskyMachines.filter(m => m.garantiDurumu === "Kritik").length;

  // Form ve UI kontrol state'leri
  const [isAlertModalOpen, setIsAlertModalOpen] = useState(false);
  const [activeBreakdownId, setActiveBreakdownId] = useState(null);
  const [breakdownDesc, setBreakdownDesc] = useState("");
  const [activeFloor, setActiveFloor] = useState(0); // Fabrika haritası kat kontrolü
  const [isMapExpanded, setIsMapExpanded] = useState(false); // Harita büyütme durumu

  // --- MALİYET VE BÜTÇE ANALİZİ (Reduce Kullanımı) ---
  // Tüm makinelerin toplam satın alma bedelini hesapla
  const toplamMakineAlim = machinesList.reduce((sum, m) => sum + (m.satin_alma_maliyeti || 0), 0);
  // Geçmişteki tüm servis/parça harcamalarını topla
  const toplamServisUcreti = allHistory.reduce((sum, h) => sum + (h.bakim_maliyet?.[0] || 0), 0);
  // Parça masrafı: Servis ücretinin %40'ı olarak simüle edilen tahmini masraf
  const toplamParcaMasrafi = Math.round(toplamServisUcreti * 0.4);

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

  // Bir uyarıyı geçici olarak listeden gizleme işlemi
  const handleIgnoreMachine = (machineId, machineName) => {
    const confirmIgnore = window.confirm(`"${machineName}" uyarısını yoksaymak üzeresiniz. Bu makine listeden kaldırılacak. Emin misiniz?`);
    if (confirmIgnore) {
      setIgnoredIds([...ignoredIds, machineId]);
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
  const handleBulkApprove = () => {
    if (selectedTaskIds.length === 0) return;
    const count = selectedTaskIds.length;
    alert(`${count} Adet bakım görevi onaylandı ve teknisyenlere iletildi! 🛠️`);

    // Onaylananları listeden çıkar ve seçimleri sıfırla
    setPendingTasks(prev => prev.filter(t => !selectedTaskIds.includes(t.id)));
    setSelectedTaskIds([]);
    setIsApprovalModalOpen(false);
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

  const totalMachinesCount = machinesList.length || 1; // Toplam makine sayısı
  const bakimdaMakineCount = machinesList.filter(m => m.aktiflik_durumu === "Bakımda").length; // Bakımdaki makineler
  const onayBekleyenCount = pendingTasks.length + pendingApprovals.length; // Bekleyen tüm bakım onayları + görevler
  const bakimiYaklasanCount = machinesList.filter(m => m.aktiflik_durumu === "Bakımı Yaklaşan").length; // Takvimi yaklaşanlar

  // Hiçbir sorunu olmayan, normal çalışan aktif makine sayısını bul
  const activeMachinesCount = Math.max(0, totalMachinesCount - bakimdaMakineCount - bakimiYaklasanCount);

  // Grafik paydası: Tüm kalemlerin toplamı (Grafiğin %100 tam daire görünmesi için)
  const chartTotal = (onayBekleyenCount + bakimdaMakineCount + bakimiYaklasanCount + activeMachinesCount) || 1;

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
      if (toplamBakimGideri === 0) gercekMaliyetYuzdesi = Math.random() * 30;
      gercekMaliyetYuzdesi = parseFloat(gercekMaliyetYuzdesi.toFixed(1));

      // 3 Renk Mantığı (İdeal, Dikkat, Kritik)
      let renkCode = "#22C55E";
      let kRit = "İdeal";
      if (gercekMaliyetYuzdesi >= 25) { renkCode = "#EF4444"; kRit = "Kritik Kayıp"; }
      else if (gercekMaliyetYuzdesi >= 10) { renkCode = "#F59E0B"; kRit = "Uyarı / Risk"; }
      else { renkCode = "#22C55E"; kRit = "İdeal"; }

      const dbAlan = m.lokasyon?.[0]?.fabrika_alani;
      let targetKat = m.lokasyon?.[0]?.kat || (index % 2 === 0 ? "Zemin Kat" : "1. Kat");

      let targetBlock = dbAlan;
      if (!targetBlock) {
        if (targetKat === "Zemin Kat") {
          const zones = ["Blok A", "Blok B", "Blok C", "Sevkiyat Alanı"];
          targetBlock = zones[index % 4];
        } else {
          const zones = ["Blok D", "Blok E", "Ofisler", "Blok F"];
          targetBlock = zones[index % 4];
        }
      }

      if (!acc[targetKat]) acc[targetKat] = {};
      if (!acc[targetKat][targetBlock]) acc[targetKat][targetBlock] = [];

      const displayNo = index + 1; // 1'den 100'e kadar sıralı numara
      acc[targetKat][targetBlock].push({ ...m, gercekMaliyetYuzdesi, renkCode, kRit, displayNo });
      return acc;
    }, {});

    const renderMachinesInBlock = (katAdi, blokAdi) => {
      const machs = groupedMachines[katAdi]?.[blokAdi] || [];
      return (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', marginTop: '12px', justifyContent: 'center', maxWidth: '100%' }}>
          {machs.map(m => (
            <div
              key={m.id}
              onClick={(e) => { e.stopPropagation(); navigate(`/makine/${m.id}`); }}
              style={{
                width: isLarge ? '28px' : '20px',
                height: isLarge ? '28px' : '20px',
                borderRadius: '50%',
                backgroundColor: m.renkCode,
                cursor: 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: '#fff', fontSize: isLarge ? '11px' : '9px', fontWeight: 'bold',
                boxShadow: '0 2px 4px rgba(0,0,0,0.2)',
                transition: 'transform 0.2s',
                position: "relative"
              }}
              onMouseOver={(e) => {
                e.currentTarget.style.transform = 'scale(1.2)';
              }}
              onMouseOut={(e) => {
                e.currentTarget.style.transform = 'scale(1)';
              }}
              title={`${m.ad}\n(Sıra: ${m.displayNo}) - Risk: %${m.gercekMaliyetYuzdesi} (${m.kRit})`}
            >
              {m.displayNo}
            </div>
          ))}
        </div>
      );
    }

    const currentBlockStyle = { ...blokStyle, background: "#f0f7ff", borderTop: "4px solid #000", padding: isLarge ? "30px" : "15px", justifyContent: 'flex-start' };
    const titleCol = { ...blokTitleStyle, fontSize: isLarge ? "20px" : "14px", color: "#000" };
    const subCol = { ...blokSubTitleStyle, fontSize: isLarge ? "14px" : "11px", color: "#111" };

    return (
      <div style={{ width: "100%", height: "100%", padding: isLarge ? "20px" : "40px 10px 10px 10px", boxSizing: "border-box", display: "flex", flexDirection: "column" }}>
        <style>
          {`
            .no-scrollbar::-webkit-scrollbar { display: none; }
          `}
        </style>

        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "15px" }}>
          <span style={{ fontSize: isLarge ? "24px" : "16px", fontWeight: "bold", color: "#2c3e50" }}>
            Fabrika Yerleşim Planı - {activeFloor === 0 ? "Zemin Kat" : "1. Kat"}
          </span>
        </div>

        {/* Legend (Harita Açıklaması) */}
        <div style={{ display: "flex", gap: "10px", width: "100%", marginBottom: "15px", fontSize: "12px", fontWeight: "bold", flexWrap: "wrap", justifyContent: "flex-start", alignItems: "center" }}>
          <span style={{ color: "#22C55E" }}>● İdeal (%0 - %10)</span>
          <span style={{ color: "#F59E0B" }}>● Uyarı / Risk (%10 - %25)</span>
          <span style={{ color: "#EF4444" }}>● Kritik Kayıp (%25+)</span>
        </div>

        {/* Fabrika Blokları (Grid Yapısı) */}
        <div
          className="no-scrollbar"
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(3, 1fr)",
            gridTemplateRows: isLarge ? "auto max-content" : "repeat(2, 1fr)",
            gap: isLarge ? "15px" : "15px",
            flex: 1,
            minHeight: 0,
            overflowY: "auto",
            paddingRight: "5px",
            msOverflowStyle: "none",
            scrollbarWidth: "none"
          }}>
          {activeFloor === 0 ? (
            <>
              {/* Zemin Kat Blokları */}
              <div style={currentBlockStyle}>
                <span style={titleCol}>Blok A</span>
                <span style={subCol}>Pres Hattı</span>
                {renderMachinesInBlock("Zemin Kat", "Blok A")}
              </div>
              <div style={currentBlockStyle}>
                <span style={titleCol}>Blok B</span>
                <span style={subCol}>Lazer Kesim</span>
                {renderMachinesInBlock("Zemin Kat", "Blok B")}
              </div>
              <div style={currentBlockStyle}>
                <span style={titleCol}>Blok C</span>
                <span style={subCol}>Lojistik & Ambar</span>
                {renderMachinesInBlock("Zemin Kat", "Blok C")}
              </div>
              <div style={{ ...currentBlockStyle, gridColumn: "span 3", border: "2px dashed #000", borderTop: "4px solid #000" }}>
                <span style={titleCol}>Sevkiyat Alanı</span>
                {renderMachinesInBlock("Zemin Kat", "Sevkiyat Alanı")}
              </div>
            </>
          ) : (
            <>
              {/* 1. Kat Blokları */}
              <div style={{ ...currentBlockStyle, gridColumn: "span 2" }}>
                <span style={titleCol}>Blok D</span>
                <span style={subCol}>Montaj Hattı</span>
                {renderMachinesInBlock("1. Kat", "Blok D")}
              </div>
              <div style={currentBlockStyle}>
                <span style={titleCol}>Blok E</span>
                <span style={subCol}>Bakım & Teknik</span>
                {renderMachinesInBlock("1. Kat", "Blok E")}
              </div>
              <div style={{ ...currentBlockStyle, gridColumn: "span 1" }}>
                <span style={titleCol}>Ofisler</span>
                {renderMachinesInBlock("1. Kat", "Ofisler")}
              </div>
              <div style={{ ...currentBlockStyle, gridColumn: "span 2" }}>
                <span style={titleCol}>Blok F</span>
                <span style={subCol}>Kalite Kontrol</span>
                {renderMachinesInBlock("1. Kat", "Blok F")}
              </div>
            </>
          )}
        </div>
      </div>
    );
  };

  // Frontend - Kat Planı Bileşeni (Recharts ile Maliyet Analizli Harita)
  function KatPlani({ katVerisi, openMachineDetail }) {
    // Recharts Scatter için özel Tooltip
    const CustomTooltip = ({ active, payload }) => {
      if (active && payload && payload.length) {
        const data = payload[0].payload;
        return (
          <div style={{ backgroundColor: '#fff', border: `2px solid ${data.renkCode}`, padding: '12px', borderRadius: '8px', boxShadow: '0 4px 6px rgba(0,0,0,0.1)' }}>
            <p style={{ margin: '0 0 5px 0', fontWeight: 'bold', color: '#1e293b' }}>{data.makine_adi}</p>
            <p style={{ margin: '0 0 5px 0', fontSize: '13px', color: '#475569' }}>📍 Makine ID: {data.makine_id}</p>
            <p style={{ margin: '0 0 5px 0', fontSize: '14px', fontWeight: 'bold', color: data.renkCode }}>
              Maliyet Oranı: %{data.maliyet_orani_yuzdesi}
            </p>
            <p style={{ margin: 0, fontSize: '11px', color: '#94a3b8', fontStyle: 'italic' }}>Tıklayarak Detaylara Git 🔍</p>
          </div>
        );
      }
      return null;
    };

    return (
      <div className="grid-container" style={{ position: 'relative', width: '100%', height: '500px', background: '#f8fafc', border: '1px solid #cbd5e0', borderRadius: '12px', padding: '15px' }}>
        <ResponsiveContainer width="100%" height="100%">
          <ScatterChart margin={{ top: 20, right: 30, bottom: 20, left: 0 }}>
            <CartesianGrid strokeDasharray="3 3" opacity={0.5} />
            {/* X ve Y eksenlerinin fabrika zeminini taklit etmesi için */}
            <XAxis type="number" dataKey="x" name="X Koordinatı" tick={{ fontSize: 11 }} domain={[0, 800]} />
            <YAxis type="number" dataKey="y" name="Y Koordinatı" tick={{ fontSize: 11 }} domain={[0, 600]} />

            {/* Noktaların (Bubble) büyüklüğünü sabitlemek için ZAxis */}
            <ZAxis type="number" range={[500, 500]} />

            <Tooltip content={<CustomTooltip />} cursor={{ strokeDasharray: '3 3' }} />

            <Scatter
              name="Makineler"
              data={katVerisi}
              onClick={(data) => openMachineDetail(data.makine_id)}
              style={{ cursor: 'pointer' }}
            >
              {katVerisi.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.renkCode} stroke="#fff" strokeWidth={2} />
              ))}
            </Scatter>
          </ScatterChart>
        </ResponsiveContainer>
      </div>
    );
  }

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
              <div style={{ fontWeight: "800", fontSize: "15px", marginBottom: "12px", borderBottom: "2px solid #f1f2f6", paddingBottom: "8px", width: "100%", textAlign: "left", color: "#2c3e50", display: "flex", alignItems: "center", gap: "8px" }}>
                Günlük Kritik Uyarılar
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

                {/* Kritik Garanti Rozeti: Garantisi bitmek üzere olanları listeler */}
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
                  onMouseOver={(e) => { e.currentTarget.style.background = "#fff"; e.currentTarget.style.borderColor = "#94a3b8"; }}
                  onMouseOut={(e) => { e.currentTarget.style.background = "#f8fafc"; e.currentTarget.style.borderColor = "#e2e8f0"; }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                    <span style={{ fontSize: "16px" }}>⌛</span>
                    <div style={{ display: "flex", flexDirection: "column" }}>
                      <span style={{ fontSize: "11px", fontWeight: "700", color: "#334155", textTransform: "uppercase" }}>Kritik Garanti</span>
                      <span style={{ fontSize: "10px", color: "#64748b" }}>Süresi Dolanlar</span>
                    </div>
                  </div>
                  <strong style={{ fontSize: "18px", color: "#1e293b", fontWeight: "900" }}>{gKCount}</strong>
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
              <div style={{ fontSize: "13px", color: "#7f8c8d", fontWeight: "700", textTransform: "uppercase", letterSpacing: "1px" }}>Fabrika OEE</div>
              <div style={{ fontSize: "42px", fontWeight: "900", color: "#27ae60", marginTop: "5px", textShadow: "0 2px 4px rgba(0,0,0,0.05)" }}>%88.4</div>
              <div style={{ fontSize: "12px", color: "#2ecc71", fontWeight: "bold", background: "rgba(46, 204, 113, 0.1)", padding: "4px 8px", borderRadius: "15px", marginTop: "8px" }}>▲ %1.2 (Geçen Hafta)</div>
            </div>
          </div>

          {/* ALT ALAN (Geniş Kaplama) */}
          <div style={{ display: "flex", gap: "20px", width: "100%", flex: 1, minHeight: "450px" }}>
            {/* FABRİKA HARİTASI (Dinamik) */}
            <div
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
            </div>

            {/* MAKİNE BAKIM YÖNETİMİ (Maliyet Grafiği) */}
            <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: "20px" }}>
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
            </div>
          </div>

          {/* TAM EKRAN HARİTA MODAL */}
          {isMapExpanded && (
            <div style={modalOverlayStyle} onClick={() => setIsMapExpanded(false)}>
              <div style={{ ...modalContentStyle, maxWidth: "90%", width: "1200px", height: "80vh", position: "relative" }} onClick={(e) => e.stopPropagation()}>
                <button onClick={() => setIsMapExpanded(false)} style={{ ...closeBtnStyle, position: "absolute", top: "20px", right: "20px", fontSize: "30px" }}>✕</button>

                <div style={{ position: "absolute", top: "25px", right: "80px", display: "flex", gap: "10px", zIndex: 10 }}>
                  <button
                    onClick={() => setActiveFloor(0)}
                    style={{ ...floorBtnStyle, padding: "10px 20px", background: activeFloor === 0 ? "#34495e" : "#f1f2f6", color: activeFloor === 0 ? "white" : "#333" }}
                  >
                    Zemin Kat
                  </button>
                  <button
                    onClick={() => setActiveFloor(1)}
                    style={{ ...floorBtnStyle, padding: "10px 20px", background: activeFloor === 1 ? "#34495e" : "#f1f2f6", color: activeFloor === 1 ? "white" : "#333" }}
                  >
                    1. Kat
                  </button>
                </div>

                {renderFloorPlan(true)}


              </div>
            </div>
          )}



          {isApprovalModalOpen && (
            <div style={modalOverlayStyle} onClick={() => setIsApprovalModalOpen(false)}>
              <div style={{ ...modalContentStyle, maxWidth: "900px" }} onClick={(e) => e.stopPropagation()}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px", borderBottom: "1px solid #eee", paddingBottom: "15px" }}>
                  <h3 style={{ margin: 0, color: "#0f3460", fontSize: "20px" }}>🔧 Bakım Yönetim Merkezi</h3>
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
                          { id: "total", label: "Aktif / Normal", count: activeMachinesCount, color: "#2ecc71", ratio: activeRatio }
                        ].map(item => (
                          <div
                            key={item.id}
                            onClick={() => setActiveDetailTab(item.id === "pending" ? "total" : item.id)}
                            style={{
                              display: "flex",
                              justifyContent: "space-between",
                              alignItems: "center",
                              padding: "6px 12px",
                              background: (activeDetailTab === item.id || (activeDetailTab === "total" && item.id === "total")) ? "#f8fafc" : "transparent",
                              borderRadius: "8px",
                              border: "1px solid",
                              borderColor: (activeDetailTab === item.id || (activeDetailTab === "total" && item.id === "total")) ? item.color : "transparent",
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
                        {activeDetailTab === "total" ? "Tüm Makineler" : activeDetailTab === "upcoming" ? "Yaklaşan Bakımlar" : "Bakımda Olanlar"}
                      </div>
                      <div style={{ maxHeight: "250px", overflowY: "auto", padding: "8px" }}>
                        {(activeDetailTab === "total"
                          ? machinesList
                          : activeDetailTab === "upcoming"
                            ? machinesList.filter(m => m.aktiflik_durumu === "Bakımı Yaklaşan")
                            : machinesList.filter(m => m.aktiflik_durumu === "Bakımda")
                        ).map(m => (
                          <div key={m.id} style={{
                            padding: "10px 12px",
                            borderBottom: "1px solid #f1f5f9",
                            fontSize: "13px",
                            fontWeight: "500",
                            color: "#334155" // Neutral dark grey
                          }}>
                            {m.makine_ad}
                          </div>
                        ))}
                        {(activeDetailTab !== "total" && machinesList.filter(m => activeDetailTab === "upcoming" ? m.aktiflik_durumu === "Bakımı Yaklaşan" : m.aktiflik_durumu === "Bakımda").length === 0) && (
                          <div style={{ textAlign: "center", padding: "20px", color: "#94a3b8", fontSize: "13px" }}>Makine bulunmuyor.</div>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* RIGHT COLUMN: Actionable Approval Box */}
                  <div style={{ flex: 1.2, background: "#fff", borderRadius: "16px", border: "2px solid #e94560", padding: "20px", boxShadow: "0 10px 25px rgba(233,69,96,0.1)" }}>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "15px" }}>
                      <h4 style={{ margin: 0, color: "#e94560", fontSize: "17px", fontWeight: "800" }}>Onay Bekleyenler</h4>
                      <span style={{ fontSize: "11px", background: "#e94560", color: "#fff", padding: "2px 8px", borderRadius: "20px", fontWeight: "bold" }}>{onayBekleyenCount} GÖREV</span>
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
                      <button
                        onClick={handleBulkApprove}
                        style={{
                          marginTop: "20px",
                          width: "100%",
                          padding: "15px",
                          background: "linear-gradient(135deg, #e94560 0%, #c0392b 100%)",
                          color: "white",
                          border: "none",
                          borderRadius: "12px",
                          fontSize: "14px",
                          fontWeight: "900",
                          cursor: "pointer",
                          boxShadow: "0 6px 15px rgba(233, 69, 96, 0.3)",
                          transition: "all 0.2s"
                        }}
                      >
                        {selectedTaskIds.length} BAKIMI ONAYLA
                      </button>
                    )}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* ONAYLAR VE ARIZA LİSTESİ MODAL (POP-UP) */}
          {isAlertModalOpen && (
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
                      <div key={m.id} style={{ position: "relative", padding: "20px", background: "white", borderRadius: "12px", border: "1px solid #e1e5eb", borderLeft: `6px solid ${getCategoryColor(m.kategori, m.garantiDurumu)}`, boxShadow: "0 2px 8px rgba(0,0,0,0.02)", overflow: "hidden" }}>
                        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                          <div>
                            {m.garantiDurumu === "Kritik" && (
                              <div style={{
                                position: "absolute",
                                top: "0",
                                right: "20px",
                                background: "#fefce8",
                                color: "#854d0e",
                                padding: "4px 12px",
                                borderRadius: "0 0 8px 8px",
                                fontSize: "10px",
                                fontWeight: "900",
                                border: "1px solid #fef08a",
                                borderTop: "none",
                                textTransform: "uppercase",
                                letterSpacing: "1px",
                                boxShadow: "0 2px 4px rgba(0,0,0,0.05)"
                              }}>
                                Garanti Riskli
                              </div>
                            )}
                            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "18px", borderBottom: "1px solid #f1f5f9", transition: "0.2s" }}>
                              <div style={{ flex: 1 }}>
                                <div style={{ display: "flex", alignItems: "center", gap: "12px", marginTop: "4px" }}>
                                  <strong style={{ fontSize: "19px", color: "#1e293b" }}>{m.ad}</strong>
                                </div>
                                <div style={{ display: "flex", gap: "8px", marginTop: "10px" }}>
                                  {/* Yüksek riskli makineler için kırmızı/gri rozet */}
                                  {m.kategori === "Yüksek Riskli" && (
                                    <span style={{ fontSize: "11px", fontWeight: "800", color: "#64748b", background: "#f1f5f9", padding: "4px 12px", borderRadius: "20px", display: "inline-flex", alignItems: "center", gap: "5px", border: "1px solid #e2e8f0" }}>
                                      🚩 Yüksek Risk
                                    </span>
                                  )}
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
          )}

          {/* OEE HAFTALIK DETAY MODAL */}
          {isOeeModalOpen && (
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
                    OEE skorumuz son haftalarda istikrarlı bir şekilde yükseliyor. Bu artış, özellikle kestirimci bakım stratejilerinin devreye sokulmasıyla <strong>Kullanılabilirlik (Availability)</strong> oranındaki iyileşmeden kaynaklanmaktadır.
                  </p>
                </div>

                {/* Sütun Grafiği (Bar Chart): Haftalık OEE skorlarını barlarla görselleştirir */}
                <div style={{ height: "250px", display: "flex", alignItems: "flex-end", gap: "30px", padding: "20px 10px", borderBottom: "2px solid #ecf0f1", overflowX: "auto" }}>
                  {oeeWeeklyData.map((d, i) => {
                    const barHeight = (d.oee - 70) * 3; // Ölçeklendirme hesabıyla bar yüksekliği
                    const isCurrent = i === oeeWeeklyData.length - 1; // En son (mevcut) haftayı kontrol et
                    return (
                      <div key={i} style={{ display: "flex", flexDirection: "column", alignItems: "center", flex: 1, minWidth: "50px", position: "relative", group: "true" }}>
                        <div style={{
                          fontSize: "12px",
                          fontWeight: "bold",
                          marginBottom: "8px",
                          color: isCurrent ? "#27ae60" : "#34495e",
                          position: "absolute",
                          top: `-${barHeight + 25}px`,
                          width: "100%",
                          textAlign: "center"
                        }}>
                          %{d.oee}
                        </div>
                        {/* Dinamik bar çubuğu */}
                        <div style={{
                          width: "35px",
                          height: `${barHeight}px`,
                          background: isCurrent ? "linear-gradient(to top, #2ecc71, #27ae60)" : "linear-gradient(to top, #bdc3c7, #95a5a6)",
                          borderRadius: "4px 4px 0 0",
                          transition: "all 0.3s ease",
                          cursor: "pointer",
                          boxShadow: isCurrent ? "0 4px 10px rgba(39, 174, 96, 0.3)" : "none"
                        }}
                          onMouseOver={(e) => e.target.style.transform = "scaleY(1.05)"}
                          onMouseOut={(e) => e.target.style.transform = "scaleY(1)"}
                        ></div>
                        <div style={{
                          marginTop: "12px",
                          fontSize: "11px",
                          fontWeight: isCurrent ? "800" : "500",
                          color: isCurrent ? "#27ae60" : "#7f8c8d",
                          whiteSpace: "nowrap"
                        }}>
                          {d.week}
                        </div>
                      </div>
                    );
                  })}
                </div>

                {/* Veri Özeti (Aktif Hafta Dağılımı) */}
                <div style={{ marginTop: "30px" }}>
                  <h4 style={{ margin: "0 0 15px 0", color: "#34495e", fontSize: "15px" }}>Bu Haftanın OEE Bileşenleri (A x P x Q)</h4>
                  <div style={{ display: "flex", gap: "20px" }}>
                    <div style={{ flex: 1, padding: "15px", background: "#f8f9fa", borderRadius: "10px", textAlign: "center", border: "1px solid #e1e5eb" }}>
                      <div style={{ fontSize: "12px", color: "#7f8c8d", fontWeight: "bold", textTransform: "uppercase" }}>Kullanılabilirlik</div>
                      <div style={{ fontSize: "24px", fontWeight: "800", color: "#3498db", marginTop: "5px" }}>%95.0</div>
                      <div style={{ fontSize: "11px", color: "#95a5a6", marginTop: "4px" }}>Arızasız çalışma süresi</div>
                    </div>
                    <div style={{ flex: 1, padding: "15px", background: "#f8f9fa", borderRadius: "10px", textAlign: "center", border: "1px solid #e1e5eb" }}>
                      <div style={{ fontSize: "12px", color: "#7f8c8d", fontWeight: "bold", textTransform: "uppercase" }}>Performans</div>
                      <div style={{ fontSize: "24px", fontWeight: "800", color: "#3498db", marginTop: "5px" }}>%95.0</div>
                      <div style={{ fontSize: "11px", color: "#95a5a6", marginTop: "4px" }}>Nominal hıza oranı</div>
                    </div>
                    <div style={{ flex: 1, padding: "15px", background: "#f8f9fa", borderRadius: "10px", textAlign: "center", border: "1px solid #e1e5eb" }}>
                      <div style={{ fontSize: "12px", color: "#7f8c8d", fontWeight: "bold", textTransform: "uppercase" }}>Kalite</div>
                      <div style={{ fontSize: "24px", fontWeight: "800", color: "#3498db", marginTop: "5px" }}>%98.0</div>
                      <div style={{ fontSize: "11px", color: "#95a5a6", marginTop: "4px" }}>Sağlam ürün oranı</div>
                    </div>
                  </div>
                </div>

              </div>
            </div>
          )}

        </div>
      </div>
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
const closeBtnStyle = { background: "transparent", border: "none", fontSize: "20px", cursor: "pointer", color: "#999" };

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
