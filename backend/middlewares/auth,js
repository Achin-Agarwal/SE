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

      if (!payload || !['vendor', 'user', 'admin'].includes(payload.role)) {
        return res.status(401).json({
          error: 'Invalid or expired token',
          code: 'UNAUTHORIZED',
        });
      }

      const roleHierarchy = {
        admin: ['admin', 'vendor', 'user'],
        vendor: ['vendor'],
        user: ['user'],
      };

      if (
        requiredRole &&
        !roleHierarchy[payload.role].includes(requiredRole)
      ) {
        return res.status(403).json({
          error: 'Unauthorized access',
          code: 'FORBIDDEN',
        });
      }

      req.user = payload;
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
