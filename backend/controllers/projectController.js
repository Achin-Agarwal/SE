import User from "../models/User.js";
import dotenv from "dotenv";
import axios from "axios";
dotenv.config();

async function findProjectByName(userId, projectName) {
  const user = await User.findById(userId);
  if (!user) return null;
  const project = user.projects.find(
    (p) => p.name.trim().toLowerCase() === projectName.trim().toLowerCase()
  );
  if (!project) return null;
  return { user, project };
}
export async function getProjectChat(req, res) {
  try {
    const { userId, projectName } = req.params;
    const found = await findProjectByName(userId, projectName);
    if (!found) return res.status(404).json({ error: "Project not found" });
    const { user, project } = found;
    if (!project.chat || project.chat.length === 0) {
      const aiMsg = {
        sender: "ai",
        message: "Give the description of the project.",
        timestamp: new Date(),
      };
      project.chat = [aiMsg];
      await user.save();
    }
    return res.json({
      chat: project.chat,
      aiPoints: project.aiPoints || [],
    });
  } catch (err) {
    console.error("getProjectChat error:", err);
    return res.status(500).json({ error: "Server error" });
  }
}

export async function postProjectMessage(req, res) {
  try {
    const { userId, projectName } = req.params;
    const { sender, message } = req.body;
    console.log(req.params);
    if (!message || !sender)
      return res.status(400).json({ error: "sender and message required" });
    const found = await findProjectByName(userId, projectName);
    if (!found) return res.status(404).json({ error: "Project not found" });
    const { user, project } = found;
    const userMsg = { sender, message, timestamp: new Date() };
    project.chat.push(userMsg);
    await user.save();
    const chat_history = {};
    project.chat.slice(-20).forEach((m, i) => {
      chat_history[m.sender] = m.message;
    });
    const payload = {
      chat_history,
      current_text: message,
    };
    const AI_API_URL = "https://eventflow-kd8x.onrender.com/chat";
    const aiResponse = await axios.post(AI_API_URL, payload);
    const aiText =
      aiResponse.data?.reply_text ||
      "Sorry, I couldn't get a response from the AI.";
    const aiMsg = { sender: "ai", message: aiText, timestamp: new Date() };
    project.chat.push(aiMsg);
    await user.save();
    return res.json({ aiMessage: aiMsg });
  } catch (err) {
    console.error("postProjectMessage error:", err.response?.data || err);
    return res.status(500).json({ error: "Server error" });
  }
}

export async function generateFlowChart(req, res) {
  try {
    const { userId, projectName } = req.params;
    const found = await findProjectByName(userId, projectName);
    if (!found) return res.status(404).json({ error: "Project not found" });
    const { user, project } = found;
    const chat_history = {};
    project.chat.forEach((c) => {
      chat_history[c.sender] = c.message;
    });
    const AI_API_URL =
      process.env.AI_API_URL ||
      "https://eventflow-kd8x.onrender.com/generate-flowchart";
    const payload = { chat_history };
    const aiResponse = await axios.post(AI_API_URL, payload);
    const { updated_plan_json, error } = aiResponse.data || {};
    if (error && error !== null) {
      return res.json({ error, aiPoints: project.aiPoints || [] });
    }
    if (!updated_plan_json) {
      return res.status(400).json({ error: "No plan received from AI" });
    }
    let cleanedJson = updated_plan_json
      .replace(/\\n/g, "\n")
      .replace(/\\"/g, '"');
    let parsedPlan;
    try {
      parsedPlan = JSON.parse(cleanedJson);
    } catch (e) {
      console.error("Failed to parse updated_plan_json:", e, cleanedJson);
      return res.status(500).json({ error: "Invalid JSON from AI" });
    }
    const aiPointsFromModel = parsedPlan?.event_plan || [];
    const existing = project.aiPoints || [];
    const normalize = (s) => (s || "").trim().toLowerCase();
    const now = new Date();
    for (const point of aiPointsFromModel) {
      const text = (point.task || "").trim();
      if (!text) continue;
      const exists = existing.find(
        (p) => normalize(p.text) === normalize(text)
      );
      if (!exists) {
        existing.push({
          text,
          details: point.details || "",
          done: false,
          createdAt: now,
          lastUpdated: now,
        });
      }
    }
    project.aiPoints = existing;
    await user.save();
    return res.json({
      message: "AI flowchart generated successfully",
      aiPoints: project.aiPoints,
    });
  } catch (err) {
    console.error("generateFlowChart error:", err.response?.data || err);
    return res.status(500).json({ error: "Server error" });
  }
}

export async function toggleFlowStep(req, res) {
  try {
    const { userId, projectName } = req.params;
    const { text, done } = req.body;

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ error: "User not found" });

    const project = user.projects.find((p) => p.name === projectName);
    if (!project) return res.status(404).json({ error: "Project not found" });

    const index = project.aiPoints.findIndex(
      (p) => p.text.trim().toLowerCase() === text.trim().toLowerCase()
    );
    if (index === -1) return res.status(404).json({ error: "Point not found" });

    project.aiPoints[index].done = done;
    project.aiPoints[index].lastUpdated = new Date();

    await user.save();
    return res.json({
      message: "Updated successfully",
      aiPoints: project.aiPoints,
    });
  } catch (err) {
    console.error("toggleFlowStep error:", err);
    return res.status(500).json({ error: "Server error" });
  }
}
