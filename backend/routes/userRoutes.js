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
import { S3Client } from "@aws-sdk/client-s3";
import multer from "multer";
import multerS3 from "multer-s3";
import dotenv from "dotenv";

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
      cb(null, `users/${Date.now()}-${file.originalname}`);
    },
    contentType: multerS3.AUTO_CONTENT_TYPE,
  }),
}).fields([{ name: "profileImage", maxCount: 1 }]);

const router = express.Router();
router.post(
  "/register",
  upload,
  safeHandler(async (req, res) => {
    const { name, email, password, phone, role } = req.body;

    if (!name || !email || !password || !phone || !role) {
      return res.error(400, "Missing required fields", "VALIDATION_ERROR");
    }

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

    const hashedPassword = await bcrypt.hash(password, 10);

    const profileImageUrl = req.files?.profileImage
      ? req.files.profileImage[0].location
      : null;

    const newUser = new User({
      name,
      email,
      phone,
      password: hashedPassword,
      role: role.toLowerCase(),
      profileImage: profileImageUrl,
    });

    await newUser.save();

    const token = generateToken({ id: newUser._id, role: "user" });

    return res.success(201, "User registered successfully", {
      token,
      user: {
        id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        phone: newUser.phone,
        role: newUser.role,
        profileImage: newUser.profileImage,
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
        image: user.profileImage,
      },
    });
  })
);

router.get(
  "/project/:userId",
  safeHandler(async (req, res) => {
    const user = await User.findById(req.params.userId).populate({
      path: "projects.sentRequests.vendor",
      model: "VendorRequest",
    });

    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }
    res.json(user.projects);
  })
);

router.post(
  "/project/:userId",
  safeHandler(async (req, res) => {
    const { name } = req.body;
    if (!name) {
      return res.status(400).json({ error: "Project name is required" });
    }
    const user = await User.findById(req.params.userId);
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }
    user.projects.push({ name, sentRequests: [] });
    await user.save();
    res
      .status(201)
      .json({
        message: "Project created successfully",
        project: user.projects[user.projects.length - 1],
      });
  })
);

router.get(
  "/vendors/:role",
  safeHandler(async (req, res) => {
    try {
      const { lat, lon } = req.query;

      if (!lat || !lon) {
        return res
          .status(400)
          .json({ error: "Latitude and longitude required" });
      }

      const userLat = parseFloat(lat);
      const userLon = parseFloat(lon);
      const radiusInKm = 10;

      const vendors = await Vendor.find({
        role: { $regex: new RegExp(`^${req.params.role}$`, "i") },
      });

      function getDistance(lat1, lon1, lat2, lon2) {
        const R = 6371;
        const dLat = ((lat2 - lat1) * Math.PI) / 180;
        const dLon = ((lon2 - lon1) * Math.PI) / 180;
        const a =
          Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos((lat1 * Math.PI) / 180) *
            Math.cos((lat2 * Math.PI) / 180) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
      }

      const nearbyVendors = vendors.filter((vendor) => {
        if (!vendor.location) return false;
        const distance = getDistance(
          userLat,
          userLon,
          vendor.location.lat,
          vendor.location.lon
        );
        console.log(`Vendor ${vendor._id} is ${distance.toFixed(2)} km away`);
        return distance <= radiusInKm;
      });

      res.json(nearbyVendors);
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
      const {
        projectId,
        userId,
        vendors,
        role,
        location,
        description,
        startDateTime,
        endDateTime,
      } = req.body;

      // 🧩 Basic validation
      if (!userId || !projectId) {
        return res.status(400).json({
          status: "error",
          message: "userId and projectId are required",
        });
      }

      if (!Array.isArray(vendors) || vendors.length === 0) {
        return res.status(400).json({
          status: "error",
          message: "vendors (array of IDs) is required",
        });
      }

      if (!startDateTime || !endDateTime) {
        return res.status(400).json({
          status: "error",
          message: "Both startDateTime and endDateTime are required",
        });
      }

      const start = new Date(startDateTime);
      const end = new Date(endDateTime);

      if (end <= start) {
        return res.status(400).json({
          status: "error",
          message: "endDateTime must be after startDateTime",
        });
      }

      // 🧩 Ensure user and project exist
      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          status: "error",
          message: "User not found",
        });
      }

      const project = user.projects.id(projectId);
      if (!project) {
        return res.status(404).json({
          status: "error",
          message: "Project not found for this user",
        });
      }

      // 🧩 Create requests for each vendor
      const requests = await Promise.all(
        vendors.map(async (vendorId) => {
          const formattedLocation = {
            type: "Point",
            coordinates: [
              location.longitude, // longitude first
              location.latitude, // latitude second
            ],
          };

          const request = await VendorRequest.create({
            user: userId,
            vendor: vendorId,
            role,
            location: formattedLocation,
            description,
            startDateTime: start,
            endDateTime: end,
            project: projectId,
          });

          await Vendor.findByIdAndUpdate(vendorId, {
            $push: { receivedRequests: request._id },
          });

          project.sentRequests.push({
            vendor: request._id,
            role: role,
          });

          return request;
        })
      );

      // 🧩 Save user with updated project data
      await user.save();

      return res.status(201).json({
        status: "success",
        message: "Requests sent successfully",
        data: requests,
      });
    } catch (err) {
      console.error("Error in /sendrequests:", err);
      return res.status(500).json({
        status: "error",
        message: "Failed to send vendor requests",
        error: err.message,
      });
    }
  })
);

router.post(
  "/projectroles",
  safeHandler(async (req, res) => {
    try {
      const { userId, projectId } = req.body;

      // 🧩 Validate input
      if (!userId || !projectId) {
        return res.status(400).json({
          status: "error",
          message: "userId and projectId are required",
        });
      }

      // 🧩 Find the user
      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          status: "error",
          message: "User not found",
        });
      }

      // 🧩 Find the project inside user's projects array
      const project = user.projects.id(projectId);
      if (!project) {
        return res.status(404).json({
          status: "error",
          message: "Project not found for this user",
        });
      }

      // 🧩 Extract all roles from sentRequests inside that project
      const roles = project.sentRequests.map((r) => r.role);

      // 🧩 Remove duplicates (optional)
      const uniqueRoles = [...new Set(roles)];

      return res.status(200).json({
        status: "success",
        message: "Roles fetched successfully",
        projectName: project.name,
        totalRoles: uniqueRoles.length,
        roles: uniqueRoles,
      });
    } catch (err) {
      console.error("Error in /projectroles:", err);
      return res.status(500).json({
        status: "error",
        message: "Failed to fetch project roles",
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
        const acceptedReq = await VendorRequest.findByIdAndUpdate(
          requestObjectId,
          { userStatus: "Accepted" },
          { new: true }
        );

        if (!acceptedReq) {
          return res.error(404, "Request not found", "REQUEST_NOT_FOUND");
        }

        const otherRequests = await VendorRequest.find({
          user: userId,
          role: { $regex: new RegExp(`^${roleLower}$`, "i") },
          _id: { $ne: requestObjectId },
        });

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

        const deleted = await VendorRequest.deleteMany({
          user: userId,
          role: { $regex: new RegExp(`^${roleLower}$`, "i") },
          _id: { $ne: requestObjectId },
        });

        return res.success(200, "Offer accepted successfully", {
          acceptedRequest: acceptedReq,
          deletedRequestsCount: deleted.deletedCount,
        });
      } else {
        const reqToDelete = await VendorRequest.findById(requestObjectId);

        if (!reqToDelete) {
          return res.error(404, "Request not found", "REQUEST_NOT_FOUND");
        }

        await Promise.all([
          User.findByIdAndUpdate(reqToDelete.user, {
            $pull: { sentRequests: reqToDelete._id },
          }),
          Vendor.findByIdAndUpdate(reqToDelete.vendor, {
            $pull: { receivedRequests: reqToDelete._id },
          }),
        ]);

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
