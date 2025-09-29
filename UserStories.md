Repo: tg-miniapp-price-service
File: UserStories.md
SHA-256: 7894a47551abeb24240726d36e2f1fde188339b36ed60ab1967201c10d3f2ec8
Bytes: 24208
Generated: 2025-09-30 02:14 GMT+7
Sources: SystemDesign.md (authoritative), prior UserStories.md (baseline)

---

# Section A — Personas & Stakeholders

> Derived from SystemDesign scope: **Canonical markets & assets registry**, multi-provider tick ingestion, **signed 1-minute snapshots**, OHLCV and **TWAP** computation, **signed quotes** for Payhub, and **USDT equivalence** for Funding.

* **Price Consumer (Service)** — An internal platform service like **Payhub**, **Funding**, or **Playhub** that requires reliable, signed price data to perform its core functions (e.g., valuing assets, settling bets, executing conversions).
* **Client Application (WebApp/Portal)** — A user-facing application that consumes public price data, such as OHLCV bars for charts or TWAP values for display.
* **Data Operator/Market Admin** — A staff member responsible for managing the registry of assets and markets, configuring data providers, and monitoring the health and accuracy of the price feeds.
* **SRE/Ops** — Monitors the health of the ingestion pipeline, snapshot generation, and API latency. Manages alerts for data staleness or high provider error rates.
* **External Data Provider** — A third-party source (e.g., CEX/DEX) that sends price ticks to the service, either via webhook or by being polled by a worker.
* **Auditor** — A persona who needs to verify the integrity of financial operations by checking the signatures on historical price snapshots and quotes.

---

# Section B — Epics → Features → User Stories (exhaustive)

## Epic B1 — Price Data Consumption

### Feature B1.1 — Fetch Signed Price Snapshots
**Story B1.1.1** — *As a Price Consumer (e.g., Payhub), I want to fetch the latest signed 1-minute price snapshot for a market,* so that *I can perform a transaction with a verifiable, trusted price.*
**Acceptance Criteria (GWT)**
1.  **Given** I am an authorized service, **when** I call `GET /v1/snapshots/1m` (`snapshots1m.get`) with a `market` parameter (e.g., 'BTC-USDT'), **then** I receive a **200 OK** with the latest `Snapshot1m` object in the response body.
2.  **Given** the response is successful, **when** I inspect the headers, **then** it must contain an `X-Signature` header with a valid Ed25519 signature for the payload.
3.  **Given** I request a snapshot for a non-existent or inactive market, **then** the service returns a **404 Not Found** error.
4.  **Given** I need a price at a specific point in the past, **when** I include the optional `at` timestamp parameter in the query, **then** the service returns the most recent snapshot at or before that time.

**Data Touchpoints**: `SNAPSHOT_1M`, `MARKET`.
**Events**: `price.snapshot.published@v1` (internal).
**Observability**: `snapshots1m.get.latency`, `snapshot.staleness` metric.

---

### Feature B1.2 — Retrieve OHLCV Data for Charts
**Story B1.2.1** — *As a Client Application, I want to retrieve OHLCV (candlestick) data for a market,* so that *I can display historical price charts to end-users.*
**Acceptance Criteria (GWT)**
1.  **Given** I need chart data for BTC-USDT, **when** I call `GET /v1/ohlcv` (`ohlcv.get`) with `market=BTC-USDT` and `tf=1h` (timeframe), **then** I receive a **200 OK** with a paginated `OhlcvPage` containing an array of `OhlcvBar` objects.
2.  **Given** I need a specific time range, **when** I provide `start` and `end` date-time parameters, **then** the result set is filtered to that window.
3.  **Given** the number of bars exceeds the page limit, **when** I receive the response, **then** it includes a `nextCursor` string that I can use in a subsequent request to fetch the next page of data.
4.  **Given** I make too many requests in a short period, **then** the service returns a **429 RateLimited** error with a `Retry-After` header.

**Data Touchpoints**: `OHLCV_BAR`, `MARKET`.

---

### Feature B1.3 — Compute Time-Weighted Average Price (TWAP)
**Story B1.3.1** — *As a Price Consumer (e.g., Funding), I want to compute a TWAP for a specific time window,* so that *I can value assets based on an average price, protecting against short-term volatility.*
**Acceptance Criteria (GWT)**
1.  **Given** I need a 1-hour TWAP for ETH-USDT, **when** I call `GET /v1/twap` (`twap.get`) with `market=ETH-USDT` and `window=1h`, **then** I receive a **200 OK** with a `Twap` object containing the calculated average price, the window, and the number of samples used.
2.  **Given** the system has insufficient tick or bar data within the requested window to provide a reliable average, **then** the service returns a server error indicating data unavailability for that period.

**Data Touchpoints**: `TWAP_WINDOW`, `OHLCV_BAR`, `PRICE_TICK`.

---

## Epic B2 — Transactional Pricing

### Feature B2.1 — Issue Signed Quotes for Conversions
**Story B2.1.1** — *As a Price Consumer (Payhub), I want to issue a signed, expiring quote,* so that *I can execute a currency conversion at a guaranteed rate.*
**Acceptance Criteria (GWT)**
1.  **Given** I am an authorized internal service, **when** I call `POST /internal/v1/quotes` (`quotes.issue`) with `from`, `to`, `amount`, and an `Idempotency-Key`, **then** the service creates a **QUOTE** record and returns a **201 Created** with the signed quote object.
2.  **Given** the response is successful, **when** I inspect the `Quote` object, **then** it must contain an `expiresAt` timestamp, a `rate`, and a unique `signature`.
3.  **Given** I make the same request again with the same `Idempotency-Key`, **then** the service returns the original `Quote` object without creating a duplicate.
4.  **Given** a public client needs a rate for UI purposes, **when** it calls `GET /v1/quotes` (`quotes.preview`), **then** it receives an unsigned `QuotePreview` object.

**Data Touchpoints**: `QUOTE`, `SNAPSHOT_1M`.
**Events**: `price.quote.issued@v1`.

---

### Feature B2.2 — Compute Signed USDT Equivalence
**Story B2.2.1** — *As a Price Consumer (Funding), I want to compute the signed USDT equivalent of an asset amount,* so that *I can enforce funding caps consistently.*
**Acceptance Criteria (GWT)**
1.  **Given** I am an authorized internal service, **when** I call `POST /internal/v1/usdt_equiv` (`usdt.equiv`) with an `asset`, `amount`, and `Idempotency-Key`, **then** the service creates a **USDT_EQUIV** record and returns a **201 Created** with the signed equivalence object.
2.  **Given** the response is successful, **when** I inspect the `UsdtEquiv` object, **then** it must contain the `usdtAmount`, the `method` used (Spot or Twap), a `timestamp`, and a `signature`.

**Data Touchpoints**: `USDT_EQUIV`, `TWAP_WINDOW`, `SNAPSHOT_1M`.

---

## Epic B3 — Data Ingestion & Management

### Feature B3.1 — Ingest Price Ticks from Providers
**Story B3.1.1** — *As a Data Operator, I want the system to ingest price ticks from multiple external providers,* so that *we can build a redundant and reliable aggregated price.*
**Acceptance Criteria (GWT)**
1.  **Given** an external provider is configured for webhook delivery, **when** the provider sends a payload to `POST /v1/webhooks/provider` (`webhooks.providerTicks`), **then** the service validates the webhook signature, accepts the data with a **202 Accepted**, and enqueues it for processing.
2.  **Given** the ingested tick's price is a significant outlier compared to the current median (based on z-score or MAD filters), **when** it is processed, **then** it is stored in the **PRICE_TICK** table with the `flags` field set to `Outlier` and is excluded from snapshot calculations.
3.  **Given** a provider's health status is `Degraded` or `Offline`, **when** ticks are ingested from it, **then** they are flagged and excluded from the primary aggregation until the provider's health is restored.

**Data Touchpoints**: `PRICE_TICK`, `PROVIDER`, `PROVIDER_HEALTH_EVENT`.

---

# Section C — End‑to‑End Scenarios

### E2E-C1: Payhub Executes a Currency Conversion
* A **User** in the WebApp wants to convert USDT to STAR.
* The **WebApp BFF** calls `GET /v1/quotes` on the **Price Service** to get a preview rate for the UI.
* When the user confirms, the **WebApp BFF** calls the **Payhub Service** to execute the conversion.
* **Payhub** calls `POST /internal/v1/quotes` on the **Price Service** with an `Idempotency-Key` to get a firm, signed `Quote`.
* **Payhub** validates the signature and expiry on the quote.
* **Payhub** executes the conversion on its ledger and confirms success to the user.

### E2E-C2: Provider Health Degradation and Recovery
* **Provider A** starts sending erratic price data for BTC-USDT.
* The **Aggregator** in the Price Service detects that Provider A's ticks have a high variance compared to Providers B and C. It creates a `PROVIDER_HEALTH_EVENT` with `status: Degraded`.
* For the next 5 minutes, all incoming ticks from Provider A are flagged as `Outlier` and are not used to calculate the signed `SNAPSHOT_1M`. The snapshot is calculated using only data from B and C.
* Provider A's data stabilizes. The health check worker detects normal variance again and updates the `PROVIDER_HEALTH_EVENT` to `status: Healthy`.
* Subsequent ticks from Provider A are now included in the aggregation again.

---

# Section D — Traceability Matrix

| Story | APIs | Entities | Events | SystemDesign anchors |
| :--- | :--- | :--- | :--- | :--- |
| B1.1.1 | `GET /v1/snapshots/1m` | SNAPSHOT\_1M, MARKET | price.snapshot.published@v1 | §5, §6.1 |
| B1.2.1 | `GET /v1/ohlcv` | OHLCV\_BAR, MARKET | (none) | §5 |
| B1.3.1 | `GET /v1/twap` | TWAP\_WINDOW, PRICE\_TICK, OHLCV\_BAR | (none) | §5, §6.2 |
| B2.1.1 | `POST /internal/v1/quotes`, `GET /v1/quotes` | QUOTE, SNAPSHOT\_1M | price.quote.issued@v1 | §5, §6.3 |
| B2.2.1 | `POST /internal/v1/usdt_equiv` | USDT\_EQUIV, TWAP\_WINDOW | (none) | §5, §6.4 |
| B3.1.1 | `POST /v1/webhooks/provider` | PRICE\_TICK, PROVIDER, PROVIDER\_HEALTH\_EVENT | (none) | §5, §6.1 |

**Deltas vs prior UserStories**: Aligned all API endpoints with the OpenAPI specification in the `SystemDesign.md`. Clarified the distinction between the internal `quotes.issue` and public `quotes.preview` endpoints. Added specific acceptance criteria for provider health monitoring and outlier detection, which are critical features of the design.

---

# Section E — Assumptions & Open Questions

* **Assumption**: The key rotation for the Ed25519 signing keys is managed by an external KMS and the service has a reliable mechanism to fetch the current public key for signing and the set of public keys (JWKS) for verification.
* **Question**: What are the specific, configurable thresholds for the z-score and Median Absolute Deviation (MAD) filters used for outlier detection?
* **Question**: What is the defined data retention policy for `PRICE_TICK` (30 days) and `SNAPSHOT_1M` (180 days), and is this sufficient for all auditing and compliance requirements?

---

# Appendix — Coverage Gates

## A1. Stakeholder Catalog

| Stakeholder | Responsibilities | Permissions | Typical Actions | KPIs/SLO interests |
| :--- | :--- | :--- | :--- | :--- |
| Price Consumer (Service) | Consumes price data for core logic | Service Token | Fetch snapshots, TWAPs, quotes | Data freshness, signature validity |
| Client Application | Displays price data to users | Public (rate-limited) | Fetch OHLCV for charts | API latency, availability |
| Data Operator/Market Admin | Manages assets, markets, providers | Staff Role | Add/update assets, monitor health | Provider uptime, data accuracy |
| SRE/Ops | Monitors system health | Staff Role | Manage alerts, review metrics | Snapshot availability, latency |
| External Data Provider | Supplies raw price data | API Key/Webhook Secret | Send price ticks | Webhook acceptance rate |
| Auditor | Verifies data integrity | Read-only access | Check historical signatures | Data retention, audit trail completeness |

## A2. RACI Matrix

| Capability | Price Consumer | Client App | Data Operator | SRE/Ops |
| :--- | :--- | :--- | :--- | :--- |
| Price Data Consumption | R | R | I | C |
| Transactional Pricing (Quotes) | A | I | I | C |
| Data Ingestion & Health | I | I | A | C |
| Asset & Market Management | I | I | A | C |
| Reliability & Observability | I | I | C | A |

_Legend: R=Responsible, A=Accountable, C=Consulted, I=Informed._

## A3. CRUD × Persona × Resource Matrix

| Resource \ Persona | Price Consumer | Client App | Data Operator/Admin |
| :--- | :--- | :--- | :--- |
| ASSET | R | R | C/R/U/D |
| MARKET | R | R | C/R/U/D |
| PROVIDER | I | I | C/R/U/D |
| PRICE\_TICK | I | I | C/R |
| SNAPSHOT\_1M | R | R | R |
| QUOTE | C/R (Internal) | R (Public) | R |
| USDT\_EQUIV | C/R (Internal) | N/A | R |

## A4. Permissions / Badge / KYC Matrix

| Action | Requirement |
| :--- | :--- |
| Fetch public OHLCV/TWAP data | None (subject to rate limits) |
| Fetch signed `Snapshot1m` data | Authorized Service Token |
| Issue a signed `Quote` | Authorized Internal Service Token |
| Issue a signed `UsdtEquiv` | Authorized Internal Service Token |
| Manage Assets/Markets/Providers | Staff Role with 'Admin' badge via Identity |

## A5. Abuse/Misuse & NFR Sweeps
* **Abuse**: API scraping of public endpoints is mitigated by per-IP rate limiting (`429 Too Many Requests`). Malicious data from a single provider is mitigated by multi-source aggregation, outlier filtering (z-score/MAD), and automated health checks that can quarantine a faulty provider.
* **Security**: Data integrity is the core security concern. This is addressed by signing all critical data outputs (snapshots, quotes, USDT equivalence) with Ed25519 keys managed via KMS. Webhooks from providers are verified using HMAC signatures.
* **Resilience**: The system is designed to be resilient to the failure of a single data provider by falling back to the median of the remaining healthy providers. Circuit breakers and queues with backpressure are used to manage ingestion load and prevent cascading failures.
* **Localization**: All timestamps are handled in UTC. User-facing clients (WebApp/Portal) are responsible for converting to GMT+7 for display.
