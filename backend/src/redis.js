import { createClient } from 'redis';
import { config } from './config.js';

export const redisClient = createClient({
  url: config.redisUrl,
});

redisClient.on('error', (err) => console.error('Redis Client Error', err));

export async function connectRedis() {
  if (!redisClient.isOpen) {
    try {
      await redisClient.connect();
      console.log('Connected to Redis at', config.redisUrl);
    } catch (err) {
      console.warn('Could not connect to Redis, caching/rate-limiting will fall back. Error:', err.message);
    }
  }
}

export default redisClient;
