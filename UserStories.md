# UserStories.md — **tg-miniapp-payhub-service**
*Generated:* 2025-09-25 02:02 +07  
*Scope:* Custody and ledger for platform currencies (**STAR, FZ, PT** for MVP; USDT/FUZE later), **holds & settlements** (win/loss/release), deposits, withdrawals, conversions, rewards, fees/treasury, compliance limits, audit. Primary consumers: **PlayHub** (matchmaking & CFB), **Funding**, **Escrow**, **Campaigns**, **Admin**.

> Format per *Guide to User Stories and Feature Lists*: **Personas → Epics → Stories** (with Acceptance Criteria, Edge Cases, Dependencies). Priorities use **MoSCoW** (M=Must, S=Should, C=Could, W=Won't for MVP). Amounts are **integers in smallest units**—no floats.

---

## Personas
- **End User** — sees balances, receives winnings/payouts, requests withdrawals.
- **Game Platform (PlayHub)** — locks stakes and settles results (server-to-server).
- **Funding Service** — places holds on purchases and captures funds.
- **Escrow Service** — holds trades, releases on dispute resolution.
- **Campaigns Service** — credits rewards and referral bonuses.
- **Admin/Finance Ops** — approves withdrawals, posts manual credits, investigates disputes.
- **SRE/SecOps** — monitors reliability, rotates keys, reviews audits.

---

## Epics
1. **Accounts & Ledger**
2. **Holds & Settlements**
3. **Deposits**
4. **Withdrawals**
5. **Conversions**
6. **Rewards & Fees**
7. **Compliance & Limits**
8. **Security, Idempotency, and Audit**
9. **Reporting & Observability**
10. **Admin Operations & Disputes**
11. **Interop & Events**

---

## 1) Epic: Accounts & Ledger
### Feature: User accounts per currency
- **US-PAY-001 (M):** *As a user, I have a balance for each supported currency so that I can participate in games and purchases.*  
  **AC**  
  - `GET /internal/v1/accounts/:userId` returns balances for STAR, FZ, PT (MVP).  
  - Balances are integers in smallest units; zero by default.  
  - Negative balances are not allowed.

### Feature: Double-entry ledger
- **US-PAY-002 (M):** *As Finance, I want a double-entry ledger so that all movements are auditable.*  
  **AC**  
  - Each movement creates **two entries** (debit/credit) with immutable `txnId`.  
  - Ledger totals per currency reconcile to sum of accounts.  
  - `txnId` carries `source` (`playhub`, `funding`, `escrow`, `campaigns`, `admin`), `entityId` (matchId/betId/purchaseId/etc).

**Edge Cases**: idempotent replay writes **no additional entries**; partial failures roll back transaction.

**Dependencies**: **tg-miniapp-shared** (DTOs, error envelope).

---

## 2) Epic: Holds & Settlements
### Feature: Create hold
- **US-PAY-010 (M):** *As PlayHub/Funding/Escrow, I can create a hold to lock a user’s funds before an operation.*  
  **AC**  
  - `POST /internal/v1/holds` with `{ userId, currency, amount, reason, correlationId }` returns `{ holdId, status:'held' }`.  
  - Fails with `402 insufficient_funds` if balance < amount; consistent after concurrent requests.  
  - Hold reduces **available** but not **total** balance.

### Feature: Settle hold (win/loss/release)
- **US-PAY-011 (M):** *As a service, I can settle a hold with outcome.*  
  **AC**  
  - `POST /internal/v1/settlements` with `{ holdId, outcome:'win'|'loss'|'release', destinationUserId?, rakeBps?, breakdown? }`.  
  - `win`: transfer pot (including counterparties’ losses) to destination; `loss`: forfeit amount to counterparties/treasury; `release`: restore available.  
  - Idempotent via `Idempotency-Key` + `correlationId` (same response on retry).  
  - Settlement emits ledger entries and closes hold.

### Feature: Batch settle
- **US-PAY-012 (S):** *As PlayHub CFB, I can settle many acceptors in one call.*  
  **AC**: `POST /internal/v1/settlements/batch` with up to N items; atomic per item; response lists successes/failures.

**Edge Cases**: settling **already closed** hold returns `409 conflict` with last receipt; stale winners guarded by version checks.

**Dependencies**: **PlayHub**, **Funding**, **Escrow**, **tg-miniapp-config** (rake defaults).

---

## 3) Epic: Deposits
### Feature: Manual/Off-chain credit (MVP)
- **US-PAY-020 (M):** *As Admin, I can credit a user’s balance (e.g., promo or migration).*  
  **AC**  
  - `POST /admin/v1/credits` with approval workflow; creates ledger tx against **treasury account**.  
  - Requires two-person approval in **Admin**; appears in user history.

### Feature: On-chain deposit (future)
- **US-PAY-021 (W):** *As a user, I can deposit USDT or FUZE on-chain to top up.*  
  **AC**: Address generation, confirmations, credit after N blocks, fee handling. *(Out of MVP)*

### Feature: Earned winnings → balance
- **US-PAY-022 (M):** *As a user, my winnings are credited automatically.*  
  **AC**: Settlement from PlayHub posts credit with receipt; visible in history.

---

## 4) Epic: Withdrawals
### Feature: Request withdrawal
- **US-PAY-030 (M):** *As a user, I can request a withdrawal of available balance.*  
  **AC**  
  - `POST /v1/withdrawals` with `{ currency, amount, target }`; returns `pending` with `withdrawalId`.  
  - Checks min/max per currency, user KYC/limits, cooldowns (from config).

### Feature: Review & approve (two-person)
- **US-PAY-031 (M):** *As Finance Ops, I review and approve withdrawals with two-person controls.*  
  **AC**: `POST /admin/v1/withdrawals/:id/approve` (two approvers), `reject`, `mark-paid`; full audit trail.

### Feature: Auto-retry payouts
- **US-PAY-032 (S):** *As the system, retry provider failures safely.*  
  **AC**: Exponential backoff; capped retries; idempotent provider reference; alarms on repeated failures.

**Edge Cases**: block withdrawals if user has **open holds** exceeding available; handle stale exchange rates for cross-currency payouts (blocked in MVP).

**Dependencies**: **Admin**, **Workers**, **Config** (limits).

---

## 5) Epic: Conversions
### Feature: Intra-platform conversion
- **US-PAY-040 (S):** *As a user, I can convert between platform currencies for fees/rewards.*  
  **AC**  
  - `POST /v1/conversions` `{ from, to, amount }` uses **Price Service** or fixed rate from **Config**.  
  - Quotes are rounded **down**; fees explicit; preview endpoint available.  
  - Atomic debit/credit with ledger entries; limits per day.

**Edge Cases**: slippage > tolerance → reject; circular conversions rate-limited.

**Dependencies**: **Price Service**, **Config**.

---

## 6) Epic: Rewards & Fees
### Feature: Referral/airdrop reward credit
- **US-PAY-050 (M):** *As Campaigns, I can credit rewards to a user.*  
  **AC**: `POST /internal/v1/rewards` with reason & correlation; idempotent; posts against rewards budget/treasury.

### Feature: Platform rake
- **US-PAY-051 (M):** *As Payhub, I apply rake on winning settlements (e.g., CFB 7%).*  
  **AC**: `rakeBps` default from Config; reflected in settlement breakdown and ledger split between winner and treasury.

### Feature: Fees on withdrawal/conversion
- **US-PAY-052 (S):** *As Finance, I set fee schedules in Config.*  
  **AC**: Fee bps or flat; min/max; per-currency overrides; included in receipt.

---

## 7) Epic: Compliance & Limits
- **US-PAY-060 (M):** *As Compliance, enforce per-user daily/weekly caps for deposits, withdrawals, conversions.*  
  **AC**: Hard stops with `403 forbidden`; counters reset by rolling windows; overrides via Admin with audit.

- **US-PAY-061 (S):** *As Ops, freeze a user’s account.*  
  **AC**: Mark `frozenAt`; all outgoing operations blocked; holds may still **release**.

- **US-PAY-062 (W):** *As Compliance, require KYC for high tiers.*  
  **AC**: Placeholder checks; integration later.

---

## 8) Epic: Security, Idempotency, and Audit
- **US-PAY-070 (M):** *All POST endpoints require `Idempotency-Key` and carry `X-Request-Id`.*  
  **AC**: Duplicate keys return the original response; stored for 24h in Redis.

- **US-PAY-071 (M):** *As SecOps, I want immutable audits for every balance-changing action.*  
  **AC**: Audit record with actor/service, requestId, payload hash, before/after balances.

- **US-PAY-072 (M):** *As Services, calls use **service JWTs**; end-user tokens not accepted.*  
  **AC**: Verify `aud/iss/kid` with JWKS; allow-list issuers.

- **US-PAY-073 (S):** *As Ops, detect anomaly patterns (rapid holds/releases, self-dealing).*  
  **AC**: Emit metrics and alerts; optional auto-freeze.

---

## 9) Epic: Reporting & Observability
- **US-PAY-080 (M):** *As Finance, I export ledger and balances by date range and currency.*  
  **AC**: CSV/JSON exports; pagination; totals footers.

- **US-PAY-081 (S):** *As SRE, I track error rates, hold latency, settlement throughput.*  
  **AC**: Prometheus metrics & dashboards; SLO burn alerts.

- **US-PAY-082 (S):** *As Support, I view a user’s transaction history.*  
  **AC**: Filterable by type (hold, settlement, credit, withdrawal, conversion).

---

## 10) Epic: Admin Operations & Disputes
- **US-PAY-090 (M):** *As Admin, I can create a manual adjustment with justification and two-person approval.*  
  **AC**: Creates ledger tx to/from treasury; tagged `manual_adjustment`; visible in audits.

- **US-PAY-091 (S):** *As Disputes, I can reverse a settlement via compensating entries.*  
  **AC**: Requires approval; links to original `txnId`; leaves original immutable.

- **US-PAY-092 (C):** *As Admin, I can temporarily pause new holds platform-wide.*  
  **AC**: Config flag; returns `503` to consumers; health page reflects pause.

---

## 11) Epic: Interop & Events
- **US-PAY-100 (M):** *As Workers, I receive events for holds, settlements, withdrawals.*  
  **AC**: Emit `HoldCreated`, `HoldSettled`, `WithdrawalRequested`, `WithdrawalPaid`, `ConversionExecuted`, with delivery guarantees (at-least-once).

- **US-PAY-101 (S):** *As PlayHub/Funding/Escrow, I can query receipts by `correlationId`.*  
  **AC**: `GET /internal/v1/receipts/:correlationId` returns final status and amounts.

---

## Non‑Functional Requirements
- **Performance:** p95 < 120 ms for `create hold`, p95 < 200 ms for `settle`.  
- **Consistency:** Strong consistency on a single user’s balance; global eventual for reports.  
- **Availability:** ≥ 99.95% (core ops).  
- **Scalability:** Horizontal via stateless API, Redis for idempotency, MongoDB for ledger.  
- **Data Integrity:** Double-entry enforced; periodic reconciliation jobs.  
- **Security:** Service JWTs, allow-lists, rate limits, strict validation, integer math.

---

## Out of Scope (MVP)
- On‑chain custody and automated blockchain payouts.  
- Fiat on‑ramp/off‑ramp integrations.  
- Multi-region active/active.

---

## Backlog & Enhancements
- **C:** Scheduled payouts (cron windows).  
- **C:** Chargeback handling with dispute states.  
- **W:** User-to-user internal transfers (requires anti-fraud).

---

## Dependencies
- **tg-miniapp-identity-service:** JWKS & service tokens.  
- **tg-miniapp-config:** Fees, rake, limits, treasury accounts.  
- **tg-miniapp-price-service:** Rates for conversions.  
- **tg-miniapp-admin:** Approvals, audits UI.  
- **tg-miniapp-workers:** Events and exports.  
- **tg-miniapp-playhub-service / funding / escrow / campaigns:** Upstream callers.
