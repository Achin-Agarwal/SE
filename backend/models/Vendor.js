import mongoose from "mongoose";
import bcrypt from "bcrypt";

const vendorSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    phone: { type: String, required: true, unique: true },
    password: { type: String, required: true },

    role: {
      type: String,
      required: true,
      enum: ["photographer", "caterer", "decorator", "musician"],
    },

    description: { type: String, required: true },

    location: {
      lat: { type: String, required: true },
      lon: { type: String, required: true },
    },

    profileImage: { type: String },
    workImages: [{ type: String }],

    rating: { type: Number, default: 0 },
    ratingMessages: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
        message: { type: String },
        rating: { type: Number, min: 1, max: 5 },
        createdAt: { type: Date, default: Date.now },
      },
    ],

    receivedRequests: [
      { type: mongoose.Schema.Types.ObjectId, ref: "VendorRequest" },
    ],
  },
  { timestamps: true }
);
vendorSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});
vendorSchema.methods.comparePassword = async function (password) {
  return await bcrypt.compare(password, this.password);
};

export default mongoose.model("Vendor", vendorSchema);
