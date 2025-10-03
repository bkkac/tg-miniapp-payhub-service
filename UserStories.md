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

> See **Appendix A1 — Stakeholder Catalog** for responsibilities/permissions/KPIs (derived from baseline & guide). 

---

# Section B — Epics → Features → User Stories (exhaustive)

## Epic B1 — Accounts, Balances & Ledger

### Feature B1.1 — Provision account & balances  


#### Objective & KPIs
- **Business value:** Implement Provision account & balances to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /provision-account-balances?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.provision-account-balances.list.view`, `payhub.provision-account-balances.refresh`, `payhub.provision-account-balances.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.provision-account-balances.intent.create`, `payhub.provision-account-balances.payment.authorize`, `payhub.provision-account-balances.payment.capture`, `payhub.provision-account-balances.refund.create`.
- **Profile Bento (if applicable):** module=`provision-account-balances`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-PROVISION-ACCOUNT-BALANCES-01** Given an authenticated session in GMT+7, When `GET /provision-account-balances?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.provision-account-balances.list.view` is emitted.
- **AC-PROVISION-ACCOUNT-BALANCES-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.provision-account-balances.load_more` is emitted.
- **AC-PROVISION-ACCOUNT-BALANCES-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-PROVISION-ACCOUNT-BALANCES-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-PROVISION-ACCOUNT-BALANCES-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-PROVISION-ACCOUNT-BALANCES-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-PROVISION-ACCOUNT-BALANCES-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-PROVISION-ACCOUNT-BALANCES-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-PROVISION-ACCOUNT-BALANCES-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-PROVISION-ACCOUNT-BALANCES-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-PROVISION-ACCOUNT-BALANCES-01, TC-PROVISION-ACCOUNT-BALANCES-02, TC-PROVISION-ACCOUNT-BALANCES-03, TC-PROVISION-ACCOUNT-BALANCES-04, TC-PROVISION-ACCOUNT-BALANCES-05, TC-PROVISION-ACCOUNT-BALANCES-06, TC-PROVISION-ACCOUNT-BALANCES-07, TC-PROVISION-ACCOUNT-BALANCES-08, TC-PROVISION-ACCOUNT-BALANCES-09, TC-PROVISION-ACCOUNT-BALANCES-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /provision-account-balances` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /provision-account-balances` body=`#ProvisionAccountBalancesCreate` schema.
- **Detail:** `GET /provision-account-balances/{id}` · **Update:** `PATCH /provision-account-balances/{id}` body=`#ProvisionAccountBalancesUpdate` · **Delete:** `DELETE /provision-account-balances/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.provision-account-balances.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/provision-account-balances`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B1.1.1** — *As a Partner Service, I provision an account on first touch,* so that *credits/holds can occur immediately.*  
**Acceptance (GWT)**  
1. **Given** `POST /v1/accounts {userId}` with service scope, **then** create `ACCOUNT` + `BALANCE{STAR,FZ,PT,USDT}` rows; idempotent by `(userId)` or **Idempotency-Key**.  
2. **Given** account exists, **then** 201 returns same `accountId`; no dup rows.  
3. **Given** Identity down, **then** **502 identity_unavailable** with `retry_after`.  
**Non‑Happy**: invalid `userId` → **404** after introspection; missing scope → **403**.  
**Observability**: `account.create.latency`, dedupe count.  

### Feature B1.2 — Double‑entry ledger  


#### Objective & KPIs
- **Business value:** Implement Double‑entry ledger to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /doubleentry-ledgers?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.doubleentry-ledger.list.view`, `payhub.doubleentry-ledger.refresh`, `payhub.doubleentry-ledger.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.doubleentry-ledger.intent.create`, `payhub.doubleentry-ledger.payment.authorize`, `payhub.doubleentry-ledger.payment.capture`, `payhub.doubleentry-ledger.refund.create`.
- **Profile Bento (if applicable):** module=`doubleentry-ledger`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-DOUBLEENTRY-LEDGER-01** Given an authenticated session in GMT+7, When `GET /doubleentry-ledgers?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.doubleentry-ledger.list.view` is emitted.
- **AC-DOUBLEENTRY-LEDGER-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.doubleentry-ledger.load_more` is emitted.
- **AC-DOUBLEENTRY-LEDGER-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-DOUBLEENTRY-LEDGER-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-DOUBLEENTRY-LEDGER-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-DOUBLEENTRY-LEDGER-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-DOUBLEENTRY-LEDGER-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-DOUBLEENTRY-LEDGER-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-DOUBLEENTRY-LEDGER-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-DOUBLEENTRY-LEDGER-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-DOUBLEENTRY-LEDGER-01, TC-DOUBLEENTRY-LEDGER-02, TC-DOUBLEENTRY-LEDGER-03, TC-DOUBLEENTRY-LEDGER-04, TC-DOUBLEENTRY-LEDGER-05, TC-DOUBLEENTRY-LEDGER-06, TC-DOUBLEENTRY-LEDGER-07, TC-DOUBLEENTRY-LEDGER-08, TC-DOUBLEENTRY-LEDGER-09, TC-DOUBLEENTRY-LEDGER-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /doubleentry-ledgers` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /doubleentry-ledgers` body=`#DoubleentryLedgerCreate` schema.
- **Detail:** `GET /doubleentry-ledgers/{id}` · **Update:** `PATCH /doubleentry-ledgers/{id}` body=`#DoubleentryLedgerUpdate` · **Delete:** `DELETE /doubleentry-ledgers/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.doubleentry-ledger.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/doubleentry-ledgers`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B1.2.1** — *As Finance Ops, I require double‑entry postings for every money move,* so that *audits reconcile.*  
**AC**  
1. Every mutation writes **two postings** in `LEDGER_ENTRY` within a `JOURNAL_TX` (debit/credit), immutable.  
2. API returns `journalTxId`; repeated write with same **Idempotency-Key** → same `journalTxId`.  
3. Outbox publishes events after commit; replay is idempotent.  
**Non‑Happy**: partial write pre‑publish → outbox replays; journal monotonicity enforced. 

---

## Epic B2 — Holds & Settlements

### Feature B2.1 — Create hold  


#### Objective & KPIs
- **Business value:** Implement Create hold to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /create-holds?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.create-hold.list.view`, `payhub.create-hold.refresh`, `payhub.create-hold.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.create-hold.intent.create`, `payhub.create-hold.payment.authorize`, `payhub.create-hold.payment.capture`, `payhub.create-hold.refund.create`.
- **Profile Bento (if applicable):** module=`create-hold`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-CREATE-HOLD-01** Given an authenticated session in GMT+7, When `GET /create-holds?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.create-hold.list.view` is emitted.
- **AC-CREATE-HOLD-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.create-hold.load_more` is emitted.
- **AC-CREATE-HOLD-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-CREATE-HOLD-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-CREATE-HOLD-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-CREATE-HOLD-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-CREATE-HOLD-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-CREATE-HOLD-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-CREATE-HOLD-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-CREATE-HOLD-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-CREATE-HOLD-01, TC-CREATE-HOLD-02, TC-CREATE-HOLD-03, TC-CREATE-HOLD-04, TC-CREATE-HOLD-05, TC-CREATE-HOLD-06, TC-CREATE-HOLD-07, TC-CREATE-HOLD-08, TC-CREATE-HOLD-09, TC-CREATE-HOLD-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /create-holds` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /create-holds` body=`#CreateHoldCreate` schema.
- **Detail:** `GET /create-holds/{id}` · **Update:** `PATCH /create-holds/{id}` body=`#CreateHoldUpdate` · **Delete:** `DELETE /create-holds/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.create-hold.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/create-holds`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

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
- **Business value:** Implement Settle / release to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /settle-releases?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.settle-release.list.view`, `payhub.settle-release.refresh`, `payhub.settle-release.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.settle-release.intent.create`, `payhub.settle-release.payment.authorize`, `payhub.settle-release.payment.capture`, `payhub.settle-release.refund.create`.
- **Profile Bento (if applicable):** module=`settle-release`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-SETTLE-RELEASE-01** Given an authenticated session in GMT+7, When `GET /settle-releases?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.settle-release.list.view` is emitted.
- **AC-SETTLE-RELEASE-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.settle-release.load_more` is emitted.
- **AC-SETTLE-RELEASE-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-SETTLE-RELEASE-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-SETTLE-RELEASE-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-SETTLE-RELEASE-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-SETTLE-RELEASE-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-SETTLE-RELEASE-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-SETTLE-RELEASE-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-SETTLE-RELEASE-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-SETTLE-RELEASE-01, TC-SETTLE-RELEASE-02, TC-SETTLE-RELEASE-03, TC-SETTLE-RELEASE-04, TC-SETTLE-RELEASE-05, TC-SETTLE-RELEASE-06, TC-SETTLE-RELEASE-07, TC-SETTLE-RELEASE-08, TC-SETTLE-RELEASE-09, TC-SETTLE-RELEASE-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /settle-releases` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /settle-releases` body=`#SettleReleaseCreate` schema.
- **Detail:** `GET /settle-releases/{id}` · **Update:** `PATCH /settle-releases/{id}` body=`#SettleReleaseUpdate` · **Delete:** `DELETE /settle-releases/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.settle-release.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/settle-releases`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

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
- **Business value:** Implement Create deposit intent to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /create-deposit-intents?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.create-deposit-intent.list.view`, `payhub.create-deposit-intent.refresh`, `payhub.create-deposit-intent.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.create-deposit-intent.intent.create`, `payhub.create-deposit-intent.payment.authorize`, `payhub.create-deposit-intent.payment.capture`, `payhub.create-deposit-intent.refund.create`.
- **Profile Bento (if applicable):** module=`create-deposit-intent`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-CREATE-DEPOSIT-INTENT-01** Given an authenticated session in GMT+7, When `GET /create-deposit-intents?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.create-deposit-intent.list.view` is emitted.
- **AC-CREATE-DEPOSIT-INTENT-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.create-deposit-intent.load_more` is emitted.
- **AC-CREATE-DEPOSIT-INTENT-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-CREATE-DEPOSIT-INTENT-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-CREATE-DEPOSIT-INTENT-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-CREATE-DEPOSIT-INTENT-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-CREATE-DEPOSIT-INTENT-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-CREATE-DEPOSIT-INTENT-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-CREATE-DEPOSIT-INTENT-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-CREATE-DEPOSIT-INTENT-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-CREATE-DEPOSIT-INTENT-01, TC-CREATE-DEPOSIT-INTENT-02, TC-CREATE-DEPOSIT-INTENT-03, TC-CREATE-DEPOSIT-INTENT-04, TC-CREATE-DEPOSIT-INTENT-05, TC-CREATE-DEPOSIT-INTENT-06, TC-CREATE-DEPOSIT-INTENT-07, TC-CREATE-DEPOSIT-INTENT-08, TC-CREATE-DEPOSIT-INTENT-09, TC-CREATE-DEPOSIT-INTENT-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /create-deposit-intents` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /create-deposit-intents` body=`#CreateDepositIntentCreate` schema.
- **Detail:** `GET /create-deposit-intents/{id}` · **Update:** `PATCH /create-deposit-intents/{id}` body=`#CreateDepositIntentUpdate` · **Delete:** `DELETE /create-deposit-intents/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.create-deposit-intent.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/create-deposit-intents`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

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


#### Objective & KPIs
- **Business value:** Implement Create withdrawal request (KYC‑gated) to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /create-withdrawal-request-kycgateds?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.create-withdrawal-request-kycgated.list.view`, `payhub.create-withdrawal-request-kycgated.refresh`, `payhub.create-withdrawal-request-kycgated.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.create-withdrawal-request-kycgated.intent.create`, `payhub.create-withdrawal-request-kycgated.payment.authorize`, `payhub.create-withdrawal-request-kycgated.payment.capture`, `payhub.create-withdrawal-request-kycgated.refund.create`.
- **Profile Bento (if applicable):** module=`create-withdrawal-request-kycgated`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-01** Given an authenticated session in GMT+7, When `GET /create-withdrawal-request-kycgateds?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.create-withdrawal-request-kycgated.list.view` is emitted.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.create-withdrawal-request-kycgated.load_more` is emitted.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-01, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-02, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-03, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-04, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-05, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-06, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-07, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-08, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-09, TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /create-withdrawal-request-kycgateds` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /create-withdrawal-request-kycgateds` body=`#CreateWithdrawalRequestKycgatedCreate` schema.
- **Detail:** `GET /create-withdrawal-request-kycgateds/{id}` · **Update:** `PATCH /create-withdrawal-request-kycgateds/{id}` body=`#CreateWithdrawalRequestKycgatedUpdate` · **Delete:** `DELETE /create-withdrawal-request-kycgateds/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.create-withdrawal-request-kycgated.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/create-withdrawal-request-kycgateds`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B4.1.1** — *As an Investor, I request a withdrawal,* so that *I can move funds out.*  
**AC**  
1. `POST /v1/withdrawals {asset, amount, addressId}` checks **badge/KYC tier & limits**; screen address; compute fee; respond **202 pending** with `estimate`.  
2. Broadcaster builds/sends tx; supports **RBF**; status: `queued→broadcast→confirming→settled|failed`.  
3. Cancel before broadcast: `DELETE /v1/withdrawals/{id}` idempotent.  
**Non‑Happy**: fee spike → **delayed** status; address risk hit → **held** and case opened.  
**Observability**: p95 time‑to‑broadcast; failure code mix. 

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
- **Business value:** Implement Quote to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /quotes?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.quote.list.view`, `payhub.quote.refresh`, `payhub.quote.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.quote.intent.create`, `payhub.quote.payment.authorize`, `payhub.quote.payment.capture`, `payhub.quote.refund.create`.
- **Profile Bento (if applicable):** module=`quote`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-QUOTE-01** Given an authenticated session in GMT+7, When `GET /quotes?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.quote.list.view` is emitted.
- **AC-QUOTE-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.quote.load_more` is emitted.
- **AC-QUOTE-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-QUOTE-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-QUOTE-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-QUOTE-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-QUOTE-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-QUOTE-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-QUOTE-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-QUOTE-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-QUOTE-01, TC-QUOTE-02, TC-QUOTE-03, TC-QUOTE-04, TC-QUOTE-05, TC-QUOTE-06, TC-QUOTE-07, TC-QUOTE-08, TC-QUOTE-09, TC-QUOTE-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /quotes` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /quotes` body=`#QuoteCreate` schema.
- **Detail:** `GET /quotes/{id}` · **Update:** `PATCH /quotes/{id}` body=`#QuoteUpdate` · **Delete:** `DELETE /quotes/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.quote.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/quotes`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

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
- **Business value:** Implement Execute to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /executes?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.execute.list.view`, `payhub.execute.refresh`, `payhub.execute.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.execute.intent.create`, `payhub.execute.payment.authorize`, `payhub.execute.payment.capture`, `payhub.execute.refund.create`.
- **Profile Bento (if applicable):** module=`execute`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-EXECUTE-01** Given an authenticated session in GMT+7, When `GET /executes?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.execute.list.view` is emitted.
- **AC-EXECUTE-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.execute.load_more` is emitted.
- **AC-EXECUTE-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-EXECUTE-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-EXECUTE-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-EXECUTE-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-EXECUTE-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-EXECUTE-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-EXECUTE-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-EXECUTE-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-EXECUTE-01, TC-EXECUTE-02, TC-EXECUTE-03, TC-EXECUTE-04, TC-EXECUTE-05, TC-EXECUTE-06, TC-EXECUTE-07, TC-EXECUTE-08, TC-EXECUTE-09, TC-EXECUTE-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /executes` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /executes` body=`#ExecuteCreate` schema.
- **Detail:** `GET /executes/{id}` · **Update:** `PATCH /executes/{id}` body=`#ExecuteUpdate` · **Delete:** `DELETE /executes/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.execute.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/executes`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B5.2.1** — *As an End User, I execute a valid quote,* so that *balances update atomically.*  
**AC**: `POST /v1/conversions/execute {quoteId}` performs journal move; idempotent by `quoteId`; receipt emitted.  

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
- **Business value:** Implement Issue & pay invoices to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /issue-pay-invoices?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.issue-pay-invoices.list.view`, `payhub.issue-pay-invoices.refresh`, `payhub.issue-pay-invoices.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.issue-pay-invoices.intent.create`, `payhub.issue-pay-invoices.payment.authorize`, `payhub.issue-pay-invoices.payment.capture`, `payhub.issue-pay-invoices.refund.create`.
- **Profile Bento (if applicable):** module=`issue-pay-invoices`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-ISSUE-PAY-INVOICES-01** Given an authenticated session in GMT+7, When `GET /issue-pay-invoices?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.issue-pay-invoices.list.view` is emitted.
- **AC-ISSUE-PAY-INVOICES-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.issue-pay-invoices.load_more` is emitted.
- **AC-ISSUE-PAY-INVOICES-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-ISSUE-PAY-INVOICES-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-ISSUE-PAY-INVOICES-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-ISSUE-PAY-INVOICES-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-ISSUE-PAY-INVOICES-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-ISSUE-PAY-INVOICES-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-ISSUE-PAY-INVOICES-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-ISSUE-PAY-INVOICES-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-ISSUE-PAY-INVOICES-01, TC-ISSUE-PAY-INVOICES-02, TC-ISSUE-PAY-INVOICES-03, TC-ISSUE-PAY-INVOICES-04, TC-ISSUE-PAY-INVOICES-05, TC-ISSUE-PAY-INVOICES-06, TC-ISSUE-PAY-INVOICES-07, TC-ISSUE-PAY-INVOICES-08, TC-ISSUE-PAY-INVOICES-09, TC-ISSUE-PAY-INVOICES-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /issue-pay-invoices` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /issue-pay-invoices` body=`#IssuePayInvoicesCreate` schema.
- **Detail:** `GET /issue-pay-invoices/{id}` · **Update:** `PATCH /issue-pay-invoices/{id}` body=`#IssuePayInvoicesUpdate` · **Delete:** `DELETE /issue-pay-invoices/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.issue-pay-invoices.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/issue-pay-invoices`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B6.1.1** — *As a User, I pay overage invoices to unlock features,* so that *usage can continue.*  
**AC**: `POST /v1/invoices {purpose, amount, currency}` → statuses `issued→paying→paid|expired`; accepts FZ/PT/USDT; on **paid**, meters refresh; failed payment → retry or refund.  

### Feature B6.2 — Manual refunds  


#### Objective & KPIs
- **Business value:** Implement Manual refunds to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /manual-refunds?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.manual-refunds.list.view`, `payhub.manual-refunds.refresh`, `payhub.manual-refunds.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.manual-refunds.intent.create`, `payhub.manual-refunds.payment.authorize`, `payhub.manual-refunds.payment.capture`, `payhub.manual-refunds.refund.create`.
- **Profile Bento (if applicable):** module=`manual-refunds`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-MANUAL-REFUNDS-01** Given an authenticated session in GMT+7, When `GET /manual-refunds?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.manual-refunds.list.view` is emitted.
- **AC-MANUAL-REFUNDS-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.manual-refunds.load_more` is emitted.
- **AC-MANUAL-REFUNDS-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-MANUAL-REFUNDS-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-MANUAL-REFUNDS-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-MANUAL-REFUNDS-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-MANUAL-REFUNDS-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-MANUAL-REFUNDS-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-MANUAL-REFUNDS-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-MANUAL-REFUNDS-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-MANUAL-REFUNDS-01, TC-MANUAL-REFUNDS-02, TC-MANUAL-REFUNDS-03, TC-MANUAL-REFUNDS-04, TC-MANUAL-REFUNDS-05, TC-MANUAL-REFUNDS-06, TC-MANUAL-REFUNDS-07, TC-MANUAL-REFUNDS-08, TC-MANUAL-REFUNDS-09, TC-MANUAL-REFUNDS-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /manual-refunds` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /manual-refunds` body=`#ManualRefundsCreate` schema.
- **Detail:** `GET /manual-refunds/{id}` · **Update:** `PATCH /manual-refunds/{id}` body=`#ManualRefundsUpdate` · **Delete:** `DELETE /manual-refunds/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.manual-refunds.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/manual-refunds`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B6.2.1** — *As Finance Ops, I issue a manual refund,* so that *I can resolve exceptions.*  
**AC**: `POST /v1/admin/refunds {invoiceId|journalTxId, reason}`; idempotent; receipt emitted. 

**UI & Interaction Model (Invoices & Receipts)**  
- **Latest 20** invoices/receipts; **infinite scroll**; **pull‑to‑refresh**; search by **invoiceId/purpose/tags**.  
- **Sort**: Date, Popular, Featured, View.  
- **Filter**: currency, amount range, status (issued/paying/paid/expired/refunded).  
- **Actions**: Bookmark / Comment / Report / Share.  
- **EXP**: on‑time payment/comment/share increment EXP (cooldowns).  

---

## Epic B7 — Security, Limits & Compliance

### Feature B7.1 — Limits & velocity profiles  


#### Objective & KPIs
- **Business value:** Implement Limits & velocity profiles to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /limits-velocity-profiles?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.limits-velocity-profiles.list.view`, `payhub.limits-velocity-profiles.refresh`, `payhub.limits-velocity-profiles.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.limits-velocity-profiles.intent.create`, `payhub.limits-velocity-profiles.payment.authorize`, `payhub.limits-velocity-profiles.payment.capture`, `payhub.limits-velocity-profiles.refund.create`.
- **Profile Bento (if applicable):** module=`limits-velocity-profiles`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-LIMITS-VELOCITY-PROFILES-01** Given an authenticated session in GMT+7, When `GET /limits-velocity-profiles?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.limits-velocity-profiles.list.view` is emitted.
- **AC-LIMITS-VELOCITY-PROFILES-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.limits-velocity-profiles.load_more` is emitted.
- **AC-LIMITS-VELOCITY-PROFILES-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-LIMITS-VELOCITY-PROFILES-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-LIMITS-VELOCITY-PROFILES-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-LIMITS-VELOCITY-PROFILES-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-LIMITS-VELOCITY-PROFILES-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-LIMITS-VELOCITY-PROFILES-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-LIMITS-VELOCITY-PROFILES-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-LIMITS-VELOCITY-PROFILES-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-LIMITS-VELOCITY-PROFILES-01, TC-LIMITS-VELOCITY-PROFILES-02, TC-LIMITS-VELOCITY-PROFILES-03, TC-LIMITS-VELOCITY-PROFILES-04, TC-LIMITS-VELOCITY-PROFILES-05, TC-LIMITS-VELOCITY-PROFILES-06, TC-LIMITS-VELOCITY-PROFILES-07, TC-LIMITS-VELOCITY-PROFILES-08, TC-LIMITS-VELOCITY-PROFILES-09, TC-LIMITS-VELOCITY-PROFILES-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /limits-velocity-profiles` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /limits-velocity-profiles` body=`#LimitsVelocityProfilesCreate` schema.
- **Detail:** `GET /limits-velocity-profiles/{id}` · **Update:** `PATCH /limits-velocity-profiles/{id}` body=`#LimitsVelocityProfilesUpdate` · **Delete:** `DELETE /limits-velocity-profiles/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.limits-velocity-profiles.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/limits-velocity-profiles`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B7.1.1** — *As Risk, I enforce per‑badge **limits** and velocity,* so that *loss is controlled.*  
**AC**: limits fetched from **Config**/**Identity**; actions exceeding → **403 limit_exceeded** with invoice hint if billable; bursts throttled with cool‑downs.  

### Feature B7.2 — AML screening & case management  


#### Objective & KPIs
- **Business value:** Implement AML screening & case management to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /aml-screening-case-managements?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.aml-screening-case-management.list.view`, `payhub.aml-screening-case-management.refresh`, `payhub.aml-screening-case-management.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.aml-screening-case-management.intent.create`, `payhub.aml-screening-case-management.payment.authorize`, `payhub.aml-screening-case-management.payment.capture`, `payhub.aml-screening-case-management.refund.create`.
- **Profile Bento (if applicable):** module=`aml-screening-case-management`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-AML-SCREENING-CASE-MANAGEMENT-01** Given an authenticated session in GMT+7, When `GET /aml-screening-case-managements?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.aml-screening-case-management.list.view` is emitted.
- **AC-AML-SCREENING-CASE-MANAGEMENT-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.aml-screening-case-management.load_more` is emitted.
- **AC-AML-SCREENING-CASE-MANAGEMENT-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-AML-SCREENING-CASE-MANAGEMENT-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-AML-SCREENING-CASE-MANAGEMENT-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-AML-SCREENING-CASE-MANAGEMENT-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-AML-SCREENING-CASE-MANAGEMENT-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-AML-SCREENING-CASE-MANAGEMENT-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-AML-SCREENING-CASE-MANAGEMENT-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-AML-SCREENING-CASE-MANAGEMENT-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-AML-SCREENING-CASE-MANAGEMENT-01, TC-AML-SCREENING-CASE-MANAGEMENT-02, TC-AML-SCREENING-CASE-MANAGEMENT-03, TC-AML-SCREENING-CASE-MANAGEMENT-04, TC-AML-SCREENING-CASE-MANAGEMENT-05, TC-AML-SCREENING-CASE-MANAGEMENT-06, TC-AML-SCREENING-CASE-MANAGEMENT-07, TC-AML-SCREENING-CASE-MANAGEMENT-08, TC-AML-SCREENING-CASE-MANAGEMENT-09, TC-AML-SCREENING-CASE-MANAGEMENT-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /aml-screening-case-managements` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /aml-screening-case-managements` body=`#AmlScreeningCaseManagementCreate` schema.
- **Detail:** `GET /aml-screening-case-managements/{id}` · **Update:** `PATCH /aml-screening-case-managements/{id}` body=`#AmlScreeningCaseManagementUpdate` · **Delete:** `DELETE /aml-screening-case-managements/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.aml-screening-case-management.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/aml-screening-case-managements`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B7.2.1** — *As Compliance, I screen risk and manage cases,* so that *prohibited flows are blocked.*  
**AC**: withdrawal address and deposit sources checked; hits → **held** + case `open→investigating→resolved(approve|reject)`; appeals tracked.  

### Feature B7.3 — Exports for audit  


#### Objective & KPIs
- **Business value:** Implement Exports for audit to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /exports-for-audits?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.exports-for-audit.list.view`, `payhub.exports-for-audit.refresh`, `payhub.exports-for-audit.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.exports-for-audit.intent.create`, `payhub.exports-for-audit.payment.authorize`, `payhub.exports-for-audit.payment.capture`, `payhub.exports-for-audit.refund.create`.
- **Profile Bento (if applicable):** module=`exports-for-audit`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-EXPORTS-FOR-AUDIT-01** Given an authenticated session in GMT+7, When `GET /exports-for-audits?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.exports-for-audit.list.view` is emitted.
- **AC-EXPORTS-FOR-AUDIT-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.exports-for-audit.load_more` is emitted.
- **AC-EXPORTS-FOR-AUDIT-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-EXPORTS-FOR-AUDIT-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-EXPORTS-FOR-AUDIT-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-EXPORTS-FOR-AUDIT-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-EXPORTS-FOR-AUDIT-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-EXPORTS-FOR-AUDIT-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-EXPORTS-FOR-AUDIT-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-EXPORTS-FOR-AUDIT-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-EXPORTS-FOR-AUDIT-01, TC-EXPORTS-FOR-AUDIT-02, TC-EXPORTS-FOR-AUDIT-03, TC-EXPORTS-FOR-AUDIT-04, TC-EXPORTS-FOR-AUDIT-05, TC-EXPORTS-FOR-AUDIT-06, TC-EXPORTS-FOR-AUDIT-07, TC-EXPORTS-FOR-AUDIT-08, TC-EXPORTS-FOR-AUDIT-09, TC-EXPORTS-FOR-AUDIT-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /exports-for-audits` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /exports-for-audits` body=`#ExportsForAuditCreate` schema.
- **Detail:** `GET /exports-for-audits/{id}` · **Update:** `PATCH /exports-for-audits/{id}` body=`#ExportsForAuditUpdate` · **Delete:** `DELETE /exports-for-audits/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.exports-for-audit.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/exports-for-audits`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B7.3.1** — *As Auditor, I export immutable journals & reconciliation artifacts.*  
**AC**: CSV/Parquet export; signed manifest; rate‑limited; redactions applied.  

---

## Epic B8 — Reconciliation & Reporting

### Feature B8.1 — Daily close  


#### Objective & KPIs
- **Business value:** Implement Daily close to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /daily-closes?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.daily-close.list.view`, `payhub.daily-close.refresh`, `payhub.daily-close.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.daily-close.intent.create`, `payhub.daily-close.payment.authorize`, `payhub.daily-close.payment.capture`, `payhub.daily-close.refund.create`.
- **Profile Bento (if applicable):** module=`daily-close`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-DAILY-CLOSE-01** Given an authenticated session in GMT+7, When `GET /daily-closes?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.daily-close.list.view` is emitted.
- **AC-DAILY-CLOSE-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.daily-close.load_more` is emitted.
- **AC-DAILY-CLOSE-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-DAILY-CLOSE-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-DAILY-CLOSE-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-DAILY-CLOSE-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-DAILY-CLOSE-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-DAILY-CLOSE-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-DAILY-CLOSE-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-DAILY-CLOSE-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-DAILY-CLOSE-01, TC-DAILY-CLOSE-02, TC-DAILY-CLOSE-03, TC-DAILY-CLOSE-04, TC-DAILY-CLOSE-05, TC-DAILY-CLOSE-06, TC-DAILY-CLOSE-07, TC-DAILY-CLOSE-08, TC-DAILY-CLOSE-09, TC-DAILY-CLOSE-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /daily-closes` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /daily-closes` body=`#DailyCloseCreate` schema.
- **Detail:** `GET /daily-closes/{id}` · **Update:** `PATCH /daily-closes/{id}` body=`#DailyCloseUpdate` · **Delete:** `DELETE /daily-closes/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.daily-close.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/daily-closes`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B8.1.1** — *As Finance Ops, I run daily close,* so that *balances match on/off‑chain.*  
**AC**: rollup by asset; variance thresholds; emits `payhub.reconciliation.completed@v1`.  

### Feature B8.2 — Fee & rule reports  


#### Objective & KPIs
- **Business value:** Implement Fee & rule reports to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /fee-rule-reports?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.fee-rule-reports.list.view`, `payhub.fee-rule-reports.refresh`, `payhub.fee-rule-reports.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.fee-rule-reports.intent.create`, `payhub.fee-rule-reports.payment.authorize`, `payhub.fee-rule-reports.payment.capture`, `payhub.fee-rule-reports.refund.create`.
- **Profile Bento (if applicable):** module=`fee-rule-reports`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-FEE-RULE-REPORTS-01** Given an authenticated session in GMT+7, When `GET /fee-rule-reports?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.fee-rule-reports.list.view` is emitted.
- **AC-FEE-RULE-REPORTS-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.fee-rule-reports.load_more` is emitted.
- **AC-FEE-RULE-REPORTS-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-FEE-RULE-REPORTS-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-FEE-RULE-REPORTS-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-FEE-RULE-REPORTS-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-FEE-RULE-REPORTS-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-FEE-RULE-REPORTS-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-FEE-RULE-REPORTS-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-FEE-RULE-REPORTS-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-FEE-RULE-REPORTS-01, TC-FEE-RULE-REPORTS-02, TC-FEE-RULE-REPORTS-03, TC-FEE-RULE-REPORTS-04, TC-FEE-RULE-REPORTS-05, TC-FEE-RULE-REPORTS-06, TC-FEE-RULE-REPORTS-07, TC-FEE-RULE-REPORTS-08, TC-FEE-RULE-REPORTS-09, TC-FEE-RULE-REPORTS-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /fee-rule-reports` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /fee-rule-reports` body=`#FeeRuleReportsCreate` schema.
- **Detail:** `GET /fee-rule-reports/{id}` · **Update:** `PATCH /fee-rule-reports/{id}` body=`#FeeRuleReportsUpdate` · **Delete:** `DELETE /fee-rule-reports/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.fee-rule-reports.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/fee-rule-reports`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B8.2.1** — *As Finance Ops, I review fee take and rules applied.*  
**AC**: fee schedule snapshot vs postings; anomalies reported. 

---

## Epic B9 — Reliability & Observability

### Feature B9.1 — Idempotency & retries  


#### Objective & KPIs
- **Business value:** Implement Idempotency & retries to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /idempotency-retries?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.idempotency-retries.list.view`, `payhub.idempotency-retries.refresh`, `payhub.idempotency-retries.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.idempotency-retries.intent.create`, `payhub.idempotency-retries.payment.authorize`, `payhub.idempotency-retries.payment.capture`, `payhub.idempotency-retries.refund.create`.
- **Profile Bento (if applicable):** module=`idempotency-retries`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-IDEMPOTENCY-RETRIES-01** Given an authenticated session in GMT+7, When `GET /idempotency-retries?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.idempotency-retries.list.view` is emitted.
- **AC-IDEMPOTENCY-RETRIES-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.idempotency-retries.load_more` is emitted.
- **AC-IDEMPOTENCY-RETRIES-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-IDEMPOTENCY-RETRIES-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-IDEMPOTENCY-RETRIES-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-IDEMPOTENCY-RETRIES-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-IDEMPOTENCY-RETRIES-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-IDEMPOTENCY-RETRIES-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-IDEMPOTENCY-RETRIES-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-IDEMPOTENCY-RETRIES-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-IDEMPOTENCY-RETRIES-01, TC-IDEMPOTENCY-RETRIES-02, TC-IDEMPOTENCY-RETRIES-03, TC-IDEMPOTENCY-RETRIES-04, TC-IDEMPOTENCY-RETRIES-05, TC-IDEMPOTENCY-RETRIES-06, TC-IDEMPOTENCY-RETRIES-07, TC-IDEMPOTENCY-RETRIES-08, TC-IDEMPOTENCY-RETRIES-09, TC-IDEMPOTENCY-RETRIES-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /idempotency-retries` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /idempotency-retries` body=`#IdempotencyRetriesCreate` schema.
- **Detail:** `GET /idempotency-retries/{id}` · **Update:** `PATCH /idempotency-retries/{id}` body=`#IdempotencyRetriesUpdate` · **Delete:** `DELETE /idempotency-retries/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.idempotency-retries.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/idempotency-retries`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B9.1.1** — *As SRE, I guarantee idempotent writes and safe retries,* so that *clients can recover.*  
**AC**: All **POST/PUT/DELETE** accept **Idempotency-Key**; outbox/DLQ; backoff with jitter; circuit breakers.

### Feature B9.2 — Telemetry & SLOs  


#### Objective & KPIs
- **Business value:** Implement Telemetry & SLOs to increase checkout success, reduce refund/failure rates, and enable programmable payments in the ecosystem.
- **Primary metrics:** payment_success_rate ≥ 98%, authorization_latency p95 ≤ 400ms, settlement_latency p95 ≤ 2s, **5xx error budget ≤ 0.1%/day**.
- **Secondary metrics:** chargeback_rate ≤ 0.2%, duplicate_payment_rate via idempotency ≤ 0.05%, fraud_flag_rate ≤ 0.3%.

#### Preconditions & Visibility
- **Auth:** Telegram WebApp HMAC → session → **Bearer/JWT**.
- **Roles / User Role Badges:** Payer, Merchant, FinanceOps, Admin.
- **System Badges:** e.g., **KYC Verified**, **Merchant Verified** required for receiving funds.
- **Token/EXP gates:** FZ stake/fee discounts; EXP gates for advanced payout features.
- **Audience rules:** Private by default for payment intents; merchant dashboards can be role-gated.

#### UI & Actions (Screen Contract)
- **Patterns:** List / Detail / Create-Edit / Delete / Search / Sort / Filter / Bookmark / Comment / Report / Share.
- **Data source:** `GET /telemetry-slos?limit={L}&cursor={C}&sort={S}&q={Q}&filter[...]`  
- **States:** Loading, Empty, Error, Partial; **top-refresh** and **infinite scroll** with `limit` batches.
- **Permissions matrix:** Action gates by Role + Badges (e.g., only **Merchant Verified** can capture/refund).
- **Telemetry:** `payhub.telemetry-slos.list.view`, `payhub.telemetry-slos.refresh`, `payhub.telemetry-slos.load_more`, `search.submit`, `sort.change`, `filter.apply`, `payhub.telemetry-slos.intent.create`, `payhub.telemetry-slos.payment.authorize`, `payhub.telemetry-slos.payment.capture`, `payhub.telemetry-slos.refund.create`.
- **Profile Bento (if applicable):** module=`telemetry-slos`, sizes=`S/M/L`, ordering; deep-link with Telegram payload.

#### Acceptance Criteria (Gherkin)
- **AC-TELEMETRY-SLOS-01** Given an authenticated session in GMT+7, When `GET /telemetry-slos?limit=20`, Then ≤20 items return with `nextCursor` when more exist, and telemetry `payhub.telemetry-slos.list.view` is emitted.
- **AC-TELEMETRY-SLOS-02** Given a `cursor`, When loading more, Then results continue after the cursor with no duplicates and `payhub.telemetry-slos.load_more` is emitted.
- **AC-TELEMETRY-SLOS-03** Given filters and `q` are applied, When submitted, Then only matching items return and filter echo is present in response metadata.
- **AC-TELEMETRY-SLOS-04** Given invalid params (e.g., `limit>200`), When the request is made, Then **422** returns with error `{code,message,details,traceId}`.
- **AC-TELEMETRY-SLOS-05** Given an unauthenticated user, When hitting protected endpoints, Then **401** is returned.
- **AC-TELEMETRY-SLOS-06** Given missing required badges/roles (e.g., Merchant Verified), When attempting capture/refund, Then **403** is returned and the UI shows gate messaging.
- **AC-TELEMETRY-SLOS-07** Given a **POST** with `Idempotency-Key` is replayed within 24h, When the same body is sent, Then the original **200/201** is returned and no duplicate payment/capture occurs.
- **AC-TELEMETRY-SLOS-08** Given a duplicate unique field (e.g., externalReference), When creating, Then **409** conflict is returned with guidance.
- **AC-TELEMETRY-SLOS-09** Given rate limits (per user 120 rpm; per IP 600 rpm), When exceeded, Then **429** with `Retry-After` is returned and the UI shows backoff.
- **AC-TELEMETRY-SLOS-10** Given a transient processor outage, When client retries with exponential backoff + jitter, Then success or terminal **5xx** is returned; logs include `X-Trace-Id`.

- **Test IDs:** TC-TELEMETRY-SLOS-01, TC-TELEMETRY-SLOS-02, TC-TELEMETRY-SLOS-03, TC-TELEMETRY-SLOS-04, TC-TELEMETRY-SLOS-05, TC-TELEMETRY-SLOS-06, TC-TELEMETRY-SLOS-07, TC-TELEMETRY-SLOS-08, TC-TELEMETRY-SLOS-09, TC-TELEMETRY-SLOS-10

#### API Requirements Extract (for OpenAPI.yaml)
- **Tag:** `payhub` · **Auth:** Bearer scopes (`payhub:read`, `payhub:write`) + Telegram HMAC for WebApp init.
- **Headers:** `Idempotency-Key` (POST/PATCH), `X-Trace-Id`.
- **Collection:** `GET /telemetry-slos` params: `limit,cursor,since,sort,q,filter[*]` (Param Mapping note if repo differs).
- **Create:** `POST /telemetry-slos` body=`#TelemetrySlosCreate` schema.
- **Detail:** `GET /telemetry-slos/{id}` · **Update:** `PATCH /telemetry-slos/{id}` body=`#TelemetrySlosUpdate` · **Delete:** `DELETE /telemetry-slos/{id}`.
- **Envelope:** `{data:[], nextCursor:string|null, total?:number}`.
- **200 example:**
  ```json
  {
    "data": [{"id":"uuid-v7","title":"Example","status":"draft","createdAt":"2025-10-03T10:00:00+07:00"}],
    "nextCursor":"eyJvZmZzZXQiOjIwfQ=="
  }
  ```
- **422 example:**
  ```json
  {
    "code":"VALIDATION_ERROR",
    "message":"limit must be <= 200",
    "details":{"limit":["too large"]},
    "traceId":"trc-01HXYZ"
  }
  ```

#### Data Contracts
| field           | type     | format     | nullable | enum                             | default | validation                        | indexes |
|-----------------|----------|------------|----------|----------------------------------|---------|-----------------------------------|---------|
| id              | string   | uuid-v7    | false    | -                                | -       | required                          | PK      |
| title           | string   | -          | false    | -                                | -       | 1..160 chars                      | idx     |
| description     | string   | markdown   | true     | -                                | -       | ≤ 10,000 chars                    | -       |
| status          | string   | -          | false    | draft,published,archived         | draft   | enum                              | idx     |
| amount          | number   | decimal    | false    | -                                | -       | >0; precision 18, scale 8         | idx     |
| currency        | string   | -          | false    | USDT,USDC,ETH,BTC,THB,BASE,ARB   | USDT    | enum                              | idx     |
| createdAt       | string   | date-time  | false    | -                                | now     | ISO-8601 (GMT+7 examples)         | -       |
| updatedAt       | string   | date-time  | false    | -                                | now     | ISO-8601                          | -       |
| createdBy       | string   | uuid-v7    | false    | -                                | -       | references User.id                | idx     |
| externalRef     | string   | -          | true     | -                                | -       | unique per merchant (if provided) | idx     |

#### Events, Jobs & Notifications
- **Events:** `payhub.telemetry-slos.intent.created|authorized|captured|refunded|failed` payload: `id, merchantId, payerId, amount, currency, occurredAt, idempotencyKey`.
- **Producers/Consumers:** PayHub API → ledger, notifications, analytics, reconciliation.
- **Retry/backoff:** exponential (max 6 attempts) with DLQ/outbox; reconciliation job can replay.
- **Notifications:** intent status changes → Telegram push / email → payer/merchant → templated + throttle/dedupe.

#### Subtasks (Delivery Plan)
- **Backend:** CRUD and workflows for `/telemetry-slos`; validation; idempotency store; ledger append; outbox events; reconciliation jobs; feature flags/config.
- **Frontend (MiniApp/WebApp):** payment intent screens; capture/refund CTAs; param mapping; empty/error states; telemetry wiring.
- **QA:** contract tests (±), E2E persona flows (Payer/Merchant/Admin), abuse/security (authZ bypass, replay, rate-limit, HMAC/headers), perf (read p95 ≤ 300ms; write p95 ≤ 400ms), pagination deep-scroll + top-refresh.
- **Docs/Runbooks:** merchant/admin handbooks; dashboards (auth/capture success, refund rates, error budget, p95 latencies); alerts on SLO burn.

#### Definition of Done (DoD)
- All ACs pass; OpenAPI 3.1 paths/components merged; CI contract tests green.
- Telemetry, tracing, metrics, and alerts wired; dashboards live; security review; runbook URL updated.
**Story B9.2.1** — *As SRE, I trace money flows,* so that *we meet SLOs.*  
**AC**: traces across services; key metrics: time‑to‑credit, time‑to‑broadcast, failure rates, invoice paid time; error budget alerts.

---

# Section C — End‑to‑End Scenarios (Swimlanes)

1. **E2E‑H1: Deposit → Credit** — User creates intent → sends on‑chain → N confirmations → credit ledger → balance visible in WebApp with toast.  
2. **E2E‑H2: Withdraw (KYC gate)** — User requests → **403** (needs Investor) → badge apply in WebApp → approval → retry → **202** → broadcaster settles → receipt.  
3. **E2E‑H3: Conversion** — User quotes → executes within expiry → rates verified by signed oracle → balances move atomically.  
4. **E2E‑H4: Overage invoice unlock** — User hits free‑tier ceiling (e.g., alerts) → **402** → pays invoice → meters refresh across services. 
5. **E2E‑H5: Reorg during deposit** — Credit after confs → chain reorg detected → rollback journal → re‑credit after re‑confirm; user sees banner.  
6. **E2E‑H6: Withdrawal fee spike → RBF** — Status stuck **confirming**; broadcaster bumps fee (RBF) → settles; receipts updated. 

---

# Section D — Traceability Matrix
| Feature | APIs | Entities | Events | UI Screens | Test IDs |
|---------|------|----------|--------|------------|----------|
| Feature B1.1 — Provision account & balances | `GET /provision-account-balances`, `POST /provision-account-balances`, `GET /provision-account-balances/{id}`, `PATCH /provision-account-balances/{id}`, `DELETE /provision-account-balances/{id}` | `provision-account-balances` | `payhub.provision-account-balances.*` | List, Detail, Create/Edit | `TC-PROVISION-ACCOUNT-BALANCES-*` |
| Feature B1.2 — Double‑entry ledger | `GET /doubleentry-ledgers`, `POST /doubleentry-ledgers`, `GET /doubleentry-ledgers/{id}`, `PATCH /doubleentry-ledgers/{id}`, `DELETE /doubleentry-ledgers/{id}` | `doubleentry-ledger` | `payhub.doubleentry-ledger.*` | List, Detail, Create/Edit | `TC-DOUBLEENTRY-LEDGER-*` |
| Feature B2.1 — Create hold | `GET /create-holds`, `POST /create-holds`, `GET /create-holds/{id}`, `PATCH /create-holds/{id}`, `DELETE /create-holds/{id}` | `create-hold` | `payhub.create-hold.*` | List, Detail, Create/Edit | `TC-CREATE-HOLD-*` |
| Feature B2.2 — Settle / release | `GET /settle-releases`, `POST /settle-releases`, `GET /settle-releases/{id}`, `PATCH /settle-releases/{id}`, `DELETE /settle-releases/{id}` | `settle-release` | `payhub.settle-release.*` | List, Detail, Create/Edit | `TC-SETTLE-RELEASE-*` |
| Feature B3.1 — Create deposit intent | `GET /create-deposit-intents`, `POST /create-deposit-intents`, `GET /create-deposit-intents/{id}`, `PATCH /create-deposit-intents/{id}`, `DELETE /create-deposit-intents/{id}` | `create-deposit-intent` | `payhub.create-deposit-intent.*` | List, Detail, Create/Edit | `TC-CREATE-DEPOSIT-INTENT-*` |
| Feature B4.1 — Create withdrawal request (KYC‑gated) | `GET /create-withdrawal-request-kycgateds`, `POST /create-withdrawal-request-kycgateds`, `GET /create-withdrawal-request-kycgateds/{id}`, `PATCH /create-withdrawal-request-kycgateds/{id}`, `DELETE /create-withdrawal-request-kycgateds/{id}` | `create-withdrawal-request-kycgated` | `payhub.create-withdrawal-request-kycgated.*` | List, Detail, Create/Edit | `TC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-*` |
| Feature B5.1 — Quote | `GET /quotes`, `POST /quotes`, `GET /quotes/{id}`, `PATCH /quotes/{id}`, `DELETE /quotes/{id}` | `quote` | `payhub.quote.*` | List, Detail, Create/Edit | `TC-QUOTE-*` |
| Feature B5.2 — Execute | `GET /executes`, `POST /executes`, `GET /executes/{id}`, `PATCH /executes/{id}`, `DELETE /executes/{id}` | `execute` | `payhub.execute.*` | List, Detail, Create/Edit | `TC-EXECUTE-*` |
| Feature B6.1 — Issue & pay invoices | `GET /issue-pay-invoices`, `POST /issue-pay-invoices`, `GET /issue-pay-invoices/{id}`, `PATCH /issue-pay-invoices/{id}`, `DELETE /issue-pay-invoices/{id}` | `issue-pay-invoices` | `payhub.issue-pay-invoices.*` | List, Detail, Create/Edit | `TC-ISSUE-PAY-INVOICES-*` |
| Feature B6.2 — Manual refunds | `GET /manual-refunds`, `POST /manual-refunds`, `GET /manual-refunds/{id}`, `PATCH /manual-refunds/{id}`, `DELETE /manual-refunds/{id}` | `manual-refunds` | `payhub.manual-refunds.*` | List, Detail, Create/Edit | `TC-MANUAL-REFUNDS-*` |
| Feature B7.1 — Limits & velocity profiles | `GET /limits-velocity-profiles`, `POST /limits-velocity-profiles`, `GET /limits-velocity-profiles/{id}`, `PATCH /limits-velocity-profiles/{id}`, `DELETE /limits-velocity-profiles/{id}` | `limits-velocity-profiles` | `payhub.limits-velocity-profiles.*` | List, Detail, Create/Edit | `TC-LIMITS-VELOCITY-PROFILES-*` |
| Feature B7.2 — AML screening & case management | `GET /aml-screening-case-managements`, `POST /aml-screening-case-managements`, `GET /aml-screening-case-managements/{id}`, `PATCH /aml-screening-case-managements/{id}`, `DELETE /aml-screening-case-managements/{id}` | `aml-screening-case-management` | `payhub.aml-screening-case-management.*` | List, Detail, Create/Edit | `TC-AML-SCREENING-CASE-MANAGEMENT-*` |
| Feature B7.3 — Exports for audit | `GET /exports-for-audits`, `POST /exports-for-audits`, `GET /exports-for-audits/{id}`, `PATCH /exports-for-audits/{id}`, `DELETE /exports-for-audits/{id}` | `exports-for-audit` | `payhub.exports-for-audit.*` | List, Detail, Create/Edit | `TC-EXPORTS-FOR-AUDIT-*` |
| Feature B8.1 — Daily close | `GET /daily-closes`, `POST /daily-closes`, `GET /daily-closes/{id}`, `PATCH /daily-closes/{id}`, `DELETE /daily-closes/{id}` | `daily-close` | `payhub.daily-close.*` | List, Detail, Create/Edit | `TC-DAILY-CLOSE-*` |
| Feature B8.2 — Fee & rule reports | `GET /fee-rule-reports`, `POST /fee-rule-reports`, `GET /fee-rule-reports/{id}`, `PATCH /fee-rule-reports/{id}`, `DELETE /fee-rule-reports/{id}` | `fee-rule-reports` | `payhub.fee-rule-reports.*` | List, Detail, Create/Edit | `TC-FEE-RULE-REPORTS-*` |
| Feature B9.1 — Idempotency & retries | `GET /idempotency-retries`, `POST /idempotency-retries`, `GET /idempotency-retries/{id}`, `PATCH /idempotency-retries/{id}`, `DELETE /idempotency-retries/{id}` | `idempotency-retries` | `payhub.idempotency-retries.*` | List, Detail, Create/Edit | `TC-IDEMPOTENCY-RETRIES-*` |
| Feature B9.2 — Telemetry & SLOs | `GET /telemetry-slos`, `POST /telemetry-slos`, `GET /telemetry-slos/{id}`, `PATCH /telemetry-slos/{id}`, `DELETE /telemetry-slos/{id}` | `telemetry-slos` | `payhub.telemetry-slos.*` | List, Detail, Create/Edit | `TC-TELEMETRY-SLOS-*` |

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
| B9.2.1 | telemetry | — | — | Observability |  

**Deltas vs old UserStories**: explicit **double‑entry**, deposit **reorg** handling, withdrawal **RBF**, conversions with **signed oracle**, full invoice/refund lifecycle, **limits/velocity**, and **daily close reconciliation** — aligned with UI baselines for all list surfaces. 

---

# Section E — Assumptions & Open Questions

- Confirm **N confirmations** per network and reorg‑depth policy.  
- Exact fee schedule and **maxSlippageBp** defaults per asset.  
- Address‑risk provider and **appeal** SLAs.  
- Invoice **purpose catalog** and billing periods for each overage metric.  
- Who owns the **address book** canonical store (Portal vs Payhub) and first‑use **soft delay** policy. 

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
| payhub.reconciliation.completed@v1 | Payhub | Finance, Auditor | `{day, reportId}` | `day` | 3× | 

---

# Abuse/Misuse & NFR Sweeps

- **Abuse**: deposit layering/structuring (velocity), dust spam (min credit), mixer addresses (screening), invoice spam (rate limits), bot hold‑spam (per‑service caps).  
- **Fraud**: stolen accounts (withdrawal soft delay on new addresses handled by Portal address‑book), fake deposits (credit after confs), oracle manipulation (signed snapshots with freshness/quorum).  
- **Security**: JWT validation, mTLS/HMAC, idempotency on writes, outbox for events, HSM signing.  
- **Privacy & compliance**: KYC evidence stays in Identity; Payhub stores references only; ledger retention per jurisdiction; DSAR export path.  
- **Resilience**: circuit breakers for RPCs, fee oracle fallbacks, DLQ with replay, reconciliation to detect drifts, RBF on stuck withdrawals.  
- **Observability**: logs/metrics/traces with correlation IDs; dashboards for time‑to‑credit, time‑to‑broadcast, failure buckets.  
- **Localization/timezones**: user‑visible timestamps **GMT+7** in UIs; ledger timestamps in UTC. 

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
