# UserStories.md — **tg-miniapp-payhub-service**
*Generated:* 2025-09-25 13:08 +07  
*Source:* SystemDesign.md (Payhub Service) and *From Vision to Value: A Guide to User Stories and Feature Lists*

> This document enumerates comprehensive **User Stories** for the **Payhub** (custody & ledger) domain. Stories follow INVEST and include acceptance criteria, edge cases, dependencies, and non‑functional notes. Scope aligns with the platform architecture: **off‑chain balances** for STAR/FZ/PT in MVP; server‑to‑server **holds & settlements** for PlayHub/CFB/Funding/Escrow; user‑initiated **deposit/withdraw/convert**; fees and treasury routing; auditing and reconciliation.

---

## 1) Personas
- **End User** — Anyone using WebApp; maintains balances in STAR/FZ/PT; requests withdrawals and conversions.
- **Game Player** — A user who stakes assets via PlayHub (matchmaking or **CFB v1**).
- **Presale Participant** — Uses Funding service; purchases using on‑platform assets.
- **Counterparty (Escrow)** — Buyer/Seller in P2P/OTC; funds are held/released via Escrow service.
- **Campaign Beneficiary** — Receives rewards/airdrops credited by Campaigns service.
- **Staff Finance Operator** — Approves withdrawals, performs manual credits, reconciles accounts.
- **Service Client** — Trusted services: PlayHub, Funding, Escrow, Campaigns, Workers, Admin BFF.
- **Workers** — Async processors for payouts, reconciliation, ledgers export.

---

## 2) Feature List (Payhub Scope)
1. **Balances & Ledger** — Per‑user accounts for STAR, FZ, PT; immutable journal entries; balance snapshots.
2. **Holds & Settlements (S2S)** — Create/cancel/settle holds for bets, purchases, escrows.
3. **Deposits** — Manual/admin credit (MVP) and on‑ramp webhook (future).
4. **Withdrawals** — User requests; two‑person approvals in Admin; payout execution by Workers.
5. **Conversions** — User converts between STAR/FZ/PT; config‑driven rates and fees.
6. **Rewards & Adjustments** — Service‑initiated credits for campaigns, refunds, compensation.
7. **Fees & Treasury** — Platform rake/fees routing to treasury accounts; CFB rake (7%) configurable.
8. **Statements & Exports** — User statements; admin exports for audits/reconciliation.
9. **Limits, Risk & Compliance** — Per‑user limits, velocity checks, blacklists via Config.
10. **Observability & Reconciliation** — Metrics, logs, traces; nightly valuation reports using Price Service.
11. **Idempotency & Integrity** — Idempotent POSTs; request hashing; double‑entry guarantees.

---

## 3) User Stories & Acceptance Criteria

### 3.1 Balances & Ledger
**US‑PAY‑001** — *As an End User, I want to view my balances so that I know how much I can spend.*  
**Acceptance Criteria**
- `GET /v1/wallets/me/balances` returns non‑negative integers for STAR, FZ, PT.
- Response includes `updatedAt` and optional pending/held amounts.

**US‑PAY‑002** — *As the Platform, I want every monetary action recorded as double‑entry ledger lines so that balances reconcile.*  
**Acceptance Criteria**
- Every mutation produces a journal with equal debits/credits and a `requestId`.
- Journal lines are immutable; corrections use reversal entries.

**US‑PAY‑003** — *As Admin, I want to download a user statement so that I can investigate disputes.*  
**Acceptance Criteria**
- `GET /internal/v1/ledgers/:userId?from&to` returns CSV/JSON with running balances.

### 3.2 Holds & Settlements (S2S)
**US‑PAY‑010** — *As PlayHub, I want to place a hold on a user’s funds when they join matchmaking so that the stake is locked.*  
**Acceptance Criteria**
- `POST /internal/v1/holds` with `{ userId, currency, amount, purpose, idemKey }` returns `holdId` if balance is sufficient.
- Insufficient balance → `409 conflict` with code `insufficient_funds`; no journal entry.
- Idempotency: same `idemKey` returns the original hold.

**US‑PAY‑011** — *As PlayHub, I want to settle holds when a winner is reported so that payouts are final.*  
**Acceptance Criteria**
- `POST /internal/v1/settlements` with `{ holdId, outcome: 'win'|'loss'|'cancel', roomId? }` posts journals:
  - `win`: loser debits → treasury pool then credits winner net of rake; fees routed to treasury.
  - `loss`: loser hold consumed; no credit to loser.
  - `cancel`: funds released back to owner balance.
- Idempotent by `requestId`/`idemKey`.

**US‑PAY‑012** — *As Funding, I want a hold then capture model so that purchases are confirmed at finalize time.*  
**Acceptance Criteria**
- Hold created at purchase intent; settle `win` to project treasury at finalize.
- Auto‑cancel holds on sale window end if not finalized.

**US‑PAY‑013** — *As Escrow, I want multi‑party holds and conditional release so that P2P trades are safe.*  
**Acceptance Criteria**
- Escrow creates two holds; release both to winner or split per policy; cancel on dispute resolve.

### 3.3 Deposits
**US‑PAY‑020** — *As Admin, I want to manually credit STAR/FZ/PT to a user so that support can resolve issues.*  
**Acceptance Criteria**
- `POST /internal/v1/deposits/manual` requires **two‑person approval** via Admin BFF (pre‑executed approvalId).
- Journal debits from `treasury:adjustments` and credits `user:currency` with `reason`.
- Idempotent on `requestId`.

**US‑PAY‑021** — *As an End User, I want to see deposit history so that I can verify credits.*  
**Acceptance Criteria**
- `GET /v1/wallets/me/activities?type=deposit` returns paged list with source and status.

*(Future)* **US‑PAY‑022** — *As the Platform, I want to accept on‑ramp webhooks so that fiat/crypto deposits can be credited.*  
**Acceptance Criteria**
- `POST /webhooks/onramp` verifies signature, deduplicates by provider event id, then journals credit.

### 3.4 Withdrawals
**US‑PAY‑030** — *As an End User, I want to request a withdrawal so that I can cash out.*  
**Acceptance Criteria**
- `POST /v1/withdrawals` validates limits, cool‑downs, and minimums from Config.
- Status becomes `pending_review` and a hold is placed on requested amount.
- Returns `withdrawalId` and ETA hints.

**US‑PAY‑031** — *As Finance Operator, I want to approve a withdrawal with 4‑eyes so that payouts are controlled.*  
**Acceptance Criteria**
- Admin BFF `POST /internal/v1/withdrawals/:id/approve` requires a second approver and capability checks.
- On approval, a **Worker** enqueues payout execution.

**US‑PAY‑032** — *As Workers, I want to execute the payout and mark it complete so that the user is paid.*  
**Acceptance Criteria**
- Worker dequeues approved withdrawal, executes payout (off‑chain in MVP), journals movement, marks status `paid`.
- Failure retries with exponential backoff; after max attempts → `failed` and hold is released back.

**US‑PAY‑033** — *As an End User, I want to cancel my pending withdrawal before approval so that I can keep my funds.*  
**Acceptance Criteria**
- `POST /v1/withdrawals/:id/cancel` allowed only in `pending_review`; releases hold.

### 3.5 Conversions
**US‑PAY‑040** — *As an End User, I want to convert STAR↔FZ↔PT so that I can participate in different features.*  
**Acceptance Criteria**
- `POST /v1/conversions` with `{ from, to, amount }` validates config rates & fees and minimums.
- Journal: debit `user:from`, credit `user:to`, fee to treasury.
- Quote endpoint `GET /v1/conversions/quote?from&to&amount` returns exact received amount and fee; idempotent execution ties to quote id and expires after short TTL.

**US‑PAY‑041** — *As Admin, I want to pause conversions globally so that I can mitigate risk.*  
**Acceptance Criteria**
- Config flag `conversions.enabled=false` makes quote return `503` with `retryAfter` header.

### 3.6 Rewards & Adjustments
**US‑PAY‑050** — *As Campaigns, I want to credit rewards to winners so that incentives are distributed.*  
**Acceptance Criteria**
- `POST /internal/v1/rewards` with `{ userId, currency, amount, campaignId }` journals credit from `treasury:campaigns` to user.
- Idempotent by `(userId,campaignId)` pair.

**US‑PAY‑051** — *As PlayHub, I want to distribute CFB rake and payouts automatically so that results settle correctly.*  
**Acceptance Criteria**
- On CFB `win`, 7% rake (configurable bps) routes to `treasury:rake` before net payout to winners (owner or acceptor pool).

### 3.7 Statements & Exports
**US‑PAY‑060** — *As an End User, I want a filterable activity list so that I can track usage.*  
**Acceptance Criteria**
- `GET /v1/wallets/me/activities?type&from&to` supports pagination and stable ordering.

**US‑PAY‑061** — *As Finance, I want to export journals and balances for a date range so that I can reconcile.*  
**Acceptance Criteria**
- `GET /internal/v1/export/journals?from&to` and `.../balances` generate CSV/Parquet; large jobs delegated to Workers and stored in object storage with signed URLs.

### 3.8 Limits, Risk & Compliance
**US‑PAY‑070** — *As the Platform, I want per‑user daily and monthly withdrawal limits so that risk is controlled.*  
**Acceptance Criteria**
- Limits and cool‑downs from Config; violations return `422` with detail.

**US‑PAY‑071** — *As the Platform, I want deny‑listed accounts blocked from financial actions so that we comply with policy.*  
**Acceptance Criteria**
- Config `users.denyList` and `countries.denyList` enforced at mutation time.

**US‑PAY‑072** — *As the Platform, I want velocity checks for holds and conversions so that abuse is detected.*  
**Acceptance Criteria**
- Sliding window counts per user and per IP; exceeding thresholds → `429` with retry hints.

### 3.9 Observability & Reconciliation
**US‑PAY‑080** — *As Ops, I want metrics for holds, settlements, and payout latencies so that I can detect regressions.*  
**Acceptance Criteria**
- Prometheus metrics: `holds_created_total`, `settlements_total{outcome}`, `withdrawals_latency_bucket`, `conversion_rate_usage`.

**US‑PAY‑081** — *As Finance, I want nightly valuation reports so that we can reconcile treasury balances.*  
**Acceptance Criteria**
- Worker aggregates end‑of‑day balances, fetches reference prices from **Price Service**, computes valuations per currency, and writes a dated report to object storage.

**US‑PAY‑082** — *As Ops, I want structured logs and traces so that issues are debuggable.*  
**Acceptance Criteria**
- Pino logs with `requestId`, `userId`, `holdId`; OpenTelemetry spans across services.

### 3.10 Idempotency & Integrity
**US‑PAY‑090** — *As the Platform, I want all POSTs to be idempotent so that retries are safe.*  
**Acceptance Criteria**
- `Idempotency-Key` required on mutating POSTs; repeated calls return the first committed result.

**US‑PAY‑091** — *As the Platform, I want automatic reversal on partial failures so that the ledger never drifts.*  
**Acceptance Criteria**
- If a multi‑step settlement fails mid‑way, a compensating journal is written and the request is marked `reversed` with reason.

---

## 4) Edge Cases & Rules
- Holding exactly all available balance leaves zero spendable; further holds → `insufficient_funds`.
- Cancelled holds restore spendable immediately; settlement `loss` consumes the hold permanently.
- Conversion quotes expire; executing with an expired quote → `409 conflict`.
- Withdrawal cancel allowed only before approval; after `approved` state it requires staff intervention.
- Duplicate webhook events (future on‑ramp) are detected via provider event id and ignored.
- Treasury accounts cannot go negative; config validation at startup prevents invalid fee/rake bps.

---

## 5) Dependencies
- **Identity** — verifies session JWTs (user endpoints) and service JWTs (internal).
- **PlayHub** — creates holds and triggers settlements; supplies roomId and outcomes (including **CFB v1**).
- **Funding** — hold→capture for purchases; refunds use `cancel` settlement.
- **Escrow** — multi‑party holds and conditional release.
- **Campaigns** — rewards credit; idempotent by campaignId.
- **Price Service** — valuations for reports; not used for user conversions in MVP unless configured.
- **Workers** — executes payouts, exports, and nightly reconciliation.
- **Admin** — approvals (two‑person) and audits; manual credits and withdrawal approvals.
- **Config** — hot reload for fees, limits, treasury routing accounts, enabled flags.
- **Infra** — object storage, metrics, logs, traces.
- **Shared** — DTOs, headers, error envelope, idempotency helpers.

---

## 6) Non‑Functional Stories
**US‑NF‑PAY‑001** — *As a User, I want balance reads under 150 ms p95.*  
**US‑NF‑PAY‑002** — *As Ops, I want 99.95% availability for hold/settle endpoints.*  
**US‑NF‑PAY‑003** — *As Security, I want all money values stored as integers with currency precision and validated schemas.*  
**US‑NF‑PAY‑004** — *As Compliance, I want full auditability: every mutation has `requestId`, `actor`, `purpose`.*  
**US‑NF‑PAY‑005** — *As DevEx, I want OpenAPI and contract tests using shared DTOs.*

---

## 7) Traceability (Endpoints × Stories)
- `GET /v1/wallets/me/balances` → US‑PAY‑001  
- `GET /v1/wallets/me/activities` → US‑PAY‑060, US‑PAY‑021  
- `POST /internal/v1/holds` → US‑PAY‑010  
- `POST /internal/v1/settlements` → US‑PAY‑011, US‑PAY‑012, US‑PAY‑013, US‑PAY‑051  
- `POST /internal/v1/rewards` → US‑PAY‑050  
- `POST /v1/withdrawals` → US‑PAY‑030  
- `POST /v1/withdrawals/:id/cancel` → US‑PAY‑033  
- `POST /internal/v1/withdrawals/:id/approve` (Admin BFF) → US‑PAY‑031  
- `POST /v1/conversions` and `GET /v1/conversions/quote` → US‑PAY‑040, US‑PAY‑041  
- `GET /internal/v1/export/*` → US‑PAY‑061

---

### Definition of Ready (DoR)
- Story includes persona, goal, measurable acceptance criteria, and dependencies.  
- DTOs and ledger impacts identified; idempotency keys defined.  
- Config flags and limits referenced.

### Definition of Done (DoD)
- Unit and contract tests pass; journals reconcile to zero drift.  
- Metrics, logs, and traces in place; dashboards updated.  
- Admin flows and approvals exercised in staging.
