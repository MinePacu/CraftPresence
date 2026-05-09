import { z } from "zod";

export const userSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  displayName: z.string(),
  role: z.enum(["admin", "user"]),
  createdAt: z.string(),
  updatedAt: z.string()
});
export type User = z.infer<typeof userSchema>;
