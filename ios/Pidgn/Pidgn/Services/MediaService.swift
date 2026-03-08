//
//  MediaService.swift
//  Pidgn
//
//  Handles image compression and Firebase Storage uploads.
//  NOTE: Requires FirebaseStorage package added via SPM in Xcode.

import Foundation
import UIKit
import FirebaseStorage
import FirebaseAuth

class MediaService {
    static let shared = MediaService()
    private let storage = Storage.storage()

    private init() {}

    // MARK: - Image Compression

    func compressImage(_ image: UIImage, maxWidth: CGFloat = 1200, quality: CGFloat = 0.7) -> Data? {
        let ratio = maxWidth / image.size.width
        let newSize: CGSize

        if ratio < 1.0 {
            newSize = CGSize(width: maxWidth, height: image.size.height * ratio)
        } else {
            newSize = image.size
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resized.jpegData(compressionQuality: quality)
    }

    // MARK: - Upload to Firebase Storage

    func uploadImage(
        _ imageData: Data,
        householdId: String,
        messageId: String
    ) async throws -> String {
        let path = "households/\(householdId)/media/\(messageId)/photo.jpg"
        let ref = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func uploadAudio(
        _ audioURL: URL,
        householdId: String,
        messageId: String
    ) async throws -> String {
        let data = try Data(contentsOf: audioURL)
        let path = "households/\(householdId)/media/\(messageId)/voice.m4a"
        let ref = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "audio/mp4"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}
