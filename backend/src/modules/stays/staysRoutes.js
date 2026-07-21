import { Router } from 'express';
import { StaysService } from './staysService.js';
import { authenticateToken } from '../../common/middleware/auth.js';
import { prisma } from '../../prisma.js';
import { EmailService } from '../../common/services/emailService.js';

const router = Router();

// Host endpoints (Consolidated & CRUD)
router.post('/properties/consolidated', authenticateToken, async (req, res) => {
  try {
    const property = await StaysService.createConsolidatedProperty(req.user.id, req.body);
    res.status(201).json(property);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/admin/properties', authenticateToken, async (req, res) => {
  try {
    const properties = await StaysService.getAdminProperties();
    res.json(properties);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.put('/properties/:id', authenticateToken, async (req, res) => {
  try {
    const property = await StaysService.updateProperty(req.params.id, req.body);
    res.json(property);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.delete('/properties/:id', authenticateToken, async (req, res) => {
  try {
    await StaysService.deleteProperty(req.params.id);
    res.json({ message: 'Property deleted successfully' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Original individual Host endpoints
router.post('/properties', authenticateToken, async (req, res) => {
  try {
    const property = await StaysService.createProperty(req.user.id, req.body);
    res.status(201).json(property);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/properties/:id/units', authenticateToken, async (req, res) => {
  try {
    const unit = await StaysService.createPropertyUnit(req.params.id, req.body);
    res.status(201).json(unit);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.put('/units/:unitId/calendar', authenticateToken, async (req, res) => {
  try {
    const { date, startDate, endDate, availableCount, price } = req.body;
    if (startDate && endDate) {
      const results = await StaysService.updateInventoryCalendarRange(req.params.unitId, { startDate, endDate, availableCount, price });
      res.json(results);
    } else {
      const inventory = await StaysService.updateInventoryCalendar(req.params.unitId, { date, availableCount, price });
      res.json(inventory);
    }
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// Search & Booking endpoints
router.get('/search', authenticateToken, async (req, res) => {
  try {
    const { destination, checkIn, checkOut, guests } = req.query;
    if (!destination || !checkIn || !checkOut) {
      return res.status(400).json({ error: 'destination, checkIn and checkOut search params are required' });
    }
    const results = await StaysService.searchProperties({ destination, checkIn, checkOut, guests });
    res.json(results);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/reservations', authenticateToken, async (req, res) => {
  try {
    const { unitId, checkIn, checkOut } = req.body;
    const idempotencyKey = req.headers['idempotency-key'];

    if (!idempotencyKey) {
      return res.status(400).json({ error: 'Idempotency-Key request header is required for hotel bookings' });
    }

    const reservation = await StaysService.createReservation(req.user.id, {
      unitId,
      checkIn,
      checkOut,
      idempotencyKey,
    });

    // Send confirmation email to guest in background
    try {
      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
      });
      const unit = await prisma.propertyUnit.findUnique({
        where: { id: unitId },
        include: { property: true },
      });

      if (user && user.email && unit) {
        await EmailService.sendBookingConfirmationEmail(user.email, {
          propertyName: unit.property.name,
          checkIn,
          checkOut,
          amount: reservation.totalAmount,
        });
      }
    } catch (emailErr) {
      console.error('Failed to send booking confirmation email:', emailErr);
    }

    res.status(201).json(reservation);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
