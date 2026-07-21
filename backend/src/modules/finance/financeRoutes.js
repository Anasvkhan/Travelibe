import { Router } from 'express';
import { FinanceService } from './financeService.js';
import { authenticateToken } from '../../common/middleware/auth.js';

const router = Router();

router.post('/connect-account', authenticateToken, async (req, res) => {
  try {
    const account = await FinanceService.createConnectedAccount(req.user.id);
    res.status(201).json(account);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/payment-intents', authenticateToken, async (req, res) => {
  try {
    const { amount, currency, paymentType } = req.body;
    const idempotencyKey = req.headers['idempotency-key'];

    if (!idempotencyKey) {
      return res.status(400).json({ error: 'Idempotency-Key request header is required for creating payments' });
    }

    const intent = await FinanceService.createPaymentIntent(req.user.id, {
      amount,
      currency,
      paymentType,
      idempotencyKey,
    });
    res.status(201).json(intent);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/ledger/:accountId', authenticateToken, async (req, res) => {
  try {
    // Only administrators or the account owner themselves can view ledger records
    if (req.user.role !== 'SUPERADMIN' && req.params.accountId !== req.user.id) {
      return res.status(403).json({ error: 'Access denied: unauthorized to view ledger' });
    }
    const balance = await FinanceService.getLedgerBalance(req.params.accountId);
    res.json(balance);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
