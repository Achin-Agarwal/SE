import { verifyToken } from '../utils/jwtFunct.js';

export default function checkAuth(requiredRole) {
  return (req, res, next) => {
    try {
      const authHeader = req.headers['authorization'];
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
          error: 'Missing or malformed token',
          code: 'UNAUTHORIZED',
        });
      }
      const token = authHeader.split(' ')[1];
      const payload = verifyToken(token);
      if (!payload || !payload.role) {
        return res.status(401).json({
          error: 'Invalid or expired token',
          code: 'UNAUTHORIZED',
        });
      }
      let normalizedRole;
      if (payload.role === 'admin') {
        normalizedRole = 'admin';
      } else if (payload.role === 'user') {
        normalizedRole = 'user';
      } else {
        normalizedRole = 'vendor';
      }
      const roleHierarchy = {
        admin: ['admin', 'vendor', 'user'],
        vendor: ['vendor'],
        user: ['user'],
      };
      if (requiredRole && !roleHierarchy[normalizedRole].includes(requiredRole)) {
        return res.status(403).json({
          error: 'Unauthorized access',
          code: 'FORBIDDEN',
        });
      }
      req.user = { ...payload, role: normalizedRole };
      next();
    } catch (err) {
      console.error('Auth error:', err);
      return res.status(500).json({
        error: 'Authentication failed',
        code: 'INTERNAL_ERROR',
      });
    }
  };
}
