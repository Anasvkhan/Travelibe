import { Router } from 'express';
import { FlightsService } from './flightsService.js';
import { authenticateToken } from '../../common/middleware/auth.js';

const router = Router();

router.post('/search', authenticateToken, async (req, res) => {
  try {
    const { origin, destination, departureDate, returnDate, cabinClass, passengersCount } = req.body;
    const offers = await FlightsService.searchOffers(req.user.id, {
      origin,
      destination,
      departureDate,
      returnDate,
      cabinClass,
      passengersCount,
    });
    res.json(offers);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/offers/:id/reprice', authenticateToken, async (req, res) => {
  try {
    const quote = await FlightsService.repriceOffer(req.params.id);
    res.json(quote);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/orders', authenticateToken, async (req, res) => {
  try {
    const { offerId, passengers, paymentToken } = req.body;
    if (!offerId || !passengers) {
      return res.status(400).json({ error: 'offerId and passengers fields are required' });
    }
    const order = await FlightsService.createOrder(req.user.id, { offerId, passengers, paymentToken });
    res.status(201).json(order);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
