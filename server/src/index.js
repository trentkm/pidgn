require('dotenv').config();
const path = require('path');
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const admin = require('firebase-admin');

if (process.env.FIREBASE_PROJECT_ID) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
} else {
  console.warn('Firebase credentials not configured — running without Firebase');
}

const { requireAuth } = require('./middleware/auth');
const householdsRouter = require('./routes/households');
const contactsRouter = require('./routes/contacts');
const mailRouter = require('./routes/mail');
const fcmRouter = require('./routes/fcm');
const usersRouter = require('./routes/users');

const app = express();

// Trust Railway's proxy for accurate IP-based rate limiting
app.set('trust proxy', 1);

app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Global rate limit: 100 requests per minute per IP
const globalLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
});
app.use(globalLimiter);

// Stricter limit for write endpoints: 20 per minute
const writeLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please slow down.' },
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/households', requireAuth, householdsRouter);
app.use('/households', requireAuth, contactsRouter);
app.use('/mail', requireAuth, writeLimiter, mailRouter);
app.use('/fcm', requireAuth, fcmRouter);
app.use('/users', requireAuth, usersRouter);

// Serve static web files (AASA, privacy policy, fallback pages)
const webRoot = path.join(__dirname, '..', '..', 'web');
app.use('/.well-known', express.static(path.join(webRoot, '.well-known')));
app.get('/privacy', (req, res) => {
  res.sendFile(path.join(webRoot, 'privacy.html'));
});
app.get('/open', (req, res) => {
  res.sendFile(path.join(webRoot, 'open.html'));
});
app.get('/', (req, res) => {
  res.sendFile(path.join(webRoot, 'index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Pidgn server listening on port ${PORT}`);
});
