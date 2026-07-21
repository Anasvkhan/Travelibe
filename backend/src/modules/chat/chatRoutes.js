import { Router } from 'express';
import { ChatService } from './chatService.js';
import { authenticateToken } from '../../common/middleware/auth.js';

const router = Router();

router.post('/conversations', authenticateToken, async (req, res) => {
  try {
    const { targetUserId } = req.body;
    const conversation = await ChatService.getOrCreateConversation(req.user.id, targetUserId);
    res.status(201).json(conversation);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/conversations', authenticateToken, async (req, res) => {
  try {
    const conversations = await ChatService.getConversations(req.user.id);
    res.json(conversations);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/conversations/:id/messages', authenticateToken, async (req, res) => {
  try {
    const { limit, cursor } = req.query;
    const messages = await ChatService.getMessages(req.user.id, req.params.id, { limit, cursor });
    res.json(messages);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// User Search endpoint
router.get('/users/search', authenticateToken, async (req, res) => {
  try {
    const { q } = req.query;
    const users = await ChatService.searchUsers(q || '', req.user.id);
    res.json(users);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Connections Management endpoints
router.get('/connections', authenticateToken, async (req, res) => {
  try {
    const connections = await ChatService.getConnections(req.user.id);
    res.json(connections);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/connections/request', authenticateToken, async (req, res) => {
  try {
    const { receiverId } = req.body;
    const conversation = await ChatService.getOrCreateConversation(req.user.id, receiverId);
    res.status(201).json(conversation);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/connections/:id/accept', authenticateToken, async (req, res) => {
  try {
    const connection = await ChatService.acceptConnection(req.user.id, req.params.id);
    res.json({ message: 'Connection accepted successfully', connection });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/connections/:id/reject', authenticateToken, async (req, res) => {
  try {
    await ChatService.rejectConnection(req.user.id, req.params.id);
    res.json({ message: 'Connection rejected and removed successfully' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete('/conversations/:id', authenticateToken, async (req, res) => {
  try {
    await ChatService.deleteConversation(req.user.id, req.params.id);
    res.json({ message: 'Conversation deleted successfully' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
