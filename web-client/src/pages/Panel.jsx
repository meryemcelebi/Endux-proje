import { useParams, useNavigate } from "react-router-dom";
import { useEffect } from "react";

function Panel() {
  const { id } = useParams();
  const navigate = useNavigate();

  // 🔒 SADECE ADMIN GİREBİLSİN
  useEffect(() => {
    const role = localStorage.getItem("role");

    if (role !== "admin") {
      navigate("/Checklistgiris/" + id);
    }
  }, []);

  return (
    <div style={{ padding: 20 }}>
      <h1>🛠 Kontrol Paneli</h1>

      <h3>Makine ID: {id}</h3>

      <div style={{ marginTop: 20 }}>
        <p>📊 Makine Durumu: Aktif</p>
        <p>⚙ Son Bakım: 2 gün önce</p>
        <p>⚠ Uyarılar: Yok</p>
      </div>
    </div>
  );
}

export default Panel;