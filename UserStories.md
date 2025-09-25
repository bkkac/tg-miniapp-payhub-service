# UserStories.md

Repo: tg-miniapp-payhub-service
print:
SHA-256: cfa7fd2dbd8796c1967cabc2032bd06e24032123ce089f9afb1396bdba30efd5
Bytes: 15758

> Traceability: Maps to **SystemDesign.md — tg-miniapp-payhub-service** (notably §§ Architecture, 3 Responsibilities, 4 Data Model, 5 Interfaces, 6 Flows, 7 Security, 8 Reliability, 9 Observability, 10 Configuration).  
> Global Product Rules applied: Crypto UX, Badge & KYC gating, Free‑tier limits with FZ/PT overage, Per‑repo verification.

_Last updated: 2025-09-25 15:23 +07_

---

## Epics → Features → Stories

### Epic A — Accounts, Balances, and Ledger (Core Custody)

**Feature A1: Create platform account & base balances**
**Story A1.1** — *As a newly authenticated user, I want a Payhub account with balances in STAR, FZ, PT (and USDT for future on‑chain), so that I can deposit, convert, and pay for services.*  
**Acceptance Criteria (GWT)**
1. **Given** I sign in the WebApp, **when** Payhub receives a `POST /internal/v1/accounts/provision` from Identity, **then** an **Account** with sub‑ledgers for STAR, FZ, PT (and placeholder USDT) is created with zero balances.  
2. **Given** the call retries with the same `Idempotency-Key`, **when** it is processed, **then** the same Account is returned (`200`) and **no duplicate** ledger rows are written.  
3. **Given** Account exists, **when** I query `/v1/me/balances`, **then** I see available, pending, and held amounts per asset.

- **Roles & Permissions:** Any authenticated user (session JWT). Staff can provision bulk.  
- **Usage & Billing:** **Not metered**; provisioning is free.  
- **Data Touchpoints:** `Account(id, userId)`, `Balance(asset, available, pending, held)`, `JournalEntry` double‑entry.  
- **Cross‑Service:** Triggered by Identity, used by WebApp, PlayHub, Funding.  
- **State & Lifecycle:** `created → active → (suspended/closed)` for risk events.  
- **Security:** All mutations require user session or service JWT; audit trail per entry.  
- **Performance:** p95 balances < 80 ms; paginated ledger queries.

**Feature A2: Holds & Settlements for S2S**
**Story A2.1** — *As a service (PlayHub/Funding/Escrow), I want to place **holds** and later **settle** or **void** them so that funds are reserved for outcomes.*  
**AC**
1. **Given** `POST /internal/v1/holds` with `{accountId, asset, amount}` and idem key, **when** balance is sufficient, **then** **held** increases and a `holdId` is returned.  
2. **Given** the balance is insufficient, **when** the request arrives, **then** `409 insufficient_funds` is returned with remaining balance.  
3. **Given** a hold exists, **when** `POST /internal/v1/settlements` with `{holdId, outcome: win | loss | void}`, **then** funds move:  
   - `win`: move both players’ held funds to winner available (PlayHub), fees applied.  
   - `loss`: release loser hold to treasury (or counterparty).  
   - `void`: move held → available to original owner.  
4. **Given** idem repeat, **when** re‑called, **then** same `settlementId` is returned; no duplicate effects.

- **Metering:** **Free tier** includes up to **100 holds/month per service**; overage is billed to service owner org in **FZ/PT** (see Epic E).  
- **Data:** `Hold(id, accountId, asset, amount, status)`, `Settlement(id, outcome)`.  
- **Cross‑Service:** PlayHub, Funding, Escrow use S2S endpoints with service JWT.  
- **Observability:** metrics `hold_ok`, `settle_ok`, `insufficient_funds`, `idem_replay`.

---

### Epic B — Deposits, Withdrawals, Conversions

**Feature B1: Off‑chain deposit (STAR/FZ/PT)**
**Story B1.1** — *As a user, I want to deposit STAR/FZ/PT to my Payhub account so that I can spend in the app.*  
**AC**
1. **Given** I select **Deposit** and asset STAR/FZ/PT, **when** I confirm, **then** a deposit reference and QR (internal transfer instruction) are shown.  
2. **Given** a valid incoming credit is detected (admin or workers), **when** reconciliation runs, **then** a credit **JournalEntry** posts to my available balance.  
3. **Given** deposit is reversed by mistake, **when** staff corrects, **then** a compensating entry is written with audit.

- **Crypto UX:** show how to get STAR/FZ/PT, fees are **0** internal; warnings about scams.  
- **Metering:** free; not billed.  
- **Cross‑Service:** Admin/Workers reconciliation job.  
- **Observability:** `deposit_pending`, `deposit_posted`, age > SLA alert.

**Feature B2: External withdrawal (future on‑chain for USDT; off‑chain for MVP)**
**Story B2.1** — *As a user, I want to withdraw to my wallet/exchange with transparent fees and confirmations.*  
**AC**
1. **Given** I have the **Investor** badge (or lower limits), **when** I request withdrawal, **then** limits and KYC are enforced: tiered max per day/month.  
2. **Given** address and chain provided, **when** validation fails (format/chain mismatch), **then** I see inline errors and cannot submit.  
3. **Given** OTP/2FA enabled, **when** I confirm, **then** a **payout request** enters `pending_review` (MVP off‑chain).  
4. **Given** reviewer approves, **when** workers execute, **then** available balance decreases, status `completed`, receipt issued.  
5. **Given** on‑chain failure (future), **when** transaction fails or under‑funded gas, **then** status `failed` with reason; funds auto‑reversed.

- **Badges:** **Investor** required for higher limits; **Unverified** users capped.  
- **Metering:** **Free tier** 2 withdrawals/month; overage fee in FZ/PT (Epic E).  
- **Data:** `Payout(id, dest, chainId, amount, fee, status)`.  
- **Cross‑Service:** Identity (badge), Admin (review), Workers (execution), Price (fee est.).  
- **Security:** manual approval threshold; two‑person approval for large amounts.  
- **Localization:** fee and ETA in user currency with **GMT+7** timestamps.

**Feature B3: Convert balances (FX)**
**Story B3.1** — *As a user, I want to convert between STAR, FZ, and PT (and USDT later) so that I can pay for features.*  
**AC**
1. **Given** I choose `from=FZ, to=PT, amount`, **when** I preview, **then** the quote uses **Price Service** TWAP with spread and taxes (from Config).  
2. **Given** I accept the quote, **when** conversion posts, **then** two **JournalEntry** rows move funds; receipt minted.  
3. **Given** quote expires (t seconds), **when** I attempt to confirm, **then** I’m asked to refresh the quote.  
4. **Given** idem replay, **when** request repeats, **then** same conversion id returned.

- **Metering:** **Free tier** up to **N conversions/month**; overage charged in target asset (or FZ/PT).  
- **Cross‑Service:** Price Service, Config, Admin.  
- **Performance:** p95 quote < 150 ms; rate limit per user to avoid abuse.

---

### Epic C — Rewards & Credits

**Feature C1: Campaign rewards and airdrop credits**
**Story C1.1** — *As a user, I want to receive STAR/FZ/PT rewards from campaigns so that I can spend them across the app.*  
**AC**
1. **Given** Campaigns posts a reward to Payhub (`/internal/v1/credits`), **when** payload signature and quota validated, **then** a credit posts to my balance.  
2. **Given** duplicate reward id, **when** request repeats, **then** idempotent 200 with same credit id.  
3. **Given** fraud suspicion, **when** risk flags trigger, **then** reward lands in `pending_review` until staff decision.

- **Metering:** free to users; Campaigns org pays per credit event beyond allowance.  
- **Data:** `Credit(id, campaignId, asset, amount, status)`; `JournalEntry` credit.  
- **Cross‑Service:** Campaigns Service, Admin, Workers.

---

### Epic D — Statements, Invoices & Receipts

**Feature D1: Downloadable statements**
**Story D1.1** — *As a user, I want monthly statements so that I can reconcile my activity.*  
**AC**
1. **Given** month selection, **when** I generate, **then** a statement aggregates ledger entries with opening/closing balances and exports as PDF/CSV.  
2. **Given** timezone set, **when** timestamps are rendered, **then** they appear in **GMT+7** in the document.

**Feature D2: Receipts for operations**
**Story D2.1** — *As a user, I want receipts for holds, settlements, conversions, and withdrawals so that I have proof.*  
**AC:** receipts include hash of ledger rows, idem key, and signature; available for download and via email/Telegram message.

---

### Epic E — Quotas, Pricing & Overage (FZ/PT)

**Feature E1: Withdrawal quota & fees**
**Story E1.1** — *As a user, I want **2 free** withdrawals per month and pay a per‑withdrawal fee in **FZ/PT** thereafter.*  
**AC**
1. **Given** `free_limit=2` and `price=p` per withdrawal, **when** `used ≤ 2`, **then** I’m charged `0` and meter updates.  
2. **Given** `used > 2`, **when** I submit, **then** Payhub prompts to pay in **FZ/PT**; on success, the withdrawal proceeds; on failure, request is blocked and meter not incremented.  
3. **Given** I have prepaid credits, **when** I exceed the limit, **then** the fee deducts from the balance first.  
4. **Given** dunning rules, **when** payment fails repeatedly, **then** further withdrawals are throttled/suspended.

**Feature E2: Conversion quota**
**Story E2.1** — *As a user, I want up to **N** conversions/month free and pay per extra conversion in **FZ/PT**.*  
**AC** mirror E1 with `metric=conversion.count.monthly`.

**Feature E3: Service‑to‑service holds quota**
**Story E3.1** — *As a service owner, I want **100 free** holds/month with overage billed in **FZ/PT** to my org account.*  
**AC**
1. **Given** PlayHub exceeds free hold limit, **when** it calls `/internal/v1/holds`, **then** Payhub charges the org’s Payhub account before accepting.  
2. **Given** org account lacks FZ/PT, **when** overage charge fails, **then** request is rejected with `payment_required` and guidance to top up.

- **Data:** `Meter(orgId, metric, periodStart, used)`, `Invoice`, `Receipt`.  
- **Cross‑Service:** Admin (pricing), Config (limits), Workers (dunning & reminders).

---

### Epic F — Fraud, Risk & Compliance

**Feature F1: Risk rules and freezes**
**Story F1.1** — *As a risk analyst, I want to apply rules that automatically freeze accounts or transactions to reduce loss.*  
**AC**
1. **Given** velocity or blacklist triggers, **when** rule matches, **then** account state becomes `suspended`, pending staff review.  
2. **Given** a freeze, **when** a hold/withdrawal is attempted, **then** operation is blocked with reason and audit.  
3. **Given** manual override, **when** staff unfreezes, **then** state returns to `active` with audit entry.

**Feature F2: Badge/KYC gating for higher limits**
**Story F2.1** — *As a user, I want higher deposit/withdrawal limits unlocked by **Investor** badge.*  
**AC:** Identity introspection required; stale cache max 60s; failure → default to lowest safe limits.

---

### Epic G — Observability & SLOs

**Feature G1: Metrics, logs, traces**
**Story G1.1** — *As SRE, I want clear telemetry so that I can spot issues early.*  
**AC**
1. **Given** each operation, **when** it completes, **then** increments counters (`journal_write_ok`, `hold_ok`, `withdraw_ok`) and histograms (`latency_ms`).  
2. **Given** errors, **when** specific codes occur (409, 422, 429), **then** logs include `requestId`, `idemKey`, `accountId`, redacted PII.  
3. **Given** SLOs, **when** burn rate exceeds threshold, **then** Alertmanager pages the on‑call.

- **SLOs:** ledger write availability 99.95%; p95 API latency < 120 ms; reconciliation delay < 15 min.  
- **Security:** redact addresses and PII in logs; signed receipts.

---

## End‑to‑End Scenarios

### Scenario 1 — PlayHub match hold → settle (winner takes all)
**Preconditions:** Two users with ≥100 FZ, **Investor** badge required by PlayHub for stakes ≥ threshold.  
**Flow (PlayHub ↔ Payhub):**
1. PlayHub calls `POST /internal/v1/holds` for both players (100 FZ each).  
2. Both holds succeed → room created → match plays.  
3. Game reports winner to PlayHub → PlayHub calls `POST /internal/v1/settlements { outcome: win }` with both `holdId`s.  
4. Payhub moves **200 FZ** from holds to winner available; **7% rake** applied if configured; receipts issued.  
**Alternates:** hold fails → PlayHub rejects matchmaking; network retry with idem key; partial failure → settlement retries idempotently.

### Scenario 2 — Funding purchase hold → capture
**Pre:** User has ≥ amount in FZ/PT; **Investor** badge required by Funding for sale tier.  
**Flow:** Funding creates hold → on finalize/cutoff, Funding settles `win` to treasury account; updates purchase; receipts stored.  
**Errors:** idem replay returns same ids; insufficient funds → Funding surfaces error.

### Scenario 3 — Withdrawal over free limit with FZ payment
**Pre:** User already made 2 free withdrawals this month.  
**Flow:** User requests 3rd withdrawal → Payhub prompts fee in FZ/PT → user pays **in‑app** using available FZ → fee captured → withdrawal proceeds after review.  
**Edge:** fee capture fails → withdrawal blocked; dunning reminder.

### Scenario 4 — Conversion with quote expiry
**Pre:** User wants to convert 500 FZ → PT.  
**Flow:** Quote fetched from Price (T seconds validity) → user confirms after expiry → Payhub rejects with `quote_expired` → new quote required.  
**Edge:** TWAP provider down → `service_unavailable` with retry‑after.

---

## Data Touchpoints (Entities & Constraints)
- **Account**(id, userId, state).  
- **Balance**(accountId, asset, available, held, pending) — per asset.  
- **JournalEntry**(entryId, debitAccount, creditAccount, asset, amount, refType, refId, requestId, createdAt) — **double‑entry** invariant: sum(debits)=sum(credits).  
- **Hold**(holdId, accountId, asset, amount, status: active|settled|voided|expired).  
- **Settlement**(settlementId, holdId, outcome, feeBps, receiptId).  
- **Payout**(id, accountId, asset, amount, dest, chainId, fee, status).  
- **Credit/Reward**(id, campaignId, asset, amount, status).  
- **Meter/Invoice/Receipt** entities per billing spec.

**Idempotency:** All POSTs accept `Idempotency-Key`; ledger writes carry `requestId` and hash to detect duplicates.  
**Referential constraints:** Journal rows must reference a concrete business object (hold/settlement/conversion/payout).

---

## Roles & Permissions
- **User:** manage own balances, deposits, withdrawals, conversions.  
- **Service (PlayHub/Funding/Escrow/Campaigns):** S2S holds/settlements/credits.  
- **Admin/Finance:** reviews payouts, configures fees/limits/prices, views audits, performs adjustments.  
- **Risk:** freeze/unfreeze and rule management.

---

## Security & Compliance
- Auth: user session JWT and service JWT; mTLS optional.  
- AuthZ: capability checks per route; org scoping for services.  
- PII/KYC: rely on Identity for KYC; store minimal payout PII with encryption.  
- Anti‑fraud: velocity/risk rules; manual approvals; two‑person controls.  
- Receipts signed; configs verified (signed via tg‑miniapp‑config).

---

## Localization & Timezones
- UI shows fees, ETAs, and statements localized; timestamps in **GMT+7**.  
- API returns ISO 8601 UTC; client formats per locale.

---

## Observability & Rate Limits
- Per‑route counters and histograms.  
- Rate limits per user/org/service; 429 includes backoff hints.  
- Alerts: ledger mismatch, reconciliation delay, payout stuck, provider down.

---

## Assumptions & Open Questions
1. Exact free limits and prices (Admin/Config).  
2. Rake logic for PlayHub settlements (global vs per‑game override).  
3. On‑chain USDT rollout timeline; chain list; bridge and gas strategy.  
4. Refund policy and chargeback handling for off‑chain deposits.  
5. Maximum holds per account and hold TTL.

