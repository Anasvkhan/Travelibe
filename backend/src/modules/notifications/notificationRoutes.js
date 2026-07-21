import { Router } from 'express';
import { NotificationService } from './notificationService.js';
import { authenticateToken } from '../../common/middleware/auth.js';

const router = Router();

// Get user notifications
router.get('/', authenticateToken, async (req, res) => {
  try {
    const notifications = await NotificationService.getNotifications(req.user.id);
    res.json(notifications);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Mark all as read
router.post('/read-all', authenticateToken, async (req, res) => {
  try {
    await NotificationService.markAllAsRead(req.user.id);
    res.json({ message: 'All notifications marked as read' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Mark single as read
router.patch('/:id/read', authenticateToken, async (req, res) => {
  try {
    await NotificationService.markAsRead(req.user.id, req.params.id);
    res.json({ message: 'Notification marked as read' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
