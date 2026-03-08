const express = require('express');
const admin = require('firebase-admin');

const router = express.Router();

// POST /households/connect
// Send a connection request from the caller's household to a target household
router.post('/connect', async (req, res) => {
  try {
    const { targetHouseholdId } = req.body;
    const uid = req.user.uid;

    if (!targetHouseholdId || typeof targetHouseholdId !== 'string') {
      return res.status(400).json({ error: 'targetHouseholdId is required' });
    }

    const db = admin.firestore();

    // Get the caller's user doc to find their household
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }

    const userData = userDoc.data();
    const fromHouseholdId = userData.householdId;

    if (!fromHouseholdId) {
      return res.status(400).json({ error: 'You must belong to a household' });
    }

    if (fromHouseholdId === targetHouseholdId) {
      return res.status(400).json({ error: 'Cannot connect to your own household' });
    }

    // Verify target household exists
    const targetDoc = await db.collection('households').doc(targetHouseholdId).get();
    if (!targetDoc.exists) {
      return res.status(404).json({ error: 'Target household not found' });
    }

    // Verify caller is a member of their household
    const fromDoc = await db.collection('households').doc(fromHouseholdId).get();
    if (!fromDoc.exists || !fromDoc.data().memberIds.includes(uid)) {
      return res.status(403).json({ error: 'You are not a member of your household' });
    }

    // Check if already connected or pending
    const existingContact = await db
      .collection('contacts').doc(fromHouseholdId)
      .collection('connected').doc(targetHouseholdId)
      .get();

    if (existingContact.exists) {
      const status = existingContact.data().status;
      if (status === 'accepted') {
        return res.status(400).json({ error: 'Already connected to this household' });
      }
      if (status === 'pending') {
        return res.status(400).json({ error: 'Connection request already pending' });
      }
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const fromHousehold = fromDoc.data();
    const targetHousehold = targetDoc.data();

    const batch = db.batch();

    // Create pending entry in sender's contacts
    batch.set(
      db.collection('contacts').doc(fromHouseholdId)
        .collection('connected').doc(targetHouseholdId),
      {
        status: 'pending',
        initiatedBy: uid,
        direction: 'outgoing',
        targetHouseholdName: targetHousehold.name,
        createdAt: now,
      }
    );

    // Create pending entry in target's contacts
    batch.set(
      db.collection('contacts').doc(targetHouseholdId)
        .collection('connected').doc(fromHouseholdId),
      {
        status: 'pending',
        initiatedBy: uid,
        direction: 'incoming',
        targetHouseholdName: fromHousehold.name,
        createdAt: now,
      }
    );

    await batch.commit();

    // Send FCM push to target household members
    try {
      const targetMembers = targetHousehold.memberIds || [];
      const tokens = [];

      for (const memberId of targetMembers) {
        const memberDoc = await db.collection('users').doc(memberId).get();
        if (memberDoc.exists) {
          const fcmTokens = memberDoc.data().fcmTokens || {};
          tokens.push(...Object.values(fcmTokens).map(t => t.token));
        }
      }

      if (tokens.length > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: {
            title: 'New Connection Request',
            body: `${fromHousehold.name} wants to connect with your household`,
          },
          data: {
            type: 'connection_request',
            fromHouseholdId,
          },
        });
      }
    } catch (fcmError) {
      console.error('FCM error (non-fatal):', fcmError.message);
    }

    return res.status(201).json({
      status: 'pending',
      targetHouseholdId,
      targetHouseholdName: targetHousehold.name,
    });
  } catch (err) {
    console.error('Error sending connection request:', err);
    return res.status(500).json({ error: 'Failed to send connection request' });
  }
});

// POST /households/connect/accept
// Accept a pending connection request
router.post('/connect/accept', async (req, res) => {
  try {
    const { fromHouseholdId } = req.body;
    const uid = req.user.uid;

    if (!fromHouseholdId || typeof fromHouseholdId !== 'string') {
      return res.status(400).json({ error: 'fromHouseholdId is required' });
    }

    const db = admin.firestore();

    // Get the caller's household
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }

    const myHouseholdId = userDoc.data().householdId;
    if (!myHouseholdId) {
      return res.status(400).json({ error: 'You must belong to a household' });
    }

    // Verify the pending request exists and is incoming
    const contactDoc = await db
      .collection('contacts').doc(myHouseholdId)
      .collection('connected').doc(fromHouseholdId)
      .get();

    if (!contactDoc.exists) {
      return res.status(404).json({ error: 'No connection request found' });
    }

    const contactData = contactDoc.data();
    if (contactData.status !== 'pending' || contactData.direction !== 'incoming') {
      return res.status(400).json({ error: 'No pending incoming request from this household' });
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();

    // Update both sides to accepted
    batch.update(
      db.collection('contacts').doc(myHouseholdId)
        .collection('connected').doc(fromHouseholdId),
      { status: 'accepted', connectedAt: now }
    );

    batch.update(
      db.collection('contacts').doc(fromHouseholdId)
        .collection('connected').doc(myHouseholdId),
      { status: 'accepted', connectedAt: now }
    );

    await batch.commit();

    // Send FCM push to the requesting household
    try {
      const fromHouseholdDoc = await db.collection('households').doc(fromHouseholdId).get();
      const myHouseholdDoc = await db.collection('households').doc(myHouseholdId).get();

      if (fromHouseholdDoc.exists) {
        const fromMembers = fromHouseholdDoc.data().memberIds || [];
        const tokens = [];

        for (const memberId of fromMembers) {
          const memberDoc = await db.collection('users').doc(memberId).get();
          if (memberDoc.exists) {
            const fcmTokens = memberDoc.data().fcmTokens || {};
            tokens.push(...Object.values(fcmTokens).map(t => t.token));
          }
        }

        if (tokens.length > 0) {
          const myName = myHouseholdDoc.exists ? myHouseholdDoc.data().name : 'A household';
          await admin.messaging().sendEachForMulticast({
            tokens,
            notification: {
              title: 'Connection Accepted',
              body: `${myName} accepted your connection request`,
            },
            data: {
              type: 'connection_accepted',
              householdId: myHouseholdId,
            },
          });
        }
      }
    } catch (fcmError) {
      console.error('FCM error (non-fatal):', fcmError.message);
    }

    return res.status(200).json({
      status: 'accepted',
      fromHouseholdId,
    });
  } catch (err) {
    console.error('Error accepting connection:', err);
    return res.status(500).json({ error: 'Failed to accept connection' });
  }
});

// GET /households/contacts/:householdId
// List all contacts (pending + accepted) for a household
router.get('/contacts/:householdId', async (req, res) => {
  try {
    const { householdId } = req.params;
    const uid = req.user.uid;

    const db = admin.firestore();

    // Verify caller is a member
    const householdDoc = await db.collection('households').doc(householdId).get();
    if (!householdDoc.exists) {
      return res.status(404).json({ error: 'Household not found' });
    }

    if (!householdDoc.data().memberIds.includes(uid)) {
      return res.status(403).json({ error: 'You are not a member of this household' });
    }

    const snapshot = await db
      .collection('contacts').doc(householdId)
      .collection('connected')
      .get();

    const contacts = snapshot.docs.map(doc => ({
      householdId: doc.id,
      householdName: doc.data().targetHouseholdName || 'Unknown',
      status: doc.data().status,
      direction: doc.data().direction || null,
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
      connectedAt: doc.data().connectedAt?.toDate?.()?.toISOString() || null,
    }));

    return res.status(200).json({ contacts });
  } catch (err) {
    console.error('Error fetching contacts:', err);
    return res.status(500).json({ error: 'Failed to fetch contacts' });
  }
});

module.exports = router;
