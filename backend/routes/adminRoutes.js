import express from "express";
import bcrypt from "bcrypt";
import { adminRegisterSchema, loginSchema } from "../validators/auth-validators.js";
import { safeHandler } from "../middlewares/safeHandler.js";
import { generateToken } from "../utils/jwtFunct.js";
import Admin from "../models/Admin.js";

const router = express.Router();
router.post(
  "/register",
  safeHandler(async (req, res) => {
    const parsed = adminRegisterSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.error(
        400,
        "Validation failed",
        "VALIDATION_ERROR"
      );
    }

    const { username, email, password } = parsed.data;

    const existingAdmin = await Admin.findOne({ email });
    if (existingAdmin) {
      return res.error(409, "Admin already exists", "ADMIN_EXISTS");
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const newAdmin = new Admin({ username, email, password: hashedPassword, role: "admin" });
    await newAdmin.save();

    const token = generateToken({ id: newAdmin._id, role: "admin" });

    return res.success(201, "Admin registered successfully", {
      token,
      admin: {
        id: newAdmin._id,
        username: newAdmin.username,
      },
    });
  })
);

router.post(
  "/login",
  safeHandler(async (req, res) => {
    const parsed = loginSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.error(
        400,
        "Validation failed",
        "VALIDATION_ERROR"
      );
    }

    const { email, password } = parsed.data;

    const admin = await Admin.findOne({ email });
    if (!admin) {
      return res.error(401, "Invalid email or password", "INVALID_CREDENTIALS");
    }

    const isPasswordValid = await bcrypt.compare(password, admin.password);
    if (!isPasswordValid) {
      return res.error(401, "Invalid email or password", "INVALID_CREDENTIALS");
    }

    const token = generateToken({ id: admin._id, role: "admin" });

    return res.success(200, "Login successful", {
      token,
      admin: {
        id: admin._id,
        username: admin.username,
      },
    });
  })
);

export default router;
