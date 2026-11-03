// Prisma 7 configuration. Connection strings come from backend/.env (see .env.example).
//
// DIRECT_URL must be the *direct* or *session pooler* connection (port 5432),
// because migrations need a session. Never the transaction pooler (port 6543).
import "dotenv/config";
import { defineConfig, env } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    url: env("DIRECT_URL"),
  },
});
