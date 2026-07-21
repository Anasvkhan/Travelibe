import app from './app.js';
import { prisma } from './prisma.js';

async function runVerification() {
  console.log('--- TRAVELIBE SYSTEM INTEGRITY VERIFICATION ---');

  // 1. Verify app routes exist
  const routes = [];
  app._router.stack.forEach((middleware) => {
    if (middleware.route) {
      routes.push(`${Object.keys(middleware.route.methods).join(', ').toUpperCase()} ${middleware.route.path}`);
    } else if (middleware.name === 'router') {
      middleware.handle.stack.forEach((handler) => {
        if (handler.route) {
          routes.push(`${Object.keys(handler.route.methods).join(', ').toUpperCase()} ${middleware.regexp} => ${handler.route.path}`);
        }
      });
    }
  });

  console.log(`[App Routing] Found ${routes.length} active endpoints registered.`);

  // 2. Verify Database Ledger balancing constraint
  const ledgerEntries = await prisma.ledgerEntry.findMany();
  
  const balanceCheck = ledgerEntries.reduce((sum, entry) => {
    return sum + (entry.entryType === 'CREDIT' ? entry.amount : -entry.amount);
  }, 0);

  console.log(`[Ledger Double-Entry Constraint] Active ledger records: ${ledgerEntries.length}`);
  console.log(`[Ledger Net Balance] Total net double-entry offset: ${balanceCheck} USD (Should equal 0 if fully balanced)`);

  if (Math.abs(balanceCheck) < 0.001) {
    console.log('✅ Ledger constraints and double-entry offsets verified successfully.');
  } else {
    console.warn('⚠️ Ledger entries are currently imbalanced.');
  }

  // 3. Verification of Outbox Event Statuses
  const outboxCount = await prisma.outboxEvent.count();
  console.log(`[Transactional Outbox] Total outbox queue size: ${outboxCount}`);

  console.log('--- VERIFICATION COMPLETED ---');
}

runVerification()
  .catch((err) => console.error('Verification script failed:', err))
  .finally(() => prisma.$disconnect());
