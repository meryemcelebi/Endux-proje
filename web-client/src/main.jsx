import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'

/**
 * React Uygulamasının Ana Giriş Noktası
 * Tüm bileşen ağacını 'root' ID'li HTML öğesine bağlar ve render eder.
 */
createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
