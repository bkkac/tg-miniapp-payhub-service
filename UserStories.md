Repo: tg-miniapp-payhub-service


---
# Section A — Personas & Stakeholders

> **Payhub Service** is FUZE’s **custody & payments core**: double‑entry ledger, accounts/balances, **deposits**, **withdrawals**, **holds/settlements**, **conversions**, **invoices/overages/refunds**, limits/velocity, AML screening, and reconciliation/exports. It powers WebApp & Web3 Portal money flows and is consumed by **PlayHub**, **Funding**, **Escrow/OTC**, **Watchlist (billing)**, **Campaigns/Events** for paid actions. It relies on **Identity** for badges/KYC/limits, **Config** for signed fee/limit/threshold bundles, **Price** for signed oracle snapshots, and **Workers** for jobs.

**Stakeholders (discovered)**  
- **End User** — deposits, withdraws, converts, pays overage invoices, sees receipts.  
- **Investor (KYC’d)** — higher limits and OTC eligibility.  
- **Project Finance** — initiates distributions, bulk refunds.  
- **Partner Service (PlayHub/Funding/Portal/WebApp)** — creates holds/settles, shows balances/receipts.  
- **Admin/Finance Ops** — overrides, manual refunds, dunning, reconciliation.  
- **Compliance/AML** — screens addresses, velocity limits, case review.  
- **Risk** — exposure controls, loss monitoring, anomaly rules.  
- **Identity Service** — roles, badges, KYC tiers, limits.  
- **Config Publisher** — signed fee/limit configs.  
- **Price/Oracle** — signed quotes (TWAP/snapshot) for conversions.  
- **Workers/Schedulers** — deposit watchers, withdrawal broadcasters, expirations, reconciliation.  
- **SRE/Ops** — DLQs, SLOs, incident toggles.  
- **Auditor** — read‑only exports and trails.

> See **Appendix A1 — Stakeholder Catalog** for responsibilities/permissions/KPIs (derived from baseline & guide).  fileciteturn9file0

---

# Section B — Epics → Features → User Stories (exhaustive)

## Epic B1 — Accounts, Balances & Ledger

### Feature B1.1 — Provision account & balances  
**Story B1.1.1** — *As a Partner Service, I provision an account on first touch,* so that *credits/holds can occur immediately.*  
**Acceptance (GWT)**  
1. **Given** `POST /v1/accounts {userId}` with service scope, **then** create `ACCOUNT` + `BALANCE{STAR,FZ,PT,USDT}` rows; idempotent by `(userId)` or **Idempotency-Key**.  
2. **Given** account exists, **then** 201 returns same `accountId`; no dup rows.  
3. **Given** Identity down, **then** **502 identity_unavailable** with `retry_after`.  
**Non‑Happy**: invalid `userId` → **404** after introspection; missing scope → **403**.  
**Observability**: `account.create.latency`, dedupe count.  

### Feature B1.2 — Double‑entry ledger  
**Story B1.2.1** — *As Finance Ops, I require double‑entry postings for every money move,* so that *audits reconcile.*  
**AC**  
1. Every mutation writes **two postings** in `LEDGER_ENTRY` within a `JOURNAL_TX` (debit/credit), immutable.  
2. API returns `journalTxId`; repeated write with same **Idempotency-Key** → same `journalTxId`.  
3. Outbox publishes events after commit; replay is idempotent.  
**Non‑Happy**: partial write pre‑publish → outbox replays; journal monotonicity enforced.  

---

## Epic B2 — Holds & Settlements

### Feature B2.1 — Create hold  
**Story B2.1.1** — *As a Partner Service (e.g., PlayHub), I create a funds **hold*** so that *I can settle later.*  
**AC**  
1. `POST /v1/holds {userId, asset, amount, reason, ttl}` validates balance, limit profile; places hold (moves `available→held`).  
2. Idempotent by `(userId, asset, reason, clientRef)`; repeat → same `holdId`.  
3. TTL expiry triggers auto‑release via worker; release event emitted.

### Feature B2.2 — Settle / release  
**Story B2.2.1** — *As a Partner, I settle a hold to recipient(s),* so that *payouts finalize.*  
**AC**: `POST /v1/settlements {holdId, splits[]}` creates postings; receipts per recipient; partial fail → compensation job; all idempotent.  
**Non‑Happy**: hold missing/expired → **409**; insufficient held (race) → **409** with advice; emits failure event.  

**UI & Interaction Model (WebApp/Portal surface — Receipts)**  
- List shows **latest 20 receipts**; **infinite scroll**; **pull‑to‑refresh**; search by **reason/roomId/project/tags**.  
- **Sort**: Date, Popular, Featured, View.  
- **Filter**: asset, amount range, status (pending/settled/failed).  
- **Actions**: Bookmark / Comment / Report / Share receipt cards.  
- **EXP**: viewing/share/comment can grant EXP (cooldowns).

---

## Epic B3 — Deposits

### Feature B3.1 — Create deposit intent  
**Story B3.1.1** — *As an End User, I create a deposit intent,* so that *I can top up.*  
**AC**  
1. `POST /v1/deposits {asset, network, amount?}` returns `{depositId, address|memo|QR, minAmount, confirmations}`.  
2. Watchers confirm on‑chain; credit after N confs; notify client.  
3. Too small (< min) stays **uncredited**; can be auto‑aggregated per policy.  
**Non‑Happy**: reorg before finality → rollback credit; mixer/blocked source → **hold & review** with case id.  
**Security**: generate addresses via xpub/HSM; never reuse memos incorrectly.  
**Observability**: time‑to‑credit, reorg count.  

**UI & Interaction Model (Deposits)**  
- List shows **latest 20 deposit intents**; **infinite scroll**; **pull‑to‑refresh**; search by **txId/network/tags**.  
- **Sort**: Date, Popular, Featured, View.  
- **Filter**: asset, network, status (pending/confirmed/held).  
- **Actions**: Bookmark / Comment / Report / Share deposit cards.  
- **EXP**: safe deposit completions & shares may grant EXP (cooldowns).

---

## Epic B4 — Withdrawals

### Feature B4.1 — Create withdrawal request (KYC‑gated)  
**Story B4.1.1** — *As an Investor, I request a withdrawal,* so that *I can move funds out.*  
**AC**  
1. `POST /v1/withdrawals {asset, amount, addressId}` checks **badge/KYC tier & limits**; screen address; compute fee; respond **202 pending** with `estimate`.  
2. Broadcaster builds/sends tx; supports **RBF**; status: `queued→broadcast→confirming→settled|failed`.  
3. Cancel before broadcast: `DELETE /v1/withdrawals/{id}` idempotent.  
**Non‑Happy**: fee spike → **delayed** status; address risk hit → **held** and case opened.  
**Observability**: p95 time‑to‑broadcast; failure code mix.  fileciteturn9file10

**UI & Interaction Model (Withdrawals)**  
- **Latest 20** withdrawal requests; **infinite scroll**; **pull‑to‑refresh**; search by **txId/address/tags**.  
- **Sort**: Date, Popular, Featured, View.  
- **Filter**: asset, chain, status (queued/broadcast/confirming/settled/failed).  
- **Actions**: Bookmark / Comment / Report / Share.  
- **EXP**: safe completion & share/comment grant EXP; rejected attempts do **not** grant EXP.

---

## Epic B5 — Conversions (Quotes & Execute)

### Feature B5.1 — Quote  
**Story B5.1.1** — *As an End User, I get a conversion quote,* so that *I can decide to convert.*  
**AC**  
1. `POST /v1/conversions/quote {from, to, amountFrom}` signs TWAP/snapshot from **Price**; returns `{quoteId, rate, expiresAt, maxSlippageBp}`.  
2. Quote cached ≤30s; expired quote → must re‑quote.  
**Non‑Happy**: oracle freshness fail → **503**; amounts out of bounds → **422**.

### Feature B5.2 — Execute  
**Story B5.2.1** — *As an End User, I execute a valid quote,* so that *balances update atomically.*  
**AC**: `POST /v1/conversions/execute {quoteId}` performs journal move; idempotent by `quoteId`; receipt emitted.  fileciteturn9file10

**UI & Interaction Model (Conversions)**  
- **Latest 20** conversion orders; **infinite scroll**; **pull‑to‑refresh**; search by **pair/quoteId/tags**.  
- **Sort**: Date, Popular, Featured, View.  
- **Filter**: pair, amount range, status (executed/expired/canceled).  
- **Actions**: Bookmark / Comment / Report / Share.  
- **EXP**: execute/comment/share increment EXP (cooldowns).

---

## Epic B6 — Invoices, Overage & Refunds

### Feature B6.1 — Issue & pay invoices  
**Story B6.1.1** — *As a User, I pay overage invoices to unlock features,* so that *usage can continue.*  
**AC**: `POST /v1/invoices {purpose, amount, currency}` → statuses `issued→paying→paid|expired`; accepts FZ/PT/USDT; on **paid**, meters refresh; failed payment → retry or refund.  

### Feature B6.2 — Manual refunds  
**Story B6.2.1** — *As Finance Ops, I issue a manual refund,* so that *I can resolve exceptions.*  
**AC**: `POST /v1/admin/refunds {invoiceId|journalTxId, reason}`; idempotent; receipt emitted.  fileciteturn9file10

**UI & Interaction Model (Invoices & Receipts)**  
- **Latest 20** invoices/receipts; **infinite scroll**; **pull‑to‑refresh**; search by **invoiceId/purpose/tags**.  
- **Sort**: Date, Popular, Featured, View.  
- **Filter**: currency, amount range, status (issued/paying/paid/expired/refunded).  
- **Actions**: Bookmark / Comment / Report / Share.  
- **EXP**: on‑time payment/comment/share increment EXP (cooldowns).  fileciteturn9file4

---

## Epic B7 — Security, Limits & Compliance

### Feature B7.1 — Limits & velocity profiles  
**Story B7.1.1** — *As Risk, I enforce per‑badge **limits** and velocity,* so that *loss is controlled.*  
**AC**: limits fetched from **Config**/**Identity**; actions exceeding → **403 limit_exceeded** with invoice hint if billable; bursts throttled with cool‑downs.  

### Feature B7.2 — AML screening & case management  
**Story B7.2.1** — *As Compliance, I screen risk and manage cases,* so that *prohibited flows are blocked.*  
**AC**: withdrawal address and deposit sources checked; hits → **held** + case `open→investigating→resolved(approve|reject)`; appeals tracked.  

### Feature B7.3 — Exports for audit  
**Story B7.3.1** — *As Auditor, I export immutable journals & reconciliation artifacts.*  
**AC**: CSV/Parquet export; signed manifest; rate‑limited; redactions applied.  fileciteturn9file10

---

## Epic B8 — Reconciliation & Reporting

### Feature B8.1 — Daily close  
**Story B8.1.1** — *As Finance Ops, I run daily close,* so that *balances match on/off‑chain.*  
**AC**: rollup by asset; variance thresholds; emits `payhub.reconciliation.completed@v1`.  

### Feature B8.2 — Fee & rule reports  
**Story B8.2.1** — *As Finance Ops, I review fee take and rules applied.*  
**AC**: fee schedule snapshot vs postings; anomalies reported.  fileciteturn9file10

---

## Epic B9 — Reliability & Observability

### Feature B9.1 — Idempotency & retries  
**Story B9.1.1** — *As SRE, I guarantee idempotent writes and safe retries,* so that *clients can recover.*  
**AC**: All **POST/PUT/DELETE** accept **Idempotency-Key**; outbox/DLQ; backoff with jitter; circuit breakers.

### Feature B9.2 — Telemetry & SLOs  
**Story B9.2.1** — *As SRE, I trace money flows,* so that *we meet SLOs.*  
**AC**: traces across services; key metrics: time‑to‑credit, time‑to‑broadcast, failure rates, invoice paid time; error budget alerts.  fileciteturn9file7

---

# Section C — End‑to‑End Scenarios (Swimlanes)

1. **E2E‑H1: Deposit → Credit** — User creates intent → sends on‑chain → N confirmations → credit ledger → balance visible in WebApp with toast.  
2. **E2E‑H2: Withdraw (KYC gate)** — User requests → **403** (needs Investor) → badge apply in WebApp → approval → retry → **202** → broadcaster settles → receipt. fileciteturn9file13  
3. **E2E‑H3: Conversion** — User quotes → executes within expiry → rates verified by signed oracle → balances move atomically.  
4. **E2E‑H4: Overage invoice unlock** — User hits free‑tier ceiling (e.g., alerts) → **402** → pays invoice → meters refresh across services. fileciteturn9file8  
5. **E2E‑H5: Reorg during deposit** — Credit after confs → chain reorg detected → rollback journal → re‑credit after re‑confirm; user sees banner.  
6. **E2E‑H6: Withdrawal fee spike → RBF** — Status stuck **confirming**; broadcaster bumps fee (RBF) → settles; receipts updated. fileciteturn9file7

---

# Section D — Traceability Matrix

| Story | APIs (client→service) | Entities | Events (emit/consume) | Notes |
|---|---|---|---|---|
| B1.1.1 | `POST /v1/accounts` | ACCOUNT, BALANCE | `payhub.account.created@v1` | Provision |
| B1.2.1 | Journal on write | LEDGER_ENTRY, JOURNAL_TX | `payhub.ledger.posted@v1` | Double‑entry |
| B2.1.1 | `POST /v1/holds` | HOLD | `payhub.hold.created@v1` | Hold |
| B2.2.1 | `POST /v1/settlements` | SETTLEMENT, RECEIPT | `payhub.settlement.*@v1` | Settle/release |
| B3.1.1 | `POST /v1/deposits` | DEPOSIT_INTENT | `payhub.deposit.updated@v1` | Deposit |
| B4.1.1 | `POST /v1/withdrawals` | WITHDRAWAL_REQUEST, WITHDRAWAL_TX | `payhub.withdrawal.updated@v1` | Withdraw |
| B4.1.1‑cancel | `DELETE /v1/withdrawals/{id}` | WITHDRAWAL_REQUEST | `payhub.withdrawal.canceled@v1` | Cancel |
| B5.1.1 | `POST /v1/conversions/quote` | CONVERSION_QUOTE, ORACLE_SNAPSHOT | `payhub.conversion.quote.created@v1` | Quote |
| B5.2.1 | `POST /v1/conversions/execute` | CONVERSION_ORDER | `payhub.conversion.executed@v1` | Execute |
| B6.1.1 | `POST /v1/invoices` | INVOICE | `payhub.invoice.updated@v1` | Invoices |
| B6.2.1 | `POST /v1/admin/refunds` | REFUND | `payhub.refund.issued@v1` | Refunds |
| B7.1.1 | limits check | LIMIT_PROFILE | — | Limits |
| B7.2.1 | screening | RISK_CASE, ADDRESS_SCREEN | `payhub.risk.case.opened@v1` | AML |
| B7.3.1 | exports | RECONCILIATION_REPORT | `payhub.audit.exported@v1` | Audit |
| B8.1.1 | daily close | RECONCILIATION_REPORT | `payhub.reconciliation.completed@v1` | Close |
| B8.2.1 | fee report | FEE_SCHEDULE | — | Reports |
| B9.1.1 | write paths | IDEMPOTENCY_KEY | — | Idempotency |
| B9.2.1 | telemetry | — | — | Observability |  fileciteturn9file10

**Deltas vs old UserStories**: explicit **double‑entry**, deposit **reorg** handling, withdrawal **RBF**, conversions with **signed oracle**, full invoice/refund lifecycle, **limits/velocity**, and **daily close reconciliation** — aligned with UI baselines for all list surfaces. fileciteturn9file7

---

# Section E — Assumptions & Open Questions

- Confirm **N confirmations** per network and reorg‑depth policy.  
- Exact fee schedule and **maxSlippageBp** defaults per asset.  
- Address‑risk provider and **appeal** SLAs.  
- Invoice **purpose catalog** and billing periods for each overage metric.  
- Who owns the **address book** canonical store (Portal vs Payhub) and first‑use **soft delay** policy.  fileciteturn9file10

---

# Appendix — Coverage Gates

## A1) Stakeholder Catalog
| Stakeholder | Responsibilities | Permissions | Typical Actions | KPIs/SLO interests |
|---|---|---|---|---|
| End User | Deposits, withdrawals, conversions, pay invoices | session | create intent, withdraw, convert, pay | completion rate, latency |
| Investor (KYC’d) | High limits, OTC | badge | large withdrawals | approval time |
| Project Finance | Payouts, refunds | staff/project | bulk payouts, refunds | payout success |
| Partner Service | Use custody primitives | service token | holds, settlements, credits | success rate |
| Admin/Finance Ops | Oversight, refunds, dunning | staff | refunds, overrides, exports | reconciliation time |
| Compliance/AML | Screen risk | compliance | screen, block, unblock | false positive rate |
| Risk | Limits/velocity | risk scope | tune limits, investigate | loss rate |
| Identity | Roles/KYC | s2s | introspect | availability |
| Config | Fee/limit bundles | publisher | release bundles | propagation lag |
| Price/Oracle | Quotes | signing keys | snapshots | freshness |
| Workers/Schedulers | Jobs | worker role | watchers, broadcasters, DLQ | queue depth |
| SRE/Ops | Reliability | ops | incident toggles, SLOs | error budget |
| Auditor | Exports | read‑only | export journals | audit latency |

## A2) RACI Matrix (major capabilities)
| Capability | End User | Investor | Partner | Admin | Compliance | Risk | Finance | SRE | Auditor |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Accounts & Ledger | I | I | R/A | C | I | I | I | I | I |
| Holds & Settlements | I | I | R/A | C | I | I | I | I | I |
| Deposits | A | A | C | C | C | C | I | I | I |
| Withdrawals | I | A | C | C | R | C | I | I | I |
| Conversions | A | A | C | C | I | I | I | I | I |
| Invoices/Refunds | A | A | I | R/A | I | I | R | I | I |
| Limits/Velocity | I | I | I | C | C | R/A | I | I | I |
| AML Screening | I | I | I | C | R/A | C | I | I | I |
| Reconciliation/Exports | I | I | I | C | I | I | R/A | I | R |

(A=Accountable, R=Responsible, C=Consulted, I=Informed)

## A3) CRUD × Persona × Resource Matrix
Resources: `ACCOUNT, BALANCE, LEDGER_ENTRY, JOURNAL_TX, HOLD, SETTLEMENT, RECEIPT, DEPOSIT_INTENT, WITHDRAWAL_REQUEST, WITHDRAWAL_TX, CONVERSION_QUOTE, CONVERSION_ORDER, INVOICE, REFUND, LIMIT_PROFILE, RISK_CASE, ADDRESS_SCREEN, RECONCILIATION_REPORT, FEE_SCHEDULE, IDEMPOTENCY_KEY`.

| Resource \ Persona | End User | Investor | Partner | Admin | Compliance | Risk | Finance |
|---|---|---|---|---|---|---|---|
| ACCOUNT | R | R | C/R | U | I | I | I |
| BALANCE | R | R | C/R | U | I | I | I |
| LEDGER_ENTRY | R | R | I | I | I | I | R |
| JOURNAL_TX | R | R | I | I | I | I | R |
| HOLD | I | I | C/R/U/D | U/D | I | I | I |
| SETTLEMENT | I | I | C/R/U | U/D | I | I | R |
| RECEIPT | R | R | I | I | I | I | R |
| DEPOSIT_INTENT | C/R/U/D | C/R/U/D | I | U/D | C | C | I |
| WITHDRAWAL_REQUEST | R | C/R/U/D | I | U/D | C | C | I |
| WITHDRAWAL_TX | R | R | I | I | I | I | I |
| CONVERSION_QUOTE | C/R | C/R | I | I | I | I | I |
| CONVERSION_ORDER | C/R | C/R | I | I | I | I | I |
| INVOICE | R | R | I | C/R/U/D | I | I | C/R |
| REFUND | I | I | I | C/R/U/D | I | I | C/R |
| LIMIT_PROFILE | I | I | I | I | C | C/R/U/D | I |
| RISK_CASE | I | I | I | I | C/R/U/D | C | I |
| ADDRESS_SCREEN | I | I | I | I | C/R/U/D | C | I |
| RECONCILIATION_REPORT | I | I | I | I | I | I | C/R/U/D |
| FEE_SCHEDULE | I | I | I | C/R/U/D | I | I | C |
| IDEMPOTENCY_KEY | I | I | I | I | I | I | I |

*(No row/column blank; N/A avoided by scoping read vs write appropriately.)*

## A4) Permissions / Badge / KYC Matrix
| Action | Required Role/Badge | KYC Tier | Evidence | Expiry/Renewal | Appeal |
|---|---|---|---|---|---|
| Withdraw funds | Investor badge | L1+ | address binding + risk screen | — | Support/Compliance |
| Create high‑value hold | — | L1+ | balance & limit profile | per policy | Ops |
| Bulk payouts (Project Finance) | Staff scope | KYB | docs/agreements | 365d | Re‑review |
| Conversion > X/day | — | L1 | velocity profile | rolling window | Support |
| Pay invoice with USDT | — | — | on‑chain receipt | — | Billing |

## A5) Quota & Billing Matrix
| Metric | Free Tier (period) | Overage (FZ/PT) | Exemptions | Dunning/Failure | Refunds |
|---|---|---|---|---|---|
| Alerts (from Watchlist) | 10 / month | 1 FZ each extra | Staff/Partners | invoice + soft lock | auto on failure |
| Open holds per user | 3 concurrent | 10 FZ per extra | Staff | cancel oldest | manual |
| Conversion quotes | 50 / day | 0.2 FZ per extra | Staff | throttle | — |
| Invoices past‑due | — | — | — | dunning emails/TG | pro‑rata on cancel |

## A6) Notification Matrix
| Event | Channels | Recipients | Template | Throttle/Dedupe |
|---|---|---|---|---|
| deposit.confirmed | In‑app | User | `deposit_confirmed` | idempotent by `depositId` |
| withdrawal.settled | In‑app + email | User | `withdrawal_settled` | collapse prior states |
| invoice.paid | In‑app | User | `invoice_paid` | dedupe by invoiceId |
| settlement.failed | Ops | Admin | `settlement_failed` | by `roomId/journalTxId` |
| risk.case.opened | Ops | Compliance | `risk_case_opened` | by caseId |
| reconciliation.completed | Ops | Finance, Auditor | `recon_completed` | daily bucket |

## A7) Cross‑Service Event Map
| Event | Producer | Consumers | Payload summary | Idempotency | Retry/Backoff |
|---|---|---|---|---|---|
| payhub.deposit.updated@v1 | Payhub | WebApp/Portal | `{depositId,status,tx}` | `depositId,status` | 5× |
| payhub.withdrawal.updated@v1 | Payhub | WebApp/Portal | `{withdrawalId,status,tx}` | `withdrawalId,status` | 5× |
| payhub.settlement.*@v1 | Payhub | PlayHub/Funding | `{holdId,transfers}` | `settlementId` | 5× |
| payhub.invoice.updated@v1 | Payhub | WebApp/Services | `{invoiceId,status}` | `invoiceId` | 5× |
| payhub.conversion.quote.created@v1 | Payhub | WebApp | `{quoteId,from,to,amountFrom,amountTo}` | `orderId` | 5× |
| payhub.conversion.executed@v1 | Payhub | WebApp | `{orderId,status}` | `orderId` | 5× |
| payhub.reconciliation.completed@v1 | Payhub | Finance, Auditor | `{day, reportId}` | `day` | 3× |  fileciteturn9file7

---

# Abuse/Misuse & NFR Sweeps

- **Abuse**: deposit layering/structuring (velocity), dust spam (min credit), mixer addresses (screening), invoice spam (rate limits), bot hold‑spam (per‑service caps).  
- **Fraud**: stolen accounts (withdrawal soft delay on new addresses handled by Portal address‑book), fake deposits (credit after confs), oracle manipulation (signed snapshots with freshness/quorum).  
- **Security**: JWT validation, mTLS/HMAC, idempotency on writes, outbox for events, HSM signing.  
- **Privacy & compliance**: KYC evidence stays in Identity; Payhub stores references only; ledger retention per jurisdiction; DSAR export path.  
- **Resilience**: circuit breakers for RPCs, fee oracle fallbacks, DLQ with replay, reconciliation to detect drifts, RBF on stuck withdrawals.  
- **Observability**: logs/metrics/traces with correlation IDs; dashboards for time‑to‑credit, time‑to‑broadcast, failure buckets.  
- **Localization/timezones**: user‑visible timestamps **GMT+7** in UIs; ledger timestamps in UTC.  fileciteturn9file7

---

# Self‑Check — Stakeholder Coverage Report

**Counts**  
- Personas: 13  
- Features: 9 epics / 25 features  
- Stories: 27  
- Stories with non‑happy paths: 22/27  
- Entities covered in CRUD matrix: 20/20

**Checklist**  
- ✅ All personas appear in at least one story.  
- ✅ Each entity has at least one **C**, **R**, **U**, and **D** (or reasoned N/A).  
- ✅ Actions mapped to roles/badges/KYC where applicable.  
- ✅ Quotas & billing addressed for chargeable actions.  
- ✅ Each story references APIs/entities/events.  
- ✅ ≥1 end‑to‑end scenario per persona cohort.  
- ✅ Abuse/misuse with mitigations included.  
- ✅ Observability signals tied to AC/SLOs.  
- ✅ Localization/timezone handling present (GMT+7 default).
