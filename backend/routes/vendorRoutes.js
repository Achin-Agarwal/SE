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
import { S3Client } from "@aws-sdk/client-s3";
import multer from "multer";
import multerS3 from "multer-s3";
import dotenv from "dotenv";

dotenv.config();

// ✅ Configure S3 client for DigitalOcean Spaces
const s3 = new S3Client({
  endpoint: process.env.DO_SPACES_ENDPOINT,
  region: "blr1",
  credentials: {
    accessKeyId: process.env.DO_SPACES_KEY,
    secretAccessKey: process.env.DO_SPACES_SECRET,
  },
});

// ✅ Multer storage for profile + work images
export const upload = multer({
  storage: multerS3({
    s3,
    bucket: process.env.DO_SPACES_BUCKET,
    acl: "public-read",
    key: (req, file, cb) => {
      cb(null, `vendors/${Date.now()}-${file.originalname}`);
    },
    contentType: multerS3.AUTO_CONTENT_TYPE,
  }),
}).fields([
  { name: "profileImage", maxCount: 1 },
  { name: "workImages", maxCount: 20 },
]);

const router = express.Router();

// ✅ Vendor Register Route
router.post(
  "/register",
  upload,
  safeHandler(async (req, res) => {
    const { name, email, password, phone, role, description, location } = req.body;

    // Parse location safely
    let parsedLocation = location;
    if (typeof location === "string") {
      try {
        parsedLocation = JSON.parse(location);
      } catch {
        return res.error(400, "Invalid location format", "VALIDATION_ERROR");
      }
    }

    // Validate fields
    if (
      !name ||
      !email ||
      !password ||
      !phone ||
      !role ||
      !description ||
      !parsedLocation?.lat ||
      !parsedLocation?.lon
    ) {
      return res.error(400, "Missing required fields", "VALIDATION_ERROR");
    }

    // Check for duplicates
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

    const hashedPassword = await bcrypt.hash(password, 10);

    const profileImageUrl = req.files?.profileImage
      ? req.files.profileImage[0].location
      : null;

    const workImagesUrls =
      req.files?.workImages?.map((file) => addHttpsPrefix(file.location)) || [];

    // ✅ Create new vendor
    const newVendor = new Vendor({
      name,
      email,
      phone,
      password: hashedPassword,
      role: role.toLowerCase(),
      description,
      location: {
        lat: parsedLocation.lat.toString(),
        lon: parsedLocation.lon.toString(),
      },
      profileImage: profileImageUrl,
      workImages: workImagesUrls,
    });

    await newVendor.save();

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
        profileImage: newVendor.profileImage,
        workImages: newVendor.workImages,
      },
    });
  })
);

router.post(
  "/login",
  safeHandler(async (req, res) => {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) {
      console.log(parsed.error);
      return res.error(400, "Validation failed", "VALIDATION_ERROR",
    parsed.error.flatten());
    }

    const { email, password, role } = parsed.data;
    if (role === "user") {
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
          image: user.profileImage,
        },
      });
    }

    // 🧑‍🎤 VENDOR LOGIN
    const vendor = await Vendor.findOne({ email });
    if (!vendor) {
      return res.error(401, "Invalid email or password", "INVALID_CREDENTIALS");
    }

    // Check if role matches database
    if (vendor.role !== role.toLowerCase()) {
      return res.error(
        400,
        `Role mismatch. This vendor is registered as '${vendor.role}'.`,
        "ROLE_MISMATCH"
      );
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
        role: vendor.role,
        image: vendor.profileImage,
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
      // const userAccepted = await VendorRequest.findOne({
      //   user: request.user,
      //   role: request.role,
      //   userStatus: "Accepted",
      // });

      // if (userAccepted) {
      //   return res.error(
      //     403,
      //     "User has already accepted another offer. You cannot respond to this request.",
      //     "USER_ALREADY_ACCEPTED"
      //   );
      // }

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

router.get(
  "/:vendorId/profile",
  safeHandler(async (req, res) => {})
);

export default router;
