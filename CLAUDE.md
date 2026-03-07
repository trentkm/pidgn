# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pidgn is a family messaging iOS app paired with a physical NFC fridge magnet. Messages are locked until the recipient taps the magnet with their phone. The NFC tap triggers a Universal Link (`https://pidgn.app/open`) that opens the app to reveal messages.

## Architecture

- **iOS app** (`/ios/Pidgn/`) — Swift + SwiftUI, iOS 17+, CoreNFC. Xcode project at `ios/Pidgn/Pidgn.xcodeproj`.
- **Express API** (`/server/`) — Thin orchestration layer on Node.js. Handles auth validation, FCM dispatch, business logic. Deployed on Railway.
- **Firebase** — Firestore (database), Firebase Auth (email/password for dev), Firebase Storage (media), FCM (push notifications).
- **Static site** (`/web/`) — Hosts `apple-app-site-association` for Universal Links and fallback pages. Served by the Express server.

The Express server is intentionally thin — Firebase handles auth, storage, and database directly. Express handles validation, FCM dispatch, and business logic that shouldn't live on the client.

## Common Commands

### Server
```bash
cd server
npm install            # Install dependencies
npm run dev            # Start with --watch (auto-restart on changes)
npm start              # Production start
```

The server requires these env vars: `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `PORT`.

### iOS
Build and run via Xcode: open `ios/Pidgn/Pidgn.xcodeproj`. NFC testing requires a physical device; simulator works for everything else.

## Data Model

Firestore collections follow access-pattern-first design (like DynamoDB composite keys):
- `users/{userId}` — profile, `fcmTokens` map keyed by device ID, `householdId`
- `households/{householdId}` — name, `memberIds` array, `nfcConfigured`
- `households/{householdId}/members/{userId}` — role, joinedAt
- `households/{householdId}/mailbox/{messageId}` — message content, `isOpened`, `openedAt`
- `contacts/{householdId}/connected/{targetHouseholdId}` — connection status

Firestore rules are in `/firebase/firestore.rules` (currently in test mode, locked down in Phase 5).

## API Endpoints (Planned)

`POST /mail/send`, `POST /mail/open`, `POST /households/connect`, `POST /households/connect/accept`, `POST /fcm/register`, `GET /households/:id/mailbox`. Currently only `GET /health` is implemented.

## Key Design Decisions

- **Household-level mailbox**: One magnet per home, shared mailbox. All household members see the same mail.
- **NFC verification at MVP**: Trust the client. No hardware attestation — the "adversary" is only cheating themselves.
- **Media uploads**: Client compresses and uploads directly to Firebase Storage, then passes URL to server. No proxying through Express.
- **FCM tokens**: Stored as a map on user docs keyed by device ID. Stale tokens pruned on FCM error.
- **No ORMs**: Direct Firestore SDK calls only.

## Development Context

- The builder is learning Swift from scratch — explain SwiftUI patterns when introducing new concepts.
- Native iOS only — no React Native or cross-platform.
- The physical NFC tap is the core product moment. Protect that experience in every decision.
- Phased build plan in `docs/pidgn-project-plan.md`, full architecture in `docs/pidgn-architecture.md`.
