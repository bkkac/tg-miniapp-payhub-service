import { z } from "zod";

/**
 * @see {@link #/components/schemas/ComplianceCheckCreate}
 */
export const ComplianceCheckCreateSchema = z.object({
  operation: z.enum(["deposit", "withdrawal", "transfer", "settlement"]).optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  destination: z.union([z.string(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/ComplianceCheckEnvelope}
 */
export const ComplianceCheckEnvelopeSchema = z.object({
  data: ComplianceVerdictSchema.optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/ComplianceVerdict}
 */
export const ComplianceVerdictSchema = z.object({
  verdict: z.enum(["ok", "risky", "blocked"]).optional(),
  reasons: z.array(z.string()).optional(),
  evaluatedAt: z.string().datetime().optional(),
});

/**
 * @see {@link #/components/schemas/Deposit}
 */
export const DepositSchema = z.object({
  id: z.string().optional(),
  method: z.string().optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  state: z.enum(["pending", "completed", "failed", "canceled"]).optional(),
  createdAt: z.string().datetime().optional(),
  updatedAt: z.string().datetime().optional(),
});

/**
 * @see {@link #/components/schemas/DepositCreate}
 */
export const DepositCreateSchema = z.object({
  method: z.enum(["onchain", "fiat"]).optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  chainId: z.union([z.string(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/DepositEnvelope}
 */
export const DepositEnvelopeSchema = z.object({
  data: DepositSchema.optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/DepositList}
 */
export const DepositListSchema = z.object({
  data: z.array(DepositSchema).optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
  total: z.union([z.number().int(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/Hold}
 */
export const HoldSchema = z.object({
  id: z.string().optional(),
  userId: z.string().optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  state: z.enum(["authorized", "captured", "released", "expired"]).optional(),
  reason: z.string().optional(),
  expiresAt: z.union([z.string().datetime(), z.any()]).optional(),
  createdAt: z.string().datetime().optional(),
  updatedAt: z.string().datetime().optional(),
});

/**
 * @see {@link #/components/schemas/HoldCreate}
 */
export const HoldCreateSchema = z.object({
  userId: z.string().optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  reason: z.string().optional(),
  ttlSeconds: z.number().int().optional(),
});

/**
 * @see {@link #/components/schemas/HoldEnvelope}
 */
export const HoldEnvelopeSchema = z.object({
  data: HoldSchema.optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/HoldList}
 */
export const HoldListSchema = z.object({
  data: z.array(HoldSchema).optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
  total: z.union([z.number().int(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/Invoice}
 */
export const InvoiceSchema = z.object({
  id: z.string().optional(),
  amount: z.number().optional(),
  currency: z.string().optional(),
  status: z.enum(["unpaid", "paid", "overdue"]).optional(),
  issuedAt: z.string().datetime().optional(),
});

/**
 * @see {@link #/components/schemas/InvoiceList}
 */
export const InvoiceListSchema = z.object({
  data: z.array(InvoiceSchema).optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
  total: z.union([z.number().int(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/LedgerEntry}
 */
export const LedgerEntrySchema = z.object({
  id: z.string().optional(),
  txId: z.string().optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  side: z.enum(["debit", "credit"]).optional(),
  account: z.string().optional(),
  counterAccount: z.string().optional(),
  refType: z.string().optional(),
  refId: z.string().optional(),
  occurredAt: z.string().datetime().optional(),
});

/**
 * @see {@link #/components/schemas/LedgerEntryList}
 */
export const LedgerEntryListSchema = z.object({
  data: z.array(LedgerEntrySchema).optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
  total: z.union([z.number().int(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/ProblemDetails}
 */
export const ProblemDetailsSchema = z.object({
  code: z.string(),
  message: z.string(),
  details: z.object({

}).optional(),
  traceId: z.string(),
});

/**
 * @see {@link #/components/schemas/QuotaLimits}
 */
export const QuotaLimitsSchema = z.object({
  quotas: z.object({

}).optional(),
  limits: z.object({

}).optional(),
  refreshedAt: z.string().datetime().optional(),
});

/**
 * @see {@link #/components/schemas/QuotaLimitsEnvelope}
 */
export const QuotaLimitsEnvelopeSchema = z.object({
  data: QuotaLimitsSchema.optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/RefundCreate}
 */
export const RefundCreateSchema = z.object({
  reason: z.enum(["void", "refund", "confiscate"]).optional(),
  amount: z.union([z.number(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/Settlement}
 */
export const SettlementSchema = z.object({
  id: z.string().optional(),
  type: z.enum(["capture", "payout", "refund"]).optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  state: z.enum(["created", "captured", "refunded", "failed"]).optional(),
  holdId: z.union([z.string(), z.any()]).optional(),
  settlementRef: z.union([z.string(), z.any()]).optional(),
  createdAt: z.string().datetime().optional(),
  updatedAt: z.string().datetime().optional(),
});

/**
 * @see {@link #/components/schemas/SettlementCreate}
 */
export const SettlementCreateSchema = z.object({
  settlementRef: z.string().optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  payerAccount: z.string().optional(),
  payeeAccount: z.string().optional(),
  type: z.enum(["capture", "payout"]).optional(),
});

/**
 * @see {@link #/components/schemas/SettlementEnvelope}
 */
export const SettlementEnvelopeSchema = z.object({
  data: SettlementSchema.optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/Transfer}
 */
export const TransferSchema = z.object({
  id: z.string().optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  fromAccount: z.string().optional(),
  toAccount: z.string().optional(),
  state: z.enum(["created", "posted", "failed"]).optional(),
  createdAt: z.string().datetime().optional(),
  updatedAt: z.string().datetime().optional(),
});

/**
 * @see {@link #/components/schemas/TransferCreate}
 */
export const TransferCreateSchema = z.object({
  fromAccount: z.string().optional(),
  toAccount: z.string().optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  reason: z.string().optional(),
});

/**
 * @see {@link #/components/schemas/TransferEnvelope}
 */
export const TransferEnvelopeSchema = z.object({
  data: TransferSchema.optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/Wallet}
 */
export const WalletSchema = z.object({
  userId: z.string().optional(),
  balances: z.array(z.object({
  asset: z.string().optional(),
  free: z.number().optional(),
  locked: z.number().optional(),
})).optional(),
  limits: z.object({
  dailyWithdrawUsd: z.number().optional(),
  remainingWithdrawUsd: z.number().optional(),
  tier: z.string().optional(),
}).optional(),
  updatedAt: z.string().datetime().optional(),
});

/**
 * @see {@link #/components/schemas/WalletEnvelope}
 */
export const WalletEnvelopeSchema = z.object({
  data: WalletSchema.optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/Withdrawal}
 */
export const WithdrawalSchema = z.object({
  id: z.string().optional(),
  method: z.string().optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  fee: z.number().optional(),
  state: z.enum(["pending", "submitting", "completed", "failed", "canceled"]).optional(),
  createdAt: z.string().datetime().optional(),
  updatedAt: z.string().datetime().optional(),
});

/**
 * @see {@link #/components/schemas/WithdrawalCreate}
 */
export const WithdrawalCreateSchema = z.object({
  method: z.enum(["onchain", "fiat"]).optional(),
  asset: z.string().optional(),
  amount: z.number().optional(),
  destination: z.string().optional(),
});

/**
 * @see {@link #/components/schemas/WithdrawalEnvelope}
 */
export const WithdrawalEnvelopeSchema = z.object({
  data: WithdrawalSchema.optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
});

/**
 * @see {@link #/components/schemas/WithdrawalList}
 */
export const WithdrawalListSchema = z.object({
  data: z.array(WithdrawalSchema).optional(),
  nextCursor: z.union([z.string(), z.any()]).optional(),
  total: z.union([z.number().int(), z.any()]).optional(),
});


export const Schemas = {
  ComplianceCheckCreate: ComplianceCheckCreateSchema,
  ComplianceCheckEnvelope: ComplianceCheckEnvelopeSchema,
  ComplianceVerdict: ComplianceVerdictSchema,
  Deposit: DepositSchema,
  DepositCreate: DepositCreateSchema,
  DepositEnvelope: DepositEnvelopeSchema,
  DepositList: DepositListSchema,
  Hold: HoldSchema,
  HoldCreate: HoldCreateSchema,
  HoldEnvelope: HoldEnvelopeSchema,
  HoldList: HoldListSchema,
  Invoice: InvoiceSchema,
  InvoiceList: InvoiceListSchema,
  LedgerEntry: LedgerEntrySchema,
  LedgerEntryList: LedgerEntryListSchema,
  ProblemDetails: ProblemDetailsSchema,
  QuotaLimits: QuotaLimitsSchema,
  QuotaLimitsEnvelope: QuotaLimitsEnvelopeSchema,
  RefundCreate: RefundCreateSchema,
  Settlement: SettlementSchema,
  SettlementCreate: SettlementCreateSchema,
  SettlementEnvelope: SettlementEnvelopeSchema,
  Transfer: TransferSchema,
  TransferCreate: TransferCreateSchema,
  TransferEnvelope: TransferEnvelopeSchema,
  Wallet: WalletSchema,
  WalletEnvelope: WalletEnvelopeSchema,
  Withdrawal: WithdrawalSchema,
  WithdrawalCreate: WithdrawalCreateSchema,
  WithdrawalEnvelope: WithdrawalEnvelopeSchema,
  WithdrawalList: WithdrawalListSchema
} as const;
