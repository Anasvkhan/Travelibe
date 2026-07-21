import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.join(__dirname, '../.env') });

export const config = {
  port: parseInt(process.env.PORT || '8000', 10),
  jwtSecret: process.env.JWT_SECRET || 'supersecretjwtkeytravelibe',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  stripePublishableKey: process.env.STRIPE_PUBLISHABLE_KEY || '',
  stripeSecretKey: process.env.STRIPE_SECRET_KEY || 'sk_test_stripe_secret_key_placeholder',
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET || 'whsec_placeholder',
  duffelApiKey: process.env.DUFFEL_API_KEY || 'duffel_test_key_placeholder',
  expediaApiKey: process.env.EXPEDIA_API_KEY || 'expedia_key_placeholder',
  expediaApiSecret: process.env.EXPEDIA_API_SECRET || 'expedia_secret_placeholder',
  awsS3Bucket: process.env.AWS_S3_BUCKET || 'travelibe-media-storage',
  awsRegion: process.env.AWS_REGION || 'us-east-1',
  awsAccessKeyId: process.env.AWS_ACCESS_KEY_ID || '',
  awsSecretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || '',
  smtpUser: process.env.SMTP_USER || 'anusag44@gmail.com',
  smtpPass: process.env.SMTP_PASS || 'kyjc ppou kpsz mlst',
};

export default config;
