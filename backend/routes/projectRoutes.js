import express from "express";
import {
  getProjectChat,
  postProjectMessage,
  generateFlowChart,
} from "../controllers/projectController.js";

const router = express.Router();

router.get("/:projectId/chat", getProjectChat);
router.post("/:projectId/chat", postProjectMessage); // send user message -> backend saves + calls OpenAI
router.post("/:projectId/flowchart", generateFlowChart); // analyze chat and update/return aiPoints

export default router;
