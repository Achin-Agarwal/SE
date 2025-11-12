import express from "express";
import {
  getProjectChat,
  postProjectMessage,
  generateFlowChart,
} from "../controllers/projectController.js";
import checkAuth from "../middlewares/auth.js";
import { safeHandler } from "../middlewares/safeHandler.js";
import User from "../models/User.js";

const router = express.Router();

// ✅ Create new project (with duplicate name check)
router.post(
  "/project/:userId",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { name } = req.body;

    if (!name) {
      return res.status(400).json({ error: "Project name is required" });
    }

    const user = await User.findById(req.params.userId);
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    // 🔍 Check for duplicate project name
    const projectExists = user.projects.some(
      (project) => project.name.toLowerCase() === name.toLowerCase()
    );

    if (projectExists) {
      return res.status(400).json({ error: "Project name already exists" });
    }

    // Add project
    user.projects.push({ name, sentRequests: [] });
    await user.save();

    res.status(201).json({
      message: "Project created successfully",
      project: user.projects[user.projects.length - 1],
    });
  })
);

// ✅ Routes for projectName-based actions
router.get("/:projectName/chat", checkAuth("user"), getProjectChat);
router.post("/:projectName/chat", checkAuth("user"), postProjectMessage);
router.post("/:projectName/flowchart", checkAuth("user"), generateFlowChart);

export default router;
