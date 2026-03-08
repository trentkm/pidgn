//
//  NFCService.swift
//  Pidgn
//
//  Handles NFC tag writing for magnet setup.
//  NOTE: Requires CoreNFC. NFC only works on physical devices, not simulator.
//  You must add "Near Field Communication Tag Reading" capability in Xcode
//  and add NFCReaderUsageDescription to Info.plist.

import Foundation
import CoreNFC

class NFCService: NSObject, NFCNDEFReaderSessionDelegate {
    static let shared = NFCService()

    private var session: NFCNDEFReaderSession?
    private var onComplete: ((Result<Void, Error>) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Write Tag

    func writeTag(completion: @escaping (Result<Void, Error>) -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else {
            completion(.failure(NFCError.notAvailable))
            return
        }

        onComplete = completion
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the magnet to set it up."
        session?.begin()
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Session is active, waiting for tag
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not used — we're writing, not reading
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [any NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found.")
            onComplete?(.failure(NFCError.noTag))
            return
        }

        session.connect(to: tag) { error in
            if let error {
                session.invalidate(errorMessage: "Connection failed.")
                self.onComplete?(.failure(error))
                return
            }

            tag.queryNDEFStatus { status, _, error in
                if let error {
                    session.invalidate(errorMessage: "Could not read tag status.")
                    self.onComplete?(.failure(error))
                    return
                }

                guard status == .readWrite else {
                    session.invalidate(errorMessage: "Tag is not writable.")
                    self.onComplete?(.failure(NFCError.notWritable))
                    return
                }

                // Create NDEF URL record for pidgn.app/open
                guard let url = URL(string: "https://pidgn.app/open"),
                      let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
                    session.invalidate(errorMessage: "Could not create URL payload.")
                    self.onComplete?(.failure(NFCError.payloadError))
                    return
                }

                let message = NFCNDEFMessage(records: [payload])

                tag.writeNDEF(message) { error in
                    if let error {
                        session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                        self.onComplete?(.failure(error))
                    } else {
                        session.alertMessage = "Magnet set up successfully!"
                        session.invalidate()
                        self.onComplete?(.success(()))
                    }
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Only report if it's not a user cancellation
        let nfcError = error as? NFCReaderError
        if nfcError?.code != .readerSessionInvalidationErrorUserCanceled {
            onComplete?(.failure(error))
        }
        self.session = nil
        onComplete = nil
    }
}

// MARK: - NFC Errors

enum NFCError: LocalizedError {
    case notAvailable
    case noTag
    case notWritable
    case payloadError

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
        }
    }
}
