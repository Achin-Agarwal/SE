import express from "express";
import bcrypt from "bcrypt";
import {
  userRegisterSchema,
  loginSchema,
} from "../validators/auth-validators.js";
import { safeHandler } from "../middlewares/safeHandler.js";
import { generateToken } from "../utils/jwtFunct.js";
import User from "../models/User.js";
import Vendor from "../models/Vendor.js";
import VendorRequest from "../models/VendorRequest.js";
import { ObjectId } from "mongodb";

const router = express.Router();
router.post(
  "/register",
  safeHandler(async (req, res) => {
    // Validate input using Zod
    const parsed = userRegisterSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.error(
        400,
        parsed.error.issues.map((e) => e.message).join(", "),
        "VALIDATION_ERROR"
      );
    }

    const { name, email, password, phone } = parsed.data;

    // Check for existing user
    const existingUser = await User.findOne({
      $or: [{ email }, { phone }],
    });

    if (existingUser) {
      return res.error(
        409,
        "User already exists with this email or phone number",
        "USER_EXISTS"
      );
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create new user
    const newUser = new User({
      name,
      email,
      password: hashedPassword,
      phone,
      role: "user", // default role for normal users
    });

    await newUser.save();

    // Generate JWT token
    const token = generateToken({ id: newUser._id, role: newUser.role });

    // Send response
    return res.success(201, "User registered successfully", {
      token,
      user: {
        id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        phone: newUser.phone,
        role: newUser.role,
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

    const { email, password } = parsed.data;

    const user = await User.findOne({ email });
    if (!user) {
      return res.error(401, "Invalid email or password", "INVALID_CREDENTIALS");
    }

    const isPasswordValid = bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.error(401, "Invalid email or password", "INVALID_CREDENTIALS");
    }

    const token = generateToken({ id: user._id, role: "user" });

    return res.success(200, "Login successful", {
      token,
      user: {
        id: user._id,
        name: user.name,
      },
    });
  })
);

// Get vendors by role
router.get(
  "/vendors/:role",
  safeHandler(async (req, res) => {
    try {
      const vendors = await Vendor.find({
        role: { $regex: new RegExp(`^${req.params.role}$`, "i") },
      });
      res.json(vendors);
    } catch (err) {
      res.status(400).json({ error: err.message });
    }
  })
);

// Send event requests to multiple vendors
router.post(
  "/sendrequests",
  safeHandler(async (req, res) => {
    try {
      const { userId, vendors, role, location, description, eventDate } =
        req.body;

      // Basic validation
      if (!userId || !Array.isArray(vendors) || vendors.length === 0) {
        return res.status(400).json({
          status: "error",
          message: "userId and vendors (array of IDs) are required",
        });
      }

      const requests = await Promise.all(
        vendors.map(async (vendorId) => {
          const request = await VendorRequest.create({
            user: userId,
            vendor: vendorId,
            role,
            location,
            description,
            eventDate,
          });

          await User.findByIdAndUpdate(userId, {
            $push: { sentRequests: request._id },
          });

          await Vendor.findByIdAndUpdate(vendorId, {
            $push: { receivedRequests: request._id },
          });

          return request;
        })
      );

      return res.status(201).json({
        status: "success",
        message: "Requests sent successfully",
        data: requests,
      });
    } catch (err) {
      console.error(err);
      return res.status(500).json({
        status: "error",
        message: "Failed to send vendor requests",
        error: err.message,
      });
    }
  })
);

// Get all sent requests by a user
router.get(
  "/:userId/requests",
  safeHandler(async (req, res) => {
    const requests = await VendorRequest.find({ user: req.params.userId })
      .populate("vendor", "name role rating description email phone")
      .select(
        "_id user vendor role location description eventDate vendorStatus userStatus createdAt updatedAt additionalDetails budget"
      )
      .lean();
    res.json(requests);
  })
);

// User accepts one vendor offer (and delete others)

router.post(
  "/acceptoffer",
  safeHandler(async (req, res) => {
    try {
      const { requestId, userId, role, accept } = req.body;

      if (!requestId || !userId || !role || typeof accept !== "boolean") {
        return res.error(400, "Missing or invalid fields", "MISSING_FIELDS");
      }

      const requestObjectId = new ObjectId(requestId);
      const roleLower = role.toLowerCase();

      if (accept) {
        // ✅ User accepts the offer
        const acceptedReq = await VendorRequest.findByIdAndUpdate(
          requestObjectId,
          { userStatus: "Accepted" },
          { new: true }
        );

        if (!acceptedReq) {
          return res.error(404, "Request not found", "REQUEST_NOT_FOUND");
        }

        // 🔹 Find all other pending requests for same user & role
        const otherRequests = await VendorRequest.find({
          user: userId,
          role: { $regex: new RegExp(`^${roleLower}$`, "i") }, // case-insensitive match
          userStatus: "pending", // only pending ones
          _id: { $ne: requestObjectId },
        });

        // 🔹 Remove references from User & Vendor
        await Promise.all(
          otherRequests.map(async (reqDoc) => {
            await Promise.all([
              User.findByIdAndUpdate(reqDoc.user, {
                $pull: { sentRequests: reqDoc._id },
              }),
              Vendor.findByIdAndUpdate(reqDoc.vendor, {
                $pull: { receivedRequests: reqDoc._id },
              }),
            ]);
          })
        );

        // 🔹 Delete other pending requests
        const deleted = await VendorRequest.deleteMany({
          user: userId,
          role: { $regex: new RegExp(`^${roleLower}$`, "i") },
          userStatus: "pending",
          _id: { $ne: requestObjectId },
        });

        return res.success(200, "Offer accepted successfully", {
          acceptedRequest: acceptedReq,
          deletedRequestsCount: deleted.deletedCount,
        });
      } else {
        // ❌ User rejects this offer
        const reqToDelete = await VendorRequest.findById(requestObjectId);

        if (!reqToDelete) {
          return res.error(404, "Request not found", "REQUEST_NOT_FOUND");
        }

        // 🔹 Remove references from User & Vendor
        await Promise.all([
          User.findByIdAndUpdate(reqToDelete.user, {
            $pull: { sentRequests: reqToDelete._id },
          }),
          Vendor.findByIdAndUpdate(reqToDelete.vendor, {
            $pull: { receivedRequests: reqToDelete._id },
          }),
        ]);

        // 🔹 Delete the request itself
        await VendorRequest.findByIdAndDelete(requestObjectId);

        return res.success(200, "Offer rejected and deleted successfully", {
          deletedRequest: requestId,
        });
      }
    } catch (err) {
      console.error("Accept offer error:", err);
      return res.error(500, "Failed to process offer", "ACCEPT_OFFER_ERROR", {
        details: err.message,
      });
    }
  })
);

export default router;
