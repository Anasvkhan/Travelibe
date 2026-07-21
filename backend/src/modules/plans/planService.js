import { prisma } from '../../prisma.js';

export class PlanService {
  static async createPlan(organizerId, planData) {
    const { title, details, destinations, dates, travelStyle, capacity, estimatedCost, organizerRules, depositPolicy, itinerary, imageUrl } = planData;

    return await prisma.$transaction(async (tx) => {
      // 1. Create the plan
      const plan = await tx.tripPlan.create({
        data: {
          organizerId,
          title,
          details,
          imageUrl,
          destinations,
          dates,
          travelStyle,
          capacity: parseInt(capacity, 10),
          estimatedCost: parseFloat(estimatedCost),
          organizerRules,
        },
      });

      // 2. Create the deposit policy if specified
      if (depositPolicy) {
        await tx.depositPolicy.create({
          data: {
            tripPlanId: plan.id,
            type: depositPolicy.type || 'NONE',
            amount: parseFloat(depositPolicy.amount || 0),
            refundTerms: depositPolicy.refundTerms,
          },
        });
      }

      // 3. Create the itinerary items if specified
      if (Array.isArray(itinerary)) {
        await tx.itineraryItem.createMany({
          data: itinerary.map((item) => ({
            tripPlanId: plan.id,
            dayIndex: parseInt(item.dayIndex || 0, 10),
            timeOffset: item.timeOffset,
            title: item.title,
            description: item.description,
            location: item.location,
            cost: item.cost ? parseFloat(item.cost) : null,
          })),
        });
      }

      // 4. Add the organizer as a participant automatically
      await tx.participant.create({
        data: {
          tripPlanId: plan.id,
          userId: organizerId,
          role: 'ORGANIZER',
          status: 'ACTIVE',
        },
      });

      return await tx.tripPlan.findUnique({
        where: { id: plan.id },
        include: {
          depositPolicy: true,
          itinerary: true,
          participants: {
            include: { user: { select: { profile: true } } },
          },
        },
      });
    },
    {
      maxWait: 5000,
      timeout: 15000,
    });
  }

  static async getPlans({ style, destination, minCost, maxCost } = {}) {
    const filter = { status: 'ACTIVE' };

    if (style) filter.travelStyle = style;
    if (minCost || maxCost) {
      filter.estimatedCost = {};
      if (minCost) filter.estimatedCost.gte = parseFloat(minCost);
      if (maxCost) filter.estimatedCost.lte = parseFloat(maxCost);
    }

    const plans = await prisma.tripPlan.findMany({
      where: filter,
      include: {
        depositPolicy: true,
        participants: {
          include: {
            user: { select: { id: true, email: true, profile: true } },
          },
        },
        organizer: {
          select: { id: true, profile: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Simple text search filter for destinations
    if (destination) {
      const destLower = destination.toLowerCase();
      return plans.filter((plan) => {
        try {
          const dests = plan.destinations;
          return JSON.stringify(dests).toLowerCase().includes(destLower);
        } catch {
          return false;
        }
      });
    }

    return plans;
  }

  static async requestJoin(userId, planId, { message }) {
    return await prisma.$transaction(async (tx) => {
      const plan = await tx.tripPlan.findUnique({
        where: { id: planId },
        include: { depositPolicy: true, participants: true },
      });

      if (!plan) throw new Error('Trip plan not found');
      if (plan.status !== 'ACTIVE') throw new Error('Trip plan is no longer active');
      
      const activeParticipants = plan.participants.filter((p) => p.status === 'ACTIVE');
      if (activeParticipants.length >= plan.capacity) {
        throw new Error('Trip plan has reached capacity');
      }

      // Check if user is already a participant
      const existingParticipant = await tx.participant.findFirst({
        where: { tripPlanId: planId, userId, status: 'ACTIVE' },
      });
      if (existingParticipant) throw new Error('You have already joined this trip');

      // Create Active Participant directly upon deposit payment
      await tx.participant.create({
        data: {
          tripPlanId: planId,
          userId,
          role: 'MEMBER',
          status: 'ACTIVE',
        },
      });

      // Also record join request as APPROVED
      const hasDeposit = plan.depositPolicy && plan.depositPolicy.type !== 'NONE' && plan.depositPolicy.amount > 0;
      const depositAmount = hasDeposit ? (plan.estimatedCost * (plan.depositPolicy.amount / 100)) : 0;
      
      return await tx.joinRequest.create({
        data: {
          tripPlanId: planId,
          userId,
          message: message || 'Paid deposit and joined trip',
          depositPaidAmount: depositAmount,
          status: 'APPROVED',
        },
      });
    });
  }

  static async approveParticipant(organizerId, planId, requestId, approve = true) {
    return await prisma.$transaction(async (tx) => {
      const plan = await tx.tripPlan.findUnique({
        where: { id: planId },
      });

      if (!plan) throw new Error('Trip plan not found');
      if (plan.organizerId !== organizerId) {
        throw new Error('Unauthorized: Only the trip organizer can approve join requests');
      }

      const request = await tx.joinRequest.findUnique({
        where: { id: requestId },
      });

      if (!request || request.tripPlanId !== planId) {
        throw new Error('Join request not found for this trip');
      }

      if (request.status !== 'PENDING' && request.status !== 'PAID_PENDING_APPROVAL') {
        throw new Error('Join request has already been processed');
      }

      if (!approve) {
        return await tx.joinRequest.update({
          where: { id: requestId },
          data: { status: 'REJECTED' },
        });
      }

      // Update request to APPROVED
      await tx.joinRequest.update({
        where: { id: requestId },
        data: { status: 'APPROVED' },
      });

      // Add to participants list
      return await tx.participant.create({
        data: {
          tripPlanId: planId,
          userId: request.userId,
          role: 'MEMBER',
          status: 'ACTIVE',
        },
      });
    });
  }

  static async getWorkspace(userId, planId) {
    const plan = await prisma.tripPlan.findUnique({
      where: { id: planId },
      include: {
        depositPolicy: true,
        itinerary: true,
        participants: {
          include: { user: { select: { profile: true } } },
        },
        joinRequests: {
          include: { user: { select: { profile: true } } },
        },
      },
    });

    if (!plan) throw new Error('Trip plan not found');

    const isMember = plan.participants.some((p) => p.userId === userId && p.status === 'ACTIVE');
    if (!isMember) {
      throw new Error('Access denied: You must be a confirmed participant to view the workspace');
    }

    return plan;
  }
}
