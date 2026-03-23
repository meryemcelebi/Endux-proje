import React from "react";
import { Link } from "react-router-dom";

const Sidebar = () => {
  const role = localStorage.getItem("role") || "guest";

  return (
    <div
      style={{
        width: "200px",
        background: "darkslategray",
        color: "white",
        height: "100vh",
        padding: "20px",
      }}
    >
      <h3>Menü</h3>

      <nav
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "15px",
          marginTop: "20px",
        }}
      >
        {/* HERKES */}
        <Link to="/dashboard" style={linkStyle}>
          Dashboard
        </Link>

        {/* SADECE ADMIN */}
        {role === "admin" && (
          <Link to="/makineler" style={linkStyle}>
            Makineler
          </Link>
        )}
      </nav>
    </div>
  );
};

const linkStyle = {
  color: "white",
  textDecoration: "none",
};

export default Sidebar;