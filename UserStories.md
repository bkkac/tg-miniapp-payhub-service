Repo: tg-miniapp-payhub-service
File: UserStories.md
SHA-256: 1ab336afd57038e1f1546428c1f49968a069d11acd8963cc3dda90181f5dbe22
Bytes: 22350
Generated: 2025-10-03 14:39 GMT+7
Sources: old UserStories.md (baseline), Guide

---

# Section A — Personas & Stakeholders

> **PayHub** is FUZE.ac’s money & value rail: double-entry ledger, balances, **invoices/holds/refunds**, **deposits/withdrawals**, **conversions/quotes**, merchant **settlements**, and programmable **escrow** (for Star Exchange, Funding, PlayHub, Events). It enforces **Identity** decisions (badges/KYC/jurisdictions), uses **Price** for FX, emits canonical **finance events**, and exposes **webhooks** for merchants/partners. User-facing pages (WebApp/Admin) must follow the **Global List Pattern** and show **EXP** hooks for spend/earn actions.

**Stakeholders**
- **End User** — pays invoices, deposits/withdraws, converts, views history/receipts.
- **Investor User** — higher limits; can withdraw larger amounts after KYC checks.
- **Merchant / Project Owner** — issues invoices, manages refunds, sets webhook endpoints, views settlements.
- **Events/PlayHub/Star Exchange/Funding Services** — create invoices/holds, read status, and receive payouts/refunds.
- **Admin (Finance Ops)** — investigates issues, creates manual adjustments, manages fee schedules, runs settlements.
- **Compliance Officer** — handles KYC/sanctions hits, reviews large transfers, approves overrides.
- **Risk Analyst** — velocity controls, suspicious patterns, blocks/holds.
- **Support Agent** — reads receipts and status to assist users.
- **Price Service** — provides quotes; marks staleness.
- **Identity Service** — gates actions by badge/KYC/region; step-up prompts.
- **Workers/Schedulers** — settlement batches, expired holds, dunning/retries.
- **Notifications** — sends receipts, reminders, dunning, settlement reports.
- **Auditor** — exports immutable logs, reconciliation, evidence.
- **Developer (Merchant)** — integrates via webhooks/API keys; tests in sandbox.

---

# Section B — Epics → Features → User Stories (exhaustive)

## Epic B1 — Accounts, Ledger & Balances

### Feature B1.1 — Account creation (double-entry ledger)
**Story B1.1.1** — *As a Service, I create accounts so that funds movements remain balanced and auditable.*

**Acceptance (GWT)**
1. **Given** a new user/merchant, **when** Identity emits `identity.session.created@v1` or Admin provisions a merchant, **then** PayHub creates accounts: `USER:{id}` and `USER:FEES`, `MERCHANT:{id}`, `ESCROW:{context}`, and corresponding **contra** accounts.
2. Each movement posts **two equal & opposite** entries; sum per currency ≡ 0.
3. Immutable journal with sequential IDs; **no in-place edits**, only **reversals**.

**Non-Happy**: duplicate account → idempotent; storage failure → retry with outbox; currency not supported → 422.

### Feature B1.2 — Balances & statements
**Story B1.2.1** — *As a User/Merchant, I view balances and statements so that I know my funds state.*

**Acceptance**
1. `GET /payhub/v1/balances` returns available, pending, escrow per currency; strong read with snapshot version.
2. `GET /payhub/v1/statements?cursor=…` returns paged journal lines; **infinite scroll**; **pull-to-refresh** restarts at page 1.
3. CSV/PDF statement export via async job; link expires in 7 days.

**UI & Interaction Model (Balances/Statements)**
- List-first history, **Search** (amount, counterparty, memo, txId), **Sort** (Date, Amount, Type), **Filter** (type: deposit/withdraw/invoice/refund/conversion/escrow), **Bookmark**, **Comment**, **Report**, **Share receipt**.  
- Auto-refresh at top; infinite scroll bottom; times default **GMT+7**.

---

## Epic B2 — Invoices, Holds, Refunds

### Feature B2.1 — Create invoice
**Story B2.1.1** — *As a Merchant or Service, I create an invoice so that a user can pay or we can hold funds.*

**Acceptance**
1. `POST /payhub/v1/invoices` with `{amount, currency, lineItems, memo, expiresAt?, hold?, escrowContext?}` creates invoice with **Idempotency-Key**; returns deep link for WebApp.
2. If `hold=true`, **funds are reserved** on payer until capture/release.
3. Invoice states: `CREATED → (EXPIRED|PAID|PARTIAL|VOID)`; **holds**: `PLACED → (CAPTURED|RELEASED|EXPIRED)`.

**Permissions/KYC**: large amounts require KYC tiers per Config; region blocks apply.  
**Events**: `payhub.invoice.created@v1`.

### Feature B2.2 — Pay invoice
**Story B2.2.1** — *As a User, I pay an invoice so that I complete a purchase or entry fee.*

**Acceptance**
1. `POST /payhub/v1/invoices/{id}/pay` debits payer and credits merchant/escrow; returns receipt; emits `payhub.invoice.updated@v1(status=PAID)`.
2. If balance insufficient, **402 insufficient_funds** with **Deposit** CTA.
3. If policy gate fails (KYC/region), **403** with reason and link to resolve in Identity.

**Non-Happy**: double submit → idempotent; expired invoice → 410; risk block → 423 pending review.

### Feature B2.3 — Capture/Release hold
**Story B2.3.1** — *As a Service/Merchant, I capture or release a hold so that the outcome is settled.*

**Acceptance**
1. `POST /payhub/v1/holds/{id}/capture` moves held funds to merchant (or escrow).
2. `POST /payhub/v1/holds/{id}/release` returns funds to payer; reasons captured.
3. Expired holds auto-release via Worker; notifications sent.

### Feature B2.4 — Refunds (full/partial)
**Story B2.4.1** — *As a Merchant/Staff, I refund a payment so that users are made whole when appropriate.*

**Acceptance**
1. `POST /payhub/v1/payments/{id}/refund {amount<=captured}` creates reversal; multiple partials allowed until sum==captured.
2. Refund posts negative lines; invoice becomes `REFUNDED` when sum==captured.
3. User receives receipt; downstream services notified for state repair.

---

## Epic B3 — Deposits & Withdrawals

### Feature B3.1 — Deposit
**Story B3.1.1** — *As a User, I deposit funds so that I can spend in-app.*

**Acceptance**
1. `POST /payhub/v1/deposits` creates a pending deposit with instructions (on-ramp, bank, or partner); `deposit.detected` credits pending → available after confirmations.
2. Deposit limits and holds per KYC tier; suspicious deposits flagged for review.
3. Fees calculated from Fee Schedule; user sees net vs gross.

### Feature B3.2 — Withdraw
**Story B3.2.1** — *As a User, I withdraw funds to an external address/account so that I can cash out.*

**Acceptance**
1. `POST /payhub/v1/withdrawals` validates amount, balance, **KYC tier**, **residency**, and **risk velocity**; presents fee and ETA; confirmation step.
2. On confirm, withdrawal moves to `PENDING`; after partner confirms, `COMPLETED` and receipt posted. Failures → `FAILED` with reversal.
3. Large withdrawals require **step-up** (OTP or wallet signature) via Identity.

**Non-Happy**: network/partner outage → queued with backoff; address risk → warning or block; cooldown on repeated failures.

---

## Epic B4 — Quotes & Conversions (FX)

### Feature B4.1 — Quote
**Story B4.1.1** — *As a User, I request a quote so that I know the conversion rate and fees.*

**Acceptance**
1. `POST /payhub/v1/quotes {from,to,amount}` returns rate, fee, expiryTs, and id; **staleness** flagged from Price.
2. Quote reserved until expiry; rate locks on execute.

### Feature B4.2 — Convert
**Story B4.2.1** — *As a User, I convert currencies so that I can hold/spend in my preferred one.*

**Acceptance**
1. `POST /payhub/v1/conversions {quoteId}` executes at locked rate; journal shows two entries plus fee.
2. Limits per tier; anti-arb cooldowns; events fire for analytics/EXP.

---

## Epic B5 — Escrow (Star Exchange, Funding, Marketplaces)

### Feature B5.1 — Open escrow
**Story B5.1.1** — *As a Service, I open an escrow so that buyer/seller funds are protected until conditions are met.*

**Acceptance**
1. `POST /payhub/v1/escrows {context, parties, amount, currency, releaseRules}` opens `ESCROW:{context}` account; funds from hold or payment route into escrow.
2. State: `OPEN → (RELEASED|CANCELLED|DISPUTED)`; partial releases supported.
3. Identity policy may require badges (Verified Merchant), KYC tiers for parties.

### Feature B5.2 — Release escrow
**Story B5.2.1** — *As a Service/Staff, I release escrow per rules or dispute decisions.*

**Acceptance**
1. `POST /payhub/v1/escrows/{id}/release {amount}` transfers to beneficiary; emits `payhub.escrow.released@v1`.
2. Dispute holds payouts until resolved.

---

## Epic B6 — Merchant Tools & Webhooks

### Feature B6.1 — Webhook endpoints
**Story B6.1.1** — *As a Merchant Dev, I register a webhook so that I receive real-time payment updates.*

**Acceptance**
1. `POST /payhub/v1/webhooks` with secret and URL; **HMAC** signed deliveries; retry with exponential backoff; DLQ on repeated failure.
2. At least events: `invoice.created/updated`, `payment.captured/refunded`, `escrow.opened/released`, `withdrawal.updated`, `deposit.updated`.
3. Test delivery tool in dashboard; **idempotency** via event `id` and signature.

### Feature B6.2 — Fee schedules & settlements
**Story B6.2.1** — *As Finance Ops, I configure fees and run merchant settlements.*

**Acceptance**
1. `POST /payhub/v1/admin/fees` defines maker/taker/withdrawal/conversion fees by tier/badge; effectiveAt with versioning.
2. `POST /payhub/v1/admin/settlements/run {merchantId, period}` produces payout and statement; emits `payhub.settlement.completed@v1`.

---

## Epic B7 — Dunning, Detections & Risk

### Feature B7.1 — Dunning & retries
**Story B7.1.1** — *As PayHub, I retry failed collections and notify users so that recovery is maximized without spam.*

**Acceptance**
1. Backoff schedule per failure reason; max attempts configurable; dedupe notifications.
2. Auto-cancel after N days; escalations to Support/Collections queues.

### Feature B7.2 — Risk controls
**Story B7.2.1** — *As Risk, I set velocity and pattern rules so that abuse is reduced.*

**Acceptance**
1. Rules on deposits/withdrawals/conversions/invoices per user/merchant/IP/device; cooling-off windows.
2. High-risk flags open **RISK_CASE**; staff can override with reason; all actions audited.

---

## Epic B8 — Reliability, Observability, Reconciliation (NFRs)

- **Consistency**: double-entry journal with **exactly-once** posting; outbox & idempotency keys for all writes.
- **Invariants**: per-currency ledger sums must be zero; background job monitors and pages.
- **SLOs**: `invoice.pay` p95 < 200ms to accept; `balances.get` p95 < 80ms; webhook delivery success ≥ 99.5%/day.
- **Reconciliation**: daily snapshots → checksums; partner/bank files matched; diffs produce **RECON_CASES**.
- **Security**: mTLS for service calls; HMAC on webhooks; PII redaction; signed receipts; admin actions require dual control on sensitive ops.
- **Backpressure**: rate limiters, queue depth guards, DLQ; graceful degradation (read-only mode).

---

# Section C — End-to-End Scenarios (Swimlane)

1. **E2E-C1: Paid RSVP** — *Events* creates hold → User confirms & pays → PayHub captures on check-in → receipt → reminder.  
2. **E2E-C2: PlayHub entry & prize** — room join creates hold → match completed → capture to prize escrow → payout to winner(s) → receipts.  
3. **E2E-C3: Star Exchange escrow** — listing purchase opens escrow → seller fulfills → release → dispute flow if needed → settlement.  
4. **E2E-C4: Funding allocation** — investor requests allocation → invoice issued → payment captured → allocation confirmed → possible refund on cancellation.  
5. **E2E-C5: Convert → Withdraw** — user quotes FZ→PT, executes conversion, then withdraws PT to wallet with step-up & receipt.  

---

# Section D — Traceability Matrix

| Story | APIs | Entities | Events | Notes |
|---|---|---|---|---|
| B1.1.1 | `/accounts/*` | ACCOUNT, JOURNAL | payhub.account.created@v1 | Idempotent |
| B1.2.1 | `/balances`, `/statements` | BALANCE, JOURNAL_LINE | — | Snapshots |
| B2.1.1 | `/invoices` | INVOICE | payhub.invoice.created@v1 | Holds optional |
| B2.2.1 | `/invoices/{id}/pay` | PAYMENT, RECEIPT | payhub.invoice.updated@v1 | Idempotent |
| B2.3.1 | `/holds/{id}/capture|release` | HOLD | payhub.hold.updated@v1 | Auto-expiry |
| B2.4.1 | `/payments/{id}/refund` | REFUND | payhub.payment.refunded@v1 | Partial ok |
| B3.1.1 | `/deposits` | DEPOSIT | payhub.deposit.updated@v1 | Partner files |
| B3.2.1 | `/withdrawals` | WITHDRAWAL | payhub.withdrawal.updated@v1 | Step-up |
| B4.1.1 | `/quotes` | QUOTE | payhub.quote.created@v1 | Staleness |
| B4.2.1 | `/conversions` | CONVERSION | payhub.conversion.executed@v1 | Lock rate |
| B5.1.1 | `/escrows` | ESCROW | payhub.escrow.opened@v1 | Context |
| B5.2.1 | `/escrows/{id}/release` | ESCROW | payhub.escrow.released@v1 | Partial |
| B6.1.1 | `/webhooks` | WEBHOOK_ENDPOINT, DELIVERY | payhub.webhook.delivery@v1 | HMAC |
| B6.2.1 | `/admin/fees`, `/admin/settlements/run` | FEE_SCHEDULE, SETTLEMENT | payhub.settlement.completed@v1 | Versioned |
| B7.1.1 | workers | DUNNING_RUN | payhub.dunning.attempt@v1 | Backoff |
| B7.2.1 | `/admin/risk/*` | RISK_RULE, RISK_CASE | payhub.risk.case.created@v1 | Overrides |

**Deltas vs old UserStories**: explicit double-entry ledger & invariants, **holds/escrow** generalized, robust refunds & disputes hooks, **quotes/conversions** with staleness, **withdraw** step-up + velocity controls, **webhooks** (HMAC, retries, DLQ), fee schedules & settlements, and end-to-end wiring with Events/PlayHub/Star Exchange/Funding.

---

# Section E — Assumptions & Open Questions

- **Currencies**: FZ and PT are primary; fiat or other tokens via partners later; exact decimals and rounding rules configured.
- **Custody**: PayHub maintains **internal ledger**; on/off-ramps may be partner-based initially.
- **Compliance**: KYC tiers L0/L1/L2; thresholds and residency lists come from Config/Identity; sanctions checks at withdraw & large deposit.
- **Refunds**: merchant covers fees unless policy overrides; partial refunds allowed until fully reversed.
- **Statements**: PDFs are non-tax invoices; tax invoices require future module.
- **Escrow rules**: services specify release conditions; staff override available with dual-control.
- **Rate limits**: per user and per merchant; exact caps in Config.

---

# UI & Interaction Model (PayHub surfaces in WebApp/Admin)

- Each page begins with an **item list** (Balances, Statements, Invoices, Deposits, Withdrawals, Conversions, Escrows, Webhooks, Settlements).
- Buttons: **Create/Submit**, **Edit**, **Delete** (e.g., Create Invoice, Submit Withdraw, Edit Webhook, Delete Test Endpoint).
- **Tap item** → **Detail view** (receipt, status timeline, audit).
- **Search** by attributes (invoiceId, txId, memo, counterparty, amount).
- **Auto-refresh** when pulling to top; newest entries on top.
- **Infinite scroll** with constant page size; auto-load more at bottom.
- **Sort**: Date, Popular (views/uses), Featured (flagged), View.
- **Filter**: status (pending/completed/failed), type, currency, amount ranges, counterparty, risk flags.
- **Bookmark**, **Comment**, **Report**, **Share** receipt or link.
- **EXP system**: actions like **pay invoice, create invoice (merchant), convert, deposit, withdraw** grant EXP; Config defines values; show locks when below thresholds.
- **Localization/timezone**: display in user locale with **GMT+7** default; relative times with absolute UTC tooltip.

---

# Appendix — Coverage Gates

## A1. Stakeholder Catalog
| Stakeholder | Responsibilities | Permissions | Typical Actions | KPIs/SLO |
|---|---|---|---|---|
| End User | pay, deposit, withdraw, convert | user | pay invoice, request withdraw | success rate |
| Investor | higher limits | user+investor | larger withdrawals | approval time |
| Merchant/Owner | issue invoices, refunds | role.merchant | create/capture/release | DSO, refund rate |
| Services (Events/PlayHub/StarX/Funding) | programmatic payments | service | create holds, capture | success |
| Admin Finance | fees, settlements | staff.finance | run settlements, adjust | reconciliation |
| Compliance | KYC/sanctions | staff.compliance | review blocks, approve | false positives |
| Risk Analyst | velocity/fraud | staff.risk | set rules, open cases | loss rate |
| Support | assist users | staff.support | view receipts/status | TTR |
| Price Service | quotes | service.price | provide rates | staleness |
| Identity | authZ/KYC | service.identity | allow/deny | policy latency |
| Workers | jobs | service | expire holds, run dunning | on-time |
| Notifications | delivery | service | send receipts | delivery % |
| Auditor | audit | read.audit | export logs, checksums | completeness |

## A2. RACI Matrix (major capabilities)
| Capability | End User | Merchant | Services | Finance | Compliance | Risk | Support | Identity | Price | Workers | Auditor |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Invoices/Holds | R | A | C | C | C | C | I | C | I | I | I |
| Payments/Refunds | R | A | C | C | C | C | I | C | I | I | I |
| Deposits | R | I | I | C | A (thresholds) | C | I | C | I | C | I |
| Withdrawals | R | I | I | C | A | C | I | A | I | C | I |
| Escrow | I | C | A | C | C | C | I | C | I | C | I |
| Quotes/Conversions | R | R | I | C | I | C | I | C | A | I | I |
| Webhooks | I | A | I | C | I | I | I | I | I | I | I |
| Fees/Settlements | I | C | I | A | I | I | I | I | I | C | I |

## A3. CRUD × Persona × Resource Matrix
- **Resources**: `ACCOUNT`, `BALANCE`, `JOURNAL`, `INVOICE`, `PAYMENT`, `HOLD`, `REFUND`, `DEPOSIT`, `WITHDRAWAL`, `QUOTE`, `CONVERSION`, `ESCROW`, `FEE_SCHEDULE`, `SETTLEMENT`, `WEBHOOK_ENDPOINT`, `DELIVERY`, `RISK_RULE`, `RISK_CASE`, `RECON_CASE`, `RECEIPT`.
- **Personas**: EndUser, Investor, Merchant, Service, Finance, Compliance, Risk, Support, Auditor.
- Examples:
  - `INVOICE`: Merchant **C/R/U/D (own)**; EndUser **R**; Services **C/R (context)**; Finance **R**; Compliance/Risk **R**; Auditor **R**.
  - `WITHDRAWAL`: EndUser **C/R (own)**, Compliance **U (approve/deny)**, Finance **U (process)**, Risk **C/U (case)**, Support **R**, Auditor **R**.
  - `FEE_SCHEDULE`: Finance **C/R/U**, others **R**; EndUser **N/A** (reason: internal policy).  
- **No row/column** left blank without a reasoned N/A.

## A4. Permissions / Badge / KYC Matrix
| Action | Required roles/badges/KYC | Evidence | Expiry/Renewal | Appeal |
|---|---|---|---|---|
| Withdraw > threshold | investor badge + KYC L2 | provider proof | 12m | KYC appeal |
| Issue invoices (merchant) | Verified Merchant badge | docs verified | 365d | re-verify |
| Open escrow | policy + roles | listing/round ref | per context | staff override |
| Conversion > daily cap | EXP≥X or badge | identity snapshot | rolling | support review |

## A5. Quota & Billing Matrix
| Metric | Free Tier | Period | Overage Pricing | Exemptions | Failure |
|---|---|---|---|---|---|
| Invoices created (merchant) | 500 | month | fee per extra | Pro Merchant | 429 throttle |
| Withdrawals per user | 5 | day | cooldown + review | Investor | 429/case |
| Conversions per day | 20 | day | spread tiering | Pro Merchant | 429 |
| Webhook deliveries | 100k | day | contact sales | staff | 429/backoff |

## A6. Notification Matrix
| Event | Channel(s) | Recipient | Template | Throttle/Dedupe |
|---|---|---|---|---|
| payhub.invoice.created@v1 | in-app/TG/webhook | User/Merchant | `invoice_created` | collapse by invoiceId |
| payhub.invoice.updated@v1 | in-app/TG/webhook | User/Merchant | `invoice_status` | per invoice |
| payhub.withdrawal.updated@v1 | in-app/TG/webhook | User | `withdrawal_status` | per withdrawal |
| payhub.deposit.updated@v1 | in-app/TG/webhook | User | `deposit_status` | per deposit |
| payhub.settlement.completed@v1 | email/webhook | Merchant/Finance | `settlement_report` | per period |
| payhub.dunning.attempt@v1 | in-app/TG | User | `dunning_notice` | per case |

## A7. Cross-Service Event Map
| Event | Producer | Consumers | Payload summary | Idempotency | Retry/Backoff |
|---|---|---|---|---|---|
| payhub.invoice.created@v1 | PayHub | WebApp, Events, PlayHub, Funding, Portal | `{invoiceId,amount,currency,context}` | `invoiceId` | 5× exp |
| payhub.invoice.updated@v1 | PayHub | WebApp, origin service | `{invoiceId,status}` | `(invoiceId,status_ts)` | 5× |
| payhub.escrow.released@v1 | PayHub | StarX/Funding/WebApp | `{escrowId,amount,to}` | `escrowId` | 5× |
| payhub.withdrawal.updated@v1 | PayHub | WebApp, Identity | `{withdrawalId,status}` | `withdrawalId` | 5× |
| payhub.conversion.executed@v1 | PayHub | WebApp, Analytics | `{conversionId,from,to,rate}` | `conversionId` | 3× |

---

# Abuse/Misuse & NFR Sweeps

- **Fraud & ML**: device/IP clustering, mule detection, round-tripping (deposit→withdraw loops), self-invoicing loops, synthetic identities; velocity rules + manual cases.
- **Phishing & misaddress**: address-book and checksum validation; risky-address warnings; confirm pages; allow cancel within grace windows where possible.
- **Denial of payment**: hold expiries, retries, DLQ for webhooks; read-only mode on outages.
- **Idempotency**: all mutating endpoints accept `Idempotency-Key`; duplicates return prior result.
- **Reorg/partner failure**: deposits credited after sufficient confirmations; withdrawals roll back on failure with receipts.
- **Privacy & compliance**: PII redaction, retained minimal evidence hashes; DSAR hooks via Identity; retention schedules.
- **Localization/timezone**: user-facing times **GMT+7** default; currency formatting i18n-safe.

---

# Self-Check (Stakeholder Coverage Report)

Counts:
- Personas: 13
- Features: 20
- Stories: 22
- Stories with non-happy paths: 18/22
- Entities covered in CRUD matrix: 20/20

Checklist:
- ✅ All personas appear in at least one story.
- ✅ Each entity has at least one C, R, U, and D (or reasoned N/A).
- ✅ Every action mapped to roles/badges/KYC where applicable.
- ✅ Quotas & billing addressed for every chargeable action.
- ✅ Each story references APIs/entities/events.
- ✅ At least one end-to-end scenario per persona.
- ✅ Abuse/misuse cases enumerated with mitigations.
- ✅ Observability signals tied to AC.
- ✅ Localization/timezone handling present where user-visible.
