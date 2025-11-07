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
    try {
      const parsedData = userRegisterSchema.parse(req.body);
      const { name, email, password, phone, role } = parsedData;

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
      let profileImageUrl = null;
      console.log(req.files?.profileImage)
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
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { userId } = req.params;
    if (req.user.role === "user" && req.user.id !== userId) {
      return res.error(
        403,
        "You are not authorized to view another user's projects",
        "UNAUTHORIZED_ACCESS"
      );
    }
    const user = await User.findById(userId).populate({
      path: "projects.sentRequests.vendorRequest",
      populate: {
        path: "vendor",
        model: "Vendor",
      },
    });

    if (!user) {
      return res.error(404, "User not found", "USER_NOT_FOUND");
    }
    return res.success(
      200,
      "User projects fetched successfully",
      user.projects
    );
  })
);

router.post(
  "/project/:userId",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { name } = req.body;
    if (!name) {
      return res.status(400).json({ error: "Project name is required" });
    }
    if (req.user.role === "user" && req.user.id !== req.params.userId) {
      return res.status(403).json({ error: "Unauthorized access" });
    }
    const user = await User.findById(req.params.userId);
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }
    user.projects.push({ name, sentRequests: [] });
    await user.save();
    res.status(201).json({
      message: "Project created successfully",
      project: user.projects[user.projects.length - 1],
    });
  })
);

router.get(
  "/accepted-roles/:userId/:projectId",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { userId, projectId } = req.params;
    if (req.user.role === "user" && req.user.id !== userId) {
      return res.status(403).json({ error: "Unauthorized access" });
    }
    const requests = await VendorRequest.find({
      user: userId,
      project: projectId,
      vendorStatus: "Accepted",
      userStatus: "Accepted",
    }).select("role -_id");
    const roles = requests.map((r) => r.role);
    res.status(200).json({ roles });
  })
);

router.get(
  "/vendors/:role",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { lat, lon, userId, projectId } = req.query;
    if (req.user.role === "user" && req.user.id !== userId) {
      return res.error(403, "Unauthorized access", "UNAUTHORIZED_ACCESS");
    }
    if (!lat || !lon || !userId || !projectId) {
      return res.error(
        400,
        "Latitude, longitude, userId & projectId required",
        "MISSING_FIELDS"
      );
    }
    const userLat = parseFloat(lat);
    const userLon = parseFloat(lon);
    const radiusInKm = 10;
    const vendors = await Vendor.find({
      role: { $regex: new RegExp(`^${req.params.role}$`, "i") },
    });
    const previousRequests = await VendorRequest.find({
      user: userId,
      project: projectId,
      role: req.params.role,
    }).select("vendor");
    const requestedVendorIds = previousRequests.map((req) =>
      req.vendor.toString()
    );
    const getDistance = (lat1, lon1, lat2, lon2) => {
      const R = 6371;
      const dLat = ((lat2 - lat1) * Math.PI) / 180;
      const dLon = ((lon2 - lon1) * Math.PI) / 180;
      const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos((lat1 * Math.PI) / 180) *
          Math.cos((lat2 * Math.PI) / 180) *
          Math.sin(dLon / 2) ** 2;
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      return R * c;
    };
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
    return res.success(
      200,
      "Nearby vendors fetched successfully",
      filteredVendors
    );
  })
);

router.post(
  "/sendrequests",
  checkAuth("user"),
  safeHandler(async (req, res) => {
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
      return res.error(
        400,
        "userId and projectId are required",
        "MISSING_FIELDS"
      );
    }
    if (req.user.role === "user" && req.user.id !== userId) {
      return res.error(403, "Unauthorized access", "UNAUTHORIZED_ACCESS");
    }
    if (!Array.isArray(vendors) || vendors.length === 0) {
      return res.error(
        400,
        "vendors (array of IDs) is required",
        "INVALID_VENDORS"
      );
    }
    if (!startDateTime || !endDateTime) {
      return res.error(
        400,
        "Both startDateTime and endDateTime are required",
        "INVALID_DATES"
      );
    }
    const start = new Date(startDateTime);
    const end = new Date(endDateTime);
    if (end <= start) {
      return res.error(
        400,
        "endDateTime must be after startDateTime",
        "INVALID_DATE_ORDER"
      );
    }
    const user = await User.findById(userId);
    if (!user) return res.error(404, "User not found", "USER_NOT_FOUND");
    const project = user.projects.id(projectId);
    if (!project)
      return res.error(404, "Project not found", "PROJECT_NOT_FOUND");
    const requests = await Promise.all(
      vendors.map(async (vendorId) => {
        const formattedLocation = {
          type: "Point",
          coordinates: [location.longitude, location.latitude],
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
    return res.success(201, "Requests sent successfully", requests);
  })
);

router.post(
  "/projectroles",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { userId, projectId } = req.body;
    if (req.user.role === "user" && req.user.id !== userId) {
      return res.error(403, "Unauthorized access", "UNAUTHORIZED_ACCESS");
    }
    if (!userId || !projectId) {
      return res.error(
        400,
        "userId and projectId are required",
        "MISSING_FIELDS"
      );
    }
    const user = await User.findById(userId);
    if (!user) return res.error(404, "User not found", "USER_NOT_FOUND");
    const project = user.projects.id(projectId);
    if (!project)
      return res.error(404, "Project not found", "PROJECT_NOT_FOUND");
    const ongoingRequests = await VendorRequest.find({
      user: userId,
      project: projectId,
      $or: [
        { vendorStatus: { $ne: "Accepted" } },
        { userStatus: { $ne: "Accepted" } },
      ],
    }).select("role");
    const uniqueRoles = [...new Set(ongoingRequests.map((r) => r.role))];
    return res.success(200, "Ongoing roles fetched successfully", {
      projectName: project.name,
      totalRoles: uniqueRoles.length,
      roles: uniqueRoles,
    });
  })
);

router.post(
  "/projectroles/accepted",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { userId, projectId } = req.body;
    if (req.user.role === "user" && req.user.id !== userId) {
      return res.error(403, "Unauthorized access", "UNAUTHORIZED_ACCESS");
    }
    if (!userId || !projectId) {
      return res.error(
        400,
        "userId and projectId are required",
        "MISSING_FIELDS"
      );
    }
    const user = await User.findById(userId);
    if (!user) return res.error(404, "User not found", "USER_NOT_FOUND");
    const project = user.projects.id(projectId);
    if (!project)
      return res.error(404, "Project not found", "PROJECT_NOT_FOUND");
    const acceptedRequests = await VendorRequest.find({
      user: userId,
      project: projectId,
      userStatus: "Accepted",
      vendorStatus: "Accepted",
    }).select("role");
    const uniqueRoles = [...new Set(acceptedRequests.map((r) => r.role))];
    return res.success(200, "Accepted roles fetched successfully", {
      projectName: project.name,
      totalRoles: uniqueRoles.length,
      roles: uniqueRoles,
    });
  })
);

router.get(
  "/:userId/requests/:projectId",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { userId, projectId } = req.params;
    if (req.user.role === "user" && req.user.id !== userId) {
      return res.status(403).json({ error: "Unauthorized access" });
    }
    const requests = await VendorRequest.find({
      user: userId,
      project: projectId,
      userStatus: { $ne: "Accepted" },
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
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { userId, projectId } = req.params;
    if (req.user.role === "user" && req.user.id !== userId) {
      return res.status(403).json({ error: "Unauthorized access" });
    }
    const user = await User.findById(userId).lean();
    if (!user) return res.status(404).json({ message: "User not found" });
    const project = user.projects.find(
      (p) => p._id.toString() === projectId.toString()
    );
    if (!project)
      return res
        .status(404)
        .json({ message: "Project not found for this user" });
    const requests = await VendorRequest.find({
      user: userId,
      project: projectId,
      userStatus: "Accepted",
      vendorStatus: "Accepted",
    })
      .populate("vendor", "name role rating description email phone")
      .lean();
    res.json({
      project: {
        _id: project._id,
        name: project.name,
      },
      requests: requests,
    });
  })
);

router.post(
  "/acceptoffer",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { requestId, userId, role, accept } = req.body;
    if (req.user.role === "user" && req.user.id !== userId) {
      return res.status(403).json({ error: "Unauthorized access" });
    }
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
    } else {
      const reqToDelete = await VendorRequest.findById(requestObjectId);
      if (!reqToDelete) {
        return res.error(404, "Request not found", "REQUEST_NOT_FOUND");
      }
      await Promise.all([
        User.updateOne(
          { _id: reqToDelete.user, "projects._id": reqToDelete.project },
          { $pull: { "projects.$.sentRequests": { vendor: reqToDelete._id } } }
        ),
        Vendor.findByIdAndUpdate(reqToDelete.vendor, {
          $pull: { receivedRequests: reqToDelete._id },
        }),
      ]);
      await VendorRequest.findByIdAndDelete(requestObjectId);
      return res.success(200, "Offer rejected and deleted successfully", {
        deletedRequest: requestId,
      });
    }
  })
);

router.post(
  "/:role/:projectId",
  checkAuth("user"),
  safeHandler(async (req, res) => {
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
  })
);

router.get(
  "/vendorrequest/:id/progress",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const request = await VendorRequest.findById(req.params.id).lean();
    if (!request) {
      return res.status(404).json({ message: "Vendor request not found" });
    }
    res.json(request.progress || []);
  })
);

router.put(
  "/vendorrequest/:id/progress",
  checkAuth("vendor"),
  safeHandler(async (req, res) => {
    const { text, done } = req.body;
    const request = await VendorRequest.findById(req.params.id);
    if (!request) {
      return res.status(404).json({ message: "Vendor request not found" });
    }
    if (
      req.user.role === "vendor" &&
      req.user.id !== request.vendor.toString()
    ) {
      return res.status(403).json({ error: "Unauthorized access" });
    }
    const step = request.progress.find((p) => p.text === text);
    if (step) step.done = done;
    await request.save();
    res.json({
      message: "Progress updated successfully",
      progress: request.progress,
    });
  })
);

router.put(
  "/vendorrequest/:id/review",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { rating, message } = req.body;
    if (!rating || rating < 1 || rating > 5) {
      return res
        .status(400)
        .json({ message: "Rating must be between 1 and 5" });
    }
    const request = await VendorRequest.findById(req.params.id).populate(
      "vendor"
    );
    if (!request) {
      return res.status(404).json({ message: "Vendor request not found" });
    }
    if (req.user.role === "user" && req.user.id !== request.user.toString()) {
      return res.status(403).json({ error: "Unauthorized access" });
    }
    request.rating = rating;
    request.ratingMessage = message;
    await request.save();
    const vendorRequests = await VendorRequest.find({
      vendor: request.vendor._id,
      rating: { $exists: true },
    });
    const totalRatings = vendorRequests.reduce((sum, r) => sum + r.rating, 0);
    const averageRating = totalRatings / vendorRequests.length;
    request.vendor.rating = averageRating.toFixed(1);
    await request.vendor.save();
    res.json({
      message: "Review added successfully",
      updatedVendorRating: request.vendor.rating,
    });
  })
);

router.get(
  "/vendorrequest/:requestId/reviewstatus",
  checkAuth("user"),
  safeHandler(async (req, res) => {
    const { requestId } = req.params;
    const request = await VendorRequest.findById(requestId);
    if (!request) {
      return res.status(404).json({ error: "Request not found" });
    }
    if (req.user.role === "user" && req.user.id !== request.user.toString()) {
      return res.status(403).json({ error: "Unauthorized access" });
    }
    const reviewSubmitted =
      request.rating !== undefined &&
      request.rating !== null &&
      request.ratingMessage &&
      request.ratingMessage.trim() !== "";
    res.json({ reviewSubmitted });
  })
);

export default router;
