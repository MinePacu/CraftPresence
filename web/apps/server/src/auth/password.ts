import { hash, verify } from "@node-rs/argon2";

export async function hashPassword(password: string) {
  return hash(password, { algorithm: 2 });
}

export async function verifyPassword(passwordHash: string, password: string) {
  return verify(passwordHash, password);
}
