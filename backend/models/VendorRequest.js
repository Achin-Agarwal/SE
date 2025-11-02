import mongoose from "mongoose";

const vendorRequestSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    vendor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Vendor",
      required: true,
    },

    project: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User.projects",
      required: true,
    },

    role: { type: String, required: true },

    location: {
      type: {
        type: String,
        enum: ["Point"],
        default: "Point",
      },
      coordinates: {
        type: [Number],
        required: true,
      },
    },

    description: { type: String, required: true },

    startDateTime: {
      type: Date,
      required: true,
    },
    endDateTime: {
      type: Date,
      required: true,
      validate: {
        validator: function (value) {
          return this.startDateTime ? value > this.startDateTime : true;
        },
        message: "End date/time must be after start date/time",
      },
    },

    vendorStatus: {
      type: String,
      enum: ["Pending", "Accepted", "Rejected"],
      default: "Pending",
    },
    userStatus: {
      type: String,
      enum: ["Pending", "Accepted", "Rejected"],
      default: "Pending",
    },

    budget: { type: Number },
    additionalDetails: { type: String },

    // 🆕 Progress tracking for booked vendors
    progress: [
      {
        text: {
          type: String,
          enum: ["Vendor booked", "Vendor arrived", "Vendor departed"],
          required: true,
        },
        done: { type: Boolean, default: false },
      },
    ],
  },
  { timestamps: true }
);

vendorRequestSchema.index({ location: "2dsphere" });
vendorRequestSchema.pre("save", function (next) {
  if (
    this.vendorStatus === "Accepted" &&
    this.userStatus === "Accepted" &&
    (!this.progress || this.progress.length === 0)
  ) {
    this.progress = [
      { text: "Vendor booked", done: true },
      { text: "Vendor arrived", done: false },
      { text: "Vendor departed", done: false },
    ];
  }
  next();
});

export default mongoose.model("VendorRequest", vendorRequestSchema);
