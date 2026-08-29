const jwt = require('jsonwebtoken');
require('dotenv').config();
const db = require('../config/db');

const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    let token = authHeader && authHeader.split(' ')[1];

    if (!token && req.query.token) {
        token = req.query.token;
    }

    if (!token || token === 'null' || token === 'undefined') {
        return res.status(401).json({ message: 'Authentication token required' });
    }

    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.status(403).json({ message: 'Invalid or expired token' });

        try {
            const dbUser = db.prepare('SELECT id, username, role, is_active FROM users WHERE id = ?').get(user.id);
            if (!dbUser) {
                return res.status(401).json({ message: 'User account no longer exists.' });
            }
            if (dbUser.is_active === 0) {
                return res.status(403).json({
                    message: 'Your account has been deactivated. Access revoked.',
                    isDeactivated: true
                });
            }

            req.user = { ...user, role: dbUser.role, is_active: dbUser.is_active };
            next();
        } catch (dbErr) {
            return res.status(500).json({ message: 'Authentication verification error', error: dbErr.message });
        }
    });
};

const authorizeRoles = (...roles) => {
    return (req, res, next) => {
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({ message: 'Access denied: Insufficient permissions' });
        }
        next();
    };
};

module.exports = { authenticateToken, authorizeRoles };
