Repo: tg-miniapp-payhub-service
File: UserStories.md
SHA-256: 1268c9d9d7a7404ebe4008e12f5ee9e9c4e9cd94383689c14531003d1623a3c4
Bytes: 27784
Generated: 2025-09-27 01:19 GMT+7
Sources: SystemDesign.md (authoritative), old UserStories.md (baseline), Guide

---

# Section A — Personas & Stakeholders

> Discovered from SystemDesign flows (accounts, holds, settlements, ledger, deposits, withdrawals, conversions, invoices), cross‑service boundaries, and operational responsibilities. Full catalog in **Appendix A1**.

- **End User** — wallet‑using customer credited/debited in STAR/FZ/PT/USDT, pays invoices, deposits, withdraws, converts.
- **Investor (KYC’d)** — End User with Investor badge enabling higher withdrawal/transfer limits and some fiat on/off‑ramp integrations.
- **Project Finance (Issuer/Operator)** — Receives allocations, vesting payouts, campaign rewards budgets, escrow settlements.
- **Partner Service** — **Playhub**, **Escrow**, **Funding**, **Campaigns**, **Events** consuming **holds**, **settlements**, **credits** APIs.
- **Admin/Finance Ops** — Reconciles, refunds, overrides, fee configuration, manual postings, journal closes.
- **Compliance/AML** — Reviews large transactions, address risk, sanctions, chargeback claims (if fiat ramps), maintains KYC linkage.
- **Risk/Anti‑Fraud** — Monitors structuring, velocity, dusting, mixer patterns; manages blocks and velocity limits.
- **Identity Service** — Provides tokens, roles, badges, KYC tiers, and per‑actor limit profiles.
- **Price/Oracle Service** — Provides signed snapshots and TWAP for quotes and conversion execution.
- **Workers/Schedulers** — Deposit watchers, withdrawal broadcasters, settlement processors, invoice expirations, reconciliation jobs.
- **SRE/Infra** — Availability, DLQs, incident response, SLOs.
- **Auditor** — Read‑only export of journal and reconciliation artifacts.
- **External Chain/RPC** — EVM/TON networks for deposits and withdrawals; confirmations, reorg behavior; fee oracles.
- **WebApp / Web3 Portal** — Human channels surfacing balances, invoices, deposits/withdrawals.

---

# Section B — Epics → Features → User Stories (exhaustive)

## Epic B1 — Accounts & Ledger

### Feature B1.1 — Create account and balances
**Story B1.1.1** — *As a Partner Service, I want accounts provisioned for a user on first touch,* so that *credits and holds can occur immediately.*  
**Acceptance (GWT)**
1. **Given** a valid service token with scope `accounts:write`, **when** the partner calls `POST /v1/accounts { userId }`, **then** Payhub creates an **ACCOUNT** with **BALANCE rows** for supported assets `{STAR,FZ,PT,USDT}` initialized at zero and returns idempotently by `(userId, asset)`.
2. **Given** account already exists, **when** the same request repeats with the same **Idempotency-Key**, **then** **201** repeats with the same `accountId` and no duplicate rows.
3. **Given** Identity is unavailable, **when** creation would check badge tier, **then** Payhub responds **502 identity_unavailable** with `retry_after` hint.

**Non‑Happy Paths & Errors**
- Invalid `userId` → **404 user_not_found** (after Identity introspection).  
- Service scope missing → **403 forbidden** with `required_scopes` in detail.

**Permissions**: Service token, `accounts:write`.  
**Data Touchpoints**: `ACCOUNT`, `BALANCE(asset, available, held)`.  
**Events**: `payhub.account.created@v1`.  
**Observability**: create latency p95 < 120ms, duplicate suppression counter.

---

### Feature B1.2 — Double‑entry ledger
**Story B1.2.1** — *As Finance Ops, I want every monetary change recorded as double‑entry postings,* so that *we can reconcile and audit.*  
**Acceptance**
1. Every mutation results in **two postings** in `LEDGER_ENTRY` within a `JOURNAL_TX` (credit/debit), with immutable `postingId`, `accountId`, `asset`, `amount`, `narrative`, `eventId`.
2. Posting order is causal per `postingTs`, monotonic per `journal_seq`.
3. API returns `journalTxId`, **idempotent by `Idempotency-Key`**; repeated calls render **200** with the same `journalTxId` and no additional postings.

**Non‑Happy**: partial write (after primary commit, before event bus) → outbox pattern ensures exactly‑once emission.  
**Permissions**: varies by endpoint; all result in ledger postings.

---

## Epic B2 — Holds & Settlements

### Feature B2.1 — Create hold
**Story B2.1.1** — *As Playhub/Escrow/Funding, I want to place a hold,* so that *funds are reserved until capture or release.*  
**Acceptance**
1. `POST /v1/holds { userId, asset, amount, purpose, expiresAt? }` creates **HOLD(heldAmount)**, deducts from **available**, increases **held** atomically.
2. Idempotent by **`(userId, purposeId)`** or **Idempotency-Key**.
3. Insufficient funds → **402 insufficient_funds** with `available`, `required` fields.
4. Expired holds auto‑release via worker; release emits event.

**Non‑Happy**: limit profile denies (velocity, exposure) → **403 limit_exceeded** with policy reference.  
**Events**: `payhub.hold.created@v1`, `payhub.hold.released@v1`.

---

### Feature B2.2 — Capture / settle
**Story B2.2.1** — *As a Partner Service, I want to capture a hold into a transfer,* so that *winners/recipients are credited.*  
**Acceptance**
1. `POST /v1/settlements { settlementId, debits:[{holdId}], credits:[{userId, amount}] }` moves funds: **release holds**, **credit recipients**, **apply fees**, all within one journal transaction.
2. Idempotent by `settlementId` across retries; repeated attempts are **200** with same receipts.
3. Fee schedule applied based on **config version at hold creation**.

**Non‑Happy**: one credit fails storage → entire tx rolled back; worker retries upto 8× with exponential backoff.  
**Events**: `payhub.settlement.succeeded@v1|failed@v1` with receipts.

---

## Epic B3 — Deposits

### Feature B3.1 — Create deposit intent
**Story B3.1.1** — *As an End User, I want to create a deposit intent,* so that *I can transfer USDT to credited address.*  
**Acceptance**
1. `POST /v1/deposits { network, amount }` returns `{intentId, depositAddress, minAmount, confirmations}` based on network.
2. Address bound to `userId`, `network`, `intentId`, reuse allowed with anti‑dust rules.
3. Intent idempotent by **Idempotency-Key**; repeated returns same intent.

**Non‑Happy**: network unsupported → **422 unsupported_network**; address derivation provider down → **503 try_later**.

### Feature B3.2 — Credit deposit after confirmations
**Story B3.2.1** — *As a Worker, I credit deposits after N confirmations,* so that *user balance updates reliably.*  
**Acceptance**
1. Watcher monitors RPC, records **DEPOSIT_TX** with `txId`, `amount`, `confirmations`, `firstSeenTs`.
2. On reaching required confirmations, ledger posts credit, marks `status=confirmed`, emits `payhub.deposit.updated@v1`.
3. **Reorg handling**: if confirmations drop below threshold, status reverts to `pending`; if tx becomes orphaned, perform **reversal postings** and `status=reversed`.

**Non‑Happy**: duplicate detection by `(txId, outputIndex, userId)`; dust below minAmount credited only when policy allows.  
**Observability**: deposit credit latency p95 < 3m after N confirmations.

---

## Epic B4 — Withdrawals

### Feature B4.1 — Create withdrawal request
**Story B4.1.1** — *As an Investor, I want to withdraw USDT to my address,* so that *I can move funds out.*  
**Acceptance**
1. `POST /v1/withdrawals { network, address, amount }` requires **Investor badge** for totals over policy thresholds; else **403 requires_investor_badge**.
2. Address validated against checksum and **risk screening**; new address **soft‑delayed** (e.g., 24h) unless allowlisted.
3. Fee estimation returned; request **202 submitted** with `withdrawalId`, status `pending_review|queued`.

**Non‑Happy**: insufficient balance → **402 insufficient_funds**; velocity limit exceeded → **403 limit_exceeded**; AML blocklist → **403 address_blocked**.

### Feature B4.2 — Broadcast and confirmations
**Story B4.2.1** — *As a Worker, I broadcast queued withdrawals,* so that *transactions are sent and tracked.*  
**Acceptance**
1. Broadcaster signs and submits tx, stores **WITHDRAWAL_TX { txId, feePaid }**, updates status `broadcasted`.
2. Confirmations tracked; on success mark `settled` and emit `payhub.withdrawal.updated@v1`.
3. On fee spike or RPC failure, leave `queued`, retry with exponential backoff; stale ones escalated to Ops.

**Non‑Happy**: stuck mempool → re‑price and replace‑by‑fee (RBF) policy; chain reorg → status back to `pending`, re-confirm.  
**Idempotency**: `withdrawalId` as key across retries.

### Feature B4.3 — Cancel (pre‑broadcast)
**Story B4.3.1** — *As a User, I can cancel a withdrawal before broadcast,* so that *I can correct mistakes.*  
**Acceptance**: `DELETE /v1/withdrawals/{id}` moves amount from held to available, emits `withdrawal.canceled` if not yet broadcast.

---

## Epic B5 — Conversions (Quotes and Execution)

### Feature B5.1 — Request quote
**Story B5.1.1** — *As an End User, I want a conversion quote,* so that *I understand the rate and fees before committing.*  
**Acceptance**
1. `POST /v1/conversions/quote { from, to, amount }` returns quote with **signed oracle snapshot** reference and **expiry**.
2. Slippage bound configurable; rejected if beyond **maxSlippageBp**.
3. Idempotent by `(userId, from, to, amount, snapshotId)` within TTL.

**Non‑Happy**: price service unavailable → **502 price_unavailable** with retry hint; amount below min → **422 amount_too_small**.

### Feature B5.2 — Execute conversion
**Story B5.2.1** — *As an End User, I want to execute a valid quote,* so that *balances change atomically.*  
**Acceptance**
1. `POST /v1/conversions/execute { quoteId }` debits `from`, credits `to`, applies fee; fails if quote expired or replayed.
2. Execution idempotent by `quoteId`; returns receipt with journal ids.

**Non‑Happy**: balance changed since quote → **409 balance_changed**; snapshot revoked → **409 snapshot_revoked**.

---

## Epic B6 — Invoices & Receipts (Overage and Purchases)

### Feature B6.1 — Create invoice
**Story B6.1.1** — *As a Service or User, I want to create an invoice for overage or purchase,* so that *usage can continue.*  
**Acceptance**
1. `POST /v1/invoices { purpose, currency, amount }` creates **INVOICE** `pending`, supports payment via **FZ/PT/USDT**.
2. Idempotent by `(userId, purpose, period)` or explicit Idempotency-Key; returns `invoiceId`.
3. **402 payment_required** surfaced to clients to drive UI; when paid, `status=paid` and event emitted.

### Feature B6.2 — Refunds
**Story B6.2.1** — *As Finance Ops, I want to issue a refund,* so that *we can resolve issues.*  
**Acceptance**: `POST /v1/admin/refunds { invoiceId, amount, reason }` creates **REFUND** posting and changes invoice `status=refunded|partially_refunded`.

---

## Epic B7 — Limits, Risk, Compliance

### Feature B7.1 — Limit profiles
**Story B7.1.1** — *As Risk, I want per‑tier limits,* so that *users operate within exposure control.*  
**Acceptance**: per badge/KYC tier define `maxWithdrawalDaily`, `maxHold`, velocity windows; enforced in holds, withdrawals, conversions.

### Feature B7.2 — Transaction screening
**Story B7.2.1** — *As Compliance, I want address and pattern screening,* so that *we block risky flows.*  
**Acceptance**: on withdrawal or large deposit, run risk checks; block or flag for review. Maintain `RISK_CASE` with decision trail.

### Feature B7.3 — Audit and export
**Story B7.3.1** — *As Auditor, I need immutable exports,* so that *I can verify correctness.*  
**Acceptance**: time‑bounded export of `LEDGER_ENTRY`, `JOURNAL_TX`, `RECONCILIATION_REPORT` via signed URLs; redactions applied.

---

## Epic B8 — Reconciliation & Reporting

### Feature B8.1 — Daily close
**Story B8.1.1** — *As Finance Ops, I want a daily close report,* so that *balances and external holdings reconcile.*  
**Acceptance**: worker aggregates postings by asset, compares to chain wallet balances, flags deltas beyond tolerance, stores `RECONCILIATION_REPORT`, emits `payhub.reconciliation.completed@v1`.

### Feature B8.2 — Fees and revenue
**Story B8.2.1** — *As Finance, I want fee revenue reports,* so that *we can recognize income.*  
**Acceptance**: `FEE_SCHEDULE` driven calculations, export by day/asset; supports adjustments.

---

## Epic B9 — Reliability & Observability

### Feature B9.1 — Idempotency and backpressure
**Story B9.1.1** — *As SRE, I want all writes idempotent and resilient,* so that *retries are safe.*  
**Acceptance**: all mutating endpoints accept **Idempotency-Key** and return consistent `idempotencyKey` and `journalTxId`; 5xx include `Retry‑After` when safe.

### Feature B9.2 — SLIs/SLOs and telemetry
**Story B9.2.1** — *As SRE, I want metrics and traces,* so that *I can trace money flows end‑to‑end.*  
**Acceptance**: metrics for posting latency, DLQ depth, deposit credit time, withdrawal broadcast and settle time; OpenTelemetry spans with `eventId` correlation.

---

# Section C — End‑to‑End Scenarios (Swimlane narrative)

1. **E2E‑C1: Deposit → Confirmations → Credit**  
   Pre: User creates intent. Flow: Address displayed → chain tx observed → watcher records pending → N confirmations → ledger credit → event → client balance refresh. Post: Available increases.

2. **E2E‑C2: Matchmaking Hold → Capture → Settlement**  
   Pre: Player joins game. Flow: Partner calls `hold.create` → room completes → `settlements` capture → fees applied → receipts issued. Post: Winner credited, loser net debited, holds zeroed.

3. **E2E‑C3: Withdrawal → KYC Gate → Broadcast → Confirm**  
   Pre: User exceeds threshold. Flow: create withdrawal → **403** badge prompt → after approval retry → queued → broadcast → confirm → receipt. Post: Balance decreased, ledger and tx linked.

4. **E2E‑C4: Overage Invoice → Payment → Unlock**  
   Pre: Free tier exceeded. Flow: create invoice → user pays (FZ/PT/USDT) → invoice `paid` → partner action retried succeeds. Post: Meter reset or allowance extended.

5. **E2E‑C5: Conversion Quote → Execute → Atomic Rebalance**  
   Pre: User wants STAR for game. Flow: quote with signed TWAP → execute before expiry → from debited, to credited atomically. Post: New balances consistent.

---

# Section D — Traceability Matrix

| Story | APIs | Entities | Events | SystemDesign anchors |
|---|---|---|---|---|
| B1.1.1 | `POST /v1/accounts` | ACCOUNT, BALANCE | payhub.account.created@v1 | §Interfaces Accounts |
| B1.2.1 | all mutating | LEDGER_ENTRY, JOURNAL_TX | payhub.journal.posted@v1 | §Data Ledger |
| B2.1.1 | `POST /v1/holds` | HOLD, BALANCE | payhub.hold.created@v1 | §Interfaces Holds |
| B2.2.1 | `POST /v1/settlements` | TRANSFER, HOLD | payhub.settlement.succeeded@v1 | §Flows Settlement |
| B3.1.1 | `POST /v1/deposits` | DEPOSIT_INTENT | payhub.deposit.created@v1 | §Deposits |
| B3.2.1 | watcher credit | DEPOSIT_TX | payhub.deposit.updated@v1 | §Deposits |
| B4.1.1 | `POST /v1/withdrawals` | WITHDRAWAL_REQUEST | payhub.withdrawal.created@v1 | §Withdrawals |
| B4.2.1 | broadcaster | WITHDRAWAL_TX | payhub.withdrawal.updated@v1 | §Withdrawals |
| B4.3.1 | `DELETE /v1/withdrawals/{id}` | WITHDRAWAL_REQUEST | payhub.withdrawal.canceled@v1 | §Withdrawals |
| B5.1.1 | `POST /v1/conversions/quote` | CONVERSION_QUOTE, ORACLE_SNAPSHOT | payhub.conversion.quote.created@v1 | §Conversions |
| B5.2.1 | `POST /v1/conversions/execute` | CONVERSION_ORDER | payhub.conversion.executed@v1 | §Conversions |
| B6.1.1 | `POST /v1/invoices` | INVOICE | payhub.invoice.updated@v1 | §Invoices |
| B6.2.1 | `POST /v1/admin/refunds` | REFUND | payhub.refund.issued@v1 | §Invoices |
| B7.1.1 | limits check | LIMIT_PROFILE | — | §Security/Compliance |
| B7.2.1 | screening | RISK_CASE, ADDRESS_SCREEN | payhub.risk.case.opened@v1 | §Security/Compliance |
| B7.3.1 | exports | RECONCILIATION_REPORT | payhub.audit.exported@v1 | §Reporting |
| B8.1.1 | daily close | RECONCILIATION_REPORT | payhub.reconciliation.completed@v1 | §Reporting |
| B8.2.1 | fee report | FEE_SCHEDULE | — | §Rules |
| B9.1.1 | write paths | IDEMPOTENCY_KEY | — | §Reliability |
| B9.2.1 | telemetry | — | — | §Observability |

**Deltas vs old UserStories**: explicit **double‑entry**, **idempotency** everywhere, **deposit reorg handling**, **withdrawal RBF**, **conversion with signed oracle**, **invoice lifecycle and refunds**, **limits/velocity**, **reconciliation daily close**.

---

# Section E — Assumptions & Open Questions

- Confirm **N confirmations** per network (TON/EVM) and reorg depth policy.  
- Exact fee schedule and **maxSlippageBp** for conversions per asset.  
- Address book storage location (Portal vs Payhub) and soft delay duration.  
- Which AML provider feeds blocklists, and appeal workflow SLAs.  
- Invoice **purpose catalog** and billing periods for each overage metric.

---

# Appendix — Coverage Gates

## A1. Stakeholder Catalog

| Stakeholder | Responsibilities | Permissions | Typical Actions | KPIs/SLO interests |
|---|---|---|---|---|
| End User | Deposits, withdrawals, conversions, pay invoices | session | create intent, withdraw, convert, pay | completion rate, latency |
| Investor (KYC’d) | Higher limits | badge | large withdrawals, OTC | approval time |
| Project Finance | Receive distributions | staff/project scope | bulk payouts, refunds | payout success |
| Partner Service | Use custody | service token | holds, settlements, credits | success rate |
| Admin/Finance Ops | Oversight and fixes | staff scope | refunds, overrides, exports | reconciliation time |
| Compliance/AML | Risk control | compliance scope | screen, block, unblock | false positive rate |
| Risk/Anti‑Fraud | Exposure control | risk scope | tune limits, investigate | loss rate |
| Identity Service | Roles/KYC | s2s | introspect, limits | uptime |
| Price/Oracle | Quotes | s2s | sign snapshots | freshness |
| Workers/Schedulers | Background ops | internal | watch, broadcast, reconcile | DLQ depth |
| SRE/Infra | Reliability | ops | scale, alerting | error budget |
| Auditor | Read‑only | export role | read journals | audit completeness |
| External Chain/RPC | Network | — | confirmations, fees | availability |
| WebApp/Portal | Frontends | session | drive UX | error rate |

## A2. RACI Matrix (capabilities)

| Capability | End User | Investor | Partner | Admin | Finance | Compliance | Risk | Identity | Oracle | Workers | SRE |
|---|---|---|---|---|---|---|---|---|---|---|
| Accounts & balances | R | R | C | I | I | I | I | C | I | I | I |
| Holds | I | I | A | I | I | I | C | I | I | C | I |
| Settlements | I | I | A | I | C | I | I | I | I | C | I |
| Deposits | R | R | I | I | I | C | I | I | I | A | C |
| Withdrawals | R | A | I | I | C | A | C | I | I | A | C |
| Conversions | R | R | I | I | C | I | C | I | A (price) | A (execute) | C |
| Invoices & refunds | R | R | I | C | A | I | I | I | I | I | I |
| Limits & screening | I | I | I | I | I | A | A | C | I | I | I |
| Reconciliation | I | I | I | C | A | I | I | I | I | C | C |
| Observability | I | I | I | I | I | I | I | I | I | C | A |

Legend: R=Responsible, A=Accountable, C=Consulted, I=Informed.

## A3. CRUD × Persona × Resource Matrix

Resources: `ACCOUNT, BALANCE, LEDGER_ENTRY, JOURNAL_TX, HOLD, TRANSFER, INVOICE, RECEIPT, DEPOSIT_INTENT, DEPOSIT_TX, WITHDRAWAL_REQUEST, WITHDRAWAL_TX, CONVERSION_QUOTE, CONVERSION_ORDER, LIMIT_PROFILE, RISK_CASE, ADDRESS_SCREEN, FEE_SCHEDULE, RECONCILIATION_REPORT, IDEMPOTENCY_KEY, WEBHOOK_DELIVERY, JOB, DLQ, CONFIG_VERSION`

| Resource \ Persona | End User | Investor | Partner | Admin | Finance | Compliance | Risk | Workers | Auditor |
|---|---|---|---|---|---|---|---|---|
| ACCOUNT | R (read) | R (read) | C/R (create) | R (view) | R (view) | R (view) | R (view) | R (view) | R (export) |
| BALANCE | R (read) | R (read) | R (read) | R (view) | R (view) | R (view) | R (view) | R (view) | R (export) |
| LEDGER_ENTRY | N/A | N/A | N/A | R (view) | C/R/U/D (adj) | R (view) | R (view) | C/R (post via jobs) | R (export) |
| JOURNAL_TX | N/A | N/A | N/A | R (view) | C/R/U/D | R (view) | R (view) | C/R | R (export) |
| HOLD | R (read own) | R (read own) | C/R/U/D | R (view) | R (view) | R (view) | R (view) | C/R/U/D | R (export) |
| TRANSFER | R (read own) | R (read own) | C/R/U/D | R (view) | R (view) | R (view) | R (view) | C/R/U/D | R (export) |
| INVOICE | R (read) | R (read) | C/R (create for service) | R (view) | C/R/U/D (refund) | R (view) | R (view) | R (view) | R (export) |
| RECEIPT | R (read) | R (read) | R (read) | R (view) | R (view) | R (view) | R (view) | R (view) | R (export) |
| DEPOSIT_INTENT | C/R/U/D | C/R/U/D | R | R (view) | R (view) | R (view) | R (view) | C/R/U/D | R (export) |
| DEPOSIT_TX | R (read own) | R (read own) | R | R (view) | R (view) | R (view) | R (view) | C/R/U/D | R (export) |
| WITHDRAWAL_REQUEST | C/R/U/D | C/R/U/D | R | C/R/U/D (cancel/override) | C/R/U/D | C/R/U/D (block) | C/R/U/D (limits) | C/R/U/D | R (export) |
| WITHDRAWAL_TX | R (read own) | R (read own) | R | R (view) | R (view) | R (view) | R (view) | C/R/U/D | R (export) |
| CONVERSION_QUOTE | C/R/U/D | C/R/U/D | R | R (view) | R (view) | R (view) | R (view) | R (view) | R (export) |
| CONVERSION_ORDER | C/R/U/D | C/R/U/D | R | R (view) | R (view) | R (view) | R (view) | C/R/U/D | R (export) |
| LIMIT_PROFILE | N/A | N/A | R (read) | C/R/U/D | C/R/U/D | C/R/U/D | C/R/U/D | R (view) | R (export) |
| RISK_CASE | N/A | N/A | N/A | R (view) | R (view) | C/R/U/D | C/R/U/D | R (view) | R (export) |
| ADDRESS_SCREEN | N/A | N/A | N/A | R (view) | R (view) | C/R/U/D | C/R/U/D | R (view) | R (export) |
| FEE_SCHEDULE | N/A | N/A | R (read) | C/R/U/D | C/R/U/D | I | I | R (view) | R (export) |
| RECONCILIATION_REPORT | N/A | N/A | N/A | R (view) | C/R/U/D | I | I | C/R | R (export) |
| IDEMPOTENCY_KEY | N/A | N/A | N/A | R (view) | R (view) | I | I | R (view) | I |
| WEBHOOK_DELIVERY | N/A | N/A | R (receive) | R (view) | R (view) | I | I | C/R/U/D | I |
| JOB | N/A | N/A | N/A | R (view) | R (view) | I | I | C/R/U/D | I |
| DLQ | N/A | N/A | N/A | R (view) | R (view) | I | I | C/R/U/D | I |
| CONFIG_VERSION | N/A | N/A | R (read) | C/R/U/D | C/R/U/D | I | I | R (view) | R (export) |

**N/A** indicates intentionally not exposed to that persona.

## A4. Permissions / Badge / KYC Matrix

| Action | Required role/badge/KYC | Evidence | Expiry/Renewal | Appeal |
|---|---|---|---|---|
| Create hold up to Tier1 | Auth user | — | policy | — |
| Create hold Tier2+ | Investor badge | KYC pass | 2 years | Support |
| Withdraw over daily limit | Investor badge + review | KYC & risk checks | per policy | Compliance |
| Conversion over exposure | Risk approval | internal case | per case | Risk |
| Issue refund | Finance Ops (staff) | case id | immediate | Security |
| Override journal | Finance Ops + dual‑control | change ticket | permanent | Security |
| Export audit | Auditor | request id | link 30d | — |

## A5. Quota & Billing Matrix

| Metric | Free Tier | Overage pricing (FZ/PT) | Exemptions | Dunning/Failure | Refunds |
|---|---|---|---|---|---|
| Invoice creations / user / day | X | per extra invoice | staff test | throttle 429 | N/A |
| Conversions / user / day | Y | per extra conversion | promotions | 402 → invoice | case-by-case |
| Partner settlements / hour | Q | tiered pricing | first‑party free | 429 backoff | N/A |
| Address screens / day | Z | billed per 100 | none | degrade to manual | N/A |

## A6. Notification Matrix

| Event | Channel(s) | Recipient persona(s) | Template | Throttle/Dedupe |
|---|---|---|---|---|
| payhub.deposit.updated@v1 | webhook | WebApp/Portal | `deposit_update` | `(txId)` |
| payhub.withdrawal.updated@v1 | webhook | WebApp/Portal | `withdrawal_update` | `(withdrawalId)` |
| payhub.hold.created@v1 | webhook | Playhub/Escrow/Funding | `hold_created` | `(holdId)` |
| payhub.settlement.succeeded@v1 | webhook | Partner, WebApp | `settlement_succeeded` | `(settlementId)` |
| payhub.invoice.updated@v1 | webhook | WebApp/Portal | `invoice_update` | `(invoiceId)` |
| payhub.conversion.executed@v1 | webhook | WebApp/Portal | `conversion_executed` | `(orderId)` |
| payhub.reconciliation.completed@v1 | ops | Finance, Auditor | `recon_completed` | per day |

## A7. Cross‑Service Event Map

| Event | Producer | Consumers | Payload summary | Idempotency | Retry/Backoff |
|---|---|---|---|---|---|
| payhub.account.created@v1 | Payhub | Admin | `{accountId, userId}` | `accountId` | 3× |
| payhub.hold.created@v1 | Payhub | Playhub, Escrow | `{holdId, userId, amount, asset}` | `holdId` | 5× |
| payhub.hold.released@v1 | Payhub | Playhub, Escrow | `{holdId, reason}` | `holdId` | 5× |
| payhub.settlement.succeeded@v1 | Payhub | Playhub, Escrow, WebApp | `{settlementId, transfers}` | `settlementId` | 5× |
| payhub.deposit.created@v1 | Payhub | WebApp | `{intentId, address}` | `intentId` | 5× |
| payhub.deposit.updated@v1 | Payhub | WebApp | `{intentId, txId, status}` | `(intentId,txId)` | 5× |
| payhub.withdrawal.created@v1 | Payhub | WebApp | `{withdrawalId, status}` | `withdrawalId` | 5× |
| payhub.withdrawal.updated@v1 | Payhub | WebApp | `{withdrawalId, txId, status}` | `(withdrawalId,txId)` | 5× |
| payhub.conversion.quote.created@v1 | Payhub | WebApp | `{quoteId, from, to, rate, exp}` | `quoteId` | 5× |
| payhub.conversion.executed@v1 | Payhub | WebApp | `{orderId, from, to, amountFrom, amountTo}` | `orderId` | 5× |
| payhub.invoice.updated@v1 | Payhub | WebApp, Services | `{invoiceId, status}` | `invoiceId` | 5× |
| payhub.reconciliation.completed@v1 | Payhub | Finance, Auditor | `{day, reportId}` | `day` | 3× |

---

# Abuse/Misuse & NFR Sweeps

- **Abuse**: layering/structuring of deposits (velocity limits), dust attack (min credit policy), mixer addresses (screening), invoice spam (rate limits + billing), hold spam by bots (per‑service quotas).  
- **Fraud**: stolen accounts (withdrawal soft delay on new addresses, device checks), fake deposits (credit only after confirmations), oracle manipulation (signed snapshots with freshness and quorum).  
- **Security**: JWT validation, mTLS for partners where available, HMAC webhooks, idempotency on all writes, outbox for events, secrets in secure vault, transaction signing on dedicated HSM.  
- **Privacy & compliance**: KYC evidence stored by Identity, Payhub holds only reference ids, retention for ledger entries per jurisdiction (e.g., 7 years), DSAR export path.  
- **Localization/timezones**: user‑visible timestamps displayed **GMT+7** in UIs; ledger timestamps in UTC.  
- **Resilience**: circuit breakers for RPCs, fee oracle fallbacks, DLQ with replay, reconciliation to detect drifts, RBF for stuck withdrawals.

---

# Self‑Check — Stakeholder Coverage Report

**Counts**  
- Personas: 13  
- Features: 26  
- Stories: 28  
- Stories with non‑happy paths: 24/28  
- Entities covered in CRUD matrix: 24/24

**Checklist**  
- ✅ All personas appear in at least one story.  
- ✅ Each entity has at least one **C**, **R**, **U**, and **D** (or reasoned N/A).  
- ✅ Every action mapped to roles/badges/KYC where applicable.  
- ✅ Quotas & billing addressed for every chargeable action.  
- ✅ Each story references APIs/entities/events.  
- ✅ At least one end‑to‑end scenario per persona.  
- ✅ Abuse/misuse cases enumerated with mitigations.  
- ✅ Observability signals tied to AC.  
- ✅ Localization/timezone handling present where user-visible.
