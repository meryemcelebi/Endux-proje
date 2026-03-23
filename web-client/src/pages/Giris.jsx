import { useState } from "react";
import { useNavigate } from "react-router-dom";

function Giris() {
  const navigate = useNavigate();

  const [role, setRole] = useState("");
  const [password, setPassword] = useState("");

  const handleLogin = () => {
    // 🔐 admin
    if (role === "admin" && password === "1234") {
      localStorage.setItem("role", "admin"); // 👈 EKLENDİ
      navigate("/Dashboard");
      return;
    }

    // 👷 operator
    if (role === "operator" && password === "1111") {
      localStorage.setItem("role", "operator"); // 👈 EKLENDİ
      navigate("/ChecklistGiris");
      return;
    }

    alert("Hatalı giriş!");
  };

  return (
    <div style={{ padding: 30 }}>
      <h1>Fabrika Giriş Sistemi</h1>

      {/* ROL SEÇİMİ */}
      <select onChange={(e) => setRole(e.target.value)}>
        <option value="">Rol seç</option>
        <option value="admin">Yönetici</option>
        <option value="operator">Operatör</option>
      </select>

      <br /><br />

      {/* ŞİFRE */}
      <input
        type="password"
        placeholder="Şifre"
        onChange={(e) => setPassword(e.target.value)}
      />

      <br /><br />

      <button onClick={handleLogin}>
        Giriş Yap
      </button>
    </div>
  );
}

export default Giris;