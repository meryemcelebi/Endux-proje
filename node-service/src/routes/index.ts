import { Router } from "express";
import authRoutes from "./authRoutes";
import kullaniciRoutes from "./kullaniciRoutes";
import makineRoutes from "./makineRoutes";
import checklistRoutes from "./checklistRoutes";
import sistemRoutes from "./sistemRoutes";


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

export default router;
