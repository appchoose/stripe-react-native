import type { StripeError } from '.';

export type LinkPaymentMethod = {
  id: string;
  type: 'Card' | 'BankAccount' | 'Unknown';
  last4: string;
  isDefault: boolean;
  // Card specific
  brand?: string;
  expYear?: number;
  expMonth?: number;
  // Bank account specific
  bankName?: string;
};

export type LookupLinkConsumerResult =
  | {
      exists: true;
      consumerSessionClientSecret: string;
      redactedPhoneNumber: string;
      consumerAccountPublishableKey?: string;
      error?: undefined;
    }
  | { exists: false; error?: undefined }
  | { exists?: undefined; error: StripeError<string> };

export type StartLinkOTPVerificationParams = {
  consumerSessionClientSecret: string;
  consumerAccountPublishableKey?: string;
};

export type StartLinkOTPVerificationResult =
  | { error?: undefined }
  | { error: StripeError<string> };

export type ConfirmLinkOTPVerificationParams = {
  consumerSessionClientSecret: string;
  code: string;
  consumerAccountPublishableKey?: string;
};

export type ConfirmLinkOTPVerificationResult =
  | { consumerSessionClientSecret: string; error?: undefined }
  | { error: StripeError<string> };

export type ListLinkPaymentMethodsParams = {
  consumerSessionClientSecret: string;
  consumerAccountPublishableKey?: string;
};

export type ListLinkPaymentMethodsResult =
  | { paymentMethods: LinkPaymentMethod[]; error?: undefined }
  | { error: StripeError<string> };
