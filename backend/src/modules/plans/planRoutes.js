import { Router } from 'express';
import { PlanService } from './planService.js';
import { authenticateToken } from '../../common/middleware/auth.js';

const router = Router();

router.post('/', authenticateToken, async (req, res) => {
  try {
    const plan = await PlanService.createPlan(req.user.id, req.body);
    res.status(201).json(plan);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/', authenticateToken, async (req, res) => {
  try {
    const { style, destination, minCost, maxCost } = req.query;
    const plans = await PlanService.getPlans({ style, destination, minCost, maxCost });
    res.json(plans);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/:id/join', authenticateToken, async (req, res) => {
  try {
    const { message } = req.body;
    const request = await PlanService.requestJoin(req.user.id, req.params.id, { message });
    res.status(201).json(request);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/:id/requests/:requestId/approve', authenticateToken, async (req, res) => {
  try {
    const { approve } = req.body; // boolean
    const participant = await PlanService.approveParticipant(req.user.id, req.params.id, req.params.requestId, approve);
    res.json(participant);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/:id/workspace', authenticateToken, async (req, res) => {
  try {
    const workspace = await PlanService.getWorkspace(req.user.id, req.params.id);
    res.json(workspace);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
