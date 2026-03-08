//
//  ComposeView.swift
//  Pidgn
//
//  Write a letter — text, photo, or voice. Like sitting down with pen and paper.

import SwiftUI
import PhotosUI
import UIKit

struct ComposeView: View {
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) var dismiss

    @State private var contacts: [Contact] = []
    @State private var selectedContact: Contact?
    @State private var messageText = ""
    @State private var isLoadingContacts = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showSentConfirmation = false

    // Photo state
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    // Voice state
    @State private var audioRecorder = AudioRecorderService()
    @State private var hasVoiceRecording = false

    // Message type
    enum MessageType: String, CaseIterable {
        case text, photo, voice
    }
    @State private var messageType: MessageType = .text

    struct Contact: Identifiable, Hashable {
        let id: String
        let name: String
    }

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    private var canSend: Bool {
        guard selectedContact != nil, !isSending else { return false }
        switch messageType {
        case .text:
            return !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && messageText.count <= 500
        case .photo:
            return selectedImage != nil
        case .voice:
            return hasVoiceRecording && !audioRecorder.isRecording
        }
    }

    private static let placeholders = [
        "What's on your mind?",
        "Write something lovely...",
        "Dear friend...",
        "A few words go a long way...",
        "Say what the heart says...",
    ]

    private var placeholder: String {
        Self.placeholders[abs(Date().hashValue) % Self.placeholders.count]
    }

    var body: some View {
        Form {
            // Warm header
            Section {
                VStack(spacing: 4) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 28))
                        .foregroundStyle(PidgnTheme.accent)
                    Text("Write a Letter")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("Take your time. No rush.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            // Recipient picker
            Section {
                if isLoadingContacts {
                    ProgressView()
                } else if contacts.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "bird")
                            .foregroundStyle(.tertiary)
                        Text("No one in your flock yet")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 15, design: .rounded))
                    }
                } else {
                    Picker("Recipient", selection: $selectedContact) {
                        Text("Choose someone").tag(nil as Contact?)
                        ForEach(contacts) { contact in
                            Text(contact.name).tag(contact as Contact?)
                        }
                    }
                }
            } header: {
                Text("Deliver to")
            }

            // Message type picker
            Section {
                Picker("Message Type", selection: $messageType) {
                    Label("Text", systemImage: "text.alignleft").tag(MessageType.text)
                    Label("Photo", systemImage: "photo").tag(MessageType.photo)
                    Label("Voice", systemImage: "mic").tag(MessageType.voice)
                }
                .pickerStyle(.segmented)
                .onChange(of: messageType) { _, _ in
                    selectedPhoto = nil
                    selectedImage = nil
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                    }
                    audioRecorder.deleteRecording()
                    hasVoiceRecording = false
                }
            }

            // Content section based on type
            switch messageType {
            case .text:
                textSection
            case .photo:
                photoSection
            case .voice:
                voiceSection
            }

            if let error = errorMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .foregroundStyle(.red)
                    .font(.caption)
                }
            }
        }
        .navigationTitle("New Letter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await sendMessage() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        HStack(spacing: 4) {
                            Text("Send")
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 12))
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(canSend ? PidgnTheme.accent : .secondary)
                    }
                }
                .disabled(!canSend)
            }
        }
        .task {
            await loadContacts()
        }
        .alert("Off it goes!", isPresented: $showSentConfirmation) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your letter has taken flight. 🕊️")
        }
    }

    // MARK: - Text Section

    private var textSection: some View {
        Section("Your Letter") {
            TextEditor(text: $messageText)
                .frame(minHeight: 150)

            HStack {
                Spacer()
                Text("\(messageText.count)/500")
                    .font(.caption)
                    .foregroundStyle(messageText.count > 500 ? Color.red : Color.secondary)
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        Group {
            Section("Photo") {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("Remove Photo", role: .destructive) {
                        selectedPhoto = nil
                        selectedImage = nil
                    }
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(
                        selectedImage == nil ? "Choose Photo" : "Change Photo",
                        systemImage: "photo.on.rectangle"
                    )
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
                }
            }

            Section("Caption (optional)") {
                TextField("Add a caption...", text: $messageText)

                HStack {
                    Spacer()
                    Text("\(messageText.count)/200")
                        .font(.caption)
                        .foregroundStyle(messageText.count > 200 ? Color.red : Color.secondary)
                }
            }
        }
    }

    // MARK: - Voice Section

    private var voiceSection: some View {
        Section("Voice Note") {
            if audioRecorder.isRecording {
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("Recording...")
                            .font(.system(.headline, design: .rounded))
                        Spacer()
                        Text(formatDuration(audioRecorder.recordingDuration))
                            .font(.system(.headline, design: .rounded))
                            .monospacedDigit()
                    }

                    ProgressView(
                        value: audioRecorder.recordingDuration,
                        total: AudioRecorderService.maxDuration
                    )
                    .tint(PidgnTheme.accent)

                    Button("Stop Recording") {
                        audioRecorder.stopRecording()
                        hasVoiceRecording = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.vertical, 8)
            } else if hasVoiceRecording {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(PidgnTheme.accent)
                        Text("Voice note ready")
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        Text(formatDuration(audioRecorder.recordingDuration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Re-record", role: .destructive) {
                        audioRecorder.deleteRecording()
                        hasVoiceRecording = false
                    }
                }
            } else {
                Button {
                    audioRecorder.startRecording()
                } label: {
                    Label("Start Recording", systemImage: "mic.fill")
                        .font(.system(.body, design: .rounded))
                }
                .tint(PidgnTheme.accent)

                Text("Up to 60 seconds — say it from the heart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = audioRecorder.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Actions

    private func loadContacts() async {
        guard let householdId else { return }
        isLoadingContacts = true

        do {
            let response = try await APIService.shared.fetchContacts(householdId: householdId)
            contacts = response.contacts
                .filter { $0.status == "accepted" }
                .map { Contact(id: $0.householdId, name: $0.householdName) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingContacts = false
    }

    private func sendMessage() async {
        guard let contact = selectedContact, let householdId else { return }
        isSending = true
        errorMessage = nil

        do {
            let messageId = UUID().uuidString
            var mediaUrl: String?

            switch messageType {
            case .text:
                break

            case .photo:
                guard let image = selectedImage,
                      let compressed = MediaService.shared.compressImage(image) else {
                    errorMessage = "Failed to compress image."
                    isSending = false
                    return
                }
                mediaUrl = try await MediaService.shared.uploadImage(
                    compressed,
                    householdId: householdId,
                    messageId: messageId
                )

            case .voice:
                guard let audioURL = audioRecorder.recordingURL else {
                    errorMessage = "No recording found."
                    isSending = false
                    return
                }
                mediaUrl = try await MediaService.shared.uploadAudio(
                    audioURL,
                    householdId: householdId,
                    messageId: messageId
                )
            }

            _ = try await APIService.shared.sendMail(
                targetHouseholdId: contact.id,
                content: messageText.trimmingCharacters(in: .whitespacesAndNewlines),
                type: messageType.rawValue,
                mediaUrl: mediaUrl
            )
            showSentConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    NavigationStack {
        ComposeView()
            .environment(AuthService())
    }
}
