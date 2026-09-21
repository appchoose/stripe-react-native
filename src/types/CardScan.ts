import type { StripeError } from './Errors';

/** Card details recognized by the device camera. The CVC is never scanned. */
export type ScannedCard = {
  /** The full primary account number (PAN). Treat this value as sensitive. */
  number: string;
  expiryMonth?: number;
  expiryYear?: number;
  /** Currently available on iOS only. */
  name?: string;
};

export enum CardScanError {
  Failed = 'Failed',
  NotSupported = 'NotSupported',
  AlreadyInProgress = 'AlreadyInProgress',
}

export type CardScanResult =
  | {
      status: 'completed';
      card: ScannedCard;
    }
  | {
      status: 'canceled';
    }
  | {
      status: 'failed';
      error: StripeError<CardScanError>;
    };
