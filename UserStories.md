Repo: tg-miniapp-payhub-service
File: UserStories.md
SHA-256: 4920400d984725350fa6d7c867ca3508d72658597fdcd6f264887363cd944888
Bytes: 28420
Generated: 2025-09-30 02:20 GMT+7
Sources: SystemDesign.md (authoritative), prior UserStories.md (baseline)

---

# Section A — Personas & Stakeholders

> Derived from SystemDesign scope: The platform's financial ledger. Manages **Accounts**, **Balances**, a **double-entry ledger**, **Holds & Settlements**, on-chain **Deposits & Withdrawals** with reorg handling, internal asset **Conversions**, and **Invoicing**.

* **End User** — The ultimate owner of an account, who interacts with Payhub indirectly via client-facing services like the WebApp or Web3 Portal to deposit, withdraw, or convert funds.
* **Investor (KYC'd)** — An End User with an 'Investor' badge, who is subject to higher transaction limits enforced by this service.
* **Partner Service** — An internal service like **Playhub**, **Funding**, or **Escrow** that acts on behalf of a user to create holds, execute settlements, or issue invoices for overages.
* **Admin/Finance Ops** — A staff member who performs manual operations like issuing refunds, managing fee schedules, triggering RBF for stuck withdrawals, and reconciling the ledger.
* **Compliance/Risk Analyst** — A staff member who monitors for risky transaction patterns, manages user limits, and reviews transactions flagged by automated screening.
* **Workers** — Background job executors responsible for monitoring blockchain transactions, processing deposit confirmations, broadcasting withdrawals, and handling hold expirations.
* **Auditor** — A read-only persona who exports immutable ledger data to verify financial integrity.
* **External Chain Watcher/Broadcaster** — An external component that monitors chain activity for deposits and broadcasts withdrawal transactions, reporting status back via webhooks.

---

# Section B — Epics → Features → User Stories (exhaustive)

## Epic B1 — Accounts & Double-Entry Ledger

### Feature B1.1 — Manage Accounts and Balances
**Story B1.1.1** — *As a Partner Service, I want to provision an account for a new user,* so that *they can immediately participate in financial activities.*
**Acceptance Criteria (GWT)**
1.  **Given** a new user is registered in the Identity service, **when** I call `POST /v1/accounts` (`accounts.create`) with their `userId`, **then** the service idempotently creates an **ACCOUNT** record and initializes **BALANCE** records for all supported assets (STAR, FZ, PT, USDT) with zero values.
2.  **Given** I am an authenticated user (via a BFF), **when** my client requests my balances via `GET /v1/accounts/{accountId}/balances` (`accounts.balances`), **then** I receive a list of my **BALANCE** records showing both `available` and `held` amounts.

**Data Touchpoints**: `ACCOUNT`, `BALANCE`.
**Events**: `payhub.account.created@v1`.

---

### Feature B1.2 — Ensure Ledger Integrity
**Story B1.2.1** — *As a Finance Ops user, I want every financial operation to be recorded as a balanced, double-entry transaction,* so that *the ledger is always auditable and consistent.*
**Acceptance Criteria (GWT)**
1.  **Given** any financial operation (e.g., a deposit), **when** it is processed, **then** a single **JOURNAL_TX** is created which contains at least two corresponding **LEDGER_ENTRY** records that sum to zero (e.g., a debit from a system account and a credit to a user account).
2.  **Given** a transaction is recorded, **when** I inspect the `LEDGER_ENTRY`, **then** it must be immutable and contain the `journalTxId`, `accountId`, `asset`, `amount` (negative for debit, positive for credit), and a descriptive `narrative`.

**Data Touchpoints**: `JOURNAL_TX`, `LEDGER_ENTRY`.

---

## Epic B2 — Holds & Settlements

### Feature B2.1 — Create and Manage Holds
**Story B2.1.1** — *As a Partner Service (e.g., Playhub), I want to place a temporary hold on a user's funds,* so that *their stake is reserved for a match.*
**Acceptance Criteria (GWT)**
1.  **Given** a user has sufficient `available` balance, **when** I call `POST /v1/holds` (`holds.create`) with an `Idempotency-Key`, `accountId`, `amount`, and `purpose`, **then** a **HOLD** record is created, and the user's **BALANCE** is atomically updated to decrease `available` and increase `held` by the same amount.
2.  **Given** the user's `available` balance is insufficient, **then** the API returns a **402 InsufficientFunds** error.
3.  **Given** a hold is no longer needed (e.g., a match is cancelled), **when** I call `POST /v1/holds/{holdId}/release` (`holds.release`), **then** the **HOLD** status becomes `Released`, and the funds are moved from `held` back to `available` in the user's **BALANCE**.

**Data Touchpoints**: `HOLD`, `BALANCE`, `JOURNAL_TX`, `LEDGER_ENTRY`.
**Events**: `payhub.hold.created@v1`, `payhub.hold.released@v1`.

---

### Feature B2.2 — Execute Settlements
**Story B2.2.1** — *As a Partner Service (e.g., Playhub), I want to settle a match by capturing holds and distributing funds,* so that *the winner is paid correctly.*
**Acceptance Criteria (GWT)**
1.  **Given** a completed match with active holds for two players, **when** I call `POST /v1/settlements` (`settlements.create`) specifying the `holdId`s and a breakdown of payments (e.g., to the winner and a rake to a system account), **then** the service creates a **SETTLEMENT** record.
2.  **Given** the settlement is processed, **when** the ledger is updated, **then** a single atomic **JOURNAL_TX** is created that captures the holds (debits `held` balances) and credits the `available` balances of the winner and the rake recipient.

**Data Touchpoints**: `SETTLEMENT`, `HOLD`, `BALANCE`.
**Events**: `payhub.settlement.succeeded@v1`.

---

## Epic B3 — On-Chain Deposits & Withdrawals

### Feature B3.1 — Process Inbound Deposits
**Story B3.1.1** — *As an End User, I want my on-chain deposits to be credited to my account promptly after they are confirmed,* so that *I can use my funds on the platform.*
**Acceptance Criteria (GWT)**
1.  **Given** I have a `DEPOSIT_INTENT`, **when** an on-chain watcher detects a transaction to my assigned address, **then** it sends a webhook to `POST /v1/webhooks/deposits` and a **DEPOSIT_TX** record is created with `confirmations: 0`.
2.  **Given** the transaction reaches the required number of confirmations, **when** the watcher sends an update, **then** the **DEPOSIT_TX** status becomes `Confirmed`, and my account's **BALANCE** is credited.
3.  **Given** a blockchain reorg occurs and my deposit transaction is orphaned, **when** the watcher detects this, **then** the **DEPOSIT_TX** status is updated to `Reorged`, and a reversing **JOURNAL_TX** is posted to debit my account for the provisional credit.

**Data Touchpoints**: `DEPOSIT_INTENT`, `DEPOSIT_TX`, `BALANCE`.
**Events**: `payhub.deposit.updated@v1`.

---

### Feature B3.2 — Process Outbound Withdrawals
**Story B3.2.1** — *As an Investor User, I want to withdraw funds to my external wallet,* so that *I can take custody of my assets.*
**Acceptance Criteria (GWT)**
1.  **Given** I have the required 'Investor' badge and am within my withdrawal limits, **when** I request a withdrawal via `POST /v1/withdrawals` (`withdrawals.create`), **then** my `available` **BALANCE** is placed on hold, and a **WITHDRAWAL_REQUEST** is created with `status: Queued`.
2.  **Given** a queued request, **when** a **Worker** picks it up, **then** it is broadcast to the network, and its status is updated to `Broadcast` with a `txHash`.
3.  **Given** a broadcast transaction becomes stuck due to low fees, **when** an **Admin** triggers a Replace-by-Fee via `POST /v1/admin/withdrawals/{withdrawalId}/rbf` (`admin.withdrawals.rbf`), **then** a **WITHDRAWAL_RBF_ATTEMPT** is recorded, and a new transaction with a higher fee is broadcast.

**Data Touchpoints**: `WITHDRAWAL_REQUEST`, `WITHDRAWAL_TX`, `WITHDRAWAL_RBF_ATTEMPT`, `LIMIT_PROFILE`.
**Events**: `payhub.withdrawal.updated@v1`.

---

## Epic B4 — Internal Asset Conversions

### Feature B4.1 — Quote and Execute Conversions
**Story B4.1.1** — *As an End User, I want to convert between assets (e.g., USDT to STAR),* so that *I have the right currency for platform activities.*
**Acceptance Criteria (GWT)**
1.  **Given** I want to perform a swap, **when** my client requests a quote via `POST /v1/conversions/quote` (`conversions.quote`), **then** Payhub gets a signed snapshot from the **Price Service** and returns a **CONVERSION_QUOTE** with a firm rate, fee, and an expiry time.
2.  **Given** I have a valid, unexpired quote, **when** I execute it via `POST /v1/conversions/execute` (`conversions.execute`) with the `quoteId`, **then** a **CONVERSION_ORDER** is created, and my asset **BALANCE** records are atomically debited and credited in a single **JOURNAL_TX**.
3.  **Given** I try to execute with a stale or already used quote, **then** the API returns a **409 Conflict** error.

**Data Touchpoints**: `CONVERSION_QUOTE`, `CONVERSION_ORDER`, `BALANCE`.
**Events**: `payhub.conversion.executed@v1`.

---

# Section C — End‑to‑End Scenarios

### E2E-C1: Deposit Credit with Reorg
* **User** gets a `DEPOSIT_INTENT` address.
* **User** sends funds. A **Watcher** detects the transaction and notifies Payhub, creating a `DEPOSIT_TX`.
* The transaction reaches the confirmation threshold. **Payhub** credits the user's **ACCOUNT** and sends a `payhub.deposit.updated@v1` event.
* A blockchain **reorg** happens. The watcher detects the transaction is no longer in a canonical block.
* The watcher notifies **Payhub**. The `DEPOSIT_TX` is marked as `Reorged`, and an atomic, reversing `JOURNAL_TX` is posted to debit the user's account. A new event is fired to notify clients of the reversal.

### E2E-C2: Hold and Settlement for a Game Match
* **Playhub** requests a `hold` on Player A's and Player B's accounts for a 100 STAR stake.
* **Payhub** creates two **HOLD** records and updates their `held` balances.
* The match concludes. Player A wins.
* **Playhub** calls `POST /v1/settlements`, specifying to capture both holds and pay 198 STAR to Player A and 2 STAR to the platform's rake account.
* **Payhub** executes this in a single **JOURNAL_TX**: Player A's `held` balance is debited by 100 and `available` is credited by 198; Player B's `held` balance is debited by 100; the Rake account is credited by 2.
* A `payhub.settlement.succeeded@v1` event is emitted.

---

# Section D — Traceability Matrix

| Story | APIs | Entities | Events | SystemDesign anchors |
| :--- | :--- | :--- | :--- | :--- |
| B1.1.1 | `POST /v1/accounts`, `GET .../balances` | ACCOUNT, BALANCE | payhub.account.created@v1 | §5 |
| B1.2.1 | (All financial operations) | JOURNAL\_TX, LEDGER\_ENTRY | payhub.journal.posted@v1 | §4 |
| B2.1.1 | `POST /v1/holds`, `POST .../release` | HOLD, BALANCE, JOURNAL\_TX | payhub.hold.created@v1, payhub.hold.released@v1 | §5, §6.1 |
| B2.2.1 | `POST /v1/settlements` | SETTLEMENT, HOLD | payhub.settlement.succeeded@v1 | §5, §6.1 |
| B3.1.1 | `/v1/webhooks/deposits` | DEPOSIT\_INTENT, DEPOSIT\_TX | payhub.deposit.updated@v1 | §5, §6.2 |
| B3.2.1 | `POST /v1/withdrawals`, `POST .../rbf` | WITHDRAWAL\_REQUEST, WITHDRAWAL\_TX, RBF\_ATTEMPT | payhub.withdrawal.updated@v1 | §5, §6.3 |
| B4.1.1 | `/v1/conversions/quote`, `/v1/conversions/execute` | CONVERSION\_QUOTE, CONVERSION\_ORDER | payhub.conversion.executed@v1 | §5, §6.4 |

**Deltas vs prior UserStories**: This version is built directly from the detailed System Design. Key additions include explicit stories for the **double-entry ledger**, handling of **blockchain reorgs**, the **Replace-by-Fee (RBF)** mechanism for stuck withdrawals, and the full quote-and-execute flow for conversions, making the financial logic far more robust and auditable.

---

# Section E — Assumptions & Open Questions

* **Assumption**: The external chain watcher and broadcaster components are highly reliable and have their own mechanisms for handling RPC node failures.
* **Question**: What are the specific numerical values for deposit confirmations (`minConf`), withdrawal limits per KYC tier (`LIMIT_PROFILE`), and fee schedules (`FEE_SCHEDULE`)?
* **Question**: What is the precise policy for handling rounding and dust in financial calculations? The design mentions banker's rounding but the threshold for dust is not defined.

---

# Appendix — Coverage Gates

## A1. Stakeholder Catalog

| Stakeholder | Responsibilities | Permissions | Typical Actions | KPIs/SLO interests |
| :--- | :--- | :--- | :--- | :--- |
| End User | Owns an account | Session | Deposit, withdraw (indirectly) | Transaction success rate |
| Partner Service | Manages holds & settlements | Service Token | Create holds, execute settlements | API success rate, p99 latency |
| Admin/Finance Ops | Manages ledger, fees, refunds | Staff scopes | Issue refunds, RBF withdrawals | Reconciliation time |
| Compliance/Risk | Manages limits & risk | Staff scopes | Review transactions, set limits | False positive rate on flags |
| Workers | Executes async tasks | Internal | Process deposits, broadcast withdrawals | Queue depth, job success rate |
| Auditor | Verifies ledger integrity | Read-only scope | Export financial records | Audit pass rate |

## A2. RACI Matrix

| Capability | End User | Partner Service | Admin/Finance | Compliance | Workers | SRE/Ops |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Account Management | R | C | U/D | I | I | I |
| Holds & Settlements | I | A | C | I | C | C |
| On-Chain Deposits | R | I | C | C | A | C |
| On-Chain Withdrawals | R | I | A | C | A | C |
| Asset Conversions | R | I | C | I | I | C |
| Risk & Limits | I | I | C | A | I | I |

_Legend: R=Responsible, A=Accountable, C=Consulted, I=Informed._

## A3. CRUD × Persona × Resource Matrix

| Resource \ Persona | End User (indirect) | Partner Service | Admin/Finance |
| :--- | :--- | :--- | :--- |
| ACCOUNT | R | C/R | R/U/D |
| BALANCE | R | R | R/U (adjust) |
| HOLD | R (own) | C/R/U | U/D (void) |
| SETTLEMENT | I | C | R |
| DEPOSIT\_INTENT | C/R | I | R |
| WITHDRAWAL\_REQUEST | C/R/D | I | R/U (RBF) |
| CONVERSION\_ORDER | C/R | I | R |
| INVOICE | R | C/R | U/D |

## A4. Permissions / Badge / KYC Matrix

| Action | Requirement | Evidence |
| :--- | :--- | :--- |
| Create Hold > Tier 1 Limit | 'Investor' Badge | Badge claim from Identity |
| Withdraw > Daily Limit | 'Investor' Badge | Badge claim from Identity |
| Issue Refund | 'Finance Ops' Role | Audit log entry |
| Trigger RBF | 'Admin' Role | Audit log entry |

## A5. Abuse/Misuse & NFR Sweeps
* **Abuse**: Structuring deposits/withdrawals to evade limits is mitigated by `USAGE_COUNTER` tracking velocity over daily and monthly windows.
* **Security**: All state-changing operations are protected by an `Idempotency-Key` to prevent duplicate transactions. The double-entry ledger ensures that funds cannot be created or destroyed, only moved. Webhooks are HMAC-signed.
* **Resilience**: The system is designed to handle blockchain reorgs by reversing provisional credits. Stuck withdrawals can be expedited via RBF. The use of an outbox pattern ensures at-least-once delivery of critical financial events.
* **Localization**: Financial amounts are handled in minor units to avoid floating-point errors. Timestamps are stored in UTC, with GMT+7 used for user-facing displays where applicable.
