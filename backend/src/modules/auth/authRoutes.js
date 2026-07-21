import { Router } from 'express';
import { AuthService } from './authService.js';
import { OtpService } from './otpService.js';
import { authenticateToken } from '../../common/middleware/auth.js';

const router = Router();

router.post('/signup', async (req, res) => {
  try {
    const { email, username, password } = req.body;
    const result = await AuthService.signUp({ email, username, password });
    res.status(201).json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const result = await AuthService.login({ email, password });
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// OTP Verification endpoints
router.post('/send-otp', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email parameter is required' });
    }
    await OtpService.sendAndSaveOtp(email);
    res.json({ message: 'Verification code sent to your email successfully.' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/verify-otp', async (req, res) => {
  try {
    const { email, code } = req.body;
    const result = await AuthService.verifyEmailOtp(email, code);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const result = await AuthService.getProfile(req.user.id);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.put('/profile', authenticateToken, async (req, res) => {
  try {
    const result = await AuthService.updateProfile(req.user.id, req.body);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

router.post('/recommendations', authenticateToken, async (req, res) => {
  try {
    const { hashedContacts } = req.body; // Array of SHA256 hashed email addresses
    if (!Array.isArray(hashedContacts)) {
      return res.status(400).json({ error: 'hashedContacts must be an array' });
    }
    const result = await AuthService.getRecommendations(req.user.id, hashedContacts);
    res.json(result);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

export default router;
