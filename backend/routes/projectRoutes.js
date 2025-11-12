import express from "express";
import {
  getProjectChat,
  postProjectMessage,
  generateFlowChart,
} from "../controllers/projectController.js";
import checkAuth from "../middlewares/auth.js";
const router = express.Router();
router.get("/:userId/:projectName/chat", checkAuth("user"), getProjectChat);
router.post("/:userId/:projectName/chat", checkAuth("user") ,postProjectMessage);
router.post("/:userId/:projectName/flowchart", checkAuth("user"), generateFlowChart);

export default router;
