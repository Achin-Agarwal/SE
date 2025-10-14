import mongoose from "mongoose";

const vendorRequestSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  vendor: { type: mongoose.Schema.Types.ObjectId, ref: "Vendor", required: true },

  // The event details sent by user
  role: { type: String, required: true },
  location: { type: String, required: true },
  description: { type: String, required: true },
  eventDate: { type: Date, required: true },

  // Vendor side action
  vendorStatus: {
    type: String,
    enum: ["Pending", "Accepted", "Rejected"],
    default: "Pending"
  },

  // User side action
  userStatus: {
    type: String,
    enum: ["Pending", "Accepted", "Rejected"],
    default: "Pending"
  },

  // When vendor accepts, they can send offer details
  budget: { type: Number },
  additionalDetails: { type: String },

}, { timestamps: true });

export default mongoose.model("VendorRequest", vendorRequestSchema);
