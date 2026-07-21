import { PlanService } from './src/modules/plans/planService.js';
import { prisma } from './src/prisma.js';

async function testPost() {
  try {
    const user = await prisma.user.findFirst();
    if (!user) throw new Error("No user found");

    console.log("Found user", user.id);

    const plan = await PlanService.createPlan(user.id, {
      title: 'Test Plan',
      details: 'Test Details',
      destinations: ['Test Destination'],
      dates: { start: '2026-10-10T00:00:00.000Z', end: '2026-10-17T00:00:00.000Z' },
      travelStyle: 'ECONOMY',
      capacity: 8,
      estimatedCost: 1200,
      imageUrl: 'http://example.com/image.jpg',
      depositPolicy: { type: 'PERCENTAGE', amount: 10, refundTerms: '100% refund up to 14 days before' }
    });

    console.log('Success:', plan);
  } catch (err) {
    console.error('Error:', err);
  } finally {
    await prisma.$disconnect();
  }
}

testPost();
