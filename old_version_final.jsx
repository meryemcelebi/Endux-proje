/*import React, { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";

export default function ChecklistGiris() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [password, setPassword] = useState("");

  const checkPassword = () => {
    if (password === "1234") {
      navigate(`/checklist/aktif/${id}`);
    } else {
      alert("┼Şifre yanl─▒┼ş");
    }
  };

  return (
    <div style={{ padding: 20 }}>
      <h2>­şöÉ Makine Eri┼şim</h2>
      <p>Makine ID: {id}</p>

      <input
        type="password"
        placeholder="┼Şifre gir"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />

      <button onClick={checkPassword}>
        Giri┼ş
      </button>
    </div>
  );
}*/
import React, { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";

export default function ChecklistGiris() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [password, setPassword] = useState("");

  const OPERATOR_PASS = "1111";
  const ADMIN_PASS = "9999";

  const handleLogin = () => {
    if (password === ADMIN_PASS) {
      // ­şöÑ Y├ûNET─░C─░ = direkt makine verisi
      navigate(`/makine/${id}`);
    }
    else if (password === OPERATOR_PASS) {
      // ­şæÀ OPERATOR = checklist
      navigate(`/checklist/${id}`);
    }
    else {
      alert("┼Şifre yanl─▒┼ş ÔØî");
    }
  };

  return (
    <div style={{ padding: 20 }}>
      <h2>Makine Giri┼şi</h2>
      <p>Makine ID: {id}</p>

      <input
        type="password"
        placeholder="┼Şifre gir"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />

      <button onClick={handleLogin}>Giri┼ş</button>
    </div>
  );
}
