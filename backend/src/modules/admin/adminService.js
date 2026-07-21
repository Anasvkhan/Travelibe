import { prisma } from '../../prisma.js';

export class AdminService {
  // Flag content or user
  static async reportContent(reporterId, { targetType, targetId, reasonCode, details, evidenceUrl }) {
    return await prisma.report.create({
      data: {
        reporterId,
        targetType,
        targetId,
        reasonCode,
        details,
        evidenceUrl,
      },
    });
  }

  // Admin and Moderation operations
  static async getFlaggedQueue() {
    return await prisma.report.findMany({
      where: { status: 'PENDING' },
      orderBy: { createdAt: 'desc' },
      include: {
        reporter: {
          select: { id: true, profile: true },
        },
      },
    });
  }

  static async resolveReport(adminId, reportId, { action, notes }) {
    return await prisma.$transaction(async (tx) => {
      const report = await tx.report.findUnique({
        where: { id: reportId },
      });

      if (!report) throw new Error('Report queue record not found');

      // 1. Mark report as resolved
      const updatedReport = await tx.report.update({
        where: { id: reportId },
        data: {
          status: action === 'dismiss' ? 'DISMISSED' : 'RESOLVED',
          actionTaken: `${action.toUpperCase()}: ${notes}`,
        },
      });

      // 2. Perform target actions
      if (action === 'suspend_user') {
        const userId = report.targetType === 'USER' ? report.targetId : null;
        if (userId) {
          await tx.user.update({
            where: { id: userId },
            data: { status: 'SUSPENDED' },
          });
        }
      } else if (action === 'delete_post') {
        if (report.targetType === 'POST') {
          await tx.post.delete({
            where: { id: report.targetId },
          });
        }
      }

      // 3. Log administrator audit trail
      await tx.outboxEvent.create({
        data: {
          eventType: 'admin.audit.log',
          payload: { adminId, reportId, action, notes, targetId: report.targetId },
        },
      });

      return updatedReport;
    });
  }
}
export default AdminService;
