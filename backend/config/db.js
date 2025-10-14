import mongoose from "mongoose";
import config from "./config.js";
import dotenv from "dotenv";
dotenv.config();

export default async function connectMongo() {
  const uri = process.env.MONGO_URI;
  if (!uri) {
    console.error("❌ MONGO_URI is not defined in .env file.");
    process.exit(1);
  }
  try {
    await mongoose.connect(config.database.uri);
    console.log("Connected to MongoDB");
  } catch (err) {
    console.error("Could not connect to MongoDB. Error:", err);
  }
}