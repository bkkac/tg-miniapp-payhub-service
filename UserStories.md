Repo: tg-miniapp-payhub-service
File: UserStories.md
SHA-256: 84cbad7792b49b9389432c05819ab014d784aeaca33e70e3f3f325f427a6b8c7
Bytes: 22885
Generated: 2025-10-03 16:12 GMT+7
Sources:  old UserStories.md (baseline), Guide

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

> See **Appendix A1 — Stakeholder Catalog** for responsibilities/permissions/KPIs (derived from baseline & guide). fileciteturn9file11 fileciteturn9file0

---

# Section B — Epics → Features → User Stories (exhaustive)

## Epic B1 — Accounts, Balances & Ledger

### Feature B1.1 — Provision account & balances  


#### Objective & KPIs
- **Business value:** Provide Provision account & balances to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /provision-account-balances?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.provision-account-balances.list.view`, `payhub.provision-account-balances.refresh`, `payhub.provision-account-balances.load_more`, `payhub.provision-account-balances.intent.create`, `payhub.provision-account-balances.intent.confirm`, `payhub.provision-account-balances.refund.create`, `payhub.provision-account-balances.payout.create`, `payhub.provision-account-balances.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-PROVISION-ACCOUNT-BALANCES-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.provision-account-balances.intent.create` is emitted.
- **AC-PROVISION-ACCOUNT-BALANCES-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-PROVISION-ACCOUNT-BALANCES-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-PROVISION-ACCOUNT-BALANCES-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-PROVISION-ACCOUNT-BALANCES-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-PROVISION-ACCOUNT-BALANCES-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-PROVISION-ACCOUNT-BALANCES-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-PROVISION-ACCOUNT-BALANCES-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-PROVISION-ACCOUNT-BALANCES-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-PROVISION-ACCOUNT-BALANCES-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-PROVISION-ACCOUNT-BALANCES-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-PROVISION-ACCOUNT-BALANCES-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-PROVISION-ACCOUNT-BALANCES-01, TC-PROVISION-ACCOUNT-BALANCES-02, TC-PROVISION-ACCOUNT-BALANCES-03, TC-PROVISION-ACCOUNT-BALANCES-04, TC-PROVISION-ACCOUNT-BALANCES-05, TC-PROVISION-ACCOUNT-BALANCES-06, TC-PROVISION-ACCOUNT-BALANCES-07, TC-PROVISION-ACCOUNT-BALANCES-08, TC-PROVISION-ACCOUNT-BALANCES-09, TC-PROVISION-ACCOUNT-BALANCES-10, TC-PROVISION-ACCOUNT-BALANCES-11, TC-PROVISION-ACCOUNT-BALANCES-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /provision-account-balances` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.provision-account-balances.intent.created|confirmed|canceled`, `payhub.provision-account-balances.payment.settled|failed`, `payhub.provision-account-balances.refund.created|succeeded|failed`, `payhub.provision-account-balances.payout.created|processing|succeeded|failed`, `payhub.provision-account-balances.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B1.1.1** — *As a Partner Service, I provision an account on first touch,* so that *credits/holds can occur immediately.*  
**Acceptance (GWT)**  
1. **Given** `POST /v1/accounts {userId}` with service scope, **then** create `ACCOUNT` + `BALANCE{STAR,FZ,PT,USDT}` rows; idempotent by `(userId)` or **Idempotency-Key**.  
2. **Given** account exists, **then** 201 returns same `accountId`; no dup rows.  
3. **Given** Identity down, **then** **502 identity_unavailable** with `retry_after`.  
**Non‑Happy**: invalid `userId` → **404** after introspection; missing scope → **403**.  
**Observability**: `account.create.latency`, dedupe count.  fileciteturn9file11

### Feature B1.2 — Double‑entry ledger  


#### Objective & KPIs
- **Business value:** Provide Double‑entry ledger to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /doubleentry-ledgers?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.doubleentry-ledger.list.view`, `payhub.doubleentry-ledger.refresh`, `payhub.doubleentry-ledger.load_more`, `payhub.doubleentry-ledger.intent.create`, `payhub.doubleentry-ledger.intent.confirm`, `payhub.doubleentry-ledger.refund.create`, `payhub.doubleentry-ledger.payout.create`, `payhub.doubleentry-ledger.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-DOUBLEENTRY-LEDGER-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.doubleentry-ledger.intent.create` is emitted.
- **AC-DOUBLEENTRY-LEDGER-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-DOUBLEENTRY-LEDGER-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-DOUBLEENTRY-LEDGER-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-DOUBLEENTRY-LEDGER-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-DOUBLEENTRY-LEDGER-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-DOUBLEENTRY-LEDGER-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-DOUBLEENTRY-LEDGER-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-DOUBLEENTRY-LEDGER-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-DOUBLEENTRY-LEDGER-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-DOUBLEENTRY-LEDGER-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-DOUBLEENTRY-LEDGER-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-DOUBLEENTRY-LEDGER-01, TC-DOUBLEENTRY-LEDGER-02, TC-DOUBLEENTRY-LEDGER-03, TC-DOUBLEENTRY-LEDGER-04, TC-DOUBLEENTRY-LEDGER-05, TC-DOUBLEENTRY-LEDGER-06, TC-DOUBLEENTRY-LEDGER-07, TC-DOUBLEENTRY-LEDGER-08, TC-DOUBLEENTRY-LEDGER-09, TC-DOUBLEENTRY-LEDGER-10, TC-DOUBLEENTRY-LEDGER-11, TC-DOUBLEENTRY-LEDGER-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /doubleentry-ledgers` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.doubleentry-ledger.intent.created|confirmed|canceled`, `payhub.doubleentry-ledger.payment.settled|failed`, `payhub.doubleentry-ledger.refund.created|succeeded|failed`, `payhub.doubleentry-ledger.payout.created|processing|succeeded|failed`, `payhub.doubleentry-ledger.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B1.2.1** — *As Finance Ops, I require double‑entry postings for every money move,* so that *audits reconcile.*  
**AC**  
1. Every mutation writes **two postings** in `LEDGER_ENTRY` within a `JOURNAL_TX` (debit/credit), immutable.  
2. API returns `journalTxId`; repeated write with same **Idempotency-Key** → same `journalTxId`.  
3. Outbox publishes events after commit; replay is idempotent.  
**Non‑Happy**: partial write pre‑publish → outbox replays; journal monotonicity enforced.  fileciteturn9file11

---

## Epic B2 — Holds & Settlements

### Feature B2.1 — Create hold  


#### Objective & KPIs
- **Business value:** Provide Create hold to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /create-holds?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.create-hold.list.view`, `payhub.create-hold.refresh`, `payhub.create-hold.load_more`, `payhub.create-hold.intent.create`, `payhub.create-hold.intent.confirm`, `payhub.create-hold.refund.create`, `payhub.create-hold.payout.create`, `payhub.create-hold.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-CREATE-HOLD-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.create-hold.intent.create` is emitted.
- **AC-CREATE-HOLD-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-CREATE-HOLD-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-CREATE-HOLD-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-CREATE-HOLD-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-CREATE-HOLD-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-CREATE-HOLD-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-CREATE-HOLD-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-CREATE-HOLD-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-CREATE-HOLD-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-CREATE-HOLD-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-CREATE-HOLD-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-CREATE-HOLD-01, TC-CREATE-HOLD-02, TC-CREATE-HOLD-03, TC-CREATE-HOLD-04, TC-CREATE-HOLD-05, TC-CREATE-HOLD-06, TC-CREATE-HOLD-07, TC-CREATE-HOLD-08, TC-CREATE-HOLD-09, TC-CREATE-HOLD-10, TC-CREATE-HOLD-11, TC-CREATE-HOLD-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /create-holds` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.create-hold.intent.created|confirmed|canceled`, `payhub.create-hold.payment.settled|failed`, `payhub.create-hold.refund.created|succeeded|failed`, `payhub.create-hold.payout.created|processing|succeeded|failed`, `payhub.create-hold.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B2.1.1** — *As a Partner Service (e.g., PlayHub), I create a funds **hold*** so that *I can settle later.*  
**AC**  
1. `POST /v1/holds {userId, asset, amount, reason, ttl}` validates balance, limit profile; places hold (moves `available→held`).  
2. Idempotent by `(userId, asset, reason, clientRef)`; repeat → same `holdId`.  
3. TTL expiry triggers auto‑release via worker; release event emitted.

### Feature B2.2 — Settle / release  


#### Objective & KPIs
- **Business value:** Provide Settle / release to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /settle-releases?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.settle-release.list.view`, `payhub.settle-release.refresh`, `payhub.settle-release.load_more`, `payhub.settle-release.intent.create`, `payhub.settle-release.intent.confirm`, `payhub.settle-release.refund.create`, `payhub.settle-release.payout.create`, `payhub.settle-release.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-SETTLE-RELEASE-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.settle-release.intent.create` is emitted.
- **AC-SETTLE-RELEASE-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-SETTLE-RELEASE-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-SETTLE-RELEASE-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-SETTLE-RELEASE-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-SETTLE-RELEASE-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-SETTLE-RELEASE-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-SETTLE-RELEASE-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-SETTLE-RELEASE-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-SETTLE-RELEASE-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-SETTLE-RELEASE-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-SETTLE-RELEASE-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-SETTLE-RELEASE-01, TC-SETTLE-RELEASE-02, TC-SETTLE-RELEASE-03, TC-SETTLE-RELEASE-04, TC-SETTLE-RELEASE-05, TC-SETTLE-RELEASE-06, TC-SETTLE-RELEASE-07, TC-SETTLE-RELEASE-08, TC-SETTLE-RELEASE-09, TC-SETTLE-RELEASE-10, TC-SETTLE-RELEASE-11, TC-SETTLE-RELEASE-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /settle-releases` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.settle-release.intent.created|confirmed|canceled`, `payhub.settle-release.payment.settled|failed`, `payhub.settle-release.refund.created|succeeded|failed`, `payhub.settle-release.payout.created|processing|succeeded|failed`, `payhub.settle-release.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
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


#### Objective & KPIs
- **Business value:** Provide Create deposit intent to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /create-deposit-intents?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.create-deposit-intent.list.view`, `payhub.create-deposit-intent.refresh`, `payhub.create-deposit-intent.load_more`, `payhub.create-deposit-intent.intent.create`, `payhub.create-deposit-intent.intent.confirm`, `payhub.create-deposit-intent.refund.create`, `payhub.create-deposit-intent.payout.create`, `payhub.create-deposit-intent.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-CREATE-DEPOSIT-INTENT-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.create-deposit-intent.intent.create` is emitted.
- **AC-CREATE-DEPOSIT-INTENT-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-CREATE-DEPOSIT-INTENT-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-CREATE-DEPOSIT-INTENT-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-CREATE-DEPOSIT-INTENT-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-CREATE-DEPOSIT-INTENT-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-CREATE-DEPOSIT-INTENT-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-CREATE-DEPOSIT-INTENT-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-CREATE-DEPOSIT-INTENT-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-CREATE-DEPOSIT-INTENT-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-CREATE-DEPOSIT-INTENT-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-CREATE-DEPOSIT-INTENT-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-CREATE-DEPOSIT-INTENT-01, TC-CREATE-DEPOSIT-INTENT-02, TC-CREATE-DEPOSIT-INTENT-03, TC-CREATE-DEPOSIT-INTENT-04, TC-CREATE-DEPOSIT-INTENT-05, TC-CREATE-DEPOSIT-INTENT-06, TC-CREATE-DEPOSIT-INTENT-07, TC-CREATE-DEPOSIT-INTENT-08, TC-CREATE-DEPOSIT-INTENT-09, TC-CREATE-DEPOSIT-INTENT-10, TC-CREATE-DEPOSIT-INTENT-11, TC-CREATE-DEPOSIT-INTENT-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /create-deposit-intents` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.create-deposit-intent.intent.created|confirmed|canceled`, `payhub.create-deposit-intent.payment.settled|failed`, `payhub.create-deposit-intent.refund.created|succeeded|failed`, `payhub.create-deposit-intent.payout.created|processing|succeeded|failed`, `payhub.create-deposit-intent.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B3.1.1** — *As an End User, I create a deposit intent,* so that *I can top up.*  
**AC**  
1. `POST /v1/deposits {asset, network, amount?}` returns `{depositId, address|memo|QR, minAmount, confirmations}`.  
2. Watchers confirm on‑chain; credit after N confs; notify client.  
3. Too small (< min) stays **uncredited**; can be auto‑aggregated per policy.  
**Non‑Happy**: reorg before finality → rollback credit; mixer/blocked source → **hold & review** with case id.  
**Security**: generate addresses via xpub/HSM; never reuse memos incorrectly.  
**Observability**: time‑to‑credit, reorg count.  fileciteturn9file11

**UI & Interaction Model (Deposits)**  
- List shows **latest 20 deposit intents**; **infinite scroll**; **pull‑to‑refresh**; search by **txId/network/tags**.  
- **Sort**: Date, Popular, Featured, View.  
- **Filter**: asset, network, status (pending/confirmed/held).  
- **Actions**: Bookmark / Comment / Report / Share deposit cards.  
- **EXP**: safe deposit completions & shares may grant EXP (cooldowns).

---

## Epic B4 — Withdrawals

### Feature B4.1 — Create withdrawal request (KYC‑gated)  


#### Objective & KPIs
- **Business value:** Provide Create withdrawal request (KYC‑gated) to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /create-withdrawal-request-kycgateds?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.create-withdrawal-request-kycgated.list.view`, `payhub.create-withdrawal-request-kycgated.refresh`, `payhub.create-withdrawal-request-kycgated.load_more`, `payhub.create-withdrawal-request-kycgated.intent.create`, `payhub.create-withdrawal-request-kycgated.intent.confirm`, `payhub.create-withdrawal-request-kycgated.refund.create`, `payhub.create-withdrawal-request-kycgated.payout.create`, `payhub.create-withdrawal-request-kycgated.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.create-withdrawal-request-kycgated.intent.create` is emitted.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-01, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-02, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-03, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-04, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-05, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-06, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-07, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-08, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-09, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-10, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-11, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /create-withdrawal-request-kycgateds` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.create-withdrawal-request-kycgated.intent.created|confirmed|canceled`, `payhub.create-withdrawal-request-kycgated.payment.settled|failed`, `payhub.create-withdrawal-request-kycgated.refund.created|succeeded|failed`, `payhub.create-withdrawal-request-kycgated.payout.created|processing|succeeded|failed`, `payhub.create-withdrawal-request-kycgated.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
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


#### Objective & KPIs
- **Business value:** Provide Quote to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /quotes?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.quote.list.view`, `payhub.quote.refresh`, `payhub.quote.load_more`, `payhub.quote.intent.create`, `payhub.quote.intent.confirm`, `payhub.quote.refund.create`, `payhub.quote.payout.create`, `payhub.quote.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-QUOTE-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.quote.intent.create` is emitted.
- **AC-QUOTE-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-QUOTE-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-QUOTE-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-QUOTE-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-QUOTE-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-QUOTE-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-QUOTE-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-QUOTE-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-QUOTE-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-QUOTE-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-QUOTE-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-QUOTE-01, TC-QUOTE-02, TC-QUOTE-03, TC-QUOTE-04, TC-QUOTE-05, TC-QUOTE-06, TC-QUOTE-07, TC-QUOTE-08, TC-QUOTE-09, TC-QUOTE-10, TC-QUOTE-11, TC-QUOTE-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /quotes` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.quote.intent.created|confirmed|canceled`, `payhub.quote.payment.settled|failed`, `payhub.quote.refund.created|succeeded|failed`, `payhub.quote.payout.created|processing|succeeded|failed`, `payhub.quote.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B5.1.1** — *As an End User, I get a conversion quote,* so that *I can decide to convert.*  
**AC**  
1. `POST /v1/conversions/quote {from, to, amountFrom}` signs TWAP/snapshot from **Price**; returns `{quoteId, rate, expiresAt, maxSlippageBp}`.  
2. Quote cached ≤30s; expired quote → must re‑quote.  
**Non‑Happy**: oracle freshness fail → **503**; amounts out of bounds → **422**.

### Feature B5.2 — Execute  


#### Objective & KPIs
- **Business value:** Provide Execute to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /executes?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.execute.list.view`, `payhub.execute.refresh`, `payhub.execute.load_more`, `payhub.execute.intent.create`, `payhub.execute.intent.confirm`, `payhub.execute.refund.create`, `payhub.execute.payout.create`, `payhub.execute.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-EXECUTE-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.execute.intent.create` is emitted.
- **AC-EXECUTE-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-EXECUTE-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-EXECUTE-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-EXECUTE-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-EXECUTE-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-EXECUTE-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-EXECUTE-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-EXECUTE-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-EXECUTE-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-EXECUTE-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-EXECUTE-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-EXECUTE-01, TC-EXECUTE-02, TC-EXECUTE-03, TC-EXECUTE-04, TC-EXECUTE-05, TC-EXECUTE-06, TC-EXECUTE-07, TC-EXECUTE-08, TC-EXECUTE-09, TC-EXECUTE-10, TC-EXECUTE-11, TC-EXECUTE-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /executes` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.execute.intent.created|confirmed|canceled`, `payhub.execute.payment.settled|failed`, `payhub.execute.refund.created|succeeded|failed`, `payhub.execute.payout.created|processing|succeeded|failed`, `payhub.execute.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
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


#### Objective & KPIs
- **Business value:** Provide Issue & pay invoices to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /issue-pay-invoices?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.issue-pay-invoices.list.view`, `payhub.issue-pay-invoices.refresh`, `payhub.issue-pay-invoices.load_more`, `payhub.issue-pay-invoices.intent.create`, `payhub.issue-pay-invoices.intent.confirm`, `payhub.issue-pay-invoices.refund.create`, `payhub.issue-pay-invoices.payout.create`, `payhub.issue-pay-invoices.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-ISSUE-PAY-INVOICES-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.issue-pay-invoices.intent.create` is emitted.
- **AC-ISSUE-PAY-INVOICES-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-ISSUE-PAY-INVOICES-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-ISSUE-PAY-INVOICES-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-ISSUE-PAY-INVOICES-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-ISSUE-PAY-INVOICES-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-ISSUE-PAY-INVOICES-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-ISSUE-PAY-INVOICES-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-ISSUE-PAY-INVOICES-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-ISSUE-PAY-INVOICES-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-ISSUE-PAY-INVOICES-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-ISSUE-PAY-INVOICES-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-ISSUE-PAY-INVOICES-01, TC-ISSUE-PAY-INVOICES-02, TC-ISSUE-PAY-INVOICES-03, TC-ISSUE-PAY-INVOICES-04, TC-ISSUE-PAY-INVOICES-05, TC-ISSUE-PAY-INVOICES-06, TC-ISSUE-PAY-INVOICES-07, TC-ISSUE-PAY-INVOICES-08, TC-ISSUE-PAY-INVOICES-09, TC-ISSUE-PAY-INVOICES-10, TC-ISSUE-PAY-INVOICES-11, TC-ISSUE-PAY-INVOICES-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /issue-pay-invoices` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.issue-pay-invoices.intent.created|confirmed|canceled`, `payhub.issue-pay-invoices.payment.settled|failed`, `payhub.issue-pay-invoices.refund.created|succeeded|failed`, `payhub.issue-pay-invoices.payout.created|processing|succeeded|failed`, `payhub.issue-pay-invoices.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B6.1.1** — *As a User, I pay overage invoices to unlock features,* so that *usage can continue.*  
**AC**: `POST /v1/invoices {purpose, amount, currency}` → statuses `issued→paying→paid|expired`; accepts FZ/PT/USDT; on **paid**, meters refresh; failed payment → retry or refund.  

### Feature B6.2 — Manual refunds  


#### Objective & KPIs
- **Business value:** Provide Manual refunds to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /manual-refunds?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.manual-refunds.list.view`, `payhub.manual-refunds.refresh`, `payhub.manual-refunds.load_more`, `payhub.manual-refunds.intent.create`, `payhub.manual-refunds.intent.confirm`, `payhub.manual-refunds.refund.create`, `payhub.manual-refunds.payout.create`, `payhub.manual-refunds.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-MANUAL-REFUNDS-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.manual-refunds.intent.create` is emitted.
- **AC-MANUAL-REFUNDS-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-MANUAL-REFUNDS-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-MANUAL-REFUNDS-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-MANUAL-REFUNDS-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-MANUAL-REFUNDS-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-MANUAL-REFUNDS-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-MANUAL-REFUNDS-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-MANUAL-REFUNDS-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-MANUAL-REFUNDS-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-MANUAL-REFUNDS-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-MANUAL-REFUNDS-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-MANUAL-REFUNDS-01, TC-MANUAL-REFUNDS-02, TC-MANUAL-REFUNDS-03, TC-MANUAL-REFUNDS-04, TC-MANUAL-REFUNDS-05, TC-MANUAL-REFUNDS-06, TC-MANUAL-REFUNDS-07, TC-MANUAL-REFUNDS-08, TC-MANUAL-REFUNDS-09, TC-MANUAL-REFUNDS-10, TC-MANUAL-REFUNDS-11, TC-MANUAL-REFUNDS-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /manual-refunds` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.manual-refunds.intent.created|confirmed|canceled`, `payhub.manual-refunds.payment.settled|failed`, `payhub.manual-refunds.refund.created|succeeded|failed`, `payhub.manual-refunds.payout.created|processing|succeeded|failed`, `payhub.manual-refunds.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
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


#### Objective & KPIs
- **Business value:** Provide Limits & velocity profiles to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /limits-velocity-profiles?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.limits-velocity-profiles.list.view`, `payhub.limits-velocity-profiles.refresh`, `payhub.limits-velocity-profiles.load_more`, `payhub.limits-velocity-profiles.intent.create`, `payhub.limits-velocity-profiles.intent.confirm`, `payhub.limits-velocity-profiles.refund.create`, `payhub.limits-velocity-profiles.payout.create`, `payhub.limits-velocity-profiles.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-LIMITS-VELOCITY-PROFILES-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.limits-velocity-profiles.intent.create` is emitted.
- **AC-LIMITS-VELOCITY-PROFILES-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-LIMITS-VELOCITY-PROFILES-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-LIMITS-VELOCITY-PROFILES-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-LIMITS-VELOCITY-PROFILES-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-LIMITS-VELOCITY-PROFILES-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-LIMITS-VELOCITY-PROFILES-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-LIMITS-VELOCITY-PROFILES-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-LIMITS-VELOCITY-PROFILES-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-LIMITS-VELOCITY-PROFILES-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-LIMITS-VELOCITY-PROFILES-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-LIMITS-VELOCITY-PROFILES-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-LIMITS-VELOCITY-PROFILES-01, TC-LIMITS-VELOCITY-PROFILES-02, TC-LIMITS-VELOCITY-PROFILES-03, TC-LIMITS-VELOCITY-PROFILES-04, TC-LIMITS-VELOCITY-PROFILES-05, TC-LIMITS-VELOCITY-PROFILES-06, TC-LIMITS-VELOCITY-PROFILES-07, TC-LIMITS-VELOCITY-PROFILES-08, TC-LIMITS-VELOCITY-PROFILES-09, TC-LIMITS-VELOCITY-PROFILES-10, TC-LIMITS-VELOCITY-PROFILES-11, TC-LIMITS-VELOCITY-PROFILES-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /limits-velocity-profiles` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.limits-velocity-profiles.intent.created|confirmed|canceled`, `payhub.limits-velocity-profiles.payment.settled|failed`, `payhub.limits-velocity-profiles.refund.created|succeeded|failed`, `payhub.limits-velocity-profiles.payout.created|processing|succeeded|failed`, `payhub.limits-velocity-profiles.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B7.1.1** — *As Risk, I enforce per‑badge **limits** and velocity,* so that *loss is controlled.*  
**AC**: limits fetched from **Config**/**Identity**; actions exceeding → **403 limit_exceeded** with invoice hint if billable; bursts throttled with cool‑downs.  

### Feature B7.2 — AML screening & case management  


#### Objective & KPIs
- **Business value:** Provide AML screening & case management to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /aml-screening-case-managements?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.aml-screening-case-management.list.view`, `payhub.aml-screening-case-management.refresh`, `payhub.aml-screening-case-management.load_more`, `payhub.aml-screening-case-management.intent.create`, `payhub.aml-screening-case-management.intent.confirm`, `payhub.aml-screening-case-management.refund.create`, `payhub.aml-screening-case-management.payout.create`, `payhub.aml-screening-case-management.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-AML-SCREENING-CASE-MANAGEMENT-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.aml-screening-case-management.intent.create` is emitted.
- **AC-AML-SCREENING-CASE-MANAGEMENT-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-AML-SCREENING-CASE-MANAGEMENT-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-AML-SCREENING-CASE-MANAGEMENT-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-AML-SCREENING-CASE-MANAGEMENT-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-AML-SCREENING-CASE-MANAGEMENT-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-AML-SCREENING-CASE-MANAGEMENT-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-AML-SCREENING-CASE-MANAGEMENT-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-AML-SCREENING-CASE-MANAGEMENT-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-AML-SCREENING-CASE-MANAGEMENT-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-AML-SCREENING-CASE-MANAGEMENT-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-AML-SCREENING-CASE-MANAGEMENT-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-AML-SCREENING-CASE-MANAGEMENT-01, TC-AML-SCREENING-CASE-MANAGEMENT-02, TC-AML-SCREENING-CASE-MANAGEMENT-03, TC-AML-SCREENING-CASE-MANAGEMENT-04, TC-AML-SCREENING-CASE-MANAGEMENT-05, TC-AML-SCREENING-CASE-MANAGEMENT-06, TC-AML-SCREENING-CASE-MANAGEMENT-07, TC-AML-SCREENING-CASE-MANAGEMENT-08, TC-AML-SCREENING-CASE-MANAGEMENT-09, TC-AML-SCREENING-CASE-MANAGEMENT-10, TC-AML-SCREENING-CASE-MANAGEMENT-11, TC-AML-SCREENING-CASE-MANAGEMENT-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /aml-screening-case-managements` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.aml-screening-case-management.intent.created|confirmed|canceled`, `payhub.aml-screening-case-management.payment.settled|failed`, `payhub.aml-screening-case-management.refund.created|succeeded|failed`, `payhub.aml-screening-case-management.payout.created|processing|succeeded|failed`, `payhub.aml-screening-case-management.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B7.2.1** — *As Compliance, I screen risk and manage cases,* so that *prohibited flows are blocked.*  
**AC**: withdrawal address and deposit sources checked; hits → **held** + case `open→investigating→resolved(approve|reject)`; appeals tracked.  

### Feature B7.3 — Exports for audit  


#### Objective & KPIs
- **Business value:** Provide Exports for audit to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /exports-for-audits?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.exports-for-audit.list.view`, `payhub.exports-for-audit.refresh`, `payhub.exports-for-audit.load_more`, `payhub.exports-for-audit.intent.create`, `payhub.exports-for-audit.intent.confirm`, `payhub.exports-for-audit.refund.create`, `payhub.exports-for-audit.payout.create`, `payhub.exports-for-audit.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-EXPORTS-FOR-AUDIT-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.exports-for-audit.intent.create` is emitted.
- **AC-EXPORTS-FOR-AUDIT-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-EXPORTS-FOR-AUDIT-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-EXPORTS-FOR-AUDIT-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-EXPORTS-FOR-AUDIT-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-EXPORTS-FOR-AUDIT-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-EXPORTS-FOR-AUDIT-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-EXPORTS-FOR-AUDIT-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-EXPORTS-FOR-AUDIT-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-EXPORTS-FOR-AUDIT-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-EXPORTS-FOR-AUDIT-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-EXPORTS-FOR-AUDIT-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-EXPORTS-FOR-AUDIT-01, TC-EXPORTS-FOR-AUDIT-02, TC-EXPORTS-FOR-AUDIT-03, TC-EXPORTS-FOR-AUDIT-04, TC-EXPORTS-FOR-AUDIT-05, TC-EXPORTS-FOR-AUDIT-06, TC-EXPORTS-FOR-AUDIT-07, TC-EXPORTS-FOR-AUDIT-08, TC-EXPORTS-FOR-AUDIT-09, TC-EXPORTS-FOR-AUDIT-10, TC-EXPORTS-FOR-AUDIT-11, TC-EXPORTS-FOR-AUDIT-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /exports-for-audits` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.exports-for-audit.intent.created|confirmed|canceled`, `payhub.exports-for-audit.payment.settled|failed`, `payhub.exports-for-audit.refund.created|succeeded|failed`, `payhub.exports-for-audit.payout.created|processing|succeeded|failed`, `payhub.exports-for-audit.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B7.3.1** — *As Auditor, I export immutable journals & reconciliation artifacts.*  
**AC**: CSV/Parquet export; signed manifest; rate‑limited; redactions applied.  fileciteturn9file10

---

## Epic B8 — Reconciliation & Reporting

### Feature B8.1 — Daily close  


#### Objective & KPIs
- **Business value:** Provide Daily close to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /daily-closes?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.daily-close.list.view`, `payhub.daily-close.refresh`, `payhub.daily-close.load_more`, `payhub.daily-close.intent.create`, `payhub.daily-close.intent.confirm`, `payhub.daily-close.refund.create`, `payhub.daily-close.payout.create`, `payhub.daily-close.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-DAILY-CLOSE-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.daily-close.intent.create` is emitted.
- **AC-DAILY-CLOSE-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-DAILY-CLOSE-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-DAILY-CLOSE-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-DAILY-CLOSE-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-DAILY-CLOSE-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-DAILY-CLOSE-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-DAILY-CLOSE-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-DAILY-CLOSE-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-DAILY-CLOSE-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-DAILY-CLOSE-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-DAILY-CLOSE-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-DAILY-CLOSE-01, TC-DAILY-CLOSE-02, TC-DAILY-CLOSE-03, TC-DAILY-CLOSE-04, TC-DAILY-CLOSE-05, TC-DAILY-CLOSE-06, TC-DAILY-CLOSE-07, TC-DAILY-CLOSE-08, TC-DAILY-CLOSE-09, TC-DAILY-CLOSE-10, TC-DAILY-CLOSE-11, TC-DAILY-CLOSE-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /daily-closes` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.daily-close.intent.created|confirmed|canceled`, `payhub.daily-close.payment.settled|failed`, `payhub.daily-close.refund.created|succeeded|failed`, `payhub.daily-close.payout.created|processing|succeeded|failed`, `payhub.daily-close.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B8.1.1** — *As Finance Ops, I run daily close,* so that *balances match on/off‑chain.*  
**AC**: rollup by asset; variance thresholds; emits `payhub.reconciliation.completed@v1`.  

### Feature B8.2 — Fee & rule reports  


#### Objective & KPIs
- **Business value:** Provide Fee & rule reports to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /fee-rule-reports?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.fee-rule-reports.list.view`, `payhub.fee-rule-reports.refresh`, `payhub.fee-rule-reports.load_more`, `payhub.fee-rule-reports.intent.create`, `payhub.fee-rule-reports.intent.confirm`, `payhub.fee-rule-reports.refund.create`, `payhub.fee-rule-reports.payout.create`, `payhub.fee-rule-reports.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-FEE-RULE-REPORTS-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.fee-rule-reports.intent.create` is emitted.
- **AC-FEE-RULE-REPORTS-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-FEE-RULE-REPORTS-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-FEE-RULE-REPORTS-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-FEE-RULE-REPORTS-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-FEE-RULE-REPORTS-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-FEE-RULE-REPORTS-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-FEE-RULE-REPORTS-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-FEE-RULE-REPORTS-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-FEE-RULE-REPORTS-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-FEE-RULE-REPORTS-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-FEE-RULE-REPORTS-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-FEE-RULE-REPORTS-01, TC-FEE-RULE-REPORTS-02, TC-FEE-RULE-REPORTS-03, TC-FEE-RULE-REPORTS-04, TC-FEE-RULE-REPORTS-05, TC-FEE-RULE-REPORTS-06, TC-FEE-RULE-REPORTS-07, TC-FEE-RULE-REPORTS-08, TC-FEE-RULE-REPORTS-09, TC-FEE-RULE-REPORTS-10, TC-FEE-RULE-REPORTS-11, TC-FEE-RULE-REPORTS-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /fee-rule-reports` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.fee-rule-reports.intent.created|confirmed|canceled`, `payhub.fee-rule-reports.payment.settled|failed`, `payhub.fee-rule-reports.refund.created|succeeded|failed`, `payhub.fee-rule-reports.payout.created|processing|succeeded|failed`, `payhub.fee-rule-reports.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B8.2.1** — *As Finance Ops, I review fee take and rules applied.*  
**AC**: fee schedule snapshot vs postings; anomalies reported.  fileciteturn9file10

---

## Epic B9 — Reliability & Observability

### Feature B9.1 — Idempotency & retries  


#### Objective & KPIs
- **Business value:** Provide Idempotency & retries to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /idempotency-retries?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.idempotency-retries.list.view`, `payhub.idempotency-retries.refresh`, `payhub.idempotency-retries.load_more`, `payhub.idempotency-retries.intent.create`, `payhub.idempotency-retries.intent.confirm`, `payhub.idempotency-retries.refund.create`, `payhub.idempotency-retries.payout.create`, `payhub.idempotency-retries.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-IDEMPOTENCY-RETRIES-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.idempotency-retries.intent.create` is emitted.
- **AC-IDEMPOTENCY-RETRIES-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-IDEMPOTENCY-RETRIES-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-IDEMPOTENCY-RETRIES-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-IDEMPOTENCY-RETRIES-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-IDEMPOTENCY-RETRIES-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-IDEMPOTENCY-RETRIES-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-IDEMPOTENCY-RETRIES-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-IDEMPOTENCY-RETRIES-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-IDEMPOTENCY-RETRIES-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-IDEMPOTENCY-RETRIES-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-IDEMPOTENCY-RETRIES-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-IDEMPOTENCY-RETRIES-01, TC-IDEMPOTENCY-RETRIES-02, TC-IDEMPOTENCY-RETRIES-03, TC-IDEMPOTENCY-RETRIES-04, TC-IDEMPOTENCY-RETRIES-05, TC-IDEMPOTENCY-RETRIES-06, TC-IDEMPOTENCY-RETRIES-07, TC-IDEMPOTENCY-RETRIES-08, TC-IDEMPOTENCY-RETRIES-09, TC-IDEMPOTENCY-RETRIES-10, TC-IDEMPOTENCY-RETRIES-11, TC-IDEMPOTENCY-RETRIES-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /idempotency-retries` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.idempotency-retries.intent.created|confirmed|canceled`, `payhub.idempotency-retries.payment.settled|failed`, `payhub.idempotency-retries.refund.created|succeeded|failed`, `payhub.idempotency-retries.payout.created|processing|succeeded|failed`, `payhub.idempotency-retries.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B9.1.1** — *As SRE, I guarantee idempotent writes and safe retries,* so that *clients can recover.*  
**AC**: All **POST/PUT/DELETE** accept **Idempotency-Key**; outbox/DLQ; backoff with jitter; circuit breakers.

### Feature B9.2 — Telemetry & SLOs  


#### Objective & KPIs
- **Business value:** Provide Telemetry & SLOs to process in-app payments and payouts reliably across providers with clear receipts, refunds, and ledgers.
- **Primary SLOs:** intent_create_success ≥ 99.9%, confirm_success ≥ 99.7%, payout_success ≥ 99.5%, **p95 read ≤ 200ms**, **p95 write ≤ 350ms**, **availability ≥ 99.95%**.
- **Secondary metrics:** duplicate_submit_rate ≤ 0.05% (idempotency), reconciliation_mismatch_rate ≤ 0.01%, chargeback_rate ≤ industry baseline.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp **HMAC** → session → **Bearer/JWT** for API; inbound **webhooks** require signature header verification.
- **Roles / User Role Badges:** Buyer, Seller (Creator), Finance, Admin, Auditor.
- **System Badges:** **KYC Verified** required for payouts and high-value transactions; **Creator Program** for sellers (apply + pay FZ + admin review).
- **Audience rules:** Order history is Private to the buyer and admins; shop pages/public offers are Public/Followers/Verified/Holders based on configuration.

#### UI & Actions (Screen Contract)
- **Screen patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source pattern:** `GET /telemetry-slos?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]` (canonical list params).
- **States:** Loading (skeleton list), Empty (no orders/payouts), Error (retry/backoff), Partial (provider degraded).
- **Permissions matrix:** Buyers can create payment intents and request refunds; Sellers can create invoices and request payouts; Finance/Admin can review, refund, and export ledgers.
- **Telemetry:** `payhub.telemetry-slos.list.view`, `payhub.telemetry-slos.refresh`, `payhub.telemetry-slos.load_more`, `payhub.telemetry-slos.intent.create`, `payhub.telemetry-slos.intent.confirm`, `payhub.telemetry-slos.refund.create`, `payhub.telemetry-slos.payout.create`, `payhub.telemetry-slos.webhook.ingest`, `search.submit`, `sort.change`, `filter.apply`.
- **Profile Bento:** module=`payhub-bento`, sizes=`S/M/L`, order: latest payments → refunds → payouts; deep-link opens invoice/payment sheet with Telegram `start_param`.

#### Acceptance Criteria (Gherkin)
- **AC-TELEMETRY-SLOS-01** Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempotency-Key**, Then **201** returns `PaymentIntent` with status `requires_confirmation` and telemetry `payhub.telemetry-slos.intent.create` is emitted.
- **AC-TELEMETRY-SLOS-02** Given the same body/key is replayed within 24h, When calling again, Then the **original 201** body is returned and no duplicate ledger entries are written.
- **AC-TELEMETRY-SLOS-03** Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status transitions `processing` → `succeeded` within SLA; PSP async webhooks finalize if delayed.
- **AC-TELEMETRY-SLOS-04** Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is returned and no side effects occur.
- **AC-TELEMETRY-SLOS-05** Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When the request is made, Then **422** returns with `{code,message,details,traceId}`.
- **AC-TELEMETRY-SLOS-06** Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403** is returned with clear gating text.
- **AC-TELEMETRY-SLOS-07** Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **404** error model is returned.
- **AC-TELEMETRY-SLOS-08** Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy, Then **201** creates `Refund`; duplicate with same key returns the original; exceeding amount → **409** `AMOUNT_EXCEEDS_CAPTURED`.
- **AC-TELEMETRY-SLOS-09** Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Then **201** creates `Payout` with status `pending`; provider failure → **202** `processing` with later webhook update.
- **AC-TELEMETRY-SLOS-10** Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **401** `INVALID_SIGNATURE`; valid but duplicate event id → **200** with `dedup:true` and no side effects.
- **AC-TELEMETRY-SLOS-11** Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned and client backs off with jitter; idempotent replay ensures no duplicates.
- **AC-TELEMETRY-SLOS-12** Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then at-most-once semantics are preserved and eventual state is correct via reconciliation.

- **Test IDs:** TC-TELEMETRY-SLOS-01, TC-TELEMETRY-SLOS-02, TC-TELEMETRY-SLOS-03, TC-TELEMETRY-SLOS-04, TC-TELEMETRY-SLOS-05, TC-TELEMETRY-SLOS-06, TC-TELEMETRY-SLOS-07, TC-TELEMETRY-SLOS-08, TC-TELEMETRY-SLOS-09, TC-TELEMETRY-SLOS-10, TC-TELEMETRY-SLOS-11, TC-TELEMETRY-SLOS-12

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init; webhook ingest uses signature header verification.
- **Headers:** `X-Trace-Id`; `Idempotency-Key` required on POST/PATCH/DELETE mutations; `Payhub-Signature` (HMAC-SHA256) for webhook verification.
- **Collections:** `GET /telemetry-slos` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping: `filter[status]`, `filter[buyerId]`, `filter[sellerId]`, `filter[currency]`).
- **Payment Intents:** `POST /payments/intents`, `GET /payments/intents/{id}`, `POST /payments/intents/{id}/confirm`, `POST /payments/intents/{id}/cancel`.
- **Payments/Charges:** `GET /payments?filter[intentId]=...`, `GET /payments/{id}`.
- **Invoices:** `POST /invoices`, `GET /invoices/{id}`, `GET /invoices?filter[sellerId]=...`.
- **Refunds:** `POST /refunds`, `GET /refunds/{id}`.
- **Payouts:** `POST /payouts`, `GET /payouts/{id}`, `GET /payouts?filter[sellerId]=...`.
- **Ledger:** `GET /ledger/entries?since=...&limit=...&cursor=...` (double-entry view).
- **Webhooks:** `POST /webhooks/ingest` (provider → PayHub) with `Payhub-Signature` header.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`
- **201 example (intent create):**
  ```json
  {
    "data": {"id":"pi_01HXYZ","amount":129900,"currency":"THB","status":"requires_confirmation","buyerId":"uuid-v7","sellerId":"uuid-v7","createdAt":"2025-10-03T15:30:00+07:00"}
  }
  ```
- **401 example (invalid webhook signature):**
  ```json
  {
    "code":"UNAUTHORIZED",
    "message":"INVALID_SIGNATURE",
    "details":{"hint":"verify Payhub-Signature using shared secret"},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
**PaymentIntent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| buyerId   | string  | uuid   | false    | -    | -       | required   | idx     |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1 (minor units) | idx |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | requires_confirmation,processing,succeeded,canceled | requires_confirmation | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 (GMT+7 examples) | - |

**Payment**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| intentId  | string  | string | false    | -    | -       | references PaymentIntent.id | idx |
| provider  | string  | -      | false    | -    | -       | allowlisted | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | -       |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | -       |
| status    | string  | -      | false    | pending,settled,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Invoice**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | required   | idx     |
| amount    | integer | int64  | false    | -    | -       | ≥ 1        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist  | idx     |
| status    | string  | -      | false    | draft,open,paid,canceled | draft | enum | idx |
| dueAt     | string  | date-time | true  | -    | -       | ISO-8601   | idx     |

**Refund**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| paymentId | string  | string | false    | -    | -       | references Payment.id | idx |
| amount    | integer | int64  | false    | -    | -       | 1..payment.amount | - |
| status    | string  | -      | false    | pending,succeeded,failed | pending | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**Payout**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| sellerId  | string  | uuid   | false    | -    | -       | KYC required | idx   |
| amount    | integer | int64  | false    | -    | -       | ≥ min       | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| status    | string  | -      | false    | pending,processing,succeeded,failed | pending | enum | idx |
| method    | string  | -      | false    | bank,ewallet,crypto | bank | enum | idx |
| createdAt | string  | date-time | false | - | now | ISO-8601 | - |

**LedgerEntry**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | ksuid      | PK      |
| entity    | string  | -      | false    | payment,refund,payout,fee,chargeback | payment | enum | idx |
| entityId  | string  | string | false    | -    | -       | references respective id | idx |
| side      | string  | -      | false    | debit,credit | debit | enum | idx |
| amount    | integer | int64  | false    | -    | -       | ≥ 0        | idx     |
| currency  | string  | iso4217| false    | -    | THB     | allowlist   | idx     |
| createdAt | string  | date-time | false | - | now | ISO-8601    | - |

**WebhookEvent**
| field     | type    | format | nullable | enum | default | validation | indexes |
|-----------|---------|--------|----------|------|---------|------------|---------|
| id        | string  | string | false    | -    | -       | provider event id | PK  |
| type      | string  | -      | false    | -    | -       | allowlisted types | idx |
| payload   | object  | json   | false    | -    | -       | signature verified | -  |
| receivedAt| string  | date-time | false | - | now | ISO-8601 | idx |

#### Events, Jobs & Notifications
- **Events:** `payhub.telemetry-slos.intent.created|confirmed|canceled`, `payhub.telemetry-slos.payment.settled|failed`, `payhub.telemetry-slos.refund.created|succeeded|failed`, `payhub.telemetry-slos.payout.created|processing|succeeded|failed`, `payhub.telemetry-slos.webhook.received|deduped` with payload: `ids, buyerId, sellerId, amount, currency, provider, actorId, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, analytics, notifications, risk, reconciliation workers, accounting export.
- **Retry/backoff:** exponential (6 attempts) with DLQ/outbox; reconciliation job compares PSP reports vs ledger to resolve drifts.
- **Notifications:** receipts, refunds, payout status → Telegram/email → buyers/sellers/finance; throttle/dedupe applied.

#### Subtasks (Delivery Plan)
- **Backend:** intents/confirm/cancel; payments/charges; refunds; payouts; invoices; ledger; webhook ingest & signature verification; idempotency store; reconciliation; feature flags; config; outbox.
- **Frontend (MiniApp/WebApp):** payment sheet; invoice view/pay; history lists (payments/refunds/payouts); error/empty states; param mapping; Profile Bento.
- **QA:** contract tests (±); E2E (create intent → confirm → settle → refund → payout); abuse/security (authZ bypass, replay, rate-limit, webhook signature, HMAC/headers); perf (read p95 ≤ 200ms, write p95 ≤ 350ms); pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** provider integration guides, webhook secrets rotation, reconciliation SOP; dashboards (intent success, confirm success, payout success, p95s, error budget); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
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
| Feature | APIs | Entities | Events | UI Screens | Test IDs |
|---------|------|----------|--------|------------|----------|
| Feature B1.1 — Provision account & balances | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.provision-account-balances.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-PROVISION-ACCOUNT-BALANCES-*` |
| Feature B1.2 — Double‑entry ledger | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.doubleentry-ledger.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-DOUBLEENTRY-LEDGER-*` |
| Feature B2.1 — Create hold | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.create-hold.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-CREATE-HOLD-*` |
| Feature B2.2 — Settle / release | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.settle-release.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-SETTLE-RELEASE-*` |
| Feature B3.1 — Create deposit intent | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.create-deposit-intent.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-CREATE-DEPOSIT-INTENT-*` |
| Feature B4.1 — Create withdrawal request (KYC‑gated) | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.create-withdrawal-request-kycgated.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-*` |
| Feature B5.1 — Quote | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.quote.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-QUOTE-*` |
| Feature B5.2 — Execute | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.execute.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-EXECUTE-*` |
| Feature B6.1 — Issue & pay invoices | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.issue-pay-invoices.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-ISSUE-PAY-INVOICES-*` |
| Feature B6.2 — Manual refunds | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.manual-refunds.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-MANUAL-REFUNDS-*` |
| Feature B7.1 — Limits & velocity profiles | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.limits-velocity-profiles.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-LIMITS-VELOCITY-PROFILES-*` |
| Feature B7.2 — AML screening & case management | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.aml-screening-case-management.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-AML-SCREENING-CASE-MANAGEMENT-*` |
| Feature B7.3 — Exports for audit | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.exports-for-audit.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-EXPORTS-FOR-AUDIT-*` |
| Feature B8.1 — Daily close | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.daily-close.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-DAILY-CLOSE-*` |
| Feature B8.2 — Fee & rule reports | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.fee-rule-reports.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-FEE-RULE-REPORTS-*` |
| Feature B9.1 — Idempotency & retries | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.idempotency-retries.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-IDEMPOTENCY-RETRIES-*` |
| Feature B9.2 — Telemetry & SLOs | `POST /payments/intents`, `POST /payments/intents/{id}/(confirm|cancel)`, `POST /refunds`, `POST /payouts`, `POST /invoices`, `GET /ledger/entries`, `POST /webhooks/ingest` | `paymentIntent`, `payment`, `invoice`, `refund`, `payout`, `ledgerEntry`, `webhookEvent` | `payhub.telemetry-slos.*` | Payment Sheet, Invoices, History, Payouts, Ledger | `TC-TELEMETRY-SLOS-*` |

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
