import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { prisma } from '../../prisma.js';
import { config } from '../../config.js';
import { OtpService } from './otpService.js';

export class AuthService {
  static async signUp({ email, username, password }) {
    if (!email) {
      throw new Error('Email is required');
    }
    if (!username) {
      throw new Error('Username is required');
    }
    if (!password) {
      throw new Error('Password is required');
    }

    // Basic email format validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new Error('Invalid email format');
    }

    // Basic username format validation
    const usernameRegex = /^[a-zA-Z0-9_]{3,30}$/;
    if (!usernameRegex.test(username)) {
      throw new Error('Username must be 3-30 characters long and contain only letters, numbers, or underscores');
    }

    if (password.length < 6) {
      throw new Error('Password must be at least 6 characters long');
    }

    // Check if email already exists
    const existingUser = await prisma.user.findFirst({
      where: { email: { equals: email, mode: 'insensitive' } },
      include: { profile: true },
    });
    if (existingUser) {
      if (existingUser.profile && existingUser.profile.verificationTier === 'UNVERIFIED') {
        // Send verification code again and return message to verify
        await OtpService.sendAndSaveOtp(email);
        return { user: existingUser, message: 'Verification OTP code sent to your email.' };
      }
      throw new Error('Email already registered');
    }

    // Check if handle already exists
    const existingProfile = await prisma.profile.findFirst({
      where: { handle: { equals: username, mode: 'insensitive' } },
    });
    if (existingProfile) {
      throw new Error('Username is already taken');
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        profile: {
          create: {
            handle: username,
            displayName: username,
          },
        },
      },
      include: {
        profile: true,
      },
    });

    // Send verification code automatically on sign up
    await OtpService.sendAndSaveOtp(email);

    return { user, message: 'Verification OTP code sent to your email.' };
  }

  static async login({ email, password }) {
    if (!email) {
      throw new Error('Email is required');
    }
    if (!password) {
      throw new Error('Password is required');
    }

    const user = await prisma.user.findFirst({
      where: { email: { equals: email, mode: 'insensitive' } },
      include: {
        profile: true,
      },
    });

    if (!user) {
      throw new Error('Invalid email or password');
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      throw new Error('Invalid email or password');
    }

    if (user.status === 'SUSPENDED') {
      throw new Error('Your account has been suspended');
    }

    if (user.profile && user.profile.verificationTier === 'UNVERIFIED') {
      throw new Error('Please verify your email before logging in');
    }

    const token = jwt.sign({ userId: user.id, role: user.role }, config.jwtSecret, {
      expiresIn: '7d',
    });

    return { user, token };
  }

  static async verifyEmailOtp(email, code) {
    if (!email) {
      throw new Error('Email is required');
    }
    if (!code) {
      throw new Error('Verification code is required');
    }

    // 1. Verify code via OtpService
    await OtpService.verifyOtp(email, code);

    // 2. Find user
    const user = await prisma.user.findFirst({
      where: { email: { equals: email, mode: 'insensitive' } },
    });
    if (!user) {
      throw new Error('User account not found');
    }

    // 3. Update profile to EMAIL_PHONE tier
    await prisma.profile.update({
      where: { userId: user.id },
      data: { verificationTier: 'EMAIL_PHONE' },
    });

    // 4. Create/Upsert verification log
    await prisma.verification.create({
      data: {
        userId: user.id,
        type: 'EMAIL',
        status: 'APPROVED',
        verifiedAt: new Date(),
      },
    });

    return { message: 'Email verified successfully' };
  }

  static async getProfile(userId) {
    const profile = await prisma.profile.findUnique({
      where: { userId },
      include: {
        user: { select: { email: true } },
      },
    });
    if (!profile) throw new Error('Profile not found');
    return {
      ...profile,
      email: profile.user?.email,
    };
  }

  static async updateProfile(userId, updateData) {
    const { handle, displayName, avatarUrl, backgroundUrl, homeLocation, languages, travelInterests, preferredStyles, isPublic, aboutMe } = updateData;

    return await prisma.profile.update({
      where: { userId },
      data: {
        handle,
        displayName,
        avatarUrl,
        backgroundUrl,
        homeLocation,
        languages,
        travelInterests,
        preferredStyles,
        isPublic,
        aboutMe,
      },
    });
  }

  static async getRecommendations(userId, hashedContacts) {
    const allUsers = await prisma.user.findMany({
      where: {
        id: { not: userId },
        email: { not: null },
      },
      include: {
        profile: true,
      },
    });

    // Match based on hashed emails instead of phone numbers
    const matchingUsers = allUsers.filter((u) => {
      const hash = crypto.createHash('sha256').update(u.email).digest('hex');
      return hashedContacts.includes(hash);
    });

    return matchingUsers.map((u) => u.profile).filter(Boolean);
  }
}

export default AuthService;
