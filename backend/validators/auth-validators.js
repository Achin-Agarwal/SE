import { z } from "zod";

export const adminRegisterSchema = z.object({
  username: z
    .string({ message: "Name is required." })
    .trim()
    .min(3, { message: "Name must be at least 3 characters long." })
    .max(50, { message: "Name must not exceed 50 characters." }),
  email: z
    .string({ message: "Email is required." })
    .trim()
    .email({ message: "Please enter a valid email address." })
    .max(50, { message: "Email must not exceed 50 characters." }),
  password: z
    .string({ message: "Password is required." })
    .min(6, { message: "Password must be at least 6 characters long." })
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+{}|:;<>,.?/~\-=\[\]])[A-Za-z\d!@#$%^&*()_+{}|:;<>,.?/~\-=\[\]]{6,}$/,
      {
        message:
          "Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character.",
      }
    ),
});

export const userRegisterSchema = z.object({
  name: z
    .string({ message: "Name is required." })
    .trim()
    .min(3, { message: "Name must be at least 3 characters long." })
    .max(50, { message: "Name must not exceed 50 characters." }),

  email: z
    .string({ message: "Email is required." })
    .trim()
    .email({ message: "Please enter a valid email address." })
    .max(50, { message: "Email must not exceed 50 characters." }),

  password: z
    .string({ message: "Password is required." })
    .min(6, { message: "Password must be at least 6 characters long." })
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+{}|:;<>,.?/~\-=\[\]])[A-Za-z\d!@#$%^&*()_+{}|:;<>,.?/~\-=\[\]]{6,}$/,
      {
        message:
          "Password must contain at least one uppercase, one lowercase, one number, and one special character.",
      }
    ),

  phone: z
    .string({ message: "Phone number is required." })
    .trim()
    .min(10, { message: "Phone number must be at least 10 digits long." })
    .max(15, { message: "Phone number must not exceed 15 digits." })
    .regex(/^\+?[0-9]{10,15}$/, {
      message: "Please enter a valid phone number.",
    }),
    profileImage: z.any().optional(),
    role: z.literal("user"),
});

export const vendorRegisterSchema = z.object({
  name: z
    .string({ message: "Name is required." })
    .trim()
    .min(3, { message: "Name must be at least 3 characters long." })
    .max(50, { message: "Name must not exceed 50 characters." }),

  email: z
    .string({ message: "Email is required." })
    .trim()
    .email({ message: "Please enter a valid email address." })
    .max(50, { message: "Email must not exceed 50 characters." }),

  password: z
    .string({ message: "Password is required." })
    .min(6, { message: "Password must be at least 6 characters long." })
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+{}|:;<>,.?/~\-=\[\]])[A-Za-z\d!@#$%^&*()_+{}|:;<>,.?/~\-=\[\]]{6,}$/,
      {
        message:
          "Password must contain uppercase, lowercase, number, and special character.",
      }
    ),

  phone: z
    .string({ message: "Phone number is required." })
    .trim()
    .min(10, { message: "Phone number must be at least 10 digits long." })
    .max(15, { message: "Phone number must not exceed 15 digits." })
    .regex(/^\+?[0-9]{10,15}$/, {
      message: "Please enter a valid phone number.",
    }),

  role: z.enum(
    ["photographer", "caterer", "decorator", "dj"],
    {
      message: "Please select a valid vendor role.",
    }
  ),

  description: z
    .string({ message: "Description is required." })
    .trim()
    .min(10, { message: "Description must be at least 10 characters long." })
    .max(500, { message: "Description must not exceed 500 characters." }),

  location: z.object({
    lat: z
      .string({ message: "Latitude is required." })
      .trim()
      .min(3, { message: "Invalid latitude format." }),
    lon: z
      .string({ message: "Longitude is required." })
      .trim()
      .min(3, { message: "Invalid longitude format." }),
  }),

  profileImage: z.any().optional(),
  workImages: z.any().optional(),
});


export const loginSchema = z.object({
  email: z
    .string({ message: "Email is required." })
    .trim()
    .email({ message: "Please enter a valid email address." })
    .max(50, { message: "Email must not exceed 50 characters." }),
  password: z
    .string({ message: "Password is required." })
    .min(6, { message: "Password must be at least 6 characters long." })
    .regex(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+{}|:;<>,.?/~\-=\[\]])[A-Za-z\d!@#$%^&*()_+{}|:;<>,.?/~\-=\[\]]{6,}$/,
      {
        message:
          "Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character.",
      }
    ),
  role: z.enum(
    [
      "user",
      "photographer",
      "caterer",
      "decorator",
      "musician",
      "dj",
      "performer",
    ],
    { message: "Role must be valid." }
  ),
});
