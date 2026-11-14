export class ClientError extends Error {
  constructor(readonly code: "invalid_base" | "empty_token" | "http" | "too_large" | "invalid_json" | "invalid_response") {
    super(code);
    this.name = "ClientError";
  }
}

