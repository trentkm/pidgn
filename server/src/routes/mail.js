const express = require('express');
const admin = require('firebase-admin');

const router = express.Router();

// POST /mail/send
// Send a message (text, photo, or voice) to a target household
router.post('/send', async (req, res) => {
  try {
    const { targetHouseholdId, content, type: messageType, mediaUrl, stationery } = req.body;
    const uid = req.user.uid;

    if (!targetHouseholdId || typeof targetHouseholdId !== 'string') {
      return res.status(400).json({ error: 'targetHouseholdId is required' });
    }

    const validTypes = ['text', 'photo', 'voice'];
    const type = validTypes.includes(messageType) ? messageType : 'text';

    // Text messages require content
    if (type === 'text') {
      if (!content || typeof content !== 'string' || content.trim().length === 0) {
        return res.status(400).json({ error: 'Message content is required' });
      }
      if (content.length > 500) {
        return res.status(400).json({ error: 'Message must be 500 characters or fewer' });
      }
    }

    // Photo captions are optional, max 200 chars
    if (type === 'photo' && content && content.length > 200) {
      return res.status(400).json({ error: 'Caption must be 200 characters or fewer' });
    }

    // Photo and voice require mediaUrl
    if ((type === 'photo' || type === 'voice') && (!mediaUrl || typeof mediaUrl !== 'string')) {
      return res.status(400).json({ error: 'mediaUrl is required for photo and voice messages' });
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
      fromPlumage: userData.plumage || 'terracotta',
      fromCrest: userData.crest || 'dove',
      type,
      content: content ? content.trim() : '',
      mediaUrl: mediaUrl || null,
      stationery: ['parchment', 'midnight', 'heron', 'rosewater'].includes(stationery) ? stationery : 'parchment',
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

// POST /mail/open
// Mark a message as opened (triggered by NFC tap / Universal Link)
router.post('/open', async (req, res) => {
  try {
    const { messageId, householdId } = req.body;
    const uid = req.user.uid;

    if (!messageId || typeof messageId !== 'string') {
      return res.status(400).json({ error: 'messageId is required' });
    }

    if (!householdId || typeof householdId !== 'string') {
      return res.status(400).json({ error: 'householdId is required' });
    }

    const db = admin.firestore();

    // Verify caller is a member of the household
    const householdDoc = await db.collection('households').doc(householdId).get();
    if (!householdDoc.exists) {
      return res.status(404).json({ error: 'Household not found' });
    }

    if (!householdDoc.data().memberIds.includes(uid)) {
      return res.status(403).json({ error: 'You are not a member of this household' });
    }

    // Get the message
    const messageRef = db
      .collection('households').doc(householdId)
      .collection('mailbox').doc(messageId);
    const messageDoc = await messageRef.get();

    if (!messageDoc.exists) {
      return res.status(404).json({ error: 'Message not found' });
    }

    const messageData = messageDoc.data();

    if (messageData.isOpened) {
      // Already opened — return the message content anyway
      return res.status(200).json({
        message: {
          id: messageDoc.id,
          ...messageData,
          sentAt: messageData.sentAt?.toDate?.()?.toISOString() || null,
          openedAt: messageData.openedAt?.toDate?.()?.toISOString() || null,
        },
        alreadyOpened: true,
      });
    }

    // Mark as opened
    const now = admin.firestore.FieldValue.serverTimestamp();
    await messageRef.update({
      isOpened: true,
      openedAt: now,
      openedByUserId: uid,
    });

    // Send "Delivered to fridge" read receipt to sender
    try {
      const senderDoc = await db.collection('users').doc(messageData.fromUserId).get();
      if (senderDoc.exists) {
        const fcmTokens = senderDoc.data().fcmTokens || {};
        const tokens = Object.values(fcmTokens).map(t => t.token);

        if (tokens.length > 0) {
          // Get opener's display name
          const openerDoc = await db.collection('users').doc(uid).get();
          const openerName = openerDoc.exists ? openerDoc.data().displayName : 'Someone';

          await admin.messaging().sendEachForMulticast({
            tokens,
            notification: {
              title: 'Delivered to fridge!',
              body: `${openerName} opened your message`,
            },
            data: {
              type: 'read_receipt',
              messageId,
              openedByUserId: uid,
            },
          });
        }
      }
    } catch (fcmError) {
      console.error('FCM read receipt error (non-fatal):', fcmError.message);
    }

    return res.status(200).json({
      message: {
        id: messageDoc.id,
        ...messageData,
        isOpened: true,
        openedAt: new Date().toISOString(),
        openedByUserId: uid,
        sentAt: messageData.sentAt?.toDate?.()?.toISOString() || null,
      },
      alreadyOpened: false,
    });
  } catch (err) {
    console.error('Error opening mail:', err);
    return res.status(500).json({ error: 'Failed to open message' });
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
