const admin = require('firebase-admin');

const requireAuth = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or malformed Authorization header' });
  }

  const token = authHeader.split('Bearer ')[1];

  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.user = {
      uid: decoded.uid,
      email: decoded.email || null,
    };
    next();
  } catch (err) {
    console.error('Auth token verification failed:', err.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};

module.exports = { requireAuth };
