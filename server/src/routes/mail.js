const express = require('express');
const admin = require('firebase-admin');

const router = express.Router();

// POST /mail/send
// Send a text message from the caller's household to a target household
router.post('/send', async (req, res) => {
  try {
    const { targetHouseholdId, content } = req.body;
    const uid = req.user.uid;

    if (!targetHouseholdId || typeof targetHouseholdId !== 'string') {
      return res.status(400).json({ error: 'targetHouseholdId is required' });
    }

    if (!content || typeof content !== 'string' || content.trim().length === 0) {
      return res.status(400).json({ error: 'Message content is required' });
    }

    if (content.length > 500) {
      return res.status(400).json({ error: 'Message must be 500 characters or fewer' });
    }

    const db = admin.firestore();

    // Get sender info
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
      return res.status(400).json({ error: 'Cannot send mail to your own household' });
    }

    // Verify connection exists and is accepted
    const contactDoc = await db
      .collection('contacts').doc(fromHouseholdId)
      .collection('connected').doc(targetHouseholdId)
      .get();

    if (!contactDoc.exists || contactDoc.data().status !== 'accepted') {
      return res.status(403).json({ error: 'You are not connected to this household' });
    }

    // Verify target household exists
    const targetDoc = await db.collection('households').doc(targetHouseholdId).get();
    if (!targetDoc.exists) {
      return res.status(404).json({ error: 'Target household not found' });
    }

    // Write message to target household's mailbox
    const messageRef = db
      .collection('households').doc(targetHouseholdId)
      .collection('mailbox').doc();

    const messageData = {
      fromUserId: uid,
      fromDisplayName: userData.displayName || 'Unknown',
      fromHouseholdId,
      type: 'text',
      content: content.trim(),
      mediaUrl: null,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      isOpened: false,
      openedAt: null,
      openedByUserId: null,
    };

    await messageRef.set(messageData);

    // Send FCM push to target household members — no content preview
    try {
      const targetMembers = targetDoc.data().memberIds || [];
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
            title: 'You have mail!',
            body: `New message from ${userData.displayName || 'someone'}`,
          },
          data: {
            type: 'new_mail',
            messageId: messageRef.id,
            fromHouseholdId,
          },
        });
      }
    } catch (fcmError) {
      console.error('FCM error (non-fatal):', fcmError.message);
    }

    return res.status(201).json({
      messageId: messageRef.id,
    });
  } catch (err) {
    console.error('Error sending mail:', err);
    return res.status(500).json({ error: 'Failed to send message' });
  }
});

// GET /mail/mailbox/:householdId
// Fetch paginated mailbox for a household
router.get('/mailbox/:householdId', async (req, res) => {
  try {
    const { householdId } = req.params;
    const uid = req.user.uid;
    const { limit: limitParam, startAfter, unreadOnly } = req.query;

    const db = admin.firestore();

    // Verify caller is a member of this household
    const householdDoc = await db.collection('households').doc(householdId).get();
    if (!householdDoc.exists) {
      return res.status(404).json({ error: 'Household not found' });
    }

    if (!householdDoc.data().memberIds.includes(uid)) {
      return res.status(403).json({ error: 'You are not a member of this household' });
    }

    const limit = Math.min(parseInt(limitParam) || 20, 50);

    let query = db
      .collection('households').doc(householdId)
      .collection('mailbox')
      .orderBy('sentAt', 'desc')
      .limit(limit);

    if (unreadOnly === 'true') {
      query = db
        .collection('households').doc(householdId)
        .collection('mailbox')
        .where('isOpened', '==', false)
        .orderBy('sentAt', 'desc')
        .limit(limit);
    }

    if (startAfter) {
      const startAfterDoc = await db
        .collection('households').doc(householdId)
        .collection('mailbox').doc(startAfter)
        .get();

      if (startAfterDoc.exists) {
        query = query.startAfter(startAfterDoc);
      }
    }

    const snapshot = await query.get();

    const messages = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      sentAt: doc.data().sentAt?.toDate?.()?.toISOString() || null,
      openedAt: doc.data().openedAt?.toDate?.()?.toISOString() || null,
    }));

    return res.status(200).json({
      messages,
      hasMore: messages.length === limit,
    });
  } catch (err) {
    console.error('Error fetching mailbox:', err);
    return res.status(500).json({ error: 'Failed to fetch mailbox' });
  }
});

module.exports = router;
