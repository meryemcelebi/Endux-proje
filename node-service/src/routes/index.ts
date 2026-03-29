import { Router } from "express";
import authRoutes from "./authRoutes";
import kullaniciRoutes from "./kullaniciRoutes";
import makineRoutes from "./makineRoutes";
import checklistRoutes from "./checklistRoutes";

const router = Router();

// Auth route'ları — /api/auth/*
router.use("/auth", authRoutes);

// Kullanıcı (personel) route'ları — /api/kullanicilar/*
router.use("/kullanicilar", kullaniciRoutes);

// Makine route'ları — /api/makineler/*
router.use("/makineler", makineRoutes);

// Checklist route'ları — /api/checklist/*
router.use("/checklist", checklistRoutes);

export default router;
