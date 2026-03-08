//
//  AudioRecorderService.swift
//  Pidgn
//
//  Records voice memos as AAC/M4A, max 60 seconds.

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
class AudioRecorderService: NSObject, AVAudioRecorderDelegate {
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var recordingURL: URL?
    var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    nonisolated(unsafe) private var timer: Timer?

    static let maxDuration: TimeInterval = 60

    override init() {
        super.init()
    }

    func startRecording() {
        errorMessage = nil
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = "Could not set up audio session: \(error.localizedDescription)"
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 64000,
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record(forDuration: Self.maxDuration)
            recordingURL = url
            isRecording = true
            recordingDuration = 0
            startTimer()
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        stopTimer()
    }

    func deleteRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        recordingDuration = 0
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                self.recordingDuration = self.audioRecorder?.currentTime ?? 0
                if self.recordingDuration >= Self.maxDuration {
                    self.stopRecording()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - AVAudioRecorderDelegate

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            isRecording = false
            stopTimer()
            if !flag {
                errorMessage = "Recording failed."
                recordingURL = nil
            }
        }
    }
}
