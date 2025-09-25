# UserStories.md

Repo: tg-miniapp-payhub-service
print:
SHA-256: 4777a071c07bb9efffcdb6cc05b27b1d1b1d3f9bf29ef17efb509926f7624301
Bytes: 15844

> Traceability: Maps to **SystemDesign.md — tg-miniapp-payhub-service** (Ledger, Accounts, Holds/Settlements, Credits/Debits, Conversions, Deposits/Withdrawals, Webhooks, Security, Observability).  
> Global Product Rules applied: Crypto UX, Badge & KYC gating, Free‑tier limits with FZ/PT overage, Per‑repo verification.  
> MVP scope: **Off‑chain custody** for **STAR/FZ/PT**; on‑chain **USDT** deposits/withdrawals supported via custodial hot wallet with confirmations; future multi‑chain expansion prepared.

_Last updated: 2025-09-25 17:07 +07_

---

## Epics → Features → Stories

### Epic A — Accounts & Ledger (Double‑Entry)

**Feature A1: Create and manage accounts**
**Story A1.1** — *As the system, I want a double‑entry ledger with per‑user/org accounts so that balances are consistent and auditable.*  
**Acceptance Criteria (GWT)**
1. **Given** a new user/org, **when** Identity creates the subject, **then** Payhub provisions **Accounts** for STAR/FZ/PT/USDT with `status=active` and `currency` decimals.  
2. **Given** I query my balances, **when** I call `GET /v1/accounts/balances`, **then** I receive available, pending, and on‑hold for each currency.  
3. **Given** ledger invariants, **when** any journal is posted, **then** total debits equal total credits; otherwise the write is rejected and an alert is raised.

- **Data Touchpoints:** `Account(id, ownerType:user|org, currency, status)`, `Journal(id, rows[], idemKey, refType, refId)`.  
- **Observability:** metric `ledger.post.ok/error`; audit per journal with hash chain.

**Feature A2: Idempotent posting**
**Story A1.2** — *As an integrator, I want idempotent writes so that retries do not double‑charge users.*  
**AC**
1. **Given** `Idempotency-Key` header, **when** the same write is retried, **then** the previous result is returned with `x-idem-hit=true`.  
2. **Given** different payload with same key, **when** retried, **then** `409 idem_mismatch` is returned with canonical payload hash.

---

### Epic B — Holds & Settlements (Matchmaking, Funding, Escrow, CFB)

**Feature B1: Create hold**
**Story B1.1** — *As PlayHub/Funding/Escrow, I want to place a hold on a user balance so that funds are reserved before the outcome is known.*  
**AC**
1. **Given** a valid request `{userId, currency, amount, reason, ttl}`, **when** I call `POST /internal/v1/holds`, **then** a `Hold` is created with `status=active` and amount moved from `available` → `onHold` in the ledger.  
2. **Given** insufficient funds, **when** hold is attempted, **then** `409 insufficient_funds` is returned and no journal is posted.  
3. **Given** TTL expiry, **when** hold expires unused, **then** it is **voided** automatically and funds return to `available`.

**Feature B2: Settle hold (win/loss/split)**
**Story B1.2** — *As the outcome authority (PlayHub game, Escrow arbiter, Funding finalizer), I want to settle holds so that winners receive funds and losers forfeit.*  
**AC**
1. **Given** `status=active`, **when** `POST /internal/v1/settlements` with `{holdId, outcome: win|loss|split, payouts[], feeBps}` succeeds, **then** the ledger posts journals to move funds accordingly; `settlementId` is returned.  
2. **Given** split outcomes (e.g., Escrow 70/30), **when** provided, **then** multiple payout rows are posted atomically.  
3. **Given** idem replay, **when** settlement retried, **then** the same `settlementId` is returned; no duplicate payouts.

**Feature B3: Platform rake / fee capture**
**Story B1.3** — *As the platform, I want to capture a fee (e.g., **7%** CFB rake) so that revenue is booked consistently.*  
**AC:** fee debited from pot at settlement; credited to `PlatformRevenue` account; memo includes `sourceService` and `roomId|contractId`.

---

### Epic C — Credits, Debits & Rewards

**Feature C1: Credit user/org balances (rewards, refunds, airdrops)**
**Story C1.1** — *As Campaigns/Funding/Admin, I want to credit accounts so that users receive rewards and refunds.*  
**AC**
1. **Given** a valid credit request with idem key, **when** `POST /internal/v1/credits` is called, **then** the ledger posts a journal to increase `available` and returns a `receiptId`.  
2. **Given** budget shortfall for org funding (optional reservation), **when** credit is requested, **then** `402 payment_required` or `awaiting_budget` is returned with retry guidance.  
3. **Given** compliance holds, **when** account is flagged, **then** credit posts to `pending` balance until review.

**Feature C2: Debit (service charges, overage)**
**Story C1.2** — *As a service, I want to debit for overage so that metered usage is monetized.*  
**AC:** `POST /internal/v1/debits` with idem key; balance checks; receipt; failure → `402 payment_required` and service should throttle.

---

### Epic D — Conversions & Quotes (FX)

**Feature D1: Quote and confirm conversion**
**Story D1.1** — *As a user, I want to convert between **STAR/FZ/PT/USDT** so that I can pay in my preferred currency.*  
**AC**
1. **Given** I request `POST /v1/conversions/quote { from, to, amountFrom }`, **when** **Price Service** returns TWAP/spot, **then** I get `quoteId`, `rate`, `expiresAt`, and fees.  
2. **Given** I confirm within `expiresAt`, **when** I `POST /v1/conversions/confirm { quoteId }`, **then** funds move atomically (debit from → credit to).  
3. **Given** expiry or price drift beyond tolerance, **when** I confirm, **then** `409 quote_expired` is returned and a new quote is suggested.

- **Crypto UX:** show network fees for USDT chain when withdrawing later; decimals and rounding per currency.  
- **Metering:** `conversion.quote.read` and `conversion.confirm.write` billed per user.

---

### Epic E — Deposits & Withdrawals (On‑chain USDT + Off‑chain STAR/FZ/PT)

**Feature E1: Deposit USDT (on‑chain)**
**Story E1.1** — *As a user, I want to deposit **USDT** so that I can fund my balance.*  
**AC**
1. **Given** I select a network (e.g., Tron/Ethereum), **when** I request a deposit address, **then** a unique address is shown with risk warning and min amount; address is bound to my account.  
2. **Given** I send funds, **when** the transaction reaches **N confirmations**, **then** Workers recognize it, credit **USDT** to my `available`, and issue a receipt.  
3. **Given** low amount < min or wrong network, **when** detected, **then** status `under_minimum` or `unsupported_network`; support path provided.

**Feature E2: Withdraw USDT (on‑chain)**
**Story E1.2** — *As a user, I want to withdraw **USDT** to my wallet so that I can self‑custody.*  
**AC**
1. **Given** sufficient available balance and KYC level, **when** I submit `{network, address, amount}`, **then** a `WithdrawalRequest` is created `pending_review` or `queued`.  
2. **Given** risk checks (velocity, sanctions, address risk), **when** flagged, **then** status `on_hold` and compliance review required.  
3. **Given** approval, **when** hot wallet signs and broadcasts, **then** `txHash` is stored; final status `paid` after confirmations; fees debited separately.  
4. **Given** idem replay, **when** same key used, **then** the same `withdrawalId` is returned.

**Feature E3: STAR/FZ/PT deposits/withdrawals (off‑chain)**
**Story E1.3** — *As a user, I want to move **STAR/FZ/PT** within the platform so that I can use them across services.*  
**AC:** deposits are typically credits from services (Campaigns/Funding/Trading); withdrawals are internal transfers to other users/orgs or redemption endpoints; external chain bridges are future scope.

---

### Epic F — Payouts & Treasury

**Feature F1: Project treasury settlement**
**Story F1.1** — *As Funding, I want to settle sale proceeds to a project treasury account so that projects are paid accurately.*  
**AC**
1. **Given** Funding finalize, **when** it calls settlements with treasury `orgAccountId`, **then** the full pot is credited minus platform fees, with receipt.  
2. **Given** multi‑currency sales, **when** configured, **then** optional auto‑conversion occurs into the treasury’s primary currency at confirm time.

**Feature F2: Game/CFB payouts**
**Story F1.2** — *As PlayHub, I want pot payouts and rake capture so that matches/bets settle fairly.*  
**AC:** split payouts supported; 7% rake example captured; receipts attached to `roomId`/`betId` and emitted as events.

---

### Epic G — Webhooks & Events

**Feature G1: Outgoing webhooks**
**Story G1.1** — *As a consuming service, I want webhooks for settlements, credits, and withdrawals so that I can update my state.*  
**AC**
1. **Given** I register a webhook with secret, **when** events occur, **then** Payhub delivers signed payloads with retries and DLQ on repeated failure.  
2. **Given** rate limits, **when** exceeded, **then** exponential backoff and `retry-after` headers apply.

**Feature G2: Incoming signed calls (S2S)**
**Story G1.2** — *As Payhub, I want to accept only signed internal calls so that only trusted services can move funds.*  
**AC:** JWT with service audience + HMAC of body; mismatch → `401/403`.

---

### Epic H — Quotas, Pricing & Overage (FZ/PT)

**Feature H1: Free limits & paid overage**
**Story H1.1** — *As a user/service, I want **free** usage up to limits and pay **FZ/PT** beyond them.*  
**AC**
1. **Given** admin sets `free_limit_transfers/day`, `free_limit_conversions/day`, `free_limit_withdrawals/month`, **when** my usage ≤ free limit, **then** no charge; meter updates.  
2. **Given** I exceed a limit, **when** I continue, **then** I’m prompted to pay in **FZ/PT** (user) or org is charged (service).  
3. **Given** prepaid balance or coupon, **when** charges occur, **then** deductions use prepaid first.  
4. **Given** repeated payment failure, **when** dunning flows trigger, **then** my non‑essential actions are throttled until resolved.

- **Meter Keys:** `transfer.create.day`, `conversion.confirm.day`, `withdrawal.create.month`, `webhook.deliver.day` (per org).  
- **Cross‑Service:** **Config/Admin** for pricing; **Workers** for dunning and reminders.

---

### Epic I — Roles, Permissions, Badges & KYC

**Feature I1: Badge/KYC gates**
**Story I1.1** — *As a platform, I want to gate high‑risk actions so that compliance is maintained.*  
**AC**
1. **Given** withdrawals over threshold or cumulative exposures, **when** user lacks **Investor** (or KYC L2) badge, **then** `403 badge_required` with CTA.  
2. **Given** expired/suspended badge, **when** mutation attempted, **then** blocked with reason; audit written.  
3. **Given** active badge, **when** action succeeds, **then** `badgeId` recorded in audit and receipt.

**Feature I2: Roles**
**Story I1.2** — *As an operator, I want roles so that duties are separated.*  
**AC:** roles include `treasury_admin` (hot wallet ops), `compliance_officer`, `auditor` (read‑only), `service_consumer`, `user`.

---

## End‑to‑End Scenarios

### Scenario 1 — PlayHub match settle with 7% rake
**Preconditions:** Two players each hold 100 FZ; PlayHub created holds; winner determined.  
**Steps:** PlayHub calls settlement → Payhub moves 200 FZ pot: 186 FZ to winner, 14 FZ to `PlatformRevenue` (7%); receipts emitted; PlayHub updates UI.  
**Errors:** settlement retry with idem → same `settlementId`; ledger invariant failure → alert + rollback.

### Scenario 2 — Funding finalize to treasury (with auto‑convert)
**Pre:** Sale in FZ, treasury prefers USDT.  
**Steps:** Funding finalizes → Payhub converts FZ→USDT via Quote→Confirm → credits org treasury → receipt sent.  
**Edge:** quote expired → Funding re‑quotes; conversion failure → transaction aborted and retried.

### Scenario 3 — USDT deposit & STAR purchase
**Pre:** User requests TRON address; sends 50 USDT.  
**Steps:** Workers see N confirmations → credit 50 USDT → user converts to STAR → buys in Funding.  
**Edge:** under‑min deposit → support flow; wrong chain → flagged and held for manual review.

### Scenario 4 — Escrow split settlement
**Pre:** Dispute resolved 70/30.  
**Steps:** Escrow calls split settlement → Payhub pays 70% to buyer, 30% to seller (or vice versa) and captures fee; idempotent; receipts recorded.

### Scenario 5 — Overage charge for conversions
**Pre:** Free daily conversions 10; user confirms 11th.  
**Steps:** Payhub checks meter → charges **p FZ/PT** → if paid, conversion proceeds; if not, `402 payment_required` and conversion blocked.

---

## Data Touchpoints & Events

**Entities**
- `Account`, `JournalRow`, `Journal`, `Receipt`  
- `Hold(id, accountId, amount, currency, status, ttl)`  
- `Settlement(id, holdId, outcome, payouts[], feeBps)`  
- `Credit/Debit`  
- `ConversionQuote(id, from, to, amountFrom, rate, expiresAt, tolerance)` → `Conversion(id, quoteId, status)`  
- `DepositAddress`, `DepositReceipt`  
- `WithdrawalRequest(id, network, address, amount, fee, status)`  
- `Meter`, `Invoice`, `Coupon`

**Events & Topics**
- `payhub.hold.created/settled/voided`  
- `payhub.settlement.completed`  
- `payhub.credit.credited/failed`  
- `payhub.conversion.quoted/confirmed/expired`  
- `payhub.withdrawal.requested/approved/paid/failed`  
- Billing: `billing.overage.charged/failed`

**Idempotency & Constraints**
- All mutating POSTs require `Idempotency-Key`.  
- Journals are append‑only; monthly closing snapshots; reconciliation jobs.  
- Withdrawals one‑at‑a‑time per user to avoid nonce collisions; backoff on chain RPC errors.

---

## Security & Compliance
- **AuthN/Z:** user session JWT; service JWT with mTLS for S2S; signed webhooks (HMAC + timestamp).  
- **Secrets:** hot wallet keys in HSM/KMS; addresses derived per user; address books whitelisted per withdrawal.  
- **AML/Risk:** sanctions checks, address risk scoring, velocity limits; freeze via Identity hook.  
- **PII:** only necessary KYC linkages; encrypt at rest; strict access controls.  
- **Audit:** append‑only with hash chain; export for external auditors.

---

## Localization & Timezones
- All user‑visible times shown in **GMT+7**; API operates in UTC.  
- i18n for receipts, error codes, and prompts.

---

## Observability & SLOs
- Metrics: ledger post latency, hold/settlement success rate, conversion quote latency, withdrawal confirmation time.  
- Alerts: ledger invariant failures, webhook DLQ, chain RPC error spikes.  
- **SLOs:** journal post p95 < 50 ms; hold create p95 < 80 ms; withdrawal broadcast within 5 min p95.

---

## Mandatory Badge/KYC & Quota Blocks

### A) Badge acquisition (template)
**Story**: As a user, I want to request the **Investor** badge so that I can **withdraw above threshold** and access higher limits.  
**AC (GWT)** — follow global template (KYC, wallet proof, approval, expiry).

### B) Gated action enforcement (template)
**Story**: As a user, I want to **withdraw or perform high‑value transfers** only if I hold the **Investor** badge.  
**AC (GWT)** — block when missing/expired; record `badgeId` on success.

### C) Free limit & paid overage (template)
**Story**: As a user/service, I want to use **Payhub** within free limits, and pay in **FZ/PT** if I exceed them.  
**AC (GWT)** — apply to `transfer.create.day`, `conversion.confirm.day`, `withdrawal.create.month`, `webhook.deliver.day` as defined above.

---

## Assumptions & Open Questions
1. Final list of supported USDT networks and confirmation counts.  
2. Exact tolerance for conversion quote drift and FX fee structure.  
3. Whether platform rake (e.g., 7% CFB) is inclusive or extra and who pays.  
4. Daily/monthly free limits and prices (from Config/Admin).  
5. Policy for under‑min or wrong‑chain deposits (auto‑return vs manual case).

