import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import { config } from '../../config.js';
import { ChatService } from './chatService.js';
import { prisma } from '../../prisma.js';

// Simple in-memory map of active socket connections: userId -> socketId
const userSocketMap = new Map();

export function initChatGateway(server) {
  const io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
  });

  // Socket Auth Middleware
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) {
      return next(new Error('Authentication token required'));
    }

    try {
      const decoded = jwt.verify(token, config.jwtSecret);
      socket.userId = decoded.userId;
      next();
    } catch (err) {
      return next(new Error('Invalid authentication token'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.userId;
    userSocketMap.set(userId, socket.id);
    console.log(`User connected to chat WS: ${userId} (${socket.id})`);

    // Broadcast online status to connections
    await broadcastStatus(io, userId, 'online');

    // Join conversation rooms
    const conversations = await prisma.conversation.findMany({
      where: { members: { some: { userId } } },
    });
    conversations.forEach((conv) => {
      socket.join(conv.id);
    });

    // Handle incoming chat message
    socket.on('send_message', async (data, callback) => {
      const { conversationId, text, messageType, attachments } = data;

      try {
        const savedMessage = await ChatService.saveMessage(userId, conversationId, {
          text,
          messageType,
          attachments,
        });

        // Emit message to the conversation room
        io.to(conversationId).emit('new_message', savedMessage);

        // Update conversation timestamp
        await prisma.conversation.update({
          where: { id: conversationId },
          data: { updatedAt: new Date() },
        });

        if (callback) callback({ success: true, message: savedMessage });
      } catch (err) {
        console.error('Error sending message via WS:', err);
        if (callback) callback({ error: err.message });
      }
    });

    // Handle typing indicator
    socket.on('typing', ({ conversationId, isTyping }) => {
      socket.to(conversationId).emit('user_typing', { userId, isTyping });
    });

    // Handle read receipt
    socket.on('read_message', async ({ conversationId, messageId }) => {
      try {
        await prisma.conversationMember.update({
          where: { conversationId_userId: { conversationId, userId } },
          data: { lastReadMessageId: messageId },
        });
        socket.to(conversationId).emit('message_read', { userId, conversationId, messageId });
      } catch (err) {
        console.error('Failed to save read receipt:', err);
      }
    });

    socket.on('disconnect', async () => {
      userSocketMap.delete(userId);
      console.log(`User disconnected from chat WS: ${userId}`);
      await broadcastStatus(io, userId, 'offline');
    });
  });

  return io;
}

export function isUserOnline(userId) {
  return userSocketMap.has(userId);
}

async function broadcastStatus(io, userId, status) {
  try {
    await prisma.device.updateMany({
      where: { userId },
      data: { lastActive: new Date() },
    }).catch(() => {});

    const connections = await prisma.connection.findMany({
      where: {
        OR: [
          { requesterId: userId, status: 'ACCEPTED' },
          { receiverId: userId, status: 'ACCEPTED' },
        ],
      },
    });

    connections.forEach((conn) => {
      const targetUserId = conn.requesterId === userId ? conn.receiverId : conn.requesterId;
      const targetSocketId = userSocketMap.get(targetUserId);
      if (targetSocketId) {
        io.to(targetSocketId).emit('presence_update', { userId, status, timestamp: new Date() });
      }
    });
  } catch (e) {
    console.error('Error in broadcastStatus:', e);
  }
}
export default initChatGateway;
