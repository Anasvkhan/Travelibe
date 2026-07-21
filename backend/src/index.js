import http from 'http';
import app from './app.js';
import { config } from './config.js';
import { connectRedis } from './redis.js';
import { prisma } from './prisma.js';
import { initChatGateway } from './modules/chat/chatGateway.js';
import { startOutboxWorker } from './common/outbox.js';
import { FeedService } from './modules/feed/feedService.js';

const server = http.createServer(app);

// Initialize Chat WS server
initChatGateway(server);

// Start transactional outbox handler
startOutboxWorker();

// Simple cron alternative: Run expired stories purge job every hour
setInterval(async () => {
  try {
    await FeedService.purgeExpiredStories();
  } catch (err) {
    console.error('Stories purge job failed:', err);
  }
}, 60 * 60 * 1000);

async function startServer() {
  // Connect to Redis
  await connectRedis();

  // Connect to PostgreSQL
  try {
    await prisma.$connect();
    console.log('connected to postgresql');
  } catch (err) {
    console.error('Failed to connect to postgresql:', err);
    throw err;
  }

  server.listen(config.port, () => {
    console.log(`[Travelibe] Server running on port ${config.port}`);
  });
}

startServer().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
