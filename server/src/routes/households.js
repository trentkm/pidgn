const express = require('express');
const admin = require('firebase-admin');
const crypto = require('crypto');

const router = express.Router();

const generateInviteCode = () => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  const bytes = crypto.randomBytes(6);
  for (let i = 0; i < 6; i++) {
    code += chars[bytes[i] % chars.length];
  }
  return code;
};

// POST /households/create
router.post('/create', async (req, res) => {
  try {
    const { name } = req.body;
    const uid = req.user.uid;

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return res.status(400).json({ error: 'Household name is required' });
    }

    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();

    const householdRef = db.collection('households').doc();
    const householdId = householdRef.id;

    const householdData = {
      name: name.trim(),
      memberIds: [uid],
      createdAt: now,
      nfcConfigured: false,
    };

    const batch = db.batch();

    batch.set(householdRef, householdData);

    batch.set(householdRef.collection('members').doc(uid), {
      role: 'owner',
      joinedAt: now,
    });

    batch.set(db.collection('users').doc(uid), {
      householdId,
    }, { merge: true });

    await batch.commit();

    return res.status(201).json({
      householdId,
      household: { ...householdData, createdAt: new Date().toISOString() },
    });
  } catch (err) {
    console.error('Error creating household:', err);
    return res.status(500).json({ error: 'Failed to create household' });
  }
});

// POST /households/invite
router.post('/invite', async (req, res) => {
  try {
    const { householdId } = req.body;
    const uid = req.user.uid;

    if (!householdId || typeof householdId !== 'string') {
      return res.status(400).json({ error: 'householdId is required' });
    }

    const db = admin.firestore();
    const householdRef = db.collection('households').doc(householdId);
    const householdDoc = await householdRef.get();

    if (!householdDoc.exists) {
      return res.status(404).json({ error: 'Household not found' });
    }

    const household = householdDoc.data();

    if (!household.memberIds.includes(uid)) {
      return res.status(403).json({ error: 'You are not a member of this household' });
    }

    const inviteCode = generateInviteCode();

    await householdRef.update({
      inviteCode,
      inviteCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ inviteCode });
  } catch (err) {
    console.error('Error generating invite:', err);
    return res.status(500).json({ error: 'Failed to generate invite code' });
  }
});

// POST /households/join
router.post('/join', async (req, res) => {
  try {
    const { inviteCode } = req.body;
    const uid = req.user.uid;

    if (!inviteCode || typeof inviteCode !== 'string') {
      return res.status(400).json({ error: 'inviteCode is required' });
    }

    const db = admin.firestore();
    const snapshot = await db.collection('households')
      .where('inviteCode', '==', inviteCode.toUpperCase())
      .limit(1)
      .get();

    if (snapshot.empty) {
      return res.status(404).json({ error: 'Invalid invite code' });
    }

    const householdDoc = snapshot.docs[0];
    const householdId = householdDoc.id;
    const household = householdDoc.data();

    if (household.memberIds.includes(uid)) {
      return res.status(400).json({ error: 'You are already a member of this household' });
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const householdRef = db.collection('households').doc(householdId);

    const batch = db.batch();

    batch.update(householdRef, {
      memberIds: admin.firestore.FieldValue.arrayUnion(uid),
    });

    batch.set(householdRef.collection('members').doc(uid), {
      role: 'member',
      joinedAt: now,
    });

    batch.set(db.collection('users').doc(uid), {
      householdId,
    }, { merge: true });

    await batch.commit();

    return res.status(200).json({
      householdId,
      household: {
        name: household.name,
        memberIds: [...household.memberIds, uid],
      },
    });
  } catch (err) {
    console.error('Error joining household:', err);
    return res.status(500).json({ error: 'Failed to join household' });
  }
});

module.exports = router;
