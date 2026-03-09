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

    if (req.body.avatarUrl !== undefined) {
      const { avatarUrl } = req.body;
      if (avatarUrl === null || avatarUrl === '') {
        updates.avatarUrl = null;
      } else if (typeof avatarUrl === 'string' && avatarUrl.startsWith('https://')) {
        updates.avatarUrl = avatarUrl;
      } else {
        return res.status(400).json({ error: 'avatarUrl must be an https URL or null' });
      }
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

// GET /users/stats
// Fetch letter counts and flock size for the authenticated user
router.get('/stats', async (req, res) => {
  try {
    const uid = req.user.uid;
    const db = admin.firestore();

    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }

    const householdId = userDoc.data().householdId;
    if (!householdId) {
      return res.status(200).json({ lettersSent: 0, lettersReceived: 0, flockMembers: 0 });
    }

    // Fetch household doc and mailbox in parallel
    const [householdDoc, receivedSnap] = await Promise.all([
      db.collection('households').doc(householdId).get(),
      db.collection('households').doc(householdId)
        .collection('mailbox').get(),
    ]);

    const flockMembers = householdDoc.exists ? (householdDoc.data().memberIds || []).length : 0;
    const lettersReceived = receivedSnap.size;

    // Count letters sent by iterating connected contacts' mailboxes
    let lettersSent = 0;
    const contactsSnap = await db.collection('contacts').doc(householdId)
      .collection('connected').where('status', '==', 'accepted').get();

    if (contactsSnap.size > 0) {
      const sentCounts = await Promise.all(
        contactsSnap.docs.map(doc =>
          db.collection('households').doc(doc.id)
            .collection('mailbox')
            .where('fromHouseholdId', '==', householdId)
            .get()
            .then(snap => snap.size)
            .catch(() => 0)
        )
      );
      lettersSent = sentCounts.reduce((a, b) => a + b, 0);
    }

    return res.status(200).json({ lettersSent, lettersReceived, flockMembers });
  } catch (err) {
    console.error('Error fetching stats:', err);
    return res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

module.exports = router;
