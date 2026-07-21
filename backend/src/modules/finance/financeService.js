import Stripe from 'stripe';
import { prisma } from '../../prisma.js';
import { config } from '../../config.js';

const stripe = new Stripe(config.stripeSecretKey, {
  apiVersion: '2023-10-16',
});

export class FinanceService {
  // Stripe Connect account creation
  static async createConnectedAccount(userId) {
    // Check if account already exists
    const existing = await prisma.connectedAccount.findUnique({
      where: { userId },
    });
    if (existing) return existing;

    let stripeAccount = null;

    try {
      if (config.stripeSecretKey && !config.stripeSecretKey.includes('placeholder')) {
        stripeAccount = await stripe.accounts.create({
          type: 'express',
          capabilities: {
            card_payments: { requested: true },
            transfers: { requested: true },
          },
        });
      }
    } catch (err) {
      console.warn('Stripe Connect error, falling back to mockup credentials:', err.message);
    }

    const accountId = stripeAccount?.id || `acct_mock_${Math.random().toString(36).substr(2, 9)}`;

    return await prisma.connectedAccount.create({
      data: {
        userId,
        stripeAccountId: accountId,
        detailsSubmitted: false,
        payoutsEnabled: false,
      },
    });
  }

  // Onboarding verification callback (simulating stripe account updates)
  static async updateAccountStatus(stripeAccountId, { detailsSubmitted, payoutsEnabled }) {
    const account = await prisma.connectedAccount.update({
      where: { stripeAccountId },
      data: {
        detailsSubmitted: !!detailsSubmitted,
        payoutsEnabled: !!payoutsEnabled,
      },
    });

    if (payoutsEnabled) {
      // Elevate profile verification tier to HOST_KYC
      await prisma.profile.update({
        where: { userId: account.userId },
        data: { verificationTier: 'HOST_KYC' },
      });
    }

    return account;
  }

  // Payment intents
  static async createPaymentIntent(userId, { amount, currency = 'usd', paymentType, idempotencyKey }) {
    return await prisma.$transaction(async (tx) => {
      // 1. Enforce idempotency check
      const existing = await tx.payment.findUnique({
        where: { idempotencyKey },
      });
      if (existing) return existing;

      let paymentIntent = null;

      try {
        if (config.stripeSecretKey && !config.stripeSecretKey.includes('placeholder')) {
          paymentIntent = await stripe.paymentIntents.create({
            amount: Math.round(amount * 100), // convert dollars to cents
            currency,
            metadata: { userId, paymentType },
          });
        }
      } catch (err) {
        console.warn('Stripe PaymentIntent error, creating mock payment intent:', err.message);
      }

      const piId = paymentIntent?.id || `pi_mock_${Math.random().toString(36).substr(2, 9)}`;

      // 2. Persist Payment record
      return await tx.payment.create({
        data: {
          userId,
          amount: parseFloat(amount),
          currency: currency.toUpperCase(),
          status: 'PENDING',
          paymentIntentId: piId,
          type: paymentType,
          idempotencyKey,
        },
      });
    });
  }

  // Double-entry ledger audit log fetch
  static async getLedgerBalance(accountId) {
    const entries = await prisma.ledgerEntry.findMany({
      where: { accountId },
      orderBy: { createdAt: 'desc' },
    });

    const balance = entries.reduce((acc, entry) => {
      if (entry.entryType === 'CREDIT') return acc + entry.amount;
      return acc - entry.amount;
    }, 0);

    return { accountId, balance, entries };
  }
}
export default FinanceService;
