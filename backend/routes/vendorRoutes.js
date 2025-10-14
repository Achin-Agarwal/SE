import express from "express";
import bcrypt from "bcrypt";
import {
  vendorRegisterSchema,
  loginSchema,
} from "../validators/auth-validators.js";
import { safeHandler } from "../middlewares/safeHandler.js";
import { generateToken } from "../utils/jwtFunct.js";
import Vendor from "../models/Vendor.js";
import VendorRequest from "../models/VendorRequest.js";
import User from "../models/User.js";

const router = express.Router();
router.post(
  "/register",
  safeHandler(async (req, res) => {
    const parsed = vendorRegisterSchema.safeParse(req.body);

    if (!parsed.success) {
      const message =
        parsed.error?.issues?.map((e) => e.message).join(", ") ||
        "Validation failed";
      return res.error(400, message, "VALIDATION_ERROR");
    }

    const { name, email, password, phone, role, description, location } =
      parsed.data;

    // Check for existing vendor
    const existingVendor = await Vendor.findOne({
      $or: [{ email }, { phone }],
    });
    if (existingVendor) {
      return res.error(
        409,
        "Vendor already exists with this email or phone number",
        "VENDOR_EXISTS"
      );
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create new vendor
    const newVendor = new Vendor({
      name,
      email,
      phone,
      password: hashedPassword,
      role,
      description,
      location,
    });

    await newVendor.save();

    // Generate JWT
    const token = generateToken({ id: newVendor._id, role: "vendor" });

    return res.success(201, "Vendor registered successfully", {
      token,
      vendor: {
        id: newVendor._id,
        name: newVendor.name,
        email: newVendor.email,
        phone: newVendor.phone,
        role: newVendor.role,
        description: newVendor.description,
        location: newVendor.location,
      },
    });
  })
);

router.post(
  "/login",
  safeHandler(async (req, res) => {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.error(400, "Validation failed", "VALIDATION_ERROR");
    }

    const { email, password, role } = parsed.data;
    if (role == "user") {
      const user = await User.findOne({ email });
      if (!user) {
        return res.error(
          401,
          "Invalid email or password",
          "INVALID_CREDENTIALS"
        );
      }
      const isPasswordValid = bcrypt.compare(password, user.password);
      if (!isPasswordValid) {
        return res.error(
          401,
          "Invalid email or password",
          "INVALID_CREDENTIALS"
        );
      }
      const token = generateToken({ id: user._id, role: "user" });
      return res.success(200, "Login successful", {
        token,
        user: {
          id: user._id,
          name: user.name,
        },
      });
    }

    const vendor = await Vendor.findOne({ email });
    console.log(vendor);
    if (!vendor) {
      return res.error(401, "Invalid email or password", "INVALID_CREDENTIALS");
    }

    const isPasswordValid = bcrypt.compare(password, vendor.password);
    if (!isPasswordValid) {
      return res.error(401, "Invalid email or password", "INVALID_CREDENTIALS");
    }

    const token = generateToken({ id: vendor._id, role });

    return res.success(200, "Login successful", {
      token,
      vendor: {
        id: vendor._id,
        name: vendor.name,
      },
    });
  })
);

// Get all requests for this vendor
router.get(
  "/:vendorId/requests",
  safeHandler(async (req, res) => {
    const requests = await VendorRequest.find({ vendor: req.params.vendorId })
      .populate("user", "name email phone")
      .lean();
    res.json(requests);
  })
);

// Vendor accepts or rejects request
router.post(
  "/respond",
  safeHandler(async (req, res) => {
    try {
      const { requestId, action, budget, additionalDetails } = req.body;

      if (!requestId || !action) {
        return res.error(400, "Missing requestId or action", "MISSING_FIELDS");
      }

      // Find the request first
      const request = await VendorRequest.findById(requestId);
      if (!request) {
        return res.error(404, "Request not found", "REQUEST_NOT_FOUND");
      }

      // ✅ Check if user has already accepted any vendor offer
      const userAccepted = await VendorRequest.findOne({
        user: request.user,
        role: request.role,
        userStatus: "Accepted",
      });

      if (userAccepted) {
        return res.error(
          403,
          "User has already accepted another offer. You cannot respond to this request.",
          "USER_ALREADY_ACCEPTED"
        );
      }

      // ✅ If vendor rejects
      if (action === "reject") {
        await Promise.all([
          User.findByIdAndUpdate(request.user, {
            $pull: { sentRequests: request._id },
          }),
          Vendor.findByIdAndUpdate(request.vendor, {
            $pull: { receivedRequests: request._id },
          }),
        ]);

        await VendorRequest.findByIdAndDelete(requestId);

        return res.success(200, "Request rejected and removed successfully");
      }

      // ✅ If vendor accepts
      if (action === "accept") {
        const updated = await VendorRequest.findByIdAndUpdate(
          requestId,
          {
            vendorStatus: "Accepted",
            budget,
            additionalDetails,
          },
          { new: true }
        );

        return res.success(200, "Request accepted successfully", updated);
      }

      return res.error(400, "Invalid action provided", "INVALID_ACTION");
    } catch (err) {
      console.error("Respond error:", err);
      return res.error(500, "Failed to process response", "RESPOND_ERROR", {
        details: err.message,
      });
    }
  })
);

export default router;
