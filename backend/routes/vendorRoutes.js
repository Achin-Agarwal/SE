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
import checkAuth from "../middlewares/auth.js";

dotenv.config();
const s3 = new S3Client({
  endpoint: process.env.DO_SPACES_ENDPOINT,
  region: "blr1",
  credentials: {
    accessKeyId: process.env.DO_SPACES_KEY,
    secretAccessKey: process.env.DO_SPACES_SECRET,
  },
});
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
  { name: "workImages", maxCount: 10000 },
]);

const router = express.Router();

const formatSpacesUrl = (url) => {
  if (!url.startsWith("https://")) {
    return url.replace(
      /^blr1\.digitaloceanspaces\.com\/achin-se/,
      "https://achin-se.blr1.digitaloceanspaces.com"
    );
  }
  return url;
};
router.post(
  "/register",
  upload,
  safeHandler(async (req, res) => {
    try {
      let parsedBody = req.body;
      console.log("FIELDS:", req.body);
      console.log("FILES:", req.files);
      if (typeof parsedBody.location === "string") {
        try {
          parsedBody.location = JSON.parse(parsedBody.location);
        } catch {
          return res.error(400, "Invalid location format", "VALIDATION_ERROR");
        }
      }
      const parsedData = vendorRegisterSchema.parse(parsedBody);
      const { name, email, password, phone, role, description, location } =
        parsedData;
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
      let profileImageUrl = null;
      console.log(req.files?.profileImage);
      if (req.files?.profileImage) {
        profileImageUrl = req.files.profileImage[0].location;
        if (
          profileImageUrl &&
          !profileImageUrl.startsWith("http://") &&
          !profileImageUrl.startsWith("https://")
        ) {
          profileImageUrl = `https://${profileImageUrl}`;
        }
      }
      const workImagesUrls =
        req.files?.workImages?.map((file) => formatSpacesUrl(file.location)) ||
        [];
      const newVendor = new Vendor({
        name,
        email,
        phone,
        password: hashedPassword,
        role: role.toLowerCase(),
        description,
        location: {
          lat: location.lat.toString(),
          lon: location.lon.toString(),
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
    } catch (err) {
      if (err.name === "ZodError") {
        return res.error(400, err.errors[0]?.message, "VALIDATION_ERROR");
      }
      throw err;
    }
  })
);

router.post(
  "/login",
  safeHandler(async (req, res) => {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) {
      console.log(parsed.error);
      return res.error(
        400,
        "Validation failed",
        "VALIDATION_ERROR",
        parsed.error.flatten()
      );
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
    const vendor = await Vendor.findOne({ email });
    if (!vendor) {
      return res.error(401, "Invalid email or password", "INVALID_CREDENTIALS");
    }
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

router.get(
  "/:vendorId/requests",
  checkAuth("vendor"),
  safeHandler(async (req, res) => {
    const vendorId = req.params.vendorId;
    if (req.user.role === "vendor" && req.user.id !== vendorId) {
      return res.status(403).json({ error: "Access denied" });
    }
    const requests = await VendorRequest.find({ vendor: req.params.vendorId })
      .populate("user", "name email phone")
      .lean();
    res.json(requests);
  })
);

router.post(
  "/respond",
  checkAuth("vendor"),
  safeHandler(async (req, res) => {
    try {
      const { requestId, action, budget, additionalDetails } = req.body;
      if (!requestId || !action) {
        return res.error(400, "Missing requestId or action", "MISSING_FIELDS");
      }
      const request = await VendorRequest.findById(requestId);
      if (!request) {
        return res.error(404, "Request not found", "REQUEST_NOT_FOUND");
      }
      if (
        req.user.role === "vendor" &&
        req.user.id !== request.vendor.toString()
      ) {
        return res.error(
          403,
          "You are not authorized to respond to this request",
          "UNAUTHORIZED_VENDOR"
        );
      }
      if (action === "reject") {
        await Promise.all([
          User.updateOne(
            {
              _id: request.user,
              "projects._id": request.project,
            },
            {
              $pull: {
                "projects.$.sentRequests": { vendor: request._id },
              },
            }
          ),
          Vendor.findByIdAndUpdate(request.vendor, {
            $pull: { receivedRequests: request._id },
          }),
        ]);
        await VendorRequest.findByIdAndDelete(requestId);
        return res.success(200, "Request rejected and removed successfully");
      }
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
