//
//  ComposeView.swift
//  Pidgn
//
//  Write a letter — quill, portrait, or songbird. Like sitting down with pen and paper.

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Stationery Moods

enum Stationery: String, CaseIterable, Identifiable {
    case parchment, midnight, heron, rosewater

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .parchment: "Parchment"
        case .midnight: "Midnight"
        case .heron: "Heron"
        case .rosewater: "Rosewater"
        }
    }

    var icon: String {
        switch self {
        case .parchment: "leaf"
        case .midnight: "moon.stars"
        case .heron: "water.waves"
        case .rosewater: "leaf.arrow.circlepath"
        }
    }

    var paperGradient: LinearGradient {
        switch self {
        case .parchment:
            LinearGradient(colors: [
                Color(red: 0.98, green: 0.95, blue: 0.90),
                Color(red: 0.94, green: 0.88, blue: 0.78),
                Color(red: 0.91, green: 0.84, blue: 0.71),
            ], startPoint: .top, endPoint: .bottom)
        case .midnight:
            LinearGradient(colors: [
                Color(red: 0.16, green: 0.15, blue: 0.27),
                Color(red: 0.11, green: 0.09, blue: 0.21),
                Color(red: 0.08, green: 0.07, blue: 0.16),
            ], startPoint: .top, endPoint: .bottom)
        case .heron:
            LinearGradient(colors: [
                Color(red: 0.93, green: 0.96, blue: 0.96),
                Color(red: 0.85, green: 0.91, blue: 0.93),
                Color(red: 0.78, green: 0.87, blue: 0.89),
            ], startPoint: .top, endPoint: .bottom)
        case .rosewater:
            LinearGradient(colors: [
                Color(red: 0.97, green: 0.93, blue: 0.95),
                Color(red: 0.94, green: 0.85, blue: 0.89),
                Color(red: 0.91, green: 0.80, blue: 0.85),
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    var textColor: Color {
        switch self {
        case .parchment: Color(red: 0.24, green: 0.18, blue: 0.12)
        case .midnight: Color(red: 0.83, green: 0.80, blue: 0.91)
        case .heron: Color(red: 0.14, green: 0.24, blue: 0.27)
        case .rosewater: Color(red: 0.26, green: 0.15, blue: 0.18)
        }
    }

    var accentColor: Color {
        switch self {
        case .parchment: Color(red: 0.76, green: 0.48, blue: 0.35)
        case .midnight: Color(red: 0.61, green: 0.56, blue: 0.77)
        case .heron: Color(red: 0.35, green: 0.61, blue: 0.67)
        case .rosewater: Color(red: 0.72, green: 0.42, blue: 0.51)
        }
    }

    var lineColor: Color {
        accentColor.opacity(0.12)
    }
}

// MARK: - Letter Type

enum LetterType: String, CaseIterable {
    case quill = "text"
    case portrait = "photo"
    case songbird = "voice"

    var label: String {
        switch self {
        case .quill: "Quill"
        case .portrait: "Portrait"
        case .songbird: "Songbird"
        }
    }

    var icon: String {
        switch self {
        case .quill: "pencil.line"
        case .portrait: "photo"
        case .songbird: "waveform"
        }
    }
}

// MARK: - Send Phase

enum SendPhase: Equatable {
    case idle, folding, sealing, dispatched
    case failed(String)
}

// MARK: - Compose View

struct ComposeView: View {
    @Environment(AuthService.self) var authService
    @Environment(\.dismiss) var dismiss

    // Data
    @State private var contacts: [Contact] = []
    @State private var selectedContact: Contact?
    @State private var messageText = ""
    @State private var isLoadingContacts = false
    @State private var errorMessage: String?

    // Photo
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    // Voice
    @State private var audioRecorder = AudioRecorderService()
    @State private var hasVoiceRecording = false

    // Compose design
    @State private var letterType: LetterType = .quill
    @State private var stationery: Stationery = .parchment
    @State private var sendPhase: SendPhase = .idle
    @State private var didDispatch = false

    struct Contact: Identifiable, Hashable {
        let id: String
        let name: String
    }

    private var householdId: String? {
        authService.userProfile?.householdId
    }

    private var canSend: Bool {
        guard selectedContact != nil, sendPhase == .idle else { return false }
        switch letterType {
        case .quill:
            return !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && messageText.count <= 500
        case .portrait:
            return selectedImage != nil
        case .songbird:
            return hasVoiceRecording && !audioRecorder.isRecording
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.06, blue: 0.05)
                .ignoresSafeArea()

            if sendPhase == .idle {
                composeContent
            } else {
                dispatchAnimation
            }
        }
        .navigationTitle("New Letter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if sendPhase != .idle {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .task { await loadContacts() }
        .sensoryFeedback(.success, trigger: didDispatch)
    }

    // MARK: - Compose Content

    private var composeContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    composeHeader
                    recipientSection
                    typeSelector
                    stationeryPicker
                    inkwell
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .foregroundStyle(.red.opacity(0.8))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }

            dispatchButton
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Header

    private var composeHeader: some View {
        VStack(spacing: 4) {
            Image(systemName: "pencil.line")
                .font(.system(size: 28))
                .foregroundStyle(PidgnTheme.accent)
            Text("Compose")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Take your time. No rush.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Recipient

    private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Addressed to")

            if isLoadingContacts {
                HStack {
                    ProgressView().tint(.white.opacity(0.4))
                    Spacer()
                }
                .padding(13)
                .background(glassBackground)
            } else if contacts.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "bird")
                        .foregroundStyle(.white.opacity(0.2))
                    Text("No one in your flock yet")
                        .foregroundStyle(.white.opacity(0.35))
                        .font(.system(size: 14, design: .rounded))
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(glassBackground)
            } else {
                Menu {
                    Button("Choose someone") { selectedContact = nil }
                    ForEach(contacts) { contact in
                        Button(contact.name) { selectedContact = contact }
                    }
                } label: {
                    HStack {
                        Text("Recipient")
                            .foregroundStyle(.white.opacity(0.35))
                            .font(.system(size: 14, design: .rounded))
                        Spacer()
                        Text(selectedContact?.name ?? "Choose someone")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(selectedContact != nil ? 0.75 : 0.4))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(13)
                    .background(glassBackground)
                }
            }
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()
                ForEach(LetterType.allCases, id: \.rawValue) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            letterType = type
                        }
                        clearMediaState()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: type.icon)
                                .font(.system(size: 13))
                            Text(type.label)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(letterType == type ? .white.opacity(0.1) : .clear)
                        )
                        .foregroundStyle(letterType == type ? .white.opacity(0.9) : .white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(3)
            .background(glassBackground)
        }
    }

    // MARK: - Stationery Picker

    private var stationeryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Stationery")

            HStack(spacing: 8) {
                ForEach(Stationery.allCases) { s in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            stationery = s
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: s.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(s.accentColor)
                            Text(s.displayName)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(s.textColor.opacity(0.7))
                                .textCase(.uppercase)
                                .tracking(0.3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(s.paperGradient)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(stationery == s ? s.accentColor : .clear, lineWidth: 2)
                        )
                        .scaleEffect(stationery == s ? 1.02 : 1.0)
                        .shadow(color: .black.opacity(stationery == s ? 0.25 : 0.1), radius: stationery == s ? 8 : 3, y: stationery == s ? 4 : 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Inkwell (Writing Area)

    @ViewBuilder
    private var inkwell: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Your ink")

            switch letterType {
            case .quill:
                quillPaper
            case .portrait:
                portraitPaper
            case .songbird:
                songbirdPaper
            }
        }
    }

    private var quillPaper: some View {
        ZStack(alignment: .topLeading) {
            // Paper background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(stationery.paperGradient)

            // Ruled lines
            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { _ in
                    Color.clear
                        .frame(height: 30)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(stationery.lineColor)
                                .frame(height: 1)
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Text editor
            TextEditor(text: $messageText)
                .font(.custom("Bradley Hand", size: 18))
                .lineSpacing(10.5)
                .foregroundStyle(stationery.textColor)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .onChange(of: messageText) { _, new in
                    if new.count > 500 { messageText = String(new.prefix(500)) }
                }

            // Character counter
            Text("\(messageText.count)/500")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(stationery.textColor.opacity(0.25))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 14)
                .padding(.bottom, 8)
        }
        .frame(height: 290)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    private var portraitPaper: some View {
        VStack(spacing: 0) {
            // Photo area
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(stationery.paperGradient)

                if let image = selectedImage {
                    VStack(spacing: 12) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        Button {
                            selectedPhoto = nil
                            selectedImage = nil
                        } label: {
                            Text("Remove")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(stationery.textColor.opacity(0.5))
                        }
                        .padding(.bottom, 8)
                    }
                } else {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 28))
                                .foregroundStyle(stationery.accentColor.opacity(0.6))
                            Text("Choose a photo")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(stationery.textColor.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }

            // Caption
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(stationery.paperGradient)

                TextField("Add a caption...", text: $messageText)
                    .font(.custom("Bradley Hand", size: 16))
                    .foregroundStyle(stationery.textColor)
                    .padding(14)
                    .onChange(of: messageText) { _, new in
                        if new.count > 200 { messageText = String(new.prefix(200)) }
                    }

                Text("\(messageText.count)/200")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(stationery.textColor.opacity(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 12)
                    .padding(.bottom, 6)
            }
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 10)
        }
    }

    private var songbirdPaper: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(stationery.paperGradient)

            VStack(spacing: 16) {
                if audioRecorder.isRecording {
                    // Recording in progress
                    VStack(spacing: 14) {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("Recording...")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(stationery.textColor)
                            Spacer()
                            Text(formatDuration(audioRecorder.recordingDuration))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(stationery.textColor)
                        }

                        ProgressView(
                            value: audioRecorder.recordingDuration,
                            total: AudioRecorderService.maxDuration
                        )
                        .tint(stationery.accentColor)

                        Button {
                            audioRecorder.stopRecording()
                            hasVoiceRecording = true
                        } label: {
                            Text("Stop")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.red))
                        }
                    }
                } else if hasVoiceRecording {
                    // Recording ready
                    VStack(spacing: 14) {
                        Image(systemName: "waveform")
                            .font(.system(size: 32))
                            .foregroundStyle(stationery.accentColor)

                        HStack {
                            Text("Voice note ready")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(stationery.textColor)
                            Spacer()
                            Text(formatDuration(audioRecorder.recordingDuration))
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(stationery.textColor.opacity(0.5))
                        }

                        Button {
                            audioRecorder.deleteRecording()
                            hasVoiceRecording = false
                        } label: {
                            Text("Re-record")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                    }
                } else {
                    // Ready to record
                    VStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(stationery.accentColor.opacity(0.6))

                        Button {
                            audioRecorder.startRecording()
                        } label: {
                            Text("Start Recording")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(stationery.accentColor))
                        }

                        Text("Up to 60 seconds — say it from the heart.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(stationery.textColor.opacity(0.4))
                    }
                }

                if let error = audioRecorder.errorMessage {
                    Text(error)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
            .padding(20)
        }
        .frame(minHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    // MARK: - Dispatch Button

    private var dispatchButton: some View {
        Button {
            Task { await dispatch() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 14))
                Text("Seal & Dispatch")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(canSend ? Color(red: 0.99, green: 0.96, blue: 0.93) : .white.opacity(0.2))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        canSend
                            ? LinearGradient(
                                colors: [PidgnTheme.accent, Color(red: 0.66, green: 0.38, blue: 0.25)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [.white.opacity(0.06), .white.opacity(0.04)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .shadow(color: canSend ? PidgnTheme.accent.opacity(0.3) : .clear, radius: 12, y: 4)
        }
        .disabled(!canSend)
        .buttonStyle(.plain)
    }

    // MARK: - Dispatch Animation

    private var dispatchAnimation: some View {
        VStack(spacing: 0) {
            Spacer()

            // Envelope
            ZStack {
                // Letter paper sliding into envelope
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(stationery.paperGradient)
                    .frame(width: 160, height: 90)
                    .overlay {
                        // Fake text lines
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach([0.9, 0.75, 0.6, 0.45], id: \.self) { w in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(stationery.textColor.opacity(0.15))
                                    .frame(width: 130 * w, height: 3)
                            }
                        }
                        .padding(14)
                    }
                    .offset(y: sendPhase == .folding ? -15 : -40)
                    .opacity(sendPhase == .folding ? 0.85 : 0)

                // Envelope body
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.87, blue: 0.78),
                            Color(red: 0.90, green: 0.82, blue: 0.71),
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 200, height: 130)
                    .overlay {
                        // V-lines
                        EnvelopeVLines()
                            .stroke(Color.brown.opacity(0.12), lineWidth: 0.8)
                    }
                    .overlay(alignment: .bottom) {
                        Text(selectedContact?.name ?? "")
                            .font(.custom("Bradley Hand", size: 14))
                            .foregroundStyle(Color.brown.opacity(0.4))
                            .padding(.bottom, 20)
                    }

                // Envelope flap
                EnvelopeFlapShape()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.91, green: 0.82, blue: 0.72),
                            Color(red: 0.94, green: 0.87, blue: 0.78),
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 200, height: 70)
                    .offset(y: -60)
                    .rotation3DEffect(
                        .degrees(sendPhase == .sealing || sendPhase == .dispatched ? 180 : 0),
                        axis: (1, 0, 0),
                        anchor: .top
                    )
                    .zIndex(sendPhase == .folding ? 2 : 0)

                // Wax seal
                if sendPhase == .sealing || sendPhase == .dispatched || sendPhase != .folding && sendPhase != .idle {
                    WaxSealStamp()
                        .scaleEffect(sendPhase == .sealing || sendPhase == .dispatched ? 1 : 2.5)
                        .opacity(sendPhase == .sealing || sendPhase == .dispatched ? 1 : 0)
                        .offset(y: -5)
                }
            }
            .frame(width: 220, height: 170)

            // Status text
            VStack(spacing: 8) {
                Text(dispatchTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(dispatchSubtitle)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            if sendPhase == .dispatched {
                Button {
                    resetCompose()
                } label: {
                    Text("Write another letter")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                                .fill(.white.opacity(0.04))
                        )
                }
                .padding(.top, 32)
            }

            if case .failed(let msg) = sendPhase {
                VStack(spacing: 12) {
                    Text(msg)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.red.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        withAnimation { sendPhase = .idle }
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(PidgnTheme.accent)
                }
                .padding(.top, 24)
            }

            Spacer()
        }
    }

    private var dispatchTitle: String {
        switch sendPhase {
        case .folding: "Folding your letter..."
        case .sealing: "Pressing the seal..."
        case .dispatched: "Letter dispatched"
        case .failed: "Couldn't send"
        case .idle: ""
        }
    }

    private var dispatchSubtitle: String {
        switch sendPhase {
        case .folding: "Tucking in the edges with care"
        case .sealing: "Stamping the wax seal"
        case .dispatched: "Your letter is on its way to \(selectedContact?.name ?? "them")"
        case .failed: ""
        case .idle: ""
        }
    }

    // MARK: - Helpers

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.04), lineWidth: 1)
            )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.3))
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func clearMediaState() {
        selectedPhoto = nil
        selectedImage = nil
        if audioRecorder.isRecording { audioRecorder.stopRecording() }
        audioRecorder.deleteRecording()
        hasVoiceRecording = false
    }

    private func resetCompose() {
        withAnimation(.easeInOut(duration: 0.3)) {
            sendPhase = .idle
        }
        messageText = ""
        selectedPhoto = nil
        selectedImage = nil
        audioRecorder.deleteRecording()
        hasVoiceRecording = false
        selectedContact = nil
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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

    private func dispatch() async {
        guard canSend, let contact = selectedContact, let householdId else { return }

        // Start folding animation
        withAnimation(.easeInOut(duration: 0.5)) { sendPhase = .folding }

        let startTime = Date()

        // Actually send the message
        let sendError = await performSend(contact: contact, householdId: householdId)

        // Ensure minimum folding duration for animation
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < 1.1 {
            try? await Task.sleep(for: .seconds(1.1 - elapsed))
        }

        if let sendError {
            withAnimation { sendPhase = .failed(sendError) }
            return
        }

        // Sealing animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            sendPhase = .sealing
        }

        try? await Task.sleep(for: .seconds(1.0))

        // Dispatched
        withAnimation(.easeInOut(duration: 0.4)) {
            sendPhase = .dispatched
            didDispatch = true
        }
    }

    private func performSend(contact: Contact, householdId: String) async -> String? {
        do {
            let messageId = UUID().uuidString
            var mediaUrl: String?

            switch letterType {
            case .quill:
                break

            case .portrait:
                guard let image = selectedImage,
                      let compressed = MediaService.shared.compressImage(image) else {
                    return "Failed to compress image."
                }
                mediaUrl = try await MediaService.shared.uploadImage(
                    compressed,
                    householdId: householdId,
                    messageId: messageId
                )

            case .songbird:
                guard let audioURL = audioRecorder.recordingURL else {
                    return "No recording found."
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
                type: letterType.rawValue,
                mediaUrl: mediaUrl
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

// MARK: - Envelope Shapes

private struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: rect.width, y: 0))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.height))
            p.closeSubpath()
        }
    }
}

private struct EnvelopeVLines: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.42))
            p.addLine(to: CGPoint(x: rect.width, y: 0))
            p.move(to: CGPoint(x: 0, y: rect.height))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.54))
            p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        }
    }
}

// MARK: - Wax Seal Stamp

private struct WaxSealStamp: View {
    var body: some View {
        ZStack {
            // Seal burst shape
            SealBurstShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.82, green: 0.52, blue: 0.38),
                            Color(red: 0.68, green: 0.38, blue: 0.25),
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 22
                    )
                )
                .frame(width: 48, height: 48)

            // Inner circle
            Circle()
                .stroke(.white.opacity(0.3), lineWidth: 0.8)
                .frame(width: 22, height: 22)

            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private struct SealBurstShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.72
        let points = 12

        return Path { p in
            for i in 0..<(points * 2) {
                let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
                let angle = Double(i) * .pi / Double(points) - .pi / 2
                let point = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radius,
                    y: center.y + CGFloat(sin(angle)) * radius
                )
                if i == 0 {
                    p.move(to: point)
                } else {
                    p.addLine(to: point)
                }
            }
            p.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ComposeView()
            .environment(AuthService())
    }
}
