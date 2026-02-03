//
//  SpeechRecognitionManager.swift
//  Vibey
//
//  Manages speech recognition for voice dictation feature
//  Uses Speech framework for live transcription
//

import Foundation
import Speech
import AVFAudio

class SpeechRecognitionManager: ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    /// Callback when transcription completes (after stopping)
    var onTranscriptionComplete: ((String) -> Void)?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    /// Request authorization for speech recognition
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(true)
                case .denied:
                    self?.errorMessage = "Speech recognition access denied. Enable it in System Settings > Privacy & Security > Speech Recognition."
                    completion(false)
                case .restricted:
                    self?.errorMessage = "Speech recognition is restricted on this device."
                    completion(false)
                case .notDetermined:
                    self?.errorMessage = "Speech recognition not yet authorized."
                    completion(false)
                @unknown default:
                    self?.errorMessage = "Unknown speech recognition authorization status."
                    completion(false)
                }
            }
        }
    }

    /// Start recording and transcribing speech
    func startRecording() {
        guard !isRecording else { return }

        requestAuthorization { [weak self] authorized in
            guard let self = self, authorized else { return }

            DispatchQueue.main.async {
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Reset state
        transcribedText = ""
        errorMessage = nil

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            return
        }

        isRecording = true

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }

            if let error = error {
                DispatchQueue.main.async {
                    // Don't show error for normal cancellation
                    let nsError = error as NSError
                    let isCancellation = nsError.code == 216 ||
                                         nsError.code == 301 ||
                                         error.localizedDescription.lowercased().contains("canceled") ||
                                         error.localizedDescription.lowercased().contains("cancelled")
                    if !isCancellation {
                        self.errorMessage = "Recognition error: \(error.localizedDescription)"
                    }
                    self.stopRecordingInternal()
                }
            }
        }
    }

    /// Stop recording and return transcribed text
    func stopRecording() {
        guard isRecording else { return }

        // Capture final text before stopping
        let finalText = transcribedText

        stopRecordingInternal()

        // Call completion handler with final transcription
        if !finalText.isEmpty {
            onTranscriptionComplete?(finalText)
        }
    }

    private func stopRecordingInternal() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false
    }

    /// Toggle recording state
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}
