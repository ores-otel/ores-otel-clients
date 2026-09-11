import { ClientError } from "./errors";

/** Minimal ambient contract for Node-style deployments without coupling this SDK to @types/node. */
declare const process: {
  readonly env: Record<string, string | undefined>;
};

export interface ClientConfig {
  baseUrl: string;
  bearerToken?: string;
  maxResponseBytes: number;
}

export function configFromEnv(
  env: Record<string, string | undefined> = process.env,
): ClientConfig {
  const baseUrl = env["ORES_OTEL_API_BASE"]?.trim();
  if (!baseUrl) {
    throw new ClientError("invalid_base");
  }
  return {
    baseUrl,
    bearerToken: env["ORES_OTEL_TOKEN"] || undefined,
    maxResponseBytes: 64 * 1024,
  };
}
