
import { Link } from "react-router-dom";

const Sidebar = () => {
  return (
    <div
      style={{
        width: "200px",
        background: "darkslategray",
        color: "white",
        height: "100vh",
        padding: "20px"
      }}
    >
      <h3>Menü</h3>

      <nav
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "15px",
          marginTop: "20px"
        }}
      >
        <Link to="/dashboard" style={linkStyle}>
          Ana Kontrol Paneli
        </Link>

        <Link to="/makineler" style={linkStyle}>
          Makineler
        </Link>

        <Link to="/kisi-ekle" style={linkStyle}>
          Kişi Ekle
        </Link>
      </nav>
    </div>
  );
};

const linkStyle = {
  color: "white",
  textDecoration: "none"
};

export default Sidebar;