//
//  NFCService.swift
//  Pidgn
//
//  Handles NFC tag writing (magnet setup) and reading (open letters).
//  NOTE: Requires CoreNFC. NFC only works on physical devices, not simulator.
//  You must add "Near Field Communication Tag Reading" capability in Xcode
//  and add NFCReaderUsageDescription to Info.plist.

import Foundation
import CoreNFC

class NFCService: NSObject, NFCNDEFReaderSessionDelegate {
    static let shared = NFCService()

    private var session: NFCNDEFReaderSession?
    private var onComplete: ((Result<Void, Error>) -> Void)?
    private var mode: SessionMode = .write

    enum SessionMode {
        case write
        case scan
    }

    private override init() {
        super.init()
    }

    // MARK: - Write Tag (magnet setup)

    func writeTag(completion: @escaping (Result<Void, Error>) -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else {
            completion(.failure(NFCError.notAvailable))
            return
        }

        mode = .write
        onComplete = completion
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the magnet to set it up."
        session?.begin()
    }

    // MARK: - Scan Tag (open a letter)

    func scanTag(completion: @escaping (Result<Void, Error>) -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else {
            completion(.failure(NFCError.notAvailable))
            return
        }

        // If a session is still cleaning up, fail fast so the continuation resolves
        guard session == nil else {
            completion(.failure(NFCError.sessionBusy))
            return
        }

        mode = .scan
        onComplete = completion
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold your iPhone near the Pidgn magnet to unseal this letter."
        session?.begin()
    }

    /// Async wrapper for scanTag
    func scanTag() async throws {
        try await withCheckedThrowingContinuation { continuation in
            scanTag { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Call onComplete exactly once, then nil it out to prevent double-firing
    private func complete(with result: Result<Void, Error>) {
        let handler = onComplete
        onComplete = nil
        handler?(result)
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("[NFC] Session active, mode: \(mode)")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // iOS routes to didDetect(tags:) when both delegates are implemented.
        // This is only called if didDetect(tags:) is not present — kept as a fallback.
        print("[NFC] didDetectNDEFs fallback called — \(messages.count) message(s)")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [any NFCNDEFTag]) {
        print("[NFC] didDetect tags called — \(tags.count) tag(s), mode: \(mode)")

        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found.")
            complete(with: .failure(NFCError.noTag))
            return
        }

        session.connect(to: tag) { error in
            if let error {
                session.invalidate(errorMessage: "Connection failed.")
                self.complete(with: .failure(error))
                return
            }

            switch self.mode {
            case .scan:
                self.handleScanTag(tag, session: session)
            case .write:
                self.handleWriteTag(tag, session: session)
            }
        }
    }

    private func handleScanTag(_ tag: any NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { message, error in
            if let error {
                print("[NFC] Read error: \(error.localizedDescription)")
                session.invalidate(errorMessage: "Couldn't read tag.")
                self.complete(with: .failure(error))
                return
            }

            guard let message else {
                print("[NFC] No NDEF message on tag")
                session.invalidate(errorMessage: "This tag is empty.")
                self.complete(with: .failure(NFCError.invalidTag))
                return
            }

            // Log records for debugging
            for (i, record) in message.records.enumerated() {
                let url = record.wellKnownTypeURIPayload()
                print("[NFC] Record[\(i)]: url=\(url?.absoluteString ?? "nil") host=\(url?.host ?? "nil")")
            }

            let isPidgnTag = message.records.contains { record in
                if let url = record.wellKnownTypeURIPayload() {
                    return url.host == "pidgn.app" || url.host == "www.pidgn.app"
                }
                return false
            }

            print("[NFC] isPidgnTag: \(isPidgnTag)")

            if isPidgnTag {
                session.alertMessage = "Letter unsealed!"
                session.invalidate()
                self.complete(with: .success(()))
            } else {
                session.invalidate(errorMessage: "This isn't a Pidgn magnet.")
                self.complete(with: .failure(NFCError.invalidTag))
            }
        }
    }

    private func handleWriteTag(_ tag: any NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.queryNDEFStatus { status, _, error in
            if let error {
                session.invalidate(errorMessage: "Could not read tag status.")
                self.complete(with: .failure(error))
                return
            }

            guard status == .readWrite else {
                session.invalidate(errorMessage: "Tag is not writable.")
                self.complete(with: .failure(NFCError.notWritable))
                return
            }

            guard let url = URL(string: "https://pidgn.app/open"),
                  let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
                session.invalidate(errorMessage: "Could not create URL payload.")
                self.complete(with: .failure(NFCError.payloadError))
                return
            }

            let message = NFCNDEFMessage(records: [payload])

            tag.writeNDEF(message) { error in
                if let error {
                    session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                    self.complete(with: .failure(error))
                } else {
                    session.alertMessage = "Magnet set up successfully!"
                    session.invalidate()
                    self.complete(with: .success(()))
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("[NFC] didInvalidateWithError: \(error.localizedDescription)")
        let nfcError = error as? NFCReaderError
        print("[NFC] NFCReaderError code: \(nfcError?.code.rawValue ?? -1)")
        if nfcError?.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
            // Successful read — didDetectNDEFs likely already completed with .success.
            // Call .success again as a safety net (no-ops if already fired).
            complete(with: .success(()))
        } else {
            // User cancelled or unexpected error
            complete(with: .failure(error))
        }

        self.session = nil
    }
}

// MARK: - NFC Errors

enum NFCError: LocalizedError, Equatable {
    case notAvailable
    case noTag
    case notWritable
    case payloadError
    case invalidTag
    case sessionBusy

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "NFC is not available on this device."
        case .noTag:
            return "No NFC tag was detected."
        case .notWritable:
            return "This tag is read-only and cannot be written to."
        case .payloadError:
            return "Failed to create the NFC payload."
        case .invalidTag:
            return "This isn't a Pidgn magnet."
        case .sessionBusy:
            return "NFC is busy. Try again in a moment."
        }
    }
}
