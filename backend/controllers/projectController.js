// controllers/projectController.js
import User from "../models/User.js"; // adapt import path
import OpenAI from "openai";
import dotenv from "dotenv";
dotenv.config();

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY, // your API key
});

/**
 * Helper: get project object (projects are embedded in user)
 * Adapt if you store projects elsewhere.
 */
async function findProjectById(projectId) {
  // If you store projects in separate collection, change this logic.
  // Here: find user that contains project._id = projectId
  const user = await User.findOne({ "projects._id": projectId });
  if (!user) return null;
  const project = user.projects.id(projectId);
  return { user, project };
}

export async function getProjectChat(req, res) {
  try {
    const { projectId } = req.params;
    const found = await findProjectById(projectId);
    if (!found) return res.status(404).json({ error: "Project not found" });
    const { user, project } = found;

    // If no chat exists, seed with initial AI prompt as first message
    if (!project.chat || project.chat.length === 0) {
      const aiMsg = {
        sender: "ai",
        message: "Give the description of the project.",
        timestamp: new Date(),
      };
      project.chat.push(aiMsg);
      await user.save();
    }

    return res.json({ chat: project.chat, aiPoints: project.aiPoints || [] });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Server error" });
  }
}

/**
 * POST /api/projects/:projectId/chat
 * body: { sender: "user", message: "..." }
 * Saves user message, calls OpenAI, saves AI reply, returns AI reply and updated chat.
 */
export async function postProjectMessage(req, res) {
  try {
    const { projectId } = req.params;
    const { sender, message } = req.body;
    if (!message || !sender) return res.status(400).json({ error: "sender and message required" });

    const found = await findProjectById(projectId);
    if (!found) return res.status(404).json({ error: "Project not found" });
    const { user, project } = found;

    // Save user message
    const userMsg = { sender, message, timestamp: new Date() };
    project.chat.push(userMsg);
    await user.save();

    // Compose context for AI: last N messages to avoid huge prompt
    const lastMsgs = project.chat.slice(-20).map(m => `${m.sender === "user" ? "User" : "AI"}: ${m.message}`).join("\n");

    // Call OpenAI (chat completion)
    const prompt = [
      { role: "system", content: "You are an assistant that helps create project progress checklist items from conversations and answers user's questions." },
      { role: "user", content: `Conversation context:\n${lastMsgs}\n\nRespond concisely as the AI message that continues the chat.` }
    ];

    const completion = await openai.createChatCompletion({
      model: "gpt-4o-mini", // pick model you have access to
      messages: prompt,
      max_tokens: 500,
      temperature: 0.2,
    });

    const aiText = completion.data.choices[0].message.content.trim();

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
 * POST /api/projects/:projectId/flowchart
 * Behavior:
 *  - Send entire conversation to the AI and ask it to return a JSON array of important points.
 *  - Compare to existing aiPoints and update/create as required.
 */
export async function generateFlowChart(req, res) {
  try {
    const { projectId } = req.params;
    const found = await findProjectById(projectId);
    if (!found) return res.status(404).json({ error: "Project not found" });
    const { user, project } = found;

    const chatText = project.chat.map(c => `${c.sender === "user" ? "User" : "AI"}: ${c.message}`).join("\n");

    // System prompt instructs the model to return strict JSON array: [{text:"", details:"", done:false}]
    const system = {
      role: "system",
      content: "You are a helpful assistant that reads the conversation and extracts project 'points' (status items). Output only a JSON array with objects {text, details, suggestedDone} where text is short title and details is optional extra info. No extra commentary."
    };

    const userPrompt = {
      role: "user",
      content:
        `Conversation:\n${chatText}\n\nTask: Extract up to 30 distinct actionable points (short title & optional details). Return JSON ONLY, like:\n[{"text":"Caterer booked","details":"venue: Hall A; time: 6pm","suggestedDone":true}, ...]\n\nDo not delete existing points in DB. We'll merge carefully on the server.`
    };

    const completion = await openai.createChatCompletion({
      model: "gpt-4o-mini",
      messages: [system, userPrompt],
      max_tokens: 1000,
      temperature: 0.0,
    });

    const raw = completion.data.choices[0].message.content.trim();

    // Try to parse JSON from response (defensive)
    let aiPointsFromModel = [];
    try {
      // attempt to find first JSON substring
      const firstBracket = raw.indexOf("[");
      const lastBracket = raw.lastIndexOf("]");
      const jsonStr = raw.slice(firstBracket, lastBracket + 1);
      aiPointsFromModel = JSON.parse(jsonStr);
    } catch (e) {
      console.error("Failed to parse AI response JSON:", e, "raw:", raw);
      return res.status(500).json({ error: "Failed to parse AI response", raw });
    }

    // Merge with existing project.aiPoints
    const existing = project.aiPoints || [];
    const now = new Date();

    // Helper normalized text
    const normalize = (s) => (s || "").trim().toLowerCase();

    for (const aiPoint of aiPointsFromModel) {
      const text = (aiPoint.text || "").trim();
      if (!text) continue;
      const normalized = normalize(text);

      // find existing by normalized text exact match
      const foundIdx = existing.findIndex(ep => normalize(ep.text) === normalized);

      // Heuristic to mark done if any chat message says something like 'booked/confirmed/paid/hired/done'
      const doneKeywords = ["booked", "confirmed", "paid", "hired", "done", "completed"];
      const mentions = project.chat.filter(c => normalize(c.message).includes(normalized) || doneKeywords.some(k => normalize(c.message).includes(k) && normalize(c.message).includes(normalized.split(" ")[0])));

      const suggestedDone = Boolean(aiPoint.suggestedDone || (mentions.length > 0 && mentions.some(m => doneKeywords.some(k => m.message.toLowerCase().includes(k)))));

      if (foundIdx === -1) {
        // Add new
        existing.push({
          text: text,
          details: aiPoint.details || "",
          done: suggestedDone,
          createdAt: now,
          lastUpdated: now,
        });
      } else {
        // Update existing carefully: do not overwrite text if same; update details if AI provided more info and it's different
        const cur = existing[foundIdx];
        const newDetails = (aiPoint.details || "").trim();
        if (newDetails && newDetails !== (cur.details || "")) {
          cur.details = cur.details ? `${cur.details} | ${newDetails}` : newDetails;
          cur.lastUpdated = now;
        }
        // update done flag if suggestedDone true and it is not already true
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
