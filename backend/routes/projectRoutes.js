import express from "express";
import {
  getProjectChat,
  postProjectMessage,
  generateFlowChart,
  toggleFlowStep,
} from "../controllers/projectController.js";
import checkAuth from "../middlewares/auth.js";
const router = express.Router();
router.get("/:userId/:projectName/chat", checkAuth("user"), getProjectChat);
router.post(
  "/:userId/:projectName/chat",
  checkAuth("user"),
  postProjectMessage
);
router.post(
  "/:userId/:projectName/flowchart",
  checkAuth("user"),
  generateFlowChart
);
router.put(
  "/:userId/:projectName/flowchart/toggle",
  checkAuth("user"),
  toggleFlowStep
);

export default router;
