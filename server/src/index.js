require('dotenv').config();
const express = require('express');
const cors = require('cors');
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

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/households', requireAuth, householdsRouter);
app.use('/households', requireAuth, contactsRouter);
app.use('/mail', requireAuth, mailRouter);
app.use('/fcm', requireAuth, fcmRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Pidgn server listening on port ${PORT}`);
});
