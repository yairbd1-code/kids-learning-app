import jwt from "jsonwebtoken";

const JWT_SECRET: string = (() => {
  const value = process.env.JWT_SECRET;
  if (!value) {
    throw new Error("Missing JWT_SECRET environment variable");
  }
  return value;
})();

export interface AuthTokenPayload {
  parentId: string;
  familyId: string;
  type: "parent";
}

export function signAuthToken(payload: Omit<AuthTokenPayload, "type">): string {
  return jwt.sign({ ...payload, type: "parent" }, JWT_SECRET, { expiresIn: "30d" });
}

export function verifyAuthToken(token: string): AuthTokenPayload {
  const decoded = jwt.verify(token, JWT_SECRET) as AuthTokenPayload;
  if (decoded.type !== "parent") {
    throw new Error("Not a parent token");
  }
  return decoded;
}

export interface ChildTokenPayload {
  childId: string;
  familyId: string;
  type: "child";
}

export function signChildToken(payload: Omit<ChildTokenPayload, "type">): string {
  return jwt.sign({ ...payload, type: "child" }, JWT_SECRET, { expiresIn: "12h" });
}

export function verifyChildToken(token: string): ChildTokenPayload {
  const decoded = jwt.verify(token, JWT_SECRET) as ChildTokenPayload;
  if (decoded.type !== "child") {
    throw new Error("Not a child token");
  }
  return decoded;
}
