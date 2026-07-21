import { prisma } from '../../prisma.js';

export class NotificationService {
  static async createNotification({ userId, actorId, type, title, message, targetId }) {
    if (userId === actorId) return null; // Don't notify self
    try {
      return await prisma.notification.create({
        data: {
          userId,
          actorId,
          type,
          title,
          message,
          targetId,
        },
      });
    } catch (e) {
      console.error('[createNotification] Error:', e);
      return null;
    }
  }

  static async getNotifications(userId) {
    return await prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: {
        actor: {
          select: {
            id: true,
            email: true,
            profile: true,
          },
        },
      },
    });
  }

  static async markAllAsRead(userId) {
    return await prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
  }

  static async markAsRead(userId, notificationId) {
    return await prisma.notification.updateMany({
      where: { id: notificationId, userId },
      data: { isRead: true },
    });
  }
}
