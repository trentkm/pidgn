# Pidgn — Project Plan

## Summary

Pidgn is a family messaging app with a physical NFC fridge magnet. Messages are sent intentionally and can only be opened by tapping the magnet. This document outlines the build plan in phases, designed for iterative development with Claude Code.

**Builder context:** Strong JavaScript/React background, DynamoDB experience at Amazon, zero Swift experience (learning with Claude Code), comfortable with Node.js/Express. Quality over speed, side project timeline.

---

## Phase 0 — Project Setup & Tooling

**Goal:** Get the development environment ready and all services provisioned.

### Tasks

- [x] Install Xcode from the Mac App Store
- [x] Create a new SwiftUI project in Xcode (target iOS 17+)
- [x] Set up Apple Developer account ($99/year) — needed for device testing and NFC
- [x] Create Firebase project at console.firebase.google.com
  - [x] Enable Firestore (start in test mode, lock down later)
  - [x] Enable Firebase Auth (email/password for dev, add phone auth later)
  - [ ] Enable Firebase Storage (console bug — deferred to Phase 4)
  - [x] Enable Cloud Messaging (FCM)
  - [x] Download `GoogleService-Info.plist`, add to Xcode project
- [x] Initialize Express project in `/server`
  - [x] `npm init`, install express, firebase-admin, cors, dotenv
  - [x] Set up Firebase Admin SDK with service account key
  - [x] Create basic health check endpoint, verify it runs locally
- [x] Set up Railway account, connect to GitHub repo, deploy Express server
- [x] Register pidgn.app domain (done)
- [x] Set up basic static site at pidgn.app with `apple-app-site-association` file
- [x] Initialize Git repo with `/ios`, `/server`, `/firebase`, `/web` structure

### Definition of Done
Express server is deployed on Railway and returns 200 on health check. Xcode project builds and runs "Hello World" in the simulator. Firebase project is provisioned.

---

## Phase 1 — Auth & Household Setup

**Goal:** Users can sign up, create a household, and invite members.

### Tasks

- [x] **Server:** Auth middleware — validate Firebase ID tokens on all routes
- [x] **iOS:** Sign up / sign in screen (email + password for MVP)
- [x] **iOS:** Firebase Auth SDK integration — get ID token, pass in API headers
- [x] **Server:** `POST /households/create` — create household doc, add creator as owner
- [x] **iOS:** "Create your household" flow — name your household
- [x] **Server:** `POST /households/invite` — generate invite code or link
- [x] **iOS:** "Join a household" flow — enter invite code
- [x] **Server:** `POST /households/join` — add user to household, update memberIds
- [x] **Firestore:** Write security rules for users and households collections
- [x] **Firestore:** Deploy `firestore.indexes.json` with required composite indexes

> **Status:** Complete. End-to-end tested: sign up, create household, generate invite code, join via code.

### Definition of Done
Two test users can sign up, one creates a household, the other joins it via invite. Household and user documents are correctly written in Firestore.

---

## Phase 2 — Send & Receive Messages (No NFC Yet)

**Goal:** Users can send text messages to a connected household and see them in a mailbox. Messages are visible immediately (NFC gating comes in Phase 3).

### Tasks

- [ ] **Server:** `POST /households/connect` — send connection request to another household
- [ ] **Server:** `POST /households/connect/accept` — accept connection request
- [ ] **iOS:** Contact list screen — show connected households
- [ ] **iOS:** "Add a connection" flow — search by household code or link
- [ ] **iOS:** Compose screen — select recipient household, write text message, send
- [ ] **Server:** `POST /mail/send` — validate, write to Firestore, trigger FCM push
- [ ] **iOS:** FCM integration — register for push notifications, store token
- [ ] **Server:** `POST /fcm/register` — store device FCM token
- [ ] **iOS:** Mailbox screen — list received messages, sorted by date
- [ ] **iOS:** Message detail screen — show full message content
- [ ] **Server:** `GET /households/:id/mailbox` — paginated mailbox query

### Definition of Done
User A sends a text message to User B's household. User B receives a push notification, opens the app, sees the message in their mailbox, and can read it. No NFC required yet.

---

## Phase 3 — NFC Tap to Open

**Goal:** Messages are locked until the recipient taps their fridge magnet. This is the core product mechanic.

### Tasks

- [ ] **iOS:** CoreNFC write session — "Set up your magnet" flow in settings
  - [ ] Write `https://pidgn.app/open` as NDEF URL to NTAG213 tag
  - [ ] Optional: lock tag after write
  - [ ] Update household doc: `nfcConfigured: true`
- [ ] **Web:** `apple-app-site-association` file properly configured for Universal Links
- [ ] **iOS:** Universal Link handler — intercept `pidgn.app/open`, route to mailbox
- [ ] **iOS:** Lock message content in mailbox UI — show sender name + "Tap magnet to read"
- [ ] **iOS:** On NFC tap / Universal Link open, call `POST /mail/open`
- [ ] **Server:** `POST /mail/open` — mark message opened, send read receipt to sender
- [ ] **iOS:** Mail opening animation — envelope opens, content reveals
- [ ] **iOS:** Push notification for sender: "Delivered to fridge"
- [ ] **Web:** Fallback page at pidgn.app/open — shown if app not installed, links to App Store

### Definition of Done
User A sends a message. User B gets a teaser notification with no content preview. User B walks to fridge, taps phone to magnet. App opens, message unlocks with animation. User A gets "delivered to fridge" notification.

---

## Phase 4 — Photo & Voice Messages

**Goal:** Support photo + caption and voice memo message types.

### Tasks

- [ ] **iOS:** Photo picker integration (PhotosUI framework)
- [ ] **iOS:** Client-side image compression (resize to max 1200px wide, JPEG 0.7 quality)
- [ ] **iOS:** Upload compressed image to Firebase Storage
- [ ] **iOS:** Compose screen — attach photo, add optional caption
- [ ] **Server:** Update `POST /mail/send` to handle photo message type
- [ ] **iOS:** Voice memo recording (AVFoundation)
  - [ ] Max 60 second recording
  - [ ] Compress to AAC/M4A
  - [ ] Upload to Firebase Storage
- [ ] **iOS:** Compose screen — record and attach voice memo
- [ ] **Server:** Update `POST /mail/send` to handle voice message type
- [ ] **iOS:** Message detail — display photo with caption
- [ ] **iOS:** Message detail — audio playback for voice memos
- [ ] **Firebase:** Storage security rules — only household members can read their media

### Definition of Done
Users can send and receive all three MVP message types: text, photo + caption, and voice memo. Media uploads are compressed client-side and stored securely.

---

## Phase 5 — Polish & App Store Prep

**Goal:** App is ready for TestFlight and eventually App Store submission.

### Tasks

- [ ] **iOS:** App icon and launch screen
- [ ] **iOS:** Onboarding flow — explain the concept, guide through setup
- [ ] **iOS:** Empty states — no messages yet, no connections yet
- [ ] **iOS:** Error handling — network failures, auth expiry, NFC not available
- [ ] **iOS:** Offline support — cache unread mail, queue opens for sync
- [ ] **iOS:** Settings screen — household info, manage members, magnet setup
- [ ] **Server:** Rate limiting on all endpoints
- [ ] **Server:** Input validation and sanitization
- [ ] **Firestore:** Lock down security rules (remove test mode)
- [ ] **Firebase:** Set up budget alerts
- [ ] **iOS:** TestFlight build — internal testing
- [ ] App Store listing — screenshots, description, keywords
- [ ] Privacy policy page on pidgn.app (required for App Store)
- [ ] App Store submission

### Definition of Done
App is live on the App Store (or in TestFlight for beta users).

---

## Post-MVP Ideas (Unscoped)

These are not part of the initial build but worth keeping in mind architecturally:

- Video messages (storage + compression complexity)
- Stickers / hand-drawn doodles
- Scheduled delivery ("arrives tomorrow morning")
- Multiple magnets per household (kitchen, office, etc.)
- Android app
- Personalized magnet ordering flow in-app
- Read receipt opt-out per household
- Message reactions (tap to send a heart back)
- "On this day" — resurface old messages as memories

---

## Key Technical Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Household-level mailbox | Yes | One magnet per home, shared mailbox. Individuals within a household all see the same mail. Simpler model, matches the physical metaphor. |
| NFC verification at MVP | Trust the client | The adversary is the recipient themselves. No financial or competitive incentive to bypass. Add nonce-based verification post-MVP if needed. |
| Express over Cloud Functions | Yes | Avoids cold start latency on the critical "tap to open" path. Railway gives always-on server for $5/month. |
| FCM tokens as map on user doc | Yes | Handles multi-device, token rotation, and stale token cleanup naturally. No separate tokens collection needed. |
| Media upload from client | Yes | Client compresses and uploads to Firebase Storage directly, then passes URL to server in send request. Avoids proxying large files through Express. |
| Firestore over Realtime Database | Yes | Document model matches DynamoDB mental model. Better querying, offline support, security rules. |

---

## Development Notes for Claude Code

- Builder is learning Swift from scratch — explain SwiftUI patterns when introducing new concepts
- Access-pattern-first database thinking — builder is fluent in this from DynamoDB, lean into it
- Keep the Express server thin — if Firebase can do it, let Firebase do it
- Native iOS only for v1 — no React Native, no cross-platform
- Test in simulator first, real device needed only for NFC testing
- The physical NFC tap is the entire product — protect that moment in every architectural decision
