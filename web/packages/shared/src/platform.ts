import { z } from "zod";

export const platformSchema = z.enum(["macOS", "iOS", "Android", "Windows", "Linux"]);
export type Platform = z.infer<typeof platformSchema>;
