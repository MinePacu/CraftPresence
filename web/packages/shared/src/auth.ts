import { z } from "zod";

export const setupInputSchema = z
  .object({
    displayName: z.string().trim().min(1).max(80),
    email: z.string().trim().email().max(160),
    password: z.string().min(8).max(200),
    confirmPassword: z.string().min(8).max(200)
  })
  .refine((value) => value.password === value.confirmPassword, {
    path: ["confirmPassword"],
    message: "Passwords do not match"
  });

export const loginInputSchema = z.object({
  email: z.string().trim().email().max(160),
  password: z.string().min(1).max(200)
});
