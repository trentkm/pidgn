# Pidgn — Technical Architecture Document

## Overview

Pidgn is a mobile app paired with a physical NFC fridge magnet that creates a ritual-based family messaging experience. Messages are sent intentionally (like mailing a letter) and can only be opened by physically tapping the magnet with your phone.

**Domain:** pidgn.app

---

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      iOS App (Swift/SwiftUI)            │
│                                                         │
│  ┌───────────┐  ┌───────────┐  ┌────────────────────┐  │
│  │ Compose   │  │ Mailbox   │  │ NFC (CoreNFC)      │  │
│  │ & Send    │  │ & Read    │  │ Read/Write NTAG213 │  │
│  └─────┬─────┘  └─────┬─────┘  └────────┬───────────┘  │
│        │              │                  │              │
│        └──────────┬───┘                  │              │
│                   │                      │              │
│         ┌────────▼────────┐    ┌────────▼────────┐     │
│         │ API Service     │    │ Universal Link   │     │
│         │ Layer           │    │ Handler          │     │
│         └────────┬────────┘    └────────┬────────┘     │
└──────────────────┼──────────────────────┼──────────────┘
                   │                      │
                   ▼                      │
┌─────────────────────────────────┐       │
│  Express API (Node.js)          │       │
│  Hosted on Railway              │       │
│                                 │       │
│  POST /mail/send                │       │
│  POST /mail/open                │◄──────┘
│  POST /households/connect       │
│  POST /fcm/register             │
│  GET  /households/:id/mailbox   │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  Firebase                               │
│                                         │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │ Firestore   │  │ Firebase Auth    │  │
│  │ (Database)  │  │ (Phone/Email)    │  │
│  └─────────────┘  └──────────────────┘  │
│                                         │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │ Storage     │  │ Cloud Messaging  │  │
│  │ (Media)     │  │ (FCM → APNs)    │  │
│  └─────────────┘  └──────────────────┘  │
└─────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| iOS App | Swift + SwiftUI | Native iOS only for v1 |
| NFC | CoreNFC (Apple) | Read/write NTAG213 tags |
| Backend API | Node.js + Express | Thin layer — validation, FCM, business logic |
| Database | Firebase Firestore | NoSQL document model, access-pattern-first design |
| Media Storage | Firebase Storage | Photos, voice memos |
| Auth | Firebase Auth | Phone number or email/password |
| Push Notifications | FCM → APNs | Firebase Cloud Messaging to Apple Push |
| API Hosting | Railway | Always-on Node server, avoids cold start latency |

---

## NFC Architecture

### Tag Hardware
- NTAG213 chips — compatible with iOS 13+ and Android
- ~$0.20/unit at bulk
- Embedded in custom fridge magnets

### What the Tag Stores
A single NDEF URL record pointing to a Universal Link:
```
https://pidgn.app/open
```

### Universal Links
- Registered via `apple-app-site-association` file hosted at `pidgn.app/.well-known/`
- When iOS encounters this URL from an NFC tap, it opens the app directly (bypasses Safari)
- Works from the lock screen

### Tag Setup Flow (one-time per household)
1. User navigates to "Set up your magnet" in app settings
2. App opens CoreNFC write session
3. User taps phone to magnet — URL written to tag
4. Tag optionally locked (read-only)
5. Tags ship blank — programming happens in-app

---

## Firestore Data Model

Design principle: access-pattern-first, same as DynamoDB composite key thinking. No ORMs.

### Collections

#### `users/{userId}`
```json
{
  "uid": "string",
  "displayName": "string",
  "email": "string",
  "fcmTokens": {
    "deviceId1": { "token": "string", "updatedAt": "timestamp" },
    "deviceId2": { "token": "string", "updatedAt": "timestamp" }
  },
  "householdId": "string",
  "createdAt": "timestamp"
}
```
Note: `fcmTokens` is a map keyed by device ID. This handles token rotation and multi-device households naturally. Stale tokens are pruned when FCM returns an error.

#### `households/{householdId}`
```json
{
  "name": "string",
  "memberIds": ["userId1", "userId2"],
  "createdAt": "timestamp",
  "nfcConfigured": "boolean"
}
```

#### `households/{householdId}/members/{userId}`
```json
{
  "role": "owner | member",
  "joinedAt": "timestamp"
}
```

#### `households/{householdId}/mailbox/{messageId}`
```json
{
  "fromUserId": "string",
  "fromDisplayName": "string",
  "fromHouseholdId": "string",
  "type": "text | photo | voice",
  "content": "string (text body or caption)",
  "mediaUrl": "string | null",
  "sentAt": "timestamp",
  "isOpened": "boolean",
  "openedAt": "timestamp | null",
  "openedByUserId": "string | null"
}
```

#### `contacts/{householdId}/connected/{targetHouseholdId}`
```json
{
  "status": "pending | accepted",
  "initiatedBy": "userId",
  "connectedAt": "timestamp",
  "targetHouseholdName": "string"
}
```

### Key Access Patterns

| Pattern | Query |
|---|---|
| Unread mail for a household | `mailbox` where `isOpened == false` ordered by `sentAt desc` |
| Open a message (NFC tap) | Update `isOpened: true`, `openedAt: now()`, `openedByUserId` |
| Conversation history with a household | `mailbox` where `fromHouseholdId == X` ordered by `sentAt desc` |
| All connected households | `contacts/{householdId}/connected` where `status == accepted` |
| All FCM tokens for a household | Read `users` docs for each `memberId` in household, collect `fcmTokens` |

### Indexes Needed
- `mailbox`: composite index on `isOpened` (asc) + `sentAt` (desc)
- `mailbox`: composite index on `fromHouseholdId` (asc) + `sentAt` (desc)

---

## Express API

The Express server is a thin orchestration layer. Firebase handles auth, storage, and database. Express handles validation, FCM dispatch, and business logic that shouldn't live on the client.

### Endpoints

#### `POST /mail/send`
- Validate sender auth token (Firebase Auth)
- Validate sender is connected to target household
- Write message document to `households/{targetHouseholdId}/mailbox`
- Fetch all FCM tokens for target household members
- Send FCM push: "You have mail from {displayName}" — no content preview
- Return message ID

#### `POST /mail/open`
- Called when NFC tap triggers Universal Link
- Validate auth token
- Validate user belongs to the target household
- Update message: `isOpened: true`, `openedAt: now()`, `openedByUserId`
- Send FCM push to sender: "Delivered to fridge" read receipt
- Return full message content

#### `POST /households/connect`
- Handle contact request between two households
- Create `pending` entries in both households' contact subcollections
- Send FCM push to target household: "Connection request from {householdName}"

#### `POST /households/connect/accept`
- Update both contact entries to `accepted`
- Send FCM push to requesting household

#### `POST /fcm/register`
- Store/update FCM token for a user device
- Keyed by device ID to handle token rotation
- Called on app launch and when token refreshes

#### `GET /households/:id/mailbox`
- Fetch paginated mailbox for a household
- Query params: `limit`, `startAfter`, `unreadOnly`
- Could also be a direct Firestore query from client — evaluate at build time

### Auth Middleware
Every request includes a Firebase Auth ID token in the `Authorization` header. Express validates this server-side using the Firebase Admin SDK before processing any request.

---

## Message Types (MVP)

| Type | Details |
|---|---|
| Text | Short message, 500 character limit. Think postcard, not email. |
| Photo + caption | Single image + optional 200 char caption. Compressed client-side before upload. |
| Voice memo | Max 60 seconds, compressed to AAC/M4A client-side. Target ~100KB for 30s. |

### Media Upload Flow
1. Client compresses media (image resize / audio encode)
2. Client uploads to Firebase Storage at `households/{householdId}/media/{messageId}/{filename}`
3. Client gets download URL
4. Client sends message via `POST /mail/send` with `mediaUrl` included

---

## FCM Token Management Strategy

- Store tokens as a map on the `users` document, keyed by device ID (e.g., `UIDevice.identifierForVendor`)
- On every app launch, register/refresh the token via `POST /fcm/register`
- When sending a push, collect all tokens for all household members
- If FCM returns `messaging/registration-token-not-registered`, delete that token entry
- This naturally handles: token rotation, device changes, multiple devices per user, household members with different devices

---

## NFC Tap Verification (MVP Approach)

At MVP, trust the client. The `/mail/open` endpoint verifies:
1. Valid Firebase Auth token
2. User belongs to the household whose mailbox is being accessed
3. Message exists and hasn't already been opened

What it does NOT verify: whether a genuine NFC tap occurred. A determined user could call the endpoint directly. This is acceptable at MVP because:
- The "adversary" is the message recipient themselves — they're only cheating their own experience
- There's no competitive or financial incentive to bypass
- Adding hardware attestation or challenge-response adds complexity with minimal user benefit

Post-MVP option: include a short-lived nonce generated when the NFC tap is detected, passed to the Universal Link as a query param, validated server-side.

---

## Universal Link Fallback

If the app is NOT installed when the NFC tag is tapped:
- iOS opens `https://pidgn.app/open` in Safari
- This page should show: app branding, brief explanation of Pidgn, App Store download link
- After install, the user can tap the magnet again to complete setup

Host this as a simple static page on pidgn.app.

---

## Offline Behavior

- On app launch and when connectivity is available, sync unread mail to local cache (Core Data or SwiftData)
- If user taps magnet while offline, app opens and displays cached unread messages
- Mark-as-read is queued and synced when connectivity returns
- Firestore's built-in offline persistence helps here — enable it in the iOS SDK config

---

## Read Receipts

"Delivered to fridge" is a core part of the charm. For MVP, it's always on. Post-MVP, consider making it opt-out per household in settings. The notification to the sender is a simple FCM push, not a persistent UI element — the sender sees it once and it's gone.

---

## File & Folder Structure (Recommended)

```
pidgn/
├── ios/                    # Xcode project
│   └── Pidgn/
│       ├── App/            # App entry point, config
│       ├── Views/          # SwiftUI views
│       ├── Models/         # Data models
│       ├── Services/       # API client, NFC, auth, storage
│       └── Utilities/      # Extensions, helpers
│
├── server/                 # Express API
│   ├── src/
│   │   ├── routes/         # Route handlers (mail, households, fcm)
│   │   ├── middleware/     # Auth validation
│   │   ├── services/       # Firestore, FCM, Storage interactions
│   │   └── index.js        # Express app entry point
│   ├── package.json
│   └── .env                # Firebase credentials, config
│
├── firebase/               # Firebase config
│   ├── firestore.rules     # Security rules
│   ├── firestore.indexes.json
│   └── storage.rules
│
└── web/                    # Static site for pidgn.app
    ├── .well-known/
    │   └── apple-app-site-association
    └── index.html          # Universal Link fallback page
```
