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








router.get("/accepted-roles/:userId/:projectId", async (req, res) => {
  try {
    const { userId, projectId } = req.params;

    const requests = await VendorRequest.find({
      user: userId,
      project: projectId,
      vendorStatus: "Accepted",
      userStatus: "Accepted",
    }).select("role -_id");

    const roles = requests.map((req) => req.role);

    res.status(200).json({ roles });
  } catch (error) {
    res.status(500).json({ error: "Server Error" });
  }
});


router.get(
  "/vendors/:role",
  safeHandler(async (req, res) => {
    try {
      const { lat, lon, userId, projectId } = req.query;
      if (!lat || !lon || !userId || !projectId) {
        return res.status(400).json({
          error: "Latitude, longitude, userId & projectId required"
        });
      }
      const userLat = parseFloat(lat);
      const userLon = parseFloat(lon);
      const radiusInKm = 10;
      const vendors = await Vendor.find({
        role: { $regex: new RegExp(`^${req.params.role}$`, "i") }
      });
      const previousRequests = await VendorRequest.find({
        user: userId,
        project: projectId,
        role: req.params.role,
      }).select("vendor");
      const requestedVendorIds = previousRequests.map(
        (req) => req.vendor.toString()
      );
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
          parseFloat(vendor.location.lat),
          parseFloat(vendor.location.lon)
        );
        return distance <= radiusInKm;
      });
      const filteredVendors = nearbyVendors.filter(
        (v) => !requestedVendorIds.includes(v._id.toString())
      );
      res.json(filteredVendors);
    } catch (err) {
      console.error(err);
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
      const requests = await Promise.all(
        vendors.map(async (vendorId) => {
          const formattedLocation = {
            type: "Point",
            coordinates: [
              location.longitude,
              location.latitude,
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
      if (!userId || !projectId) {
        return res.status(400).json({
          status: "error",
          message: "userId and projectId are required",
        });
      }

      // Verify user exists
      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          status: "error",
          message: "User not found",
        });
      }

      // Verify project exists for user
      const project = user.projects.id(projectId);
      if (!project) {
        return res.status(404).json({
          status: "error",
          message: "Project not found for this user",
        });
      }

      // ✅ Fetch vendor requests that are NOT fully accepted
      const ongoingRequests = await VendorRequest.find({
        user: userId,
        project: projectId,
        $or: [
          { vendorStatus: { $ne: "Accepted" } },
          { userStatus: { $ne: "Accepted" } },
        ],
      }).select("role");

      // ✅ Extract unique roles
      const roles = ongoingRequests.map((r) => r.role);
      const uniqueRoles = [...new Set(roles)];

      return res.status(200).json({
        status: "success",
        message: "Ongoing roles fetched successfully",
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

router.post(
  "/projectroles/accepted",
  safeHandler(async (req, res) => {
    try {
      const { userId, projectId } = req.body;
      if (!userId || !projectId) {
        return res.status(400).json({
          status: "error",
          message: "userId and projectId are required",
        });
      }

      // Ensure user exists
      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          status: "error",
          message: "User not found",
        });
      }

      // Ensure project exists for this user
      const project = user.projects.id(projectId);
      if (!project) {
        return res.status(404).json({
          status: "error",
          message: "Project not found for this user",
        });
      }

      // ✅ Find all accepted vendor requests for this project
      const acceptedRequests = await VendorRequest.find({
        user: userId,
        project: projectId,
        userStatus: "Accepted",
        vendorStatus: "Accepted",
      }).select("role");

      // ✅ Extract unique roles that are booked
      const roles = acceptedRequests.map((r) => r.role);
      const uniqueRoles = [...new Set(roles)];

      return res.status(200).json({
        status: "success",
        message: "Accepted roles fetched successfully",
        projectName: project.name,
        totalRoles: uniqueRoles.length,
        roles: uniqueRoles,
      });
    } catch (err) {
      console.error("Error in /projectroles/accepted:", err);
      return res.status(500).json({
        status: "error",
        message: "Failed to fetch accepted roles",
        error: err.message,
      });
    }
  })
);

router.get(
  "/:userId/requests/:projectId",
  safeHandler(async (req, res) => {
    const { userId, projectId } = req.params;

    const requests = await VendorRequest.find({
      user: userId,
      project: projectId,
      userStatus: { $ne: "Accepted" },
      vendorStatus: { $ne: "Accepted" },
    })
      .populate("vendor", "name role rating description email phone")
      .select(
        "_id user vendor role location description eventDate vendorStatus userStatus createdAt updatedAt additionalDetails budget"
      )
      .lean();

    res.json(requests);
  })
);

router.get(
  "/:userId/accepted/:projectId",
  safeHandler(async (req, res) => {
    const { userId, projectId } = req.params;

    const acceptedRequests = await VendorRequest.find({
      user: userId,
      project: projectId,
      userStatus: "Accepted",
      vendorStatus: "Accepted",
    })
      .populate("vendor", "name role rating description email phone")
      .select(
        "_id user vendor role location description eventDate vendorStatus userStatus createdAt updatedAt additionalDetails budget"
      )
      .lean();

    res.json(acceptedRequests);
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
      if (accept) {
        const acceptedReq = await VendorRequest.findByIdAndUpdate(
          requestObjectId,
          { userStatus: "Accepted" },
          { new: true }
        );

        if (!acceptedReq) {
          return res.error(404, "Request not found", "REQUEST_NOT_FOUND");
        }
        return res.success(200, "Offer accepted successfully", {
          acceptedRequest: acceptedReq,
        });
      }
      else {
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

router.post(
  "/:role/:projectId",
  safeHandler(async (req, res) => {
    try {
      const { role, projectId } = req.params;
      if (!role || !projectId) {
        return res.error(400, "Missing role or projectId", "MISSING_FIELDS");
      }
      const roleLower = role.toLowerCase();
      const deletedRequests = await VendorRequest.find({
        project: projectId,
        role: { $regex: new RegExp(`^${roleLower}$`, "i") },
        userStatus: { $ne: "Accepted" },
      });

      if (!deletedRequests.length) {
        return res.success(200, "No pending requests to delete", {
          deletedCount: 0,
        });
      }

      await Promise.all(
        deletedRequests.map(async (reqDoc) => {
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

      const result = await VendorRequest.deleteMany({
        project: projectId,
        role: { $regex: new RegExp(`^${roleLower}$`, "i") },
        userStatus: { $ne: "Accepted" },
      });

      return res.success(200, "Deleted all unaccepted requests successfully", {
        deletedCount: result.deletedCount,
      });
    } catch (err) {
      console.error("Delete unaccepted requests error:", err);
      return res.error(
        500,
        "Failed to delete unaccepted requests",
        "DELETE_UNACCEPTED_REQUESTS_ERROR",
        { details: err.message }
      );
    }
  })
);

router.get("/vendorrequest/:id/progress", async (req, res) => {
  try {
    const request = await VendorRequest.findById(req.params.id).lean();
    if (!request) {
      return res.status(404).json({ message: "Vendor request not found" });
    }
    res.json(request.progress || []);
  } catch (err) {
    console.error("Error fetching progress:", err);
    res.status(500).json({ message: "Error fetching progress" });
  }
});

router.put("/vendorrequest/:id/progress", async (req, res) => {
  try {
    const { text, done } = req.body;
    const request = await VendorRequest.findById(req.params.id);
    if (!request) {
      return res.status(404).json({ message: "Vendor request not found" });
    }

    const step = request.progress.find((p) => p.text === text);
    if (step) step.done = done;

    await request.save();

    res.json({
      message: "Progress updated successfully",
      progress: request.progress,
    });
  } catch (err) {
    console.error("Error updating progress:", err);
    res.status(500).json({ message: "Error updating progress" });
  }
});

router.put("/vendorrequest/:id/review", async (req, res) => {
  try {
    const { userId, message, rating } = req.body;

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ message: "Rating must be between 1 and 5" });
    }

    const vendor = await Vendor.findById(req.params.id);
    if (!vendor) {
      return res.status(404).json({ message: "Vendor not found" });
    }
    vendor.ratingMessages.push({
      userId,
      message,
      rating,
    });
    const totalRatings = vendor.ratingMessages.reduce((sum, r) => sum + r.rating, 0);
    const averageRating = totalRatings / vendor.ratingMessages.length;
    vendor.rating = averageRating.toFixed(1);

    await vendor.save();

    res.json({
      message: "Review added successfully",
      vendor: {
        _id: vendor._id,
        name: vendor.name,
        rating: vendor.rating,
        ratingMessages: vendor.ratingMessages,
      },
    });
  } catch (err) {
    console.error("Error adding review:", err);
    res.status(500).json({ message: "Error adding review" });
  }
});

export default router;
