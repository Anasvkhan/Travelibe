import { prisma } from '../../prisma.js';
import { isUserOnline } from './chatGateway.js';

export class ChatService {
  static async getOrCreateConversation(userId, targetUserId) {
    // Check if conversation exists
    const existing = await prisma.conversation.findFirst({
      where: {
        type: 'ONE_TO_ONE',
        AND: [
          { members: { some: { userId } } },
          { members: { some: { userId: targetUserId } } },
        ],
      },
      include: {
        members: { include: { user: { select: { profile: true } } } },
      },
    });

    if (existing) return existing;

    // Check if connection exists, otherwise create it as PENDING
    let connection = await prisma.connection.findFirst({
      where: {
        OR: [
          { requesterId: userId, receiverId: targetUserId },
          { requesterId: targetUserId, receiverId: userId },
        ],
      },
    });

    if (!connection) {
      connection = await prisma.connection.create({
        data: {
          requesterId: userId,
          receiverId: targetUserId,
          status: 'PENDING',
        },
      });
    }

    return await prisma.conversation.create({
      data: {
        type: 'ONE_TO_ONE',
        members: {
          create: [
            { userId },
            { userId: targetUserId },
          ],
        },
      },
      include: {
        members: { include: { user: { select: { profile: true } } } },
      },
    });
  }

  static async saveMessage(senderId, conversationId, { text, messageType, attachments }) {
    // Check if user is a member of the conversation
    const member = await prisma.conversationMember.findUnique({
      where: {
        conversationId_userId: { conversationId, userId: senderId },
      },
    });

    if (!member) throw new Error('You are not a member of this conversation');

    // If sender sends a message, check connection. If it was PENDING and receiver is replying, auto-accept it!
    const members = await prisma.conversationMember.findMany({
      where: { conversationId },
    });
    const targetMember = members.find(m => m.userId !== senderId);

    if (targetMember) {
      const conn = await prisma.connection.findFirst({
        where: {
          OR: [
            { requesterId: senderId, receiverId: targetMember.userId },
            { requesterId: targetMember.userId, receiverId: senderId },
          ],
        },
      });

      // If receiver of connection is sending a message (replying), accept connection
      if (conn && conn.status === 'PENDING' && conn.receiverId === senderId) {
        await prisma.connection.update({
          where: { id: conn.id },
          data: { status: 'ACCEPTED' },
        });
      }
    }

    return await prisma.message.create({
      data: {
        conversationId,
        senderId,
        text,
        messageType: messageType || 'TEXT',
        attachments: {
          create: attachments?.map((att) => ({
            fileUrl: att.fileUrl,
            fileType: att.fileType,
            fileName: att.fileName,
            fileSize: att.fileSize,
          })) || [],
        },
      },
      include: {
        attachments: true,
      },
    });
  }

  static async getConversations(userId) {
    const conversations = await prisma.conversation.findMany({
      where: {
        members: { some: { userId } },
      },
      include: {
        members: {
          include: { user: { select: { id: true, profile: true } } },
        },
        messages: {
          take: 1,
          orderBy: { createdAt: 'desc' },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return conversations.map((conv) => {
      const formattedMembers = conv.members.map((m) => ({
        ...m,
        isOnline: isUserOnline(m.userId),
      }));
      return {
        ...conv,
        members: formattedMembers,
      };
    });
  }

  static async getMessages(userId, conversationId, { limit = 50, cursor } = {}) {
    const member = await prisma.conversationMember.findUnique({
      where: {
        conversationId_userId: { conversationId, userId },
      },
    });

    if (!member) throw new Error('Access denied: not a member');

    return await prisma.message.findMany({
      where: { conversationId },
      take: parseInt(limit, 10),
      orderBy: { createdAt: 'desc' },
      include: {
        attachments: true,
      },
    });
  }

  // Connection management services
  static async searchUsers(query, excludeUserId) {
    return await prisma.user.findMany({
      where: {
        id: { not: excludeUserId },
        OR: [
          { email: { contains: query, mode: 'insensitive' } },
          { profile: { displayName: { contains: query, mode: 'insensitive' } } },
          { profile: { handle: { contains: query, mode: 'insensitive' } } },
        ],
      },
      include: { profile: true },
    });
  }

  static async getConnections(userId) {
    return await prisma.connection.findMany({
      where: {
        OR: [
          { requesterId: userId },
          { receiverId: userId },
        ],
      },
      include: {
        requester: { include: { profile: true } },
        receiver: { include: { profile: true } },
      },
    });
  }

  static async acceptConnection(userId, connectionId) {
    const conn = await prisma.connection.findUnique({
      where: { id: connectionId },
    });

    if (!conn) throw new Error('Connection request not found');
    if (conn.receiverId !== userId) {
      throw new Error('Only the recipient of the connection can accept it');
    }

    return await prisma.connection.update({
      where: { id: connectionId },
      data: { status: 'ACCEPTED' },
    });
  }

  static async rejectConnection(userId, connectionId) {
    const conn = await prisma.connection.findUnique({
      where: { id: connectionId },
    });

    if (!conn) throw new Error('Connection request not found');
    if (conn.receiverId !== userId && conn.requesterId !== userId) {
      throw new Error('Unauthorized to reject connection');
    }

    // Create a mock outbox notification event if the receiver rejected the requester's invite
    if (conn.receiverId === userId) {
      await prisma.outboxEvent.create({
        data: {
          eventType: 'CONNECTION_REJECTED',
          payload: {
            requesterId: conn.requesterId,
            receiverId: conn.receiverId,
            message: 'Your connection request was rejected.',
          },
        },
      });
    }

    return await prisma.connection.delete({
      where: { id: connectionId },
    });
  }

  static async deleteConversation(userId, conversationId) {
    const member = await prisma.conversationMember.findUnique({
      where: {
        conversationId_userId: { conversationId, userId },
      },
    });
    if (!member) throw new Error('You are not a member of this conversation');

    const messages = await prisma.message.findMany({
      where: { conversationId },
      select: { id: true },
    });
    const messageIds = messages.map((m) => m.id);

    await prisma.messageAttachment.deleteMany({
      where: { messageId: { in: messageIds } },
    });
    await prisma.message.deleteMany({
      where: { conversationId },
    });
    await prisma.conversationMember.deleteMany({
      where: { conversationId },
    });
    return await prisma.conversation.delete({
      where: { id: conversationId },
    });
  }
}
