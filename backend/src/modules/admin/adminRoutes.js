import { Router } from 'express';
import { AdminService } from './adminService.js';
import { authenticateToken, requireRoles } from '../../common/middleware/auth.js';

const router = Router();

// Submit report endpoint (available to users)
router.post('/reports', authenticateToken, async (req, res) => {
  try {
    const { targetType, targetId, reasonCode, details, evidenceUrl } = req.body;
    const report = await AdminService.reportContent(req.user.id, { targetType, targetId, reasonCode, details, evidenceUrl });
    res.status(201).json(report);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Admin Queue management
router.get('/queue', authenticateToken, requireRoles('SUPERADMIN'), async (req, res) => {
  try {
    const queue = await AdminService.getFlaggedQueue();
    res.json(queue);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/queue/:reportId/resolve', authenticateToken, requireRoles('SUPERADMIN'), async (req, res) => {
  try {
    const { action, notes } = req.body;
    if (!action) return res.status(400).json({ error: 'action parameter is required' });
    const resolved = await AdminService.resolveReport(req.user.id, req.params.reportId, { action, notes });
    res.json(resolved);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
