// models/User.js
import mongoose from "mongoose";
import bcrypt from "bcrypt";

const chatMessageSchema = new mongoose.Schema({
  sender: { type: String, enum: ["user", "ai"], required: true },
  message: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
});

const aiPointSchema = new mongoose.Schema({
  text: { type: String, required: true }, // e.g. "Caterer booked"
  details: { type: String, default: "" }, // extra info AI extracts e.g. "venue: Hall A"
  done: { type: Boolean, default: false }, // toggle for progress tracking
  createdAt: { type: Date, default: Date.now },
  lastUpdated: { type: Date, default: Date.now },
});

const projectSchema = new mongoose.Schema({
  name: { type: String, required: true },

  sentRequests: [
    {
      vendorRequest: { type: mongoose.Schema.Types.ObjectId, ref: "VendorRequest" },
      role: { type: String, required: true },
    },
  ],

  // Chat history for this project
  chat: [chatMessageSchema],

  // AI-generated points (like progress checklist)
  aiPoints: [aiPointSchema],
});

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    phone: { type: String, required: true },
    password: { type: String, required: true },
    role: { type: String, required: true, enum: ["user"] },
    profileImage: { type: String },

    projects: [projectSchema],
  },
  { timestamps: true }
);

userSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});
userSchema.methods.comparePassword = async function (password) {
  return await bcrypt.compare(password, this.password);
};

export default mongoose.model("User", userSchema);
