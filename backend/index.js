import express from "express";
import cors from "cors";
import helmet from "helmet";
import hpp from "hpp";
import nocache from "nocache";
import config from "./config/config.js";
import responseHandler from "./middlewares/responseHandler.js";
import connectMongo from "./config/db.js";
import ApiError from "./utils/errorClass.js";
import adminRoutes from "./routes/adminRoutes.js";
import userRoutes from "./routes/userRoutes.js";
import vendorRoutes from "./routes/vendorRoutes.js";
import projectRoutes from "./routes/projectRoutes.js";

const app = express();
app.set('trust proxy', 1);
import rateLimit from "express-rate-limit";

app.use(helmet());
app.use(hpp());
app.use(nocache());

app.use(responseHandler);

app.use((req, res, next) => {
  console.log(req.url, req.method);
  next();
});

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const limiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  limit: 50,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    status: "error",
    message: "Too many requests from this IP. Please try again later.",
  },
});
app.use(limiter);

connectMongo();

app.use((err, req, res, next) => {
  console.error("Error encountered:", err);
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      status: "error",
      errorCode: err.errorCode,
      message: err.message,
      data: err.data,
    });
  }
  res.status(500).send("Something went wrong!");
});

app.use("/admin", adminRoutes,);
app.use("/user", userRoutes);
app.use("/vendor", vendorRoutes);
app.use("/:userId", projectRoutes);

app.listen(config.server.port, () => {
  console.log(`Server running at http://localhost:${config.server.port}`);
});
