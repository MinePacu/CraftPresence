export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(path, {
    ...init,
    credentials: "include",
    headers: init.body instanceof FormData ? init.headers : { "Content-Type": "application/json", ...init.headers }
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) throw new ApiError(response.status, data?.message ?? "Request failed");
  return data as T;
}

export function jsonBody(value: unknown): RequestInit {
  return { body: JSON.stringify(value) };
}
