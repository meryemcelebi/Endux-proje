
import React, { useState } from "react";
import { useNavigate } from "react-router-dom";

export default function AdminGiris() {
    const [password, setPassword] = useState("");
    const navigate = useNavigate();

    const login = () => {
        if (password === "1111") {
            navigate("/dashboard");
        } else {
            alert("Hatalı şifre");
        }
    };

    return (
        <div style={{ padding: 50 }}>
            <h2>Yönetici Girişi</h2>

            <input
                type="password"
                placeholder="Şifre"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
            />

            <button onClick={login} style={{ marginLeft: 10 }}>
                Giriş
            </button>
        </div>
    );
}