import { prisma } from '../prisma.js';

export async function processOutboxEvents() {
  const events = await prisma.outboxEvent.findMany({
    where: { status: 'PENDING' },
    orderBy: { createdAt: 'asc' },
    take: 50,
  });

  for (const event of events) {
    try {
      // Process event based on type
      await routeOutboxEvent(event);

      await prisma.outboxEvent.update({
        where: { id: event.id },
        data: { status: 'PROCESSED' },
      });
    } catch (err) {
      console.error(`Failed to process outbox event ${event.id}:`, err);
      await prisma.outboxEvent.update({
        where: { id: event.id },
        data: {
          status: 'FAILED',
          error: err.message,
        },
      });
    }
  }
}

async function routeOutboxEvent(event) {
  const { eventType, payload } = event;

  switch (eventType) {
    case 'stripe.payment.succeeded':
      console.log('Dispatching Stripe payment success actions...', payload);
      // Handled via the database transactions inside the finance/stays/plans modules.
      break;
    case 'booking.reservation.confirmed':
      console.log('Sending stay booking confirmation emails/push notifications...', payload);
      break;
    case 'trip.plan.announcement':
      console.log('Pushing announcement notifications to trip participants...', payload);
      break;
    case 'chat.message.notification':
      console.log('Sending mobile push notification for new message...', payload);
      break;
    default:
      console.warn(`Unhandled outbox event type: ${eventType}`);
  }
}

// Simple loop to run the outbox processor every 5 seconds
export function startOutboxWorker() {
  setInterval(async () => {
    try {
      await processOutboxEvents();
    } catch (err) {
      console.error('Outbox worker error:', err);
    }
  }, 5000);
  console.log('Outbox worker started.');
}

export default startOutboxWorker;
