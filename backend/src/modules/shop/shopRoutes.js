import { Router } from 'express';
import { ShopService } from './shopService.js';
import { authenticateToken, requireRoles } from '../../common/middleware/auth.js';

const router = Router();

// Catalog management
router.post('/products', authenticateToken, requireRoles('SUPERADMIN'), async (req, res) => {
  try {
    const product = await ShopService.createProduct(req.body);
    res.status(201).json(product);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/products', authenticateToken, async (req, res) => {
  try {
    const products = await ShopService.getProducts(req.query);
    res.json(products);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.put('/products/:id', authenticateToken, requireRoles('SUPERADMIN'), async (req, res) => {
  try {
    const product = await ShopService.updateProduct(req.params.id, req.body);
    res.json(product);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete('/products/:id', authenticateToken, requireRoles('SUPERADMIN'), async (req, res) => {
  try {
    await ShopService.deleteProduct(req.params.id);
    res.json({ message: 'Product deleted successfully' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/orders', authenticateToken, async (req, res) => {
  try {
    const { items, shippingAddress } = req.body;
    if (!items || !shippingAddress) {
      return res.status(400).json({ error: 'items and shippingAddress fields are required' });
    }
    const order = await ShopService.checkoutOrder(req.user.id, { items, shippingAddress });
    res.status(201).json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Boost Campaigns
router.post('/boosts', authenticateToken, async (req, res) => {
  try {
    const { targetType, targetId, budgetCap, impressionPacing } = req.body;
    const campaign = await ShopService.createBoostCampaign({ targetType, targetId, budgetCap, impressionPacing });
    res.status(201).json(campaign);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/boosts/:id/impression', authenticateToken, async (req, res) => {
  try {
    const campaign = await ShopService.logBoostImpression(req.params.id);
    res.json(campaign);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
