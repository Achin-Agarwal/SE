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
  },
  { timestamps: true }
);

vendorRequestSchema.index({ location: "2dsphere" });

export default mongoose.model("VendorRequest", vendorRequestSchema);