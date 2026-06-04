import { Decimal } from '@prisma/client/runtime/library';

export function decimalToNumber(value: Decimal | null | undefined): number {
  if (value == null) return 0;
  return Number(value);
}

export function jsonRecord(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}
