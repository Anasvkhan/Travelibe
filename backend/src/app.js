import express from 'express';
import cors from 'cors';
import { idempotencyMiddleware } from './common/middleware/idempotency.js';
import path from 'path';
import { fileURLToPath } from 'url';
import authRoutes from './modules/auth/authRoutes.js';
import feedRoutes from './modules/feed/feedRoutes.js';
import planRoutes from './modules/plans/planRoutes.js';
import flightRoutes from './modules/flights/flightsRoutes.js';
import staysRoutes from './modules/stays/staysRoutes.js';
import shopRoutes from './modules/shop/shopRoutes.js';
import financeRoutes from './modules/finance/financeRoutes.js';
import adminRoutes from './modules/admin/adminRoutes.js';
import uploadRoutes from './modules/upload/uploadRoutes.js';
import chatRoutes from './modules/chat/chatRoutes.js';
import notificationRoutes from './modules/notifications/notificationRoutes.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

app.use(cors());
app.use(express.json());

// Serve uploaded files statically
app.use('/uploads', express.static(path.join(__dirname, '../public/uploads')));

// Idempotency check applied on state changes
app.use(idempotencyMiddleware);

// API Routes mounting
app.use('/api/auth', authRoutes);
app.use('/api/feed', feedRoutes);
app.use('/api/plans', planRoutes);
app.use('/api/flights', flightRoutes);
app.use('/api/stays', staysRoutes);
app.use('/api/shop', shopRoutes);
app.use('/api/finance', financeRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/notifications', notificationRoutes);

// Base health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date() });
});

export default app;
