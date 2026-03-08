const express = require('express');
const admin = require('firebase-admin');

const router = express.Router();

// POST /fcm/register
// Store/update FCM token for a user device
router.post('/register', async (req, res) => {
  try {
    const { token, deviceId } = req.body;
    const uid = req.user.uid;

    if (!token || typeof token !== 'string') {
      return res.status(400).json({ error: 'FCM token is required' });
    }

    if (!deviceId || typeof deviceId !== 'string') {
      return res.status(400).json({ error: 'deviceId is required' });
    }

    const db = admin.firestore();

    await db.collection('users').doc(uid).set({
      fcmTokens: {
        [deviceId]: {
          token,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
    }, { merge: true });

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('Error registering FCM token:', err);
    return res.status(500).json({ error: 'Failed to register FCM token' });
  }
});

module.exports = router;
