# SystemDesign.md — tg-miniapp-payhub-service

> High‑level architectural blueprint for the **Payhub** service — the platform’s bank/ledger of record. This document is scoped to Payhub while ensuring clean interoperability with sibling repos (Identity, PlayHub/CFB, Campaigns, Escrow, Funding, Discovery, Events, WebApp, Admin, Workers, Config, Infra, Shared).

---

## 1) Architecture Diagram

```
flowchart LR
  subgraph Clients
    ADMIN[Admin UI]:::client
    WORKERS[Workers]:::client
    SVC_PLAYHUB[PlayHub/CFB]:::peer
    SVC_ESCROW[Escrow]:::peer
    SVC_CAMPAIGNS[Campaigns]:::peer
    SVC_FUNDING[Funding]:::peer
  end

  subgraph Payhub["tg-miniapp-payhub-service"]
    API[/Internal REST API\n/healthz, /readyz/]:::svc
    HOLD[Holds Engine]:::logic
    SETTLE[Settlement Engine]:::logic
    CONVERT[Conversion Engine]:::logic
    LEDGER[(MongoDB: wallets, ledger, holds, settlements, conversions, withdrawals)]:::db
    CACHE[(Redis: idempotency, locks, queues)]:::cache
    QUEUES[Queues (BullMQ)]:::queue
    RULES[Limits & Fees\n(config hot‑reload)]:::edge
  end

  EXT_PRICE[Price/FX Source\n(Price Service / Static Rates)]:::ext
  EXT_CUST[Future: On‑chain Custody Adapter]:::ext
  EXT_FIAT[Future: Fiat On‑/Off‑ramp]:::ext

  SVC_PLAYHUB -->|/internal/v1/holds, /settlements| API
  SVC_ESCROW -->|/internal/*| API
  SVC_CAMPAIGNS -->|rewards.mint via settlements| API
  SVC_FUNDING -->|intents: hold/settle| API
  ADMIN -->|read-only ledger, limited admin ops| API
  WORKERS -->|recon, DLQ replays| API
  API --> HOLD --> LEDGER
  API --> SETTLE --> LEDGER
  API --> CONVERT --> LEDGER
  RULES --> API
  API --> CACHE
  QUEUES --> API
  EXT_PRICE --> CONVERT
  EXT_CUST -.-> API
  EXT_FIAT -.-> API

  classDef client fill:#E3F2FD,stroke:#1E88E5;
  classDef peer fill:#ECEFF1,stroke:#546E7A;
  classDef svc fill:#E8F5E9,stroke:#43A047;
  classDef logic fill:#F1F8E9,stroke:#7CB342;
  classDef db fill:#FFF3E0,stroke:#FB8C00;
  classDef cache fill:#F3E5F5,stroke:#8E24AA;
  classDef queue fill:#FFEBEE,stroke:#E53935;
  classDef edge fill:#FFFDE7,stroke:#FBC02D;
  classDef ext fill:#FFFDE7,stroke:#FBC02D,stroke-dasharray: 5 5;
```
*Notes:* Payhub is **internal‑only**; it exposes primitives (holds, settlements, conversions, deposits, withdrawals) and never implements domain/game logic.

---

## 2) Technology Stack

| Layer | Choice | Rationale |
|------|--------|-----------|
| Runtime | Node.js ≥20, TypeScript | Shared ecosystem and tooling with other services |
| Framework | Express + Zod | Minimal, predictable validation |
| Database | MongoDB | Append‑only ledger, document models for holds/settlements |
| Cache/Queues | Redis + BullMQ | Idempotency store, locks, async recon jobs |
| Crypto | Ed25519 JWT via `jose` | Service‑to‑service auth; small keys, fast verify |
| Telemetry | OpenTelemetry + Pino | Unified tracing/metrics/logs |
| Config | tg-miniapp-config | Signed, hot‑reloaded rates/limits/fees |
| Deploy | Docker + Helm (infra repo) | Standardized CI/CD |

Currencies (configurable per env): **STAR, FZ, PT, FUZE, USDT**.

---

## 3) Responsibilities & Interfaces

### Responsibilities (SoR)
- **Wallet Balances** per user & currency (available = non‑held funds).
- **Ledger Entries** immutable, double‑entry style.
- **Holds** create escrowed amounts with lifecycle `held → released|settled`.
- **Settlements** consume a hold as `win|loss` and apply credits/debits.
- **Conversions** between currencies using rate snapshots and fees.
- **Deposits / Withdrawals** (off‑chain MVP) with status tracking.
- **Rewards** issuance for campaigns via settlement primitives.

### Internal API (MVP)
All endpoints require service JWT; mutations require `Idempotency-Key`.

- `GET  /internal/v1/wallets/:userId/balances`
- `POST /internal/v1/holds` → `{ holdId }`
- `POST /internal/v1/holds/release` → release back to available
- `POST /internal/v1/settlements` → apply `win|loss` and finalize hold
- `POST /internal/v1/conversions` → convert `from→to` with snapshot+fee
- `POST /internal/v1/withdrawals` / `POST /internal/v1/deposits/credit`

Headers: `Authorization: Bearer <svc-jwt>`, `Idempotency-Key`, `X-Request-Id`.

---

## 4) Data Model

- **WalletBalance** `{ userId, currency, available:int, updatedAt }` (unique by `userId+currency`)
- **Hold** `{ holdId, userId, currency, amount:int, reason, reference, status:held|released|settled, createdAt }`
- **Settlement** `{ settlementId, holdId, outcome:win|loss, payout?{currency,amount}, createdAt }` (unique by `holdId`)
- **LedgerEntry** `{ entryId, userId, currency, amount:int, type:debit|credit, reason, refId, createdAt }`
- **Conversion** `{ conversionId, userId, from, to, fromAmount, toAmount, fee, rateSnapshotId, createdAt }`
- **Withdrawal** `{ withdrawalId, userId, currency, amount, dest, status, createdAt }`

**Invariants**
- For each currency: `Σ(credits) - Σ(debits) = Σ(balances) + Σ(active holds)`
- A **hold** is single‑use and transitions exactly once to a terminal state.

Indexes: `WalletBalance(userId,currency)` unique; `Hold(holdId)` unique; time‑ordered compound indexes for queries.

---

## 5) Data Flow

### 5.1 Hold → Settle (PlayHub/CFB, Escrow, Funding)
1. Caller → `POST /internal/v1/holds { userId, currency, amount, reason, reference, idempotencyKey }`
2. Payhub verifies sufficient **available** balance; moves `amount` to **held** (by ledger entries) and returns `holdId`.
3. Later, caller → `POST /internal/v1/settlements { holdId, outcome, payout? }`.

   - **win**: credit `payout.amount` to `userId` (usually equals total pot for winners in PlayHub), mark hold **settled**.

   - **loss**: debit **held** amount (forfeit) from `userId`, mark hold **settled**.

4. Idempotency returns the same receipt on duplicate requests.

### 5.2 Conversion
1. Caller → `POST /internal/v1/conversions { userId, from, to, amount, rateSnapshotId, feeBps }`
2. Payhub debits `from`, credits `toAmount = floor(amount*rate*(1-feeBps/10_000))`, writes conversion + ledger entries.

### 5.3 Deposit/Withdraw (off‑chain MVP)
- **Deposit credit**: system treasury → user wallet credit (admin/worker invoked).
- **Withdraw**: place hold, perform off‑chain payout, then settle **loss** to consume hold; on failure, release hold.

### 5.4 Reconciliation (Workers)
- Periodic job scans **orphan holds** older than TTL with no correlation → releases.
- Ledger invariant check emits alerts on mismatch.

---

## 6) Security Plan

- **Service JWT** (Ed25519) with audience & issuer allow‑lists; optional mTLS inside cluster.
- **Idempotency**: every mutation requires `Idempotency-Key` (UUID); canonical response cached 48h.
- **Input Validation**: Zod schemas; integer amounts (smallest units), no floats.
- **Authorization**: only trusted services can call internal APIs; Admin has read‑only by default.
- **Auditability**: append‑only ledger; every state change has correlation IDs (roomId/betId/escrowId/fundingIntent).
- **Secrets**: managed via secret manager; no secrets committed.
- **Rate Limits**: per‑issuer rate limits and spike protection on holds/settlements.
- **DoS/Backpressure**: bounded concurrency; queue overflow to Workers for retries.

---

## 7) Scalability & Reliability

- **Stateless** API pods; horizontal scale behind a service mesh/ingress.
- **MongoDB** with write concern `majority`; tuned indexes for hot paths.
- **Redis** cluster for idempotency & queues; BullMQ with DLQ for failed jobs.
- **SLOs**: 99.95% availability; p95 < 100ms for `GET balances`, < 300ms for mutations.
- **Health**: `/healthz`, `/readyz` verify DB/Redis connectivity and config freshness.
- **Deployments**: Blue/green via Helm; zero‑downtime rolling updates.
- **DR**: backups + PITR; ability to freeze conversions via config on provider outage.

---

## 8) Observability

- **Tracing**: propagate `X-Request-Id`; spans include `userId`, `holdId`, `settlementId`.
- **Metrics**: holds/sec, settlements/sec, idempotency hit rate, invariant check status, p95 latencies.
- **Logs**: structured JSON; redact PII; include correlation fields.
- **Alerts**: orphan holds > threshold, settlement error rate spike, ledger mismatch, provider/rates stale.

---

## 9) Configuration & ENV

Pulled via **tg-miniapp-config** (hot‑reload ≤60s):
- **Fees**: conversion fee BPS per pair
- **Limits**: daily withdrawal caps, conversion count caps
- **Currencies Enabled**
- **Rate Source**: `oracle` (price service) or static

Key ENV (service):
- `SERVICE_JWKS_URL` (trusted issuers), `TRUSTED_ISSUERS`
- `MONGO_URL`, `REDIS_URL`
- `RATES_SOURCE`, `RECON_ORPHAN_HOLDS_MINUTES`

---

## 10) Failure & Recovery Scenarios

- **Idempotency cache loss**: duplicate POSTs could replay → protect by unique constraints and request hash comparisons.
- **Rates outage**: refuse conversions; keep ledger primitives operational.
- **Partial settlement**: network error after ledger write → idempotency returns completed result; DLQ worker reconciles.
- **Mongo or Redis outage**: 503 with circuit‑breaker; Workers pause; Admin alerted.

---

## 11) User Stories & Feature List (Service‑centric)

### Feature List
- Create/release/settle holds
- Credit/debit via settlements (win/loss patterns)
- Currency conversions with fees and snapshots
- Off‑chain deposits/withdrawals tracking
- Read balances & ledger with pagination
- Reconciliation & orphan hold GC

### User Stories
- *As PlayHub*, I need to place holds before matchmaking so that funds are guaranteed at settle time.
- *As PlayHub/CFB*, I need to settle winner and loser holds atomically so that payouts are correct.
- *As Campaigns*, I want to mint rewards via a settlement so that claims are idempotent and auditable.
- *As Escrow*, I need dual holds and controlled release so that P2P trades are safe.
- *As Funding*, I want payment intents to reserve funds and settle after confirmation so that oversell cannot occur.
- *As Admin/Finance*, I need read‑only ledgers and invariant checks so that I can audit and reconcile.

---

## 12) Compatibility Notes (Cross‑Repo)

- **Identity**: callers authenticate with service JWTs; no end‑user tokens accepted directly.
- **PlayHub/CFB**: uses holds & settlements; payout currency must match hold currency (MVP).
- **Campaigns**: rewards implemented as settlements from a campaign treasury user → claimant.
- **Escrow**: two holds (maker/taker) settled according to dispute/completion outcome.
- **Funding**: intents use holds and settle on confirmation; expiry releases.
- **Workers**: run `orphan_holds.gc`, DLQ replays, and periodic invariant checks.
- **Config**: controls fees/limits/currency enablement; changes hot‑reload safely.
- **Infra**: Helm chart probes/requests; OTel collector integrated.

---

## 13) Non‑Functional Requirements

- 85%+ test coverage on holds/settlements; 100% on idempotency core.
- Deterministic integer math; no floating point in balances/ledger.
- Throughput: sustain ≥ 300 holds/sec and ≥ 300 settlements/sec at p95 < 300ms under nominal load.
- Strong consistency for ledger writes; read‑your‑writes for balance queries of same user.

---

## 14) Roadmap

- Bulk settlements endpoint for batch payouts
- On‑chain custody adapter (EVM vaults) behind `CustodyAdapter`
- Ledger snapshots & time‑travel queries
- Advanced fraud/velocity rules and anomaly detection
