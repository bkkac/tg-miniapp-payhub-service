# UserStories.md

Repo: tg-miniapp-payhub-service
print: 
SHA-256: d2281b6f3c7fb2270729fa2b8de0a433803051db2aea2c4573a8b277f618fd53
Bytes: 15566

---

## 1) Epics → Features → User Stories

> **Traceability note:** Stories reference the uploaded **SystemDesign.md** for this repo (e.g., “§4 Data Model”, “§5 Interfaces”, “§6 Flows”, “§7 Security”, “§8 Reliability”). Section numbers follow your document for Payhub.

### Epic A — Wallets & Ledger (STAR/FZ/PT, USDT later-ready)
Accounts, balances, holds, settlements, and double-entry ledger entries.  
**Traceability:** §3 Scope, §4 Data Model (Wallet, LedgerEntry, Hold, Settlement), §6.1 Hold→Settle Flow, §7 Security.

#### Feature A1 — Internal Wallet Creation & Fetch
**Story:** As a **logged-in user**, I want an internal wallet automatically provisioned for supported assets (STAR/FZ/PT), so that I can deposit, hold, convert, and settle funds.  
**Acceptance Criteria (GWT):**
1. **Given** a first successful login/session, **when** Payhub receives a `POST /internal/v1/wallets/provision` from Identity/Workers, **then** Wallets for STAR/FZ/PT are created if absent, idempotently.  
2. **Given** I am logged in, **when** WebApp calls `GET /v1/wallets`, **then** I see per-asset balances: `available`, `onHold`, `total`.  
3. **Given** the wallet exists, **when** the same provision call is retried with the same `Idempotency-Key`, **then** Payhub returns **200** and no duplicates.  
**Non‑Happy Paths & Errors:** invalid auth; unsupported asset; DB unavailability (503).  
**Permissions & Roles:** user (self), staff (read via Admin), services (internal only).  
**Data Touchpoints:** `Wallet` upsert; `User` (foreign key).  
**Cross‑Service Interactions:** Identity (provision trigger), Workers (repair jobs).  
**State & Lifecycle:** wallet: `active` → `archived` (rare).  
**Security & Compliance:** JWT verify, PII minimal.  
**Observability:** `wallet_provision_ok/fail`, dashboard by asset.  
**Performance:** p95 list < 100 ms; pagination if > 20 assets.  
**Edge Cases:** user has zeroed balances; partial asset rollout.

#### Feature A2 — Double‑Entry Ledger & Balance Integrity
**Story:** As a **platform operator**, I want every money movement to be represented as balanced ledger entries, so that balances are consistent and auditable.  
**Acceptance Criteria:**
1. **Given** any balance change (deposit, hold, settle, convert, payout, fee), **when** it is committed, **then** Payhub writes **two** `LedgerEntry` rows (debit/credit) with the same `journalId` and `requestId`.  
2. **Given** a ledger journal, **when** summed by account and asset, **then** the delta equals the visible balance change.  
3. **Given** a transient failure mid‑write, **when** Workers replay by `Idempotency-Key`, **then** exactly‑once semantics apply—no duplicate entries.  
**Errors:** foreign key miss; asset mismatch; negative resulting balance rejected (except hold release).  
**State & Lifecycle:** `LedgerEntry.status`: `pending` → `posted` → `voided` (reversals).  
**Observability:** mismatch detector job; metric `ledger_post_fail` with alert.  
**Traceability:** §4 (Ledger model), §6 (flows), §8 (reliability).

### Epic B — Holds & Settlements (Matchmaking, Funding, Escrow)
Create monetary reservations (holds) and finalize via settlement outcomes.  
**Traceability:** §5 Interfaces `/internal/v1/holds`, `/internal/v1/settlements`, §6.1 Hold→Settle.

#### Feature B1 — Create Hold
**Story:** As **PlayHub** or **Funding**, I want to reserve a bet or purchase amount, so that funds are guaranteed before gameplay or order placement.  
**Acceptance Criteria:**
1. **Given** a valid service JWT and payload `{{userId, asset, amount, reason, idemKey}}`, **when** caller posts `POST /internal/v1/holds`, **then** Payhub verifies `available ≥ amount`, debits `available`, credits `onHold`, and returns `{{holdId, status: active}}`.  
2. **Given** insufficient funds, **when** the call is made, **then** Payhub returns **409 conflict** `{{code: insufficient_funds}}` and does **not** create a hold.  
3. **Given** a repeated request with the same `idemKey`, **when** retried, **then** the same `holdId` and state are returned (idempotent).  
4. **Given** an unsupported asset, **then** Payhub returns **400 bad_request**.  
**Permissions:** internal services only (PlayHub, Funding, Escrow) by allowlist audience.  
**Data Touchpoints:** `Hold` create; ledger `reserve` journal; `Wallet` balances.  
**Observability:** metrics per caller; 95p latency < 80 ms.  
**Edge Cases:** concurrent holds racing on same wallet; stale balance cache invalidated.

#### Feature B2 — Settle Hold (Win/Loss/Cancel/Partial)
**Story:** As **PlayHub** (or Funding/Escrow), I want to finalize a hold with an outcome, so that the wallet reflects the final result.  
**Acceptance Criteria:**
1. **Given** an active hold, **when** `POST /internal/v1/settlements` with `{{holdId, outcome: "win" | "loss" | "cancel" | "partial", amount?, fees?}}` arrives, **then** Payhub posts balanced ledger entries:  
   - **win**: move loser’s hold to winner’s available; apply rake/fees; close both holds.  
   - **loss**: forfeit owner’s hold to treasury/winner per context; close hold.  
   - **cancel**: release back to owner’s available.  
   - **partial**: proportionally release/forfeit `amount`.  
2. **Given** settlement already applied, **when** retried with the same `idemKey`, **then** response is idempotent with the final state.  
3. **Given** invalid outcome vs state (e.g., cancelled hold), **then** **409 conflict** returned.  
**Permissions:** internal only; audience must match expected caller (e.g., PlayHub for game holds).  
**Cross‑Service:** emits `wallet.settled` event (Workers fan‑out notifications, WebApp refresh).  
**State:** `Hold.status`: `active` → `settled|cancelled|partially_settled`.  
**Observability:** settlement latency and failure alerts.  
**Traceability:** §6.1 Match settle; §5.2 Internal APIs.

### Epic C — Deposits & Withdrawals (Custody)
MVP focuses on STAR/FZ/PT off‑chain custody; USDT added later.  
**Traceability:** §5 Public APIs `/v1/deposits`, `/v1/withdrawals`, §7 Security.

#### Feature C1 — Deposit (Admin Mint or Earned Rewards)
**Story:** As a **user**, I want to receive STAR/FZ/PT into my wallet from rewards, conversions, or administrative grants, so that I can play and participate.  
**Acceptance Criteria:**
1. **Given** a staff action or reward event, **when** Workers post `POST /internal/v1/deposits` with `{{userId, asset, amount, source, idemKey}}`, **then** the user’s `available` increases and a ledger journal is posted.  
2. **Given** a duplicate `idemKey`, **when** retried, **then** response is idempotent.  
3. **Given** negative or zero amount, **then** **400** returned.  
**Permissions:** internal (Workers, Admin BFF), not public.  
**Observability:** deposit counts by source; audit trail for staff grants.  
**Security:** capability `finance.deposit` required.

#### Feature C2 — Withdraw (Optional gated / future on‑chain)
**Story:** As a **user**, I want to withdraw STAR/FZ/PT (policy‑gated), so that I can cash out or transfer (future).  
**Acceptance Criteria:**
1. **Given** configured withdrawal policy in **tg‑miniapp‑config**, **when** I submit `POST /v1/withdrawals` with KYC‑compliant info, **then** request enters `pending_review` (MVP may disable external withdrawals).  
2. **Given** staff approval via Admin, **when** status becomes `approved`, **then** Workers execute movement (off‑platform transfer or voucher) and mark `completed`.  
3. **Given** insufficient available balance, **then** **409 insufficient_funds**.  
**State:** `pending_review` → `approved|rejected` → `completed|failed`.  
**Traceability:** §3 Scope (custody), §5 Public API.

### Epic D — Conversions (STAR↔FZ↔PT, rate via Price Service/config)
**Traceability:** §5 Interfaces `/v1/conversions`, §6 Flows, §11 Config (fees).

#### Feature D1 — Fixed‑Rate Conversion
**Story:** As a **user**, I want to convert between STAR/FZ/PT at configured rates, so that I can fund a specific game or product.  
**Acceptance Criteria:**
1. **Given** a valid `POST /v1/conversions` `{{fromAsset, toAsset, amountFrom, idemKey}}`, **when** the rate is fetched from Config/Price Service, **then** Payhub debits `fromAsset.available`, credits `toAsset.available`, and records fees (if any).  
2. **Given** cross‑asset not allowed in config, **then** **403 forbidden**.  
3. **Given** balance insufficient, **then** **409 conflict**.  
4. **Given** a retry with same `idemKey`, **then** response repeats the same `conversionId`.  
**Data:** ledger entries with `type=conversion`, `fxRate`.  
**Observability:** conversion histogram; fee revenue metrics.

### Epic E — Fees, Treasury & Revenue Share
Rake on wins, conversion fee, withdrawal fee; treasury accounting.  
**Traceability:** §4 Data Model (FeeSchedule), §6 Settlement, §11 Config.

#### Feature E1 — Apply Rake/Fees
**Story:** As the **platform**, I want fees to be automatically applied per config, so that revenue is captured consistently.  
**Acceptance Criteria:**
1. **Given** a settlement **win**, **when** config says rake 7%, **then** Payhub moves 7% to treasury account and 93% to winner.  
2. **Given** a conversion or withdrawal, **when** fee rules are active, **then** ledger journals include fee lines to treasury.  
3. **Given** fee calculation rounding, **then** results use integer math and round in favor of treasury as configured.  
**Observability:** fee accrual vs realized; daily revenue report job.  
**Security:** fee schedules from signed config only.

### Epic F — Admin & Reporting
**Traceability:** §5 Admin endpoints, §9 Observability.

#### Feature F1 — Wallet Search & Ledger Explorer
**Story:** As **staff (finance)**, I want to search wallets and inspect ledger journals, so that I can investigate disputes.  
**Acceptance Criteria:**
1. **Given** capability `finance.read`, **when** Admin BFF calls `GET /internal/v1/wallets?query=...`, **then** paginated wallets return with balances.  
2. **Given** a specific `journalId`, **when** Admin fetches `GET /internal/v1/ledger/:journalId`, **then** both sides of the journal and metadata are returned.  
3. **Given** export requested for a time range, **then** CSV streaming starts with backpressure.  
**Observability:** slow query alert; audit for staff views over threshold.

### Epic G — Reliability & Repair Jobs (Workers)
**Traceability:** §8 Reliability, §9 Observability.

#### Feature G1 — Idempotent Retry & Ledger Repair
**Story:** As a **worker**, I want to safely retry failed jobs by `Idempotency-Key`, so that operations are exactly-once and repairable.  
**Acceptance Criteria:**
1. **Given** a failed hold/settlement with stored idem key, **when** Workers retry, **then** Payhub returns the original result atomically.  
2. **Given** mismatch between ledger and balance snapshot, **when** repair runs, **then** the job detects and proposes corrective journals guarded by audit approval.  
3. **Given** queue overload, **then** backpressure kicks in and metrics alert.  

---

## 2) End‑to‑End Scenarios (Cross‑Service)

### Scenario 1 — PlayHub Match: Hold → Game → Settle → Balance Update
**Preconditions:** Both players have sufficient `available` balance in STAR/FZ/PT; PlayHub matched them (roomId).  
**Steps:**
1. **PlayHub → Payhub:** `POST /internal/v1/holds` twice for both players.  
2. **Game Service:** Room created and played; winner decided.  
3. **Game → PlayHub:** `POST /internal/v1/results` with winner.  
4. **PlayHub → Payhub:** `POST /internal/v1/settlements` for both holds (`win` & `loss`), applying **7% rake** from config.  
5. **Payhub → Events/Workers:** emit `wallet.settled` for WebApp refresh.  
6. **WebApp → Payhub:** `GET /v1/wallets` shows updated balances.  
**Alternates:** Hold creation fails → PlayHub returns error to UI; Game reports `draw` → `cancel` both holds; Partial settle if disconnect/time cap.  
**Post‑conditions:** Consistent ledger; treasury accrual for rake; audit trail.  
**Traceability:** §6.1 Settlement flow; §5 Interfaces.

### Scenario 2 — Funding Purchase: Hold → Capture to Treasury
**Preconditions:** Active sale; user chooses FZ; price and caps validated by Funding.  
**Steps:**
1. **Funding → Payhub:** `POST /internal/v1/holds` for purchase amount.  
2. **Funding:** allocates units (`floor(amount/price)`), awaits finalize.  
3. **Funding → Payhub:** `POST /internal/v1/settlements` with `outcome=win` to treasury account.  
4. **Workers:** vesting/allocations updated downstream; notifications to user.  
**Alternates:** Window ends without finalize → Funding cancels hold.  
**Post‑conditions:** Treasury credited; user allocation created.  
**Traceability:** §6 Purchase Flow; §5 Interfaces.

### Scenario 3 — Conversion STAR→PT for Game Entry
**Preconditions:** Rates present in config; user has STAR.  
**Steps:** WebApp → Payhub `POST /v1/conversions`; Payhub posts ledger; WebApp refreshes balances.  
**Alternates:** Rate stale → 409 `stale_rate`; retry after refresh; insufficient funds → 409.  
**Post‑conditions:** PT available increases; audit conversion recorded.

### Scenario 4 — Admin Grant Reward
**Preconditions:** Staff with `finance.deposit`.  
**Steps:** Admin BFF → Payhub `POST /internal/v1/deposits`; user sees new balance; event emitted.  
**Alternates:** Wrong user → 404; idem retry returns same `depositId`.  
**Post‑conditions:** Ledger balanced; audit trail with actorId.

---

## 3) Assumptions & Open Questions
**Assumptions**
- MVP assets: **STAR/FZ/PT**; USDT integration deferred but modeled in data schema.  
- Rake default **7%** as per PlayHub CFB doc; configurable via **tg‑miniapp‑config**.  
- Holds may expire via TTL (Workers cron) if caller forgets to settle.  
- Conversions use signed config rates or **Price Service** when enabled.

**Open Questions**
1. What are the **per‑asset withdrawal policies** for MVP (disabled, voucher, or manual)?  
2. Treasury account structure: per asset single account vs multi‑bucket?  
3. Detailed **fee rounding** rule (banker’s rounding vs floor/ceil in favor of treasury).  
4. Max **holds per user** and **max onHold/available ratio** for risk control.  
5. Required **export formats** for finance (CSV columns, timezones).

---

## 4) Permissions Matrix (Summary)
| Action | User | Staff (Finance) | Admin (Platform) | Services (PlayHub/Funding/Escrow) |
|---|---:|---:|---:|---:|
| GET /v1/wallets | ✅ | ✅ | ✅ | ❌ |
| POST /internal/v1/wallets/provision | ❌ | ✅ | ✅ | ✅ (Workers only) |
| POST /internal/v1/holds | ❌ | ❌ | ❌ | ✅ |
| POST /internal/v1/settlements | ❌ | ❌ | ❌ | ✅ |
| POST /internal/v1/deposits | ❌ | ✅ | ✅ | ✅ (Workers) |
| POST /v1/withdrawals | ✅ (policy) | ✅ (review) | ✅ | ❌ |
| GET /internal/v1/ledger/:journalId | ❌ | ✅ | ✅ | ❌ |
| GET /internal/v1/wallets | ❌ | ✅ | ✅ | ❌ |

---

## 5) SLOs & Observability
- **Holds** p95 < 80 ms; **Settlements** p95 < 120 ms; error rate < 0.1%.  
- **Ledger**: zero‑skew invariant job; alert if nonzero > 1 minute.  
- **Queues**: retry budget < 5 attempts; dead‑letter alert.  
- **Dashboards**: balances, holds per minute, settlement outcomes, fee accrual, treasury balance, conversion volume.

---

*Last generated:* 2025-09-25 14:05 +07
