import { Router } from "express";
import authRoutes from "./authRoutes";
import kullaniciRoutes from "./kullaniciRoutes";
import makineRoutes from "./makineRoutes";
import checklistRoutes from "./checklistRoutes";
import sistemRoutes from "./sistemRoutes";
import bakimRoutes from "./bakimRoutes";
import { TedarikciRouter, ServisFirmasiRouter } from "./firmaRoutes";
import gorevRoutes from "./gorevRoutes";
import { ServisPuanRouter, TedarikciPuanRouter } from "./puanRoute";
import aiRoutes from "./aiRoutes";
import oeeRoutes from "./oeeRoutes";



const router = Router();

// Auth route'ları — /api/auth/*
router.use("/auth", authRoutes);

// Kullanıcı (personel) route'ları — /api/kullanicilar/*
router.use("/kullanicilar", kullaniciRoutes);

// Makine route'ları — /api/makineler/*
router.use("/makineler", makineRoutes);

// Checklist route'ları — /api/checklist/*
router.use("/checklist", checklistRoutes);

router.use("/sistem", sistemRoutes);

router.use("/bakimlar", bakimRoutes);

router.use("/tedarikciler", TedarikciRouter); // /api/tedarikciler/*

router.use("/servis-firmalari", ServisFirmasiRouter); // /api/servis-firmalari/*

router.use("/gorevler", gorevRoutes);

router.use("/servis-puan", ServisPuanRouter);

router.use("/tedarikci-puan", TedarikciPuanRouter);

router.use("/ai", aiRoutes); // /api/ai/*

router.use("/oee", oeeRoutes); // /api/oee/*

export default router;
