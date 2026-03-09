const express = require('express');
const admin = require('firebase-admin');

const router = express.Router();

// POST /users/profile
// Update the authenticated user's profile (plumage, crest, bio)
router.post('/profile', async (req, res) => {
  try {
    const uid = req.user.uid;
    const { plumage, crest, bio } = req.body;

    const validPlumages = ['terracotta', 'sage', 'slate', 'plum', 'midnight', 'ember'];
    const validCrests = ['dove', 'owl', 'robin', 'swan', 'eagle', 'feather'];

    const updates = {};

    if (plumage !== undefined) {
      updates.plumage = validPlumages.includes(plumage) ? plumage : 'terracotta';
    }

    if (crest !== undefined) {
      updates.crest = validCrests.includes(crest) ? crest : 'dove';
    }

    if (bio !== undefined) {
      if (typeof bio !== 'string') {
        return res.status(400).json({ error: 'Bio must be a string' });
      }
      updates.bio = bio.slice(0, 80);
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    const db = admin.firestore();
    await db.collection('users').doc(uid).update(updates);

    return res.status(200).json({ status: 'updated', ...updates });
  } catch (err) {
    console.error('Error updating profile:', err);
    return res.status(500).json({ error: 'Failed to update profile' });
  }
});

module.exports = router;
