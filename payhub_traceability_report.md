# Acceptance Criteria Traceability Report

| AC ID | Requirement Summary | Mapped OpenAPI Operation | Response Code(s) | Coverage Status |
| :--- | :--- | :--- | :--- | :--- |
| AC-PROVISION-ACCOUNT-BALANCES-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-PROVISION-ACCOUNT-BALANCES-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-DOUBLEENTRY-LEDGER-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-DOUBLEENTRY-LEDGER-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-DOUBLEENTRY-LEDGER-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-DOUBLEENTRY-LEDGER-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-DOUBLEENTRY-LEDGER-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-DOUBLEENTRY-LEDGER-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-DOUBLEENTRY-LEDGER-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-DOUBLEENTRY-LEDGER-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-DOUBLEENTRY-LEDGER-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-DOUBLEENTRY-LEDGER-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-DOUBLEENTRY-LEDGER-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-DOUBLEENTRY-LEDGER-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-CREATE-HOLD-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `POST /v1/holds` | 201 | ✅ |
| AC-CREATE-HOLD-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-CREATE-HOLD-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-CREATE-HOLD-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-CREATE-HOLD-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-CREATE-HOLD-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-CREATE-HOLD-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-CREATE-HOLD-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-CREATE-HOLD-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-CREATE-HOLD-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-CREATE-HOLD-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-CREATE-HOLD-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-SETTLE-RELEASE-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-SETTLE-RELEASE-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-SETTLE-RELEASE-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-SETTLE-RELEASE-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-SETTLE-RELEASE-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-SETTLE-RELEASE-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-SETTLE-RELEASE-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-SETTLE-RELEASE-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-SETTLE-RELEASE-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-SETTLE-RELEASE-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-SETTLE-RELEASE-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-SETTLE-RELEASE-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `POST /v1/deposits` | 201 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-CREATE-DEPOSIT-INTENT-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `POST /v1/withdrawals` | 201 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-CREATE-WITHDRAWAL-REQUEST-KYCGATED-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-QUOTE-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-QUOTE-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-QUOTE-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-QUOTE-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-QUOTE-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-QUOTE-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-QUOTE-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-QUOTE-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-QUOTE-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-QUOTE-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-QUOTE-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-QUOTE-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-EXECUTE-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-EXECUTE-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-EXECUTE-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-EXECUTE-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-EXECUTE-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-EXECUTE-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-EXECUTE-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-EXECUTE-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-EXECUTE-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-EXECUTE-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-EXECUTE-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-EXECUTE-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-ISSUE-PAY-INVOICES-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/invoices` | 201 | ✅ |
| AC-ISSUE-PAY-INVOICES-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-ISSUE-PAY-INVOICES-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-ISSUE-PAY-INVOICES-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-ISSUE-PAY-INVOICES-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-ISSUE-PAY-INVOICES-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-ISSUE-PAY-INVOICES-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-ISSUE-PAY-INVOICES-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-ISSUE-PAY-INVOICES-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-ISSUE-PAY-INVOICES-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-ISSUE-PAY-INVOICES-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-ISSUE-PAY-INVOICES-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-MANUAL-REFUNDS-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-MANUAL-REFUNDS-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-MANUAL-REFUNDS-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-MANUAL-REFUNDS-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-MANUAL-REFUNDS-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-MANUAL-REFUNDS-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-MANUAL-REFUNDS-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-MANUAL-REFUNDS-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-MANUAL-REFUNDS-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-MANUAL-REFUNDS-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-MANUAL-REFUNDS-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-MANUAL-REFUNDS-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/quotas-limits` | 201 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-LIMITS-VELOCITY-PROFILES-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-AML-SCREENING-CASE-MANAGEMENT-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-EXPORTS-FOR-AUDIT-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-EXPORTS-FOR-AUDIT-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-EXPORTS-FOR-AUDIT-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-EXPORTS-FOR-AUDIT-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-EXPORTS-FOR-AUDIT-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-EXPORTS-FOR-AUDIT-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-EXPORTS-FOR-AUDIT-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-EXPORTS-FOR-AUDIT-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-EXPORTS-FOR-AUDIT-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-EXPORTS-FOR-AUDIT-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-EXPORTS-FOR-AUDIT-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-EXPORTS-FOR-AUDIT-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-DAILY-CLOSE-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-DAILY-CLOSE-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-DAILY-CLOSE-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-DAILY-CLOSE-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-DAILY-CLOSE-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-DAILY-CLOSE-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-DAILY-CLOSE-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-DAILY-CLOSE-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-DAILY-CLOSE-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-DAILY-CLOSE-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-DAILY-CLOSE-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-DAILY-CLOSE-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-FEE-RULE-REPORTS-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-FEE-RULE-REPORTS-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-FEE-RULE-REPORTS-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-FEE-RULE-REPORTS-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-FEE-RULE-REPORTS-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-FEE-RULE-REPORTS-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-FEE-RULE-REPORTS-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-FEE-RULE-REPORTS-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-FEE-RULE-REPORTS-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-FEE-RULE-REPORTS-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-FEE-RULE-REPORTS-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-FEE-RULE-REPORTS-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-IDEMPOTENCY-RETRIES-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-IDEMPOTENCY-RETRIES-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-IDEMPOTENCY-RETRIES-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-IDEMPOTENCY-RETRIES-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-IDEMPOTENCY-RETRIES-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-IDEMPOTENCY-RETRIES-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-IDEMPOTENCY-RETRIES-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-IDEMPOTENCY-RETRIES-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-IDEMPOTENCY-RETRIES-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-IDEMPOTENCY-RETRIES-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-IDEMPOTENCY-RETRIES-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-IDEMPOTENCY-RETRIES-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-TELEMETRY-SLOS-01 | Given an authenticated Buyer in GMT+7, When `POST /payments/intents` is called with **Idempot... | `GET /v1/wallets/me` | 201 | ✅ |
| AC-TELEMETRY-SLOS-02 | Given the same body/key is replayed within 24h, When calling again, Then the **original 201**... | `GET /v1/wallets/me/ledger-entries` | 201 | ✅ |
| AC-TELEMETRY-SLOS-03 | Given a valid intent, When `POST /payments/intents/{id}/confirm` is called, Then status trans... | `GET /v1/wallets/me` | 200 | ✅ |
| AC-TELEMETRY-SLOS-04 | Given a canceled or succeeded intent, When confirm is called, Then **409** `INVALID_STATE` is... | `GET /v1/wallets/me` | 409 | ✅ |
| AC-TELEMETRY-SLOS-05 | Given invalid params (e.g., `amount <= 0`, `currency` not in allowlist, `limit>200`), When th... | `GET /v1/quotas-limits` | 200, 422 | ✅ |
| AC-TELEMETRY-SLOS-06 | Given unauthenticated access or missing KYC badge for payouts, When requested, Then **401/403... | `GET /v1/wallets/me` | 401, 403 | ✅ |
| AC-TELEMETRY-SLOS-07 | Given a nonexistent resource (intent/payment/refund/payout/invoice), When requested, Then **4... | `GET /v1/invoices` | 404 | ✅ |
| AC-TELEMETRY-SLOS-08 | Given `POST /refunds` for a settled payment, When amount ≤ captured amount and within policy,... | `GET /v1/wallets/me` | 201, 409 | ✅ |
| AC-TELEMETRY-SLOS-09 | Given `POST /payouts` for a KYC-verified seller, When bank/wallet details pass validation, Th... | `GET /v1/wallets/me` | 201, 202 | ✅ |
| AC-TELEMETRY-SLOS-10 | Given inbound webhook `POST /webhooks/ingest` with invalid signature, When received, Then **4... | `GET /v1/wallets/me` | 200, 401 | ✅ |
| AC-TELEMETRY-SLOS-11 | Given provider or API rate limits, When exceeded, Then **429** with `Retry-After` is returned... | `GET /v1/quotas-limits` | 429 | ✅ |
| AC-TELEMETRY-SLOS-12 | Given backend 5xx or network errors, When client retries with same **Idempotency-Key**, Then ... | `GET /v1/wallets/me` | 200 | ✅ |