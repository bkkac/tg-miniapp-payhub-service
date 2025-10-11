#!/usr/bin/env bash
set -euo pipefail

# ---------- Helpers ----------
RED="$(printf '\033[31m')"; GREEN="$(printf '\033[32m')"; YELLOW="$(printf '\033[33m')"; BLUE="$(printf '\033[34m')"; RESET="$(printf '\033[0m')"
log(){ printf "%b[scaffold]%b %s\n" "$BLUE" "$RESET" "$*"; }
warn(){ printf "%b[warn]%b %s\n" "$YELLOW" "$RESET" "$*"; }
die(){ printf "%b[error]%b %s\n" "$RED" "$RESET" "$*"; exit 1; }

# ---------- Defaults & Args ----------
REPO="tg-miniapp-payhub-service"
SPEC_DEFAULT="./openapi/${REPO}-openapi.bundled.yaml"
LANGUAGE="node-ts"
PM="pnpm"          # pnpm|npm|yarn
PORT="8080"

usage(){ cat <<'USAGE'
Usage:
  ./scaffold.sh [--repo NAME] [--spec PATH] [--language node-ts|go|python] [--pm pnpm|npm|yarn] [--port 8080] [--force]

Examples:
  ./scaffold.sh
  ./scaffold.sh --repo tg-miniapp-payhub-service --spec ./openapi/tg-miniapp-payhub-service-openapi.bundled.yaml --language node-ts --pm pnpm --port 8080
USAGE
}

FORCE="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:?}"; shift 2;;
    --spec) SPEC_DEFAULT="${2:?}"; shift 2;;
    --language) LANGUAGE="${2:?}"; shift 2;;
    --pm) PM="${2:?}"; shift 2;;
    --port) PORT="${2:?}"; shift 2;;
    --force) FORCE="1"; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown arg: $1";;
  esac
done
SPEC="$SPEC_DEFAULT"

# ---------- Preflight ----------
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

need bash
need git
need docker
if command -v docker-compose >/dev/null 2>&1; then :; else need docker; fi
need curl
command -v jq >/dev/null 2>&1 || warn "jq not found – continuing"
command -v yq >/dev/null 2>&1 || warn "yq not found – continuing"

if [[ "$LANGUAGE" == "node-ts" ]]; then
  need node
  # Optional helpers
  if ! command -v corepack >/dev/null 2>&1; then warn "corepack not found – continuing"; fi
fi

[[ -f "$SPEC" ]] || die "OpenAPI bundled spec not found at: $SPEC"

# ---------- Idempotent writers ----------
write_file(){
  # write_file <path> <content>
  local path="$1"; shift
  local content="$*"
  local dir; dir="$(dirname "$path")"
  mkdir -p "$dir"
  if [[ -f "$path" && "$FORCE" != "1" ]]; then
    log "Skip existing: $path"
    return 0
  fi
  printf "%s\n" "$content" > "$path"
  log "Wrote: $path"
}

append_once(){
  local path="$1"; shift
  local content="$*"
  mkdir -p "$(dirname "$path")"
  if [[ -f "$path" ]] && grep -Fqx "$content" "$path"; then
    log "Line already in $path"
  else
    printf "%s\n" "$content" >> "$path"
    log "Appended to: $path"
  fi
}

# ---------- Layout ----------
log "Scaffolding repo: $REPO (language: $LANGUAGE, pm: $PM, port: $PORT)"
mkdir -p openapi sdks scripts migrations \
  src/{middlewares,routes,validators,queues,clients,errors,features/{payments,transactions,webhooks}} \
  tests/{unit,integration}

# Spec copy (idempotent)
if [[ -f "openapi/${REPO}-openapi.bundled.yaml" && "$FORCE" != "1" ]]; then
  log "Spec already present: openapi/${REPO}-openapi.bundled.yaml"
else
  cp -f "$SPEC" "openapi/${REPO}-openapi.bundled.yaml"
  log "Copied spec to openapi/${REPO}-openapi.bundled.yaml"
fi

# ---------- Root meta files ----------
write_file ".editorconfig" "$(cat <<'EOF'
root = true

[*]
charset = utf-8
end_of_line = lf
indent_size = 2
indent_style = space
insert_final_newline = true
trim_trailing_whitespace = true
EOF
)"
write_file ".gitattributes" "*.sh text eol=lf"
write_file ".gitignore" "$(cat <<'EOF'
# Node / TypeScript
node_modules/
dist/
coverage/
.env
.env.*
*.log
.DS_Store
# Docker
*.local.yml
# OpenAPI generated
sdks/
EOF
)"
write_file "LICENSE" "$(cat <<'EOF'
Apache License 2.0
Copyright (c) 2025
EOF
)"
write_file "README.md" "$(cat <<'EOF'
# tg-miniapp-payhub-service

Payment orchestration for Telegram Mini App (charge, refund, ledger, webhooks).  
Source of truth: `openapi/tg-miniapp-payhub-service-openapi.bundled.yaml`.

## Quickstart
```bash
cp .env.example .env
docker compose -f docker-compose.dev.yml up -d
pnpm install
pnpm run codegen
pnpm run dev
open http://localhost:8080/docs
```
EOF
)"

# ---------- Makefile ----------
write_file "Makefile" "$(cat <<'EOF'
PM ?= pnpm
PORT ?= 8080

dev:
	$(PM) run dev

build:
	$(PM) run build

start:
	$(PM) run start

test:
	$(PM) test

lint:
	$(PM) run lint || true
	npx @stoplight/spectral-cli lint openapi/*-openapi.bundled.yaml -r .spectral.yaml || true

codegen:
	$(PM) run codegen

migrate:
	./scripts/migrate.sh

up:
	docker compose -f docker-compose.dev.yml up -d

down:
	docker compose -f docker-compose.dev.yml down -v

docs:
	$(PM) run docs
EOF
)"

# ---------- Docker ----------
write_file "Dockerfile" "$(cat <<'EOF'
# syntax=docker/dockerfile:1.6
FROM node:20-alpine AS base
WORKDIR /app
ENV NODE_ENV=production

FROM base AS deps
COPY package.json pnpm-lock.yaml* package-lock.json* yarn.lock* ./
RUN --mount=type=cache,target=/root/.npm \
    if [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    elif [ -f yarn.lock ]; then corepack enable yarn && yarn install --frozen-lockfile; \
    else npm i; fi

FROM base AS build
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm pkg set scripts.build="tsc -p tsconfig.json" >/dev/null 2>&1 || true
RUN npx tsc -p tsconfig.json

FROM base AS runtime
USER node
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY .env* ./
EXPOSE 8080
CMD ["node","dist/index.js"]
EOF
)"

write_file ".dockerignore" "$(cat <<'EOF'
node_modules
dist
.git
.gitignore
Dockerfile
docker-compose*.yml
openapi/*.yaml
sdks
coverage
EOF
)"

# ---------- docker-compose.dev.yml ----------
write_file "docker-compose.dev.yml" "$(cat <<'EOF'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_USER: postgres
      POSTGRES_DB: tgmini
    ports: ["5432:5432"]
    volumes:
      - pgdata:/var/lib/postgresql/data
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
  mailhog:
    image: mailhog/mailhog
    ports: ["8025:8025","1025:1025"]
volumes:
  pgdata: {}
EOF
)"

# ---------- Spectral rules (minimal) ----------
write_file ".spectral.yaml" "$(cat <<'EOF'
extends: "spectral:recommended"
rules:
  oas3-operation-tags:
    given: "$.paths.*.*"
    then:
      field: tags
      function: truthy
  has-problem-details:
    description: 4xx/5xx must use ProblemDetails
    given: "$.paths.*.*.responses[?(@property.match(/^(4|5)\\d{2}$/))].content.application/problem+json.schema"
    then:
      function: schema
      functionOptions:
        schema:
          $ref: "#/components/schemas/ProblemDetails"
  collection-params:
    description: Collection GETs must have canonical params
    given: "$.paths[?(@property.indexOf('}') == -1)].get.parameters[*].$ref"
    then:
      function: pattern
      functionOptions:
        match: "#/components/parameters/(Limit|Cursor|Since|Sort|Q|Filter)$"
EOF
)"

# ---------- Environment ----------
write_file ".env.example" "$(cat <<'EOF'
# Service
SERVICE_NAME=tg-miniapp-payhub-service
PORT=8080
NODE_ENV=development
LOG_LEVEL=info

# Auth & Security
JWT_PUBLIC_KEY_PATH=./secrets/jwt_pub.pem
JWT_AUDIENCE=tg-miniapp
JWT_ISSUER=https://auth.example.com
HMAC_SECRET=replace-with-hex
X_FUZE_SIGNATURE_HEADER=X-Fuze-Signature

# Datastores
DATABASE_URL=postgres://postgres:postgres@localhost:5432/tgmini?sslmode=disable
REDIS_URL=redis://localhost:6379

# Payments
PAYMENT_PROVIDER=stripe           # stripe|mock|other
CURRENCY_DEFAULT=USD
PAYMENT_CAPTURE_MODE=automatic    # automatic|manual
WEBHOOK_SIGNING_SECRET=replace-me
RETRY_MAX_ATTEMPTS=8
RETRY_BACKOFF_MS=2000

# Observability
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
SENTRY_DSN=
EOF
)"

# ---------- Scripts ----------
write_file "scripts/wait-for.sh" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
host="${1:-localhost}"; port="${2:-5432}"; timeout="${3:-60}"
for i in $(seq 1 "$timeout"); do
  if (echo >/dev/tcp/"$host"/"$port") >/dev/null 2>&1; then exit 0; fi
  sleep 1
done
echo "Timeout waiting for $host:$port"; exit 1
EOF
)"
chmod +x scripts/wait-for.sh

write_file "scripts/migrate.sh" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "[migrate] Placeholder. Implement with Prisma/Knex/TypeORM. Create tables from x-db: payments, transactions, refunds, ledgers."
exit 0
EOF
)"
chmod +x scripts/migrate.sh

write_file "scripts/register-provider-webhooks.sh" "$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Example for Stripe-like providers (replace with real command via provider CLI or HTTP API)
: "${WEBHOOK_SIGNING_SECRET:?Missing WEBHOOK_SIGNING_SECRET}"
echo "[webhooks] Register webhook endpoint with provider (placeholder). Secret: $WEBHOOK_SIGNING_SECRET"
EOF
)"
chmod +x scripts/register-provider-webhooks.sh

# ---------- Node/TS Source ----------
if [[ "$LANGUAGE" == "node-ts" ]]; then
  write_file "package.json" "$(cat <<EOF
{
  "name": "${REPO}",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js",
    "test": "vitest run",
    "lint": "eslint . --ext .ts || true",
    "codegen": "openapi-generator-cli generate -i openapi/${REPO}-openapi.bundled.yaml -g typescript-axios -o sdks/${REPO} --additional-properties=useSingleRequestParameter=true,withSeparateModelsAndApi=true,modelPropertyNaming=original",
    "docs": "node ./scripts/serve-docs.js"
  },
  "dependencies": {
    "bullmq": "^5.6.0",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "express-openapi-validator": "^5.0.6",
    "helmet": "^7.0.0",
    "ioredis": "^5.3.2",
    "pino": "^9.0.0",
    "pino-http": "^9.0.0",
    "swagger-ui-express": "^5.0.0",
    "uuid": "^9.0.1",
    "yamljs": "^0.3.0"
  },
  "devDependencies": {
    "@stoplight/spectral-cli": "^6.11.1",
    "@types/express": "^4.17.21",
    "@types/node": "^20.12.7",
    "@types/supertest": "^2.0.16",
    "@typescript-eslint/eslint-plugin": "^7.8.0",
    "@typescript-eslint/parser": "^7.8.0",
    "eslint": "^9.1.0",
    "openapi-generator-cli": "^2.13.7",
    "supertest": "^7.0.0",
    "tsx": "^4.15.7",
    "typescript": "^5.4.5",
    "vitest": "^1.6.0"
  }
}
EOF
)"
  write_file "tsconfig.json" "$(cat <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "node",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*.ts", "scripts/**/*.ts", "tests/**/*.ts"]
}
EOF
)"
  write_file ".eslintrc.json" "$(cat <<'EOF'
{
  "root": true,
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "extends": ["eslint:recommended", "plugin:@typescript-eslint/recommended"],
  "env": { "node": true, "es2022": true }
}
EOF
)"
  write_file "scripts/serve-docs.js" "$(cat <<'EOF'
#!/usr/bin/env node
import express from "express";
import swaggerUi from "swagger-ui-express";
import YAML from "yamljs";
const spec = YAML.load(`./openapi/tg-miniapp-payhub-service-openapi.bundled.yaml`);
const app = express();
app.use("/docs", swaggerUi.serve, swaggerUi.setup(spec));
app.listen(6060, () => console.log("Docs at http://localhost:6060/docs"));
EOF
)"
  write_file "src/errors/problem-details.ts" "$(cat <<'EOF'
export type ProblemDetails = {
  code: string;
  message: string;
  details?: any;
  traceId: string;
};
export function toProblem(code: string, message: string, details?: any, traceId?: string): ProblemDetails {
  return { code, message, details, traceId: traceId || `req_${Math.random().toString(36).slice(2)}` };
}
EOF
)"
  write_file "src/middlewares/requestId.ts" "$(cat <<'EOF'
import { randomUUID } from "crypto";
import type { Request, Response, NextFunction } from "express";
export function requestId(req: Request, res: Response, next: NextFunction) {
  const incoming = (req.headers["x-request-id"] as string) || randomUUID();
  res.setHeader("X-Request-Id", incoming);
  (req as any).traceId = incoming;
  next();
}
EOF
)"
  write_file "src/middlewares/idempotency.ts" "$(cat <<'EOF'
import type { Request, Response, NextFunction } from "express";
export function requireIdempotency(req: Request, res: Response, next: NextFunction) {
  if (["POST","PATCH","DELETE","PUT"].includes(req.method)) {
    const key = req.header("Idempotency-Key");
    if (!key) {
      return res.status(400).json({ code: "missing_idempotency_key", message: "Idempotency-Key header is required", traceId: (req as any).traceId });
    }
  }
  next();
}
EOF
)"
  write_file "src/middlewares/jwt.ts" "$(cat <<'EOF'
import type { Request, Response, NextFunction } from "express";
export function bearerAuth(req: Request, res: Response, next: NextFunction) {
  const hdr = req.header("authorization") || "";
  if (!hdr.startsWith("Bearer ")) {
    return res.status(401).json({ code: "unauthorized", message: "Missing bearer token", traceId: (req as any).traceId });
  }
  // TODO: validate JWT using JWT_PUBLIC_KEY_PATH, audience, issuer
  next();
}
EOF
)"
  write_file "src/middlewares/errorHandler.ts" "$(cat <<'EOF'
import type { Request, Response, NextFunction } from "express";
import { toProblem } from "../errors/problem-details.js";
export function errorHandler(err: any, req: Request, res: Response, _next: NextFunction) {
  const status = err.status || 500;
  const problem = toProblem(err.code || "internal_error", err.message || "Internal Server Error", err.errors, (req as any).traceId);
  res.status(status).type("application/problem+json").json(problem);
}
EOF
)"
  write_file "src/middlewares/webhookHmac.ts" "$(cat <<'EOF'
import crypto from "crypto";
import type { Request, Response, NextFunction } from "express";
export function verifyHmac(headerName = "X-Fuze-Signature") {
  const secret = process.env.WEBHOOK_SIGNING_SECRET || process.env.HMAC_SECRET || "";
  return (req: Request, res: Response, next: NextFunction) => {
    const sig = req.header(headerName) || "";
    const body = (req as any).rawBody || JSON.stringify(req.body || {});
    const h = crypto.createHmac("sha256", secret).update(body).digest("hex");
    if (!sig || !crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(h))) {
      return res.status(401).json({ code: "invalid_signature", message: "Webhook signature verification failed", traceId: (req as any).traceId });
    }
    next();
  };
}
EOF
)"
  write_file "src/validators/openapi.ts" "$(cat <<'EOF'
import YAML from "yamljs";
import { OpenApiValidator } from "express-openapi-validator";
import type { Express } from "express";
export async function applyOpenApi(app: Express) {
  const spec = YAML.load("./openapi/tg-miniapp-payhub-service-openapi.bundled.yaml");
  await new OpenApiValidator({
    apiSpec: spec,
    validateRequests: true,
    validateResponses: true,
  }).install(app);
}
EOF
)"
  write_file "src/index.ts" "$(cat <<'EOF'
import "dotenv/config";
import express from "express";
import helmet from "helmet";
import cors from "cors";
import swaggerUi from "swagger-ui-express";
import YAML from "yamljs";
import { requestId } from "./middlewares/requestId.js";
import { requireIdempotency } from "./middlewares/idempotency.js";
import { bearerAuth } from "./middlewares/jwt.js";
import { errorHandler } from "./middlewares/errorHandler.js";
import { applyOpenApi } from "./validators/openapi.js";
import { verifyHmac } from "./middlewares/webhookHmac.js";

const app = express();
app.use(express.json({ verify: (req, _res, buf) => ((req as any).rawBody = buf.toString()) }));
app.use(helmet());
app.use(cors());
app.use(requestId);
app.use(requireIdempotency);

const spec = YAML.load("./openapi/tg-miniapp-payhub-service-openapi.bundled.yaml");
app.use("/docs", swaggerUi.serve, swaggerUi.setup(spec));

app.get("/healthz", (_req, res) => res.json({ status: "ok", at: new Date().toISOString() }));
app.get("/readyz", (_req, res) => res.json({ ready: true }));

// Example: provider webhook endpoint (path should match OpenAPI)
app.post("/webhooks/provider", verifyHmac(), (req, res) => {
  res.status(202).json({ received: true, at: new Date().toISOString() });
});

// Apply OpenAPI validator (routes should conform to spec)
await applyOpenApi(app);

app.use(errorHandler);

const port = Number(process.env.PORT || 8080);
app.listen(port, () => console.log(`Listening on http://localhost:${port}`));
EOF
)"
  write_file "src/features/payments/README.md" "Place create payment, capture, cancel, refund handlers here."
  write_file "src/features/transactions/README.md" "Place ledger & transaction history handlers here."
  write_file "src/features/webhooks/README.md" "Place inbound provider webhooks mapping here."
  write_file "tests/unit/problem-details.test.ts" "$(cat <<'EOF'
import { describe, it, expect } from "vitest";
import { toProblem } from "../../src/errors/problem-details.js";
describe("ProblemDetails", () => {
  it("creates problem details with defaults", () => {
    const p = toProblem("x", "y");
    expect(p.code).toBe("x");
    expect(p.message).toBe("y");
    expect(p.traceId).toMatch(/^req_/);
  });
});
EOF
)"
  write_file "tests/integration/health.test.ts" "$(cat <<'EOF'
import { describe, it, expect } from "vitest";
import request from "supertest";
import express from "express";
import { requestId } from "../../src/middlewares/requestId.js";
describe("healthz", () => {
  it("returns ok and sets X-Request-Id", async () => {
    const app = express(); app.use(requestId); app.get("/healthz", (_req,res)=>res.json({status:"ok"}));
    const res = await request(app).get("/healthz");
    expect(res.status).toBe(200);
    expect(res.headers["x-request-id"]).toBeTruthy();
  });
});
EOF
)"
fi

# ---------- Final tree & next steps ----------
log "Scaffold complete."
cat <<EOF

${GREEN}Next steps:${RESET}
  1) cp .env.example .env && edit secrets
  2) docker compose -f docker-compose.dev.yml up -d
  3) ${PM} install
  4) ${PM} run codegen
  5) ${PM} run dev
  6) Open http://localhost:${PORT}/docs

Tip: re-run with --force to overwrite existing files.
EOF

# Print a simple tree
echo
echo "[Created files]"
find . -maxdepth 3 -type f \( -name "scaffold.sh" -o -name "README.md" -o -name "Dockerfile" -o -name "Makefile" -o -name ".env.example" -o -name "*.json" -o -name "*.ts" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" \) | sed 's#^\./##' | sort
