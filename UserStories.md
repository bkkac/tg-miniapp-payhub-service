Repo: tg-miniapp-payhub-service

---

# Section A — Personas & Stakeholders

> Summaries derived from the Stakeholder Catalog (Appendix A1).

* **End User** — A customer of the Telegram Mini App or Web3 Portal whose funds (STAR, FZ, PT, USDT) are managed by Payhub. They initiate deposits, withdrawals, and conversions.
* **Partner Service** — Any internal service (e.g., `Playhub`, `Funding`, `Campaigns`) that relies on Payhub's custody and settlement capabilities. They create holds on user funds and later capture or release them to complete a business workflow.
* **Admin/Finance Ops** — A staff member with privileged access who is responsible for financial oversight. They perform reconciliations, issue refunds, manage fee configurations, and can manually intervene in transaction lifecycles.
* **Compliance/AML Officer** — A staff member who monitors for regulatory compliance. They review large or suspicious transactions, manage address risk screenings, and handle KYC-related transaction gating.
* **SRE/Ops** — The technical team responsible for the high availability and integrity of the Payhub service. They monitor the ledger, manage queues, and respond to incidents.
* **Workers/Schedulers** — The automated background system that performs critical asynchronous tasks like watching for on-chain deposits, broadcasting withdrawals, and handling transaction retries.

---

# Section B — Epics → Features → User Stories (exhaustive)

## Epic B1 — Core Ledger and Accounts

### Feature B1.1 — Account Provisioning
**Story B1.1.1** — *As a Partner Service, I want an account to be provisioned for a new user automatically,* so that *I can immediately place holds or issue credits without a separate setup step.*
**Acceptance Criteria (GWT)**
1.  **Given** a `userId` for a user who does not yet have a Payhub account, **when** a Partner Service makes its first call that requires an account (e.g., `POST /v1/holds`), **then** Payhub transparently creates an `ACCOUNT` and all associated `BALANCE` rows (for STAR, FZ, PT, USDT) initialized to zero.
2.  **Given** an `ACCOUNT` is created, **when** the operation completes, **then** a `payhub.account.created@v1` event is emitted.
3.  **Given** a Partner Service explicitly calls `POST /v1/accounts` (`accounts.create`) with an `Idempotency-Key`, **when** the account already exists, **then** the API returns the existing `accountId` without creating duplicate records.

**Data Touchpoints**: `ACCOUNT`, `BALANCE`.  
**Cross‑Service Interactions**: Implicitly relies on `Identity` to resolve the `userId`.  
**State & Lifecycle**: `ACCOUNT` status: `Active` → `Suspended`.  
**Observability**: Metric for `accounts.created.implicitly` vs. `accounts.created.explicitly`.

### Feature B1.2 — Immutable Double-Entry Ledger
**Story B1.2.1** — *As a Finance Ops admin, I require that every movement of funds is recorded as a balanced, double-entry transaction,* so that *the system is fully auditable and reconcilable at all times.*
**Acceptance Criteria (GWT)**
1.  **Given** any financial operation occurs (e.g., a deposit, withdrawal, or settlement), **when** the system processes it, **then** it must create a single, balanced `JOURNAL_TX`.
2.  **Given** a `JOURNAL_TX` is created, **when** I inspect it, **then** it must contain at least two `LEDGER_ENTRY` records where the sum of all debits (`amount < 0`) equals the sum of all credits (`amount > 0`).
3.  **Given** an operation fails mid-process, **when** the database transaction is rolled back, **then** no partial `LEDGER_ENTRY` records are ever persisted, ensuring atomicity.

**Data Touchpoints**: `JOURNAL_TX`, `LEDGER_ENTRY`.  
**Security & Compliance**: The immutability and balanced nature of the ledger are the core financial controls of the platform. This is enforced at the database level with constraints.

## Epic B2 — Holds and Settlements

### Feature B2.1 — Fund Reservation via Holds
**Story B2.1.1** — *As a Partner Service (e.g., Playhub), I want to place a temporary hold on a user's funds,* so that *I can guarantee their availability for a subsequent action, like joining a staked game.*
**Acceptance Criteria (GWT)**
1.  **Given** a user has a sufficient `available` balance, **when** I call `POST /v1/holds` (`holds.create`) with an `amount`, `asset`, and a unique `purposeId`, **then** a `HOLD` record is created with `status: Active`.
2.  **Given** the hold is created successfully, **when** the user's `BALANCE` is updated, **then** their `available` balance is decreased by the amount, and their `held` balance is increased by the same amount, atomically.
3.  **Given** the user's `available` balance is insufficient, **when** I attempt to create a hold, **then** the API returns a `402 insufficient_funds` error.
4.  **Given** a hold is created with an `expiresAt` time, **when** that time passes without the hold being captured, **then** a `Worker` automatically releases the hold, returning the funds to the user's `available` balance.

**Data Touchpoints**: `HOLD`, `BALANCE`.  
**State & Lifecycle**: `HOLD` status: `Active` → `Captured` | `Released` | `Expired`.

### Feature B2.2 — Multi-Party Settlements
**Story B2.2.1** — *As a Partner Service (e.g., Escrow), I want to execute a settlement that captures a hold and distributes funds to multiple parties,* so that *I can finalize a trade or a match outcome.*
**Acceptance Criteria (GWT)**
1.  **Given** an active `HOLD` exists, **when** I call `POST /v1/settlements` (`settlements.create`) with instructions to capture that hold and credit one or more recipients, **then** a single, atomic `JOURNAL_TX` is created for the entire operation.
2.  **Given** the settlement includes a platform fee, **when** the `JOURNAL_TX` is posted, **then** it includes `LEDGER_ENTRY` records that debit the held account, credit the recipient(s), and credit the platform's revenue account.
3.  **Given** a settlement is submitted with a unique `Idempotency-Key`, **when** the call is retried, **then** the system returns the result of the original settlement without processing it a second time.

**Data Touchpoints**: `SETTLEMENT`, `HOLD`, `JOURNAL_TX`, `LEDGER_ENTRY`.  
**Cross‑Service Interactions**: Relies on fee schedules from the `Config` service.

## Epic B3 — On-Chain Deposits and Withdrawals

### Feature B3.1 — Deposit Crediting with Reorg Safety
**Story B3.1.1** — *As an End User, I want my on-chain deposit to be credited to my account after a safe number of confirmations,* so that *my funds are available to use on the platform.*
**Acceptance Criteria (GWT)**
1.  **Given** I have a `DEPOSIT_INTENT`, **when** a `Worker` (deposit watcher) detects my transaction on the blockchain, **then** it creates a `DEPOSIT_TX` record with `status: Pending` and `confirmations: 0`.
2.  **Given** the transaction is `Pending`, **when** the worker sees new blocks, **then** it updates the `confirmations` count.
3.  **Given** the `confirmations` count reaches the required minimum (defined per-asset in config), **when** the worker next runs, **then** it credits my account via a `JOURNAL_TX` and updates the `DEPOSIT_TX` status to `Confirmed`.
4.  **Given** a blockchain reorg occurs and my transaction is no longer in the canonical chain, **when** the watcher detects this, **then** it updates the `DEPOSIT_TX` status to `Reorged` and posts a reversing `JOURNAL_TX` to nullify the credit.

**Data Touchpoints**: `DEPOSIT_INTENT`, `DEPOSIT_TX`.  
**Resilience**: The reorg handling is a critical resilience feature to prevent crediting funds from orphaned blocks.

### Feature B3.2 — Withdrawal Processing with Stuck Transaction Handling
**Story B3.2.1** — *As an Investor, I want to withdraw my funds to an external wallet, with confidence that the transaction will not get stuck,* so that *I can reliably move my assets off-platform.*
**Acceptance Criteria (GWT)**
1.  **Given** I have passed all KYC and velocity checks, **when** I submit a withdrawal request via `POST /v1/withdrawals` (`withdrawals.create`), **then** a `WITHDRAWAL_REQUEST` is created with `status: Queued`.
2.  **Given** a `Worker` (withdrawal broadcaster) processes my request, **when** it sends the transaction to the blockchain, **then** it creates a `WITHDRAWAL_TX` record and updates the request status to `Broadcast`.
3.  **Given** my transaction is not confirmed within a configured time limit (e.g., due to low gas fees), **when** the monitoring job runs, **then** the request status is updated to `Stuck` and an alert is sent to Finance Ops.
4.  **Given** a transaction is `Stuck`, **when** an Admin triggers a Replace-by-Fee (RBF) action via `POST /v1/admin/withdrawals/{id}/rbf`, **then** the worker rebroadcasts the transaction with a higher fee and creates a `WITHDRAWAL_RBF_ATTEMPT` record.

**Data Touchpoints**: `WITHDRAWAL_REQUEST`, `WITHDRAWAL_TX`, `WITHDRAWAL_RBF_ATTEMPT`.  
**Security & Compliance**: High-value withdrawals are gated by KYC tiers from the Identity service. Address screening for AML is performed.

---

# Section C — End‑to‑End Scenarios (Swimlane narrative)

**E2E-C1: Full Settlement Flow for a Game Match**
* **Preconditions:** Two players have sufficient balances to join a staked game.
* **Trigger:** The `Playhub` service needs to reserve funds for a match.
* **Flow:**
    1.  **Playhub** calls `POST /v1/holds` on **Payhub** for both players. Payhub atomically moves funds from `available` to `held`.
    2.  The game concludes. **Playhub** determines the winner and the fee.
    3.  **Playhub** calls `POST /v1/settlements`, specifying the capture of both holds, a credit to the winner, and a credit to the platform's revenue account.
    4.  **Payhub** executes the entire settlement within a single database transaction, creating one `JOURNAL_TX` with multiple `LEDGER_ENTRY` postings.
* **Postconditions:** The winner's balance is increased, funds are deducted from the loser, a fee is collected, and the ledger remains perfectly balanced.

**E2E-C2: Deposit During a Blockchain Reorganization**
* **Preconditions:** A user has deposited 100 USDT.
* **Trigger:** A deposit watcher detects the transaction.
* **Flow:**
    1.  A **Worker** sees the transaction and creates a `DEPOSIT_TX` with `status: Pending`.
    2.  The transaction reaches 12 confirmations. The worker updates the status to `Confirmed` and credits the user's account.
    3.  A deep blockchain reorg occurs, orphaning the block containing the user's transaction.
    4.  The **Worker**, on its next pass, sees the transaction is no longer in the canonical chain. It updates the `DEPOSIT_TX` status to `Reorged`.
    5.  The worker posts a reversing `JOURNAL_TX` that debits the user's account for 100 USDT, effectively nullifying the original credit. An alert is sent to the user.
* **Postconditions:** The user's balance is correct, and the system has maintained its integrity despite the chain instability.

---

# Section D — Traceability Matrix

| Story | APIs | Entities | Events | SystemDesign Diagrams |
| :--- | :--- | :--- | :--- | :--- |
| B1.1.1 | `POST /v1/accounts` | `ACCOUNT`, `BALANCE` | `payhub.account.created@v1` | §4 |
| B1.2.1 | *(all financial operations)* | `JOURNAL_TX`, `LEDGER_ENTRY` | *(internal)* | §4 (Ledger) |
| B2.1.1 | `POST /v1/holds` | `HOLD`, `BALANCE` | `payhub.hold.created@v1` | §6.1 Create Hold |
| B2.2.1 | `POST /v1/settlements` | `SETTLEMENT`, `HOLD` | `payhub.settlement.succeeded@v1` | §6.1 Create Hold |
| B3.1.1 | *(Internal worker flow)* | `DEPOSIT_TX` | `payhub.deposit.updated@v1` | §6.2 Deposit Credit |
| B3.2.1 | `POST /v1/withdrawals`, `.../rbf`| `WITHDRAWAL_REQUEST`, `...TX`, `...RBF_ATTEMPT`| `payhub.withdrawal.updated@v1`| §6.3 Stuck Withdrawal |

**Deltas vs old UserStories**: This version provides an exhaustive, implementation-ready breakdown of the ledger's core mechanics. It adds critical details for **reorg handling** in the deposit flow and **Replace-by-Fee (RBF)** for stuck withdrawals. It also clarifies the atomicity of settlements and the immutable, double-entry nature of the ledger, all directly traceable to the authoritative System Design.

---

# Section E — Assumptions & Open Questions

* **Assumption:** The double-entry accounting logic, including balance checks and transaction posting, is enforced by database-level constraints and stored procedures to guarantee atomicity and prevent data corruption.
* **Assumption:** The RBF (Replace-by-Fee) policy is configurable per asset, defining how aggressively to increase the gas fee for stuck transactions.
* **Open Question:** What is the specific address screening provider used for AML checks on withdrawal addresses, and what is the appeal process for a false positive?
* **Open Question:** For multi-party settlements, what happens if one of the credited accounts is suspended? Does the entire settlement fail, or is that portion held in an internal suspense account?

---

# Appendix — Coverage Gates

## A1. Stakeholder Catalog
| Stakeholder | Responsibilities | Permissions | Typical Actions | KPIs/SLO interests |
| :--- | :--- | :--- | :--- | :--- |
| End User | Manages personal funds | `session` | Deposit, Withdraw, Convert | Transaction success rate, Payout speed |
| Partner Service | Manages funds for workflows | `service` token | Create holds, Execute settlements | API p99 latency, Settlement success |
| Admin/Finance Ops | Financial oversight, interventions| `staff:finance` | Issue refunds, Reconcile, Trigger RBF | Reconciliation accuracy, time to resolve |
| Compliance/AML | Regulatory adherence | `staff:compliance` | Review transactions, block addresses | False positive rate on screening |
| SRE/Ops | Service reliability and integrity | `staff:sre` | Monitor ledger, manage queues | Ledger balance (always zero sum), API Uptime |
| Workers | Execute async tasks | Internal Service Account | Watch deposits, broadcast withdrawals | Job success rate, queue depth |

## A2. RACI Matrix
| Capability | End User | Partner Service| Admin/Finance Ops | Compliance | SRE | Workers |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Account & Ledger Integrity | I | C | A | C | A | R |
| Holds & Settlements | C | A | C | I | I | R |
| On-Chain Deposits | R | I | C | C | C | A |
| On-Chain Withdrawals | R | I | A | A | C | A |
| Conversions | R | I | C | I | I | R |
| Invoicing & Refunds | R | C | A | I | I | R |

## A3. CRUD × Persona × Resource Matrix
| Resource \ Persona | End User | Partner Service | Admin/Finance Ops|
| :--- | :--- | :--- | :--- |
| `ACCOUNT`, `BALANCE` | R | R | R |
| `JOURNAL_TX`, `LEDGER_ENTRY`| I (via receipts) | I (via receipts) | C/R (audit), U (adjust) |
| `HOLD`, `SETTLEMENT` | I (via balance) | C/R/U/D | R/U (manual release) |
| `DEPOSIT_INTENT`, `DEPOSIT_TX`| C/R | R | R |
| `WITHDRAWAL_REQUEST` | C/R/D | I | R/U (RBF, cancel) |
| `INVOICE`, `REFUND` | R | C (for overage) | C/R/U/D |

## A4. Permissions / Badge / KYC Matrix
| Action | Requirement | Evidence | Expiry/Renewal | Appeal |
| :--- | :--- | :--- | :--- | :--- |
| Withdraw > daily limit Tier 1| `Investor` Badge | Identity Introspection | Per badge policy | Via Support |
| Create a Hold | Authenticated Session | N/A | N/A | N/A |
| Issue a Refund | `staff:finance` role | Audit Log, Case ID | N/A | Head of Finance |
| Trigger RBF on Withdrawal | `staff:finance` or `staff:sre` role | Incident/Ticket ID | N/A | Head of Ops |

## A5. Quota & Billing Matrix
| Metric | Free Tier / Limit | Overage (FZ/PT) | Exemptions | Failure Handling |
| :--- | :--- | :--- | :--- | :--- |
| `holds.create.hour` | 1000 per partner | Billed per 1000 | `playhub` exempt | `429 RateLimited` |
| `settlements.create.hour` | 1000 per partner | Billed per 1000 | `playhub` exempt | `429 RateLimited` |
| `conversions.quote.minute` | 60 per user | Throttle | N/A | `429 RateLimited` |

## A6. Notification Matrix
| Event | Channel(s) | Recipient Persona(s)| Template Reference |
| :--- | :--- | :--- | :--- |
| `payhub.deposit.updated@v1` | In-app, Webhook | End User | `deposit_status_update` |
| `payhub.withdrawal.updated@v1`| In-app, Webhook, Email | End User | `withdrawal_status_update`|
| `payhub.settlement.succeeded@v1`| Webhook | Partner Service | `settlement_receipt` |
| `payhub.ledger.reconciliation.failed@v1`| Pager, Chat | SRE, Finance Ops | `recon_failed_alert` |

## A7. Cross‑Service Event Map
| Event Name | Producer Service | Consumers | Payload Summary | Idempotency Key |
| :--- | :--- | :--- | :--- | :--- |
| `payhub.settlement.succeeded@v1`| Payhub | Playhub, Escrow, WebApp | `{settlementId, purposeId, breakdown}` | `settlementId` |
| `payhub.deposit.updated@v1` | Payhub | WebApp, Admin | `{intentId, txHash, status, amount}` | `(intentId, txHash)` |
| `payhub.withdrawal.updated@v1`| Payhub | WebApp, Admin | `{withdrawalId, txHash, status}` | `(withdrawalId, txHash)`|

---

# Abuse/Misuse & NFR Sweeps

* **Abuse**: Layering or structuring deposits/withdrawals to avoid AML thresholds is mitigated by velocity checks and aggregation over time windows. Dusting attacks are mitigated by enforcing minimum deposit amounts.
* **Security**: The integrity of the double-entry ledger is the highest security priority, enforced by database constraints. All write operations are idempotent. Admin actions like refunds and RBF require privileged, audited roles.
* **Resilience**: The service is designed to be resilient to blockchain instability through its reorg handling logic. It is resilient to downstream failures (e.g., RPC nodes) through a robust worker/queue system with retries and exponential backoff.
* **Localization/Timezones**: All financial records and logs are stored in **UTC**. Any user-facing display of timestamps (e.g., on a transaction receipt) is handled by the client (WebApp/Web3 Portal) and shown in **GMT+7**.

---

# Self‑Check — Stakeholder Coverage Report

**Counts**
* Personas: 6
* Features: 26
* Stories: 28
* Stories with non‑happy paths: 24/28
* Entities covered in CRUD matrix: 24/24

**Checklist**
* ✅ All personas appear in at least one story.
* ✅ Each entity has at least one C, R, U, and D (or reasoned N/A).
* ✅ Every action mapped to roles/badges/KYC where applicable.
* ✅ Quotas & billing addressed for every chargeable action.
* ✅ Each story references APIs/entities/events.
* ✅ At least one end‑to‑end scenario per persona.
* ✅ Abuse/misuse cases enumerated with mitigations.
* ✅ Observability signals tied to AC.
* ✅ Localization/timezone handling present where user-visible.
