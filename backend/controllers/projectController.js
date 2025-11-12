import User from "../models/User.js";
import OpenAI from "openai";
import dotenv from "dotenv";
dotenv.config();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

/**
 * Helper: find project by userId + projectName
 */
async function findProjectByName(userId, projectName) {
  const user = await User.findById(userId);
  if (!user) return null;
  const project = user.projects.find(
    (p) => p.name.trim().toLowerCase() === projectName.trim().toLowerCase()
  );
  if (!project) return null;
  return { user, project };
}

/**
 * GET /api/projects/:userId/:projectName/chat
 */
export async function getProjectChat(req, res) {
  try {
    const { userId, projectName } = req.params;

    const found = await findProjectByName(userId, projectName);
    if (!found)
      return res.status(404).json({ error: "Project not found" });

    const { user, project } = found;

    // If no chat exists, seed with initial AI prompt
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

/**
 * POST /api/projects/:userId/:projectName/chat
 * body: { sender: "user", message: "..." }
 */
export async function postProjectMessage(req, res) {
  try {
    const { userId, projectName } = req.params;
    const { sender, message } = req.body;
    console.log(req.params)

    if (!message || !sender)
      return res.status(400).json({ error: "sender and message required" });

    const found = await findProjectByName(userId, projectName);
    if (!found)
      return res.status(404).json({ error: "Project not found" });

    const { user, project } = found;

    // Save user message
    const userMsg = { sender, message, timestamp: new Date() };
    project.chat.push(userMsg);
    await user.save();

    // Compose recent conversation context
    const lastMsgs = project.chat
      .slice(-20)
      .map((m) => `${m.sender === "user" ? "User" : "AI"}: ${m.message}`)
      .join("\n");

    const prompt = [
      {
        role: "system",
        content:
          "You are an assistant that helps create project progress checklist items from conversations and answers user's questions.",
      },
      {
        role: "user",
        content: `Conversation context:\n${lastMsgs}\n\nRespond concisely as the AI message that continues the chat.`,
      },
    ];

    // 🧠 Call OpenAI
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: prompt,
      max_tokens: 500,
      temperature: 0.2,
    });

    const aiText =
      completion.choices?.[0]?.message?.content?.trim() ||
      "Sorry, I couldn’t process that.";

    const aiMsg = { sender: "ai", message: aiText, timestamp: new Date() };
    project.chat.push(aiMsg);
    await user.save();

    return res.json({ aiMessage: aiMsg, chat: project.chat });
  } catch (err) {
    console.error("postProjectMessage error:", err);
    return res.status(500).json({ error: "Server error" });
  }
}

/**
 * POST /api/projects/:userId/:projectName/flowchart
 */
export async function generateFlowChart(req, res) {
  try {
    const { userId, projectName } = req.params;

    const found = await findProjectByName(userId, projectName);
    if (!found)
      return res.status(404).json({ error: "Project not found" });

    const { user, project } = found;

    const chatText = project.chat
      .map((c) => `${c.sender === "user" ? "User" : "AI"}: ${c.message}`)
      .join("\n");

    const systemPrompt = {
      role: "system",
      content:
        "You are a helpful assistant that reads the conversation and extracts project 'points'. Output only JSON array with {text, details, suggestedDone}. No extra text.",
    };

    const userPrompt = {
      role: "user",
      content: `Conversation:\n${chatText}\n\nTask: Extract up to 30 distinct actionable points (short title & optional details). Return JSON ONLY.`,
    };

    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [systemPrompt, userPrompt],
      max_tokens: 1000,
      temperature: 0.0,
    });

    const raw = completion.choices?.[0]?.message?.content?.trim() || "[]";

    let aiPointsFromModel = [];
    try {
      const start = raw.indexOf("[");
      const end = raw.lastIndexOf("]");
      aiPointsFromModel = JSON.parse(raw.slice(start, end + 1));
    } catch (e) {
      console.error("Failed to parse AI JSON:", e, raw);
      return res
        .status(500)
        .json({ error: "Failed to parse AI response", raw });
    }

    // Merge AI points with existing
    const existing = project.aiPoints || [];
    const now = new Date();
    const normalize = (s) => (s || "").trim().toLowerCase();

    for (const aiPoint of aiPointsFromModel) {
      const text = (aiPoint.text || "").trim();
      if (!text) continue;
      const normalized = normalize(text);
      const idx = existing.findIndex(
        (ep) => normalize(ep.text) === normalized
      );

      const doneKeywords = [
        "booked",
        "confirmed",
        "paid",
        "hired",
        "done",
        "completed",
      ];
      const mentions = project.chat.filter(
        (c) =>
          normalize(c.message).includes(normalized) ||
          doneKeywords.some(
            (k) =>
              normalize(c.message).includes(k) &&
              normalize(c.message).includes(normalized.split(" ")[0])
          )
      );

      const suggestedDone =
        aiPoint.suggestedDone ||
        mentions.some((m) =>
          doneKeywords.some((k) => m.message.toLowerCase().includes(k))
        );

      if (idx === -1) {
        existing.push({
          text,
          details: aiPoint.details || "",
          done: suggestedDone,
          createdAt: now,
          lastUpdated: now,
        });
      } else {
        const cur = existing[idx];
        const newDetails = (aiPoint.details || "").trim();
        if (newDetails && newDetails !== (cur.details || "")) {
          cur.details = cur.details
            ? `${cur.details} | ${newDetails}`
            : newDetails;
          cur.lastUpdated = now;
        }
        if (suggestedDone && !cur.done) {
          cur.done = true;
          cur.lastUpdated = now;
        }
      }
    }

    project.aiPoints = existing;
    await user.save();

    return res.json({ aiPoints: project.aiPoints });
  } catch (err) {
    console.error("generateFlowChart error:", err);
    return res.status(500).json({ error: "Server error" });
  }
}
