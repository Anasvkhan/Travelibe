import jwt from 'jsonwebtoken';
import { config } from '../../config.js';
import { prisma } from '../../prisma.js';

export async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, config.jwtSecret);
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: {
        id: true,
        email: true,
        phone: true,
        role: true,
        status: true,
        profile: true,
      },
    });

    if (!user) {
      return res.status(404).json({ error: 'User account not found' });
    }

    if (user.status === 'SUSPENDED') {
      return res.status(403).json({ error: 'User account suspended' });
    }

    req.user = user;
    next();
  } catch (err) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
}

// Role-Based Access Control Middleware
export function requireRoles(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthenticated user request' });
    }

    if (roles.indexOf(req.user.role) === -1) {
      return res.status(403).json({ error: 'Access denied: insufficient permission roles' });
    }

    next();
  };
}

export default authenticateToken;
