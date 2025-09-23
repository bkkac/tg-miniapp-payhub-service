# SystemDesign.md — **tg-miniapp-payhub-service**
*Version:* v0.1.0  
*Last Updated:* 2025-09-24 01:03 +07  
*Owner:* Platform Engineering — Ledger & Custody

> **What it is:** The high‑level architectural blueprint for **Payhub**, the platform’s **bank/ledger of record**. Payhub exposes safe, idempotent primitives—**holds**, **settlements**, **conversions**, **deposits/withdrawals**—consumed by PlayHub/CFB, Escrow, Campaigns, and Funding. It never contains game/business rules; it guarantees **money correctness** across all repos.

---

## 1) Architecture Diagram (High‑Level)
```mermaid
flowchart LR
  subgraph Clients
    ADMIN[Admin UI]:::client
    WORKERS[Workers]:::client
  end

  subgraph Callers
    PLAYHUB[PlayHub/CFB]:::peer
    ESCROW[Escrow]:::peer
    CAMPAIGNS[Campaigns]:::peer
    FUNDING[Funding]:::peer
  end

  subgraph Payhub["tg-miniapp-payhub-service"]
    API[/Internal REST API\n/healthz /readyz/]:::svc
    HOLDS[Holds Engine]:::logic
    SETTLE[Settlement Engine]:::logic
    FX[Conversion Engine]:::logic
    LEDGER[(MongoDB\nwallets, ledger, holds, settlements, fx, wd/deposits)]:::db
    CACHE[(Redis\nidempotency, locks, rate limits)]:::cache
    RULES[Limits/Fees\n(config hot‑reload)]:::edge
  end

  PRICE[[Price Service\n(or static rates)]]:::ext

  PLAYHUB -->|/internal/v1/*| API
  ESCROW -->|/internal/v1/*| API
  CAMPAIGNS -->|/internal/v1/*| API
  FUNDING -->|/internal/v1/*| API
  ADMIN -->|read-only + ops| API
  WORKERS -->|recon + DLQ| API

  API --> HOLDS --> LEDGER
  API --> SETTLE --> LEDGER
  API --> FX --> LEDGER
  API --> CACHE
  RULES --> API
  PRICE --> FX

  classDef client fill:#E3F2FD,stroke:#1E88E5;
  classDef peer fill:#ECEFF1,stroke:#546E7A;
  classDef svc fill:#E8F5E9,stroke:#43A047;
  classDef logic fill:#F1F8E9,stroke:#7CB342;
  classDef db fill:#FFF3E0,stroke:#FB8C00;
  classDef cache fill:#F3E5F5,stroke:#8E24AA;
  classDef edge fill:#FFFDE7,stroke:#FBC02D;
  classDef ext fill:#FFFDE7,stroke:#FBC02D,stroke-dasharray:5 5;
```
*Inter‑repo fit:* Identity issues end‑user tokens (not accepted here). Callers authenticate with **service JWTs** against Payhub’s allow‑list. Price Service optionally supplies rates for conversions.

---

## 2) Technology Stack
| Layer | Choice | Why |
|---|---|---|
| Runtime | Node.js ≥20 + TypeScript | Shared tooling across repos |
| Framework | Express + Zod | Small, predictable, schema‑first validation |
| DB | **MongoDB** | Append‑only ledger + flexible wallet/hold docs |
| Cache/Queue | **Redis** (+ BullMQ in Workers) | Idempotency, locks, async recon |
| Auth | `jose` (Ed25519 service JWT) | Fast verify, compact keys |
| Telemetry | OpenTelemetry + Pino | Consistent traces/metrics/logs |
| Config | **tg-miniapp-config** (signed JSON) | Fees/limits/currency enablement, hot‑reload |
| Deploy | Docker + Helm (infra repo) | Reproducible pipelines |

**Currencies (MVP):** STAR, FZ, PT, FUZE, USDT (config‑gated). All amounts are **integers of smallest units** (no floats).

---

## 3) Data Flow (How data moves)
### 3.1 Hold → Settle (used by PlayHub, Escrow, Funding)
1. **Caller** → `POST /internal/v1/holds` `{ userId, currency, amount, reason, reference }` + `Idempotency-Key`  
2. **Payhub** checks available balance; moves funds to **held** via ledger entries; returns `{ holdId }`.  
3. Later **caller** → `POST /internal/v1/settlements` `{ holdId, outcome: 'win'|'loss', payout? }`  
   - **win**: credit `payout.amount` to winner user; mark hold settled.  
   - **loss**: forfeit held amount; mark hold settled.  
4. **Idempotency** guarantees the same receipt on retries; unique constraints prevent double‑spend.

### 3.2 CFB v1 Settlement (from PlayHub)
- PlayHub computes winners and **payout totals** (after rake).  
- For **each** participant hold: settle with `win|loss`.  
- Ledger guarantees invariant: `Σcredits − Σdebits = Σbalances + ΣactiveHolds`.

### 3.3 Conversion (FX)
1. **Caller** → `POST /internal/v1/conversions` `{ userId, from, to, amount, rateSnapshotId, feeBps }`.  
2. **Payhub** debits `from`, credits `to = floor(amount * rate * (1 − fee))`; persists snapshot reference.  
3. **Rates** from Price Service or static table; conversions can be **disabled** via config on oracle outage.

### 3.4 Deposits & Withdrawals (Off‑chain MVP)
- **Deposit credit**: admin/worker credits user from **treasury** user account.  
- **Withdraw**: create hold → perform off‑chain payout → settle **loss** to consume hold; on payout failure, **release** the hold.

### 3.5 Reconciliation (Workers)
- Orphan hold GC (older than TTL) → `release`.  
- Invariant checker → emits alerts on mismatch.  
- DLQ replays for partially completed mutations.

---

## 4) Scalability & Security Plan
### 4.1 Scalability & Reliability
- Stateless API pods; horizontal scale behind ingress.  
- MongoDB tuned indexes: `wallet(userId,currency)` unique; `holds(holdId)`; `ledger(userId,currency,createdAt)`.  
- Redis cluster for idempotency/locks; backpressure with 429 & queues.  
- **SLOs:** p95 < 100ms on reads, < 300ms on mutations; 99.95% availability.  
- Blue/green deploys; health checks `/healthz`, `/readyz` include DB/Redis/config readiness.  
- DR: daily backups; **PITR** recommended; config switch for “read‑only” mode on emergencies.

### 4.2 Security
- **Service‑to‑service JWT** (Ed25519); strict issuer/audience allow‑lists; optional mTLS.  
- **Idempotency required** on all POST/PUT/PATCH; Redis‑backed with 48h retention.  
- **Input validation** with Zod; integer amounts only; currency allow‑list from config.  
- **Authorization**: no end‑user tokens; only trusted services & restricted admin ops.  
- **Auditability**: append‑only ledger; correlation IDs (roomId/betId/escrowId).  
- **Secrets** in secret manager; rotated keys; least‑privilege DB roles.  
- **Rate limits** per issuer; anomaly detection for velocity spikes.  
- **Compliance**: privacy‑by‑design (no PII beyond userId); export ledgers for audits.

---

## 5) User Stories & Feature List (Service‑centric)
### Feature List
- Create/release **Holds** (escrow funds).  
- **Settlements** with outcomes `win|loss`.  
- **Conversions** with fees and rate snapshots.  
- **Deposits/Withdrawals** (off‑chain MVP) with statuses.  
- **Balances & Ledger** read APIs.  
- **Reconciliation** jobs & orphan hold GC.

### User Stories
- *As PlayHub*, I place holds before a match so funds are guaranteed when settling the winner and loser.  
- *As CFB (PlayHub)*, I settle each participant’s hold with win/loss to distribute the pot correctly after rake.  
- *As Escrow*, I need dual holds and atomic release/forfeit so OTC trades are safe.  
- *As Campaigns*, I mint rewards via a settlement so claims are idempotent and auditable.  
- *As Finance/Admin*, I need read‑only ledger exports and invariant checks for audits.

---

## 6) Interfaces (for interoperability)
**Authentication:** `Authorization: Bearer <service-jwt>` (no user tokens).  
**Headers:** `Idempotency-Key`, `X-Request-Id`.  

**Endpoints (MVP)**  
- `GET  /internal/v1/wallets/:userId/balances`  
- `POST /internal/v1/holds` → `{{ holdId }}`  
- `POST /internal/v1/holds/release`  
- `POST /internal/v1/settlements`  
- `POST /internal/v1/conversions`  
- `POST /internal/v1/withdrawals` / `POST /internal/v1/deposits/credit`

**Contracts:** DTOs and error envelopes provided by `tg-miniapp-shared`. Config (fees/limits/currencies) from `tg-miniapp-config` with hot‑reload ≤60s.

---

## 7) Data Model (canonical)
- **WalletBalance**: `{ userId, currency, available:int, updatedAt }`  
- **Hold**: `{ holdId, userId, currency, amount:int, reason, reference, status:held|released|settled, createdAt }`  
- **Settlement**: `{ settlementId, holdId, outcome, payout?{currency,amount}, createdAt }` (1:1 with hold)  
- **LedgerEntry**: `{ entryId, userId, currency, amount:int, type:debit|credit, reason, refId, createdAt }`  
- **Conversion**: `{ conversionId, userId, from, to, fromAmount, toAmount, fee, rateSnapshotId, createdAt }`  
- **Withdrawal/Deposit**: standard state machines (`pending→processing→succeeded|failed`).

**Invariants:** for each currency & time window:  
`Σcredits − Σdebits == Σbalances + ΣactiveHolds`

---

## 8) Failure Modes & Recovery
- **Idempotency cache loss** → rely on unique constraints & request hashes; replays return same receipt.  
- **Rates/Price outage** → conversions disabled; core ledger stays operational.  
- **Partial commit then network error** → subsequent retry returns committed result (idempotent).  
- **DB/Redis outage** → 503 with circuit‑breaker; Workers pause queues; alerting escalates.  

---

## 9) Implementation Notes
- Integer math utilities (BigInt or fixed‑point lib only for parsing; store integers).  
- Deterministic rounding for FX; document policy in `CHANGELOG`.  
- Pagination & time‑range filters for ledger reads.  
- Consistent correlation IDs across services for end‑to‑end traceability.

---

## 10) Roadmap
- Batch settlements API (bulk payouts).  
- On‑chain custody adapters behind `CustodyAdapter` interface.  
- Ledger snapshots/time‑travel queries.  
- Velocity/fraud heuristics for withdrawals.  
