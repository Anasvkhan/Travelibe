import { redisClient } from '../../redis.js';
import { EmailService } from '../../common/services/emailService.js';

// In-memory fallback cache
const memoryCache = new Map();

export class OtpService {
  static generateOtp() {
    // Generate a secure 6-digit random number
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  static async sendAndSaveOtp(email) {
    const otp = this.generateOtp();
    const redisKey = `otp:${email.toLowerCase()}`;

    // Try storing in Redis first
    let storedInRedis = false;
    if (redisClient.isOpen) {
      try {
        await redisClient.set(redisKey, otp, {
          EX: 600, // 10 minutes TTL
        });
        storedInRedis = true;
      } catch (err) {
        console.warn('[OtpService] Failed to set OTP in Redis, falling back to memory. Error:', err.message);
      }
    }

    if (!storedInRedis) {
      // Fallback to memory cache
      memoryCache.set(email.toLowerCase(), {
        otp,
        expiresAt: Date.now() + 10 * 60 * 1000, // 10 minutes
      });
    }

    // Send the email in the background so it doesn't block the response
    EmailService.sendOtpEmail(email, otp)
      .then(() => console.log(`[OtpService] OTP email sent successfully to ${email}. Code: ${otp}`))
      .catch((err) => console.warn(`[OtpService] Failed to send real SMTP email. Code: ${otp}. Error:`, err.message));

    console.log(`\n=== DEVELOPMENT OTP CODE FOR ${email} IS: ${otp} ===\n`);
    return true;
  }

  static async verifyOtp(email, code) {
    const redisKey = `otp:${email.toLowerCase()}`;
    let savedOtp = null;

    // Try reading from Redis first
    let readFromRedis = false;
    if (redisClient.isOpen) {
      try {
        savedOtp = await redisClient.get(redisKey);
        readFromRedis = true;
      } catch (err) {
        console.warn('[OtpService] Failed to get OTP from Redis, falling back to memory. Error:', err.message);
      }
    }

    if (!readFromRedis) {
      // Fallback to memory cache
      const cached = memoryCache.get(email.toLowerCase());
      if (cached) {
        if (cached.expiresAt > Date.now()) {
          savedOtp = cached.otp;
        } else {
          memoryCache.delete(email.toLowerCase()); // Expired
        }
      }
    }

    if (!savedOtp) {
      throw new Error('OTP has expired or does not exist');
    }

    if (savedOtp !== code.trim()) {
      throw new Error('Invalid OTP code');
    }

    // Clean up
    if (redisClient.isOpen) {
      try {
        await redisClient.del(redisKey);
      } catch (err) {
        // Ignore delete errors
      }
    }
    memoryCache.delete(email.toLowerCase());

    return true;
  }
}

export default OtpService;
