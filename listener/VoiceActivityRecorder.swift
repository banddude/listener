//
//  VoiceActivityRecorder.swift
//  listener
//
//  Created by Mike Shaffer on 5/23/25.
//

import Foundation
import AVFoundation
import Speech
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

class VoiceActivityRecorder: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isListening = false
    @Published var isSpeechDetected = false
    @Published var isRecordingClip = false
    @Published var currentClipDuration: TimeInterval = 0
    @Published var clipsCount = 0
    @Published var statusMessage = "Ready"
    @Published var errorMessage = ""
    @Published var savedRecordings: [URL] = []
    @Published var currentlyPlayingURL: URL?
    @Published var silenceThreshold: TimeInterval = 5.0
    
    // MARK: - Audio Components
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioBuffer: CircularAudioBuffer
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - Configuration
    private let sampleRate: Double = 44_100
    private let channels: AVAudioChannelCount = 1
    private let bufferDuration: TimeInterval = 30.0  // 30 seconds for pre-speech
    private let preRecordingDuration: TimeInterval = 2.0
    
    // MARK: - Recording State
    private var speechStartTime: Date?
    private var lastSpeechTime: Date?
    private var silenceTimer: Timer?
    private var clipUpdateTimer: Timer?
    private var currentRecordingData = Data()
    private var hasMeaningfulSpeech = false
    
    // Streaming to disk for long conversations
    private var activeRecordingFileURL: URL?
    private var isRecordingToFile = false
    
    // MARK: - File Management
    private let recordingsURL: URL
    
    override init() {
        // Create recordings directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingsURL = documentsPath.appendingPathComponent("VoiceRecordings")
        
        // Initialize audio buffer
        audioBuffer = CircularAudioBuffer(
            sampleRate: sampleRate,
            channels: channels,
            duration: bufferDuration
        )
        
        super.init()
        
        // Create recordings directory
        createRecordingsDirectory()
        setupAudio()
        setupSpeechRecognizer()
        refreshRecordings()
        setupBackgroundNotifications()
    }
    
    // MARK: - Setup Methods
    private func setupAudio() {
        // Configure audio session for both recording and playback with background support
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playAndRecord category to support both operations
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            
            // Add observer for audio interruptions
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioInterruption),
                name: AVAudioSession.interruptionNotification,
                object: audioSession
            )
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            }
        }
        #endif
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    private func createRecordingsDirectory() {
        do {
            try FileManager.default.createDirectory(at: recordingsURL, withIntermediateDirectories: true)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create recordings directory: \(error.localizedDescription)"
            }
        }
    }
    
    private func setupBackgroundNotifications() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }
    
    // MARK: - Permission Handling
    func requestPermissions() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.statusMessage = "Ready to listen"
                case .denied, .restricted:
                    self?.errorMessage = "Speech recognition permission denied"
                case .notDetermined:
                    self?.statusMessage = "Waiting for speech permission..."
                @unknown default:
                    self?.errorMessage = "Unknown speech permission status"
                }
            }
        }
        
        // Request microphone permission
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.statusMessage = "Microphone permission granted"
                } else {
                    self?.errorMessage = "Microphone permission denied"
                }
            }
        }
    }
    
    // MARK: - Recording Control
    func startListening() {
        guard !isListening else { return }
        
        // Clear any previous error messages
        DispatchQueue.main.async {
            self.errorMessage = ""
            self.statusMessage = "Starting..."
        }
        
        do {
            // Start audio engine
            try startAudioEngine()
            
            // Start speech recognition
            startSpeechRecognition()
            
            DispatchQueue.main.async {
                self.isListening = true
                self.statusMessage = "Listening for speech..."
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start listening: \(error.localizedDescription)"
                
                // Clear error after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.errorMessage = ""
                    self.statusMessage = "Ready"
                }
            }
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Stop speech recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Stop any timers
        silenceTimer?.invalidate()
        clipUpdateTimer?.invalidate()
        
        // Finish any current recording
        if isRecordingClip {
            finishCurrentClip()
        }
        
        DispatchQueue.main.async {
            self.isListening = false
            self.isSpeechDetected = false
            self.isRecordingClip = false
            self.currentClipDuration = 0
            self.statusMessage = "Stopped listening"
        }
    }
    
    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Always add to circular buffer for pre-recording
        audioBuffer.append(buffer: buffer)
        
        // If actively recording a conversation, also stream to disk
        if isRecordingToFile {
            appendToActiveRecording(buffer: buffer)
        }
        
        // Also add to speech recognizer if we have one
        recognitionRequest?.append(buffer)
    }
    
    private func appendToActiveRecording(buffer: AVAudioPCMBuffer) {
        guard let fileURL = activeRecordingFileURL,
              let channelData = buffer.floatChannelData?[0] else { 
            print("❌ No file URL or channel data")
            return 
        }
        
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        // Convert float samples to 16-bit PCM data
        var pcmData = Data()
        for sample in samples {
            let clampedSample = max(-1.0, min(1.0, sample))
            let intSample = Int16(clampedSample * 32_767.0)
            let littleEndianSample = intSample.littleEndian
            withUnsafeBytes(of: littleEndianSample) { bytes in
                pcmData.append(contentsOf: bytes)
            }
        }
        
        // Append to file using more robust method
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let existingData = try Data(contentsOf: fileURL)
                let combinedData = existingData + pcmData
                try combinedData.write(to: fileURL)
                print("📝 Appended \(pcmData.count) bytes, total: \(combinedData.count)")
            } else {
                try pcmData.write(to: fileURL)
                print("📝 Created file with \(pcmData.count) bytes")
            }
        } catch {
            print("❌ Error writing to temp file: \(error)")
        }
    }
    
    private func startSpeechRecognition() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                self?.handleSpeechRecognitionResult(result)
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    let errorMessage = error.localizedDescription
                    
                    // Only show persistent error for serious errors, not cancellation
                    if errorMessage.contains("Cancelled") || errorMessage.contains("canceled") {
                        // For cancellation, just clear the error and continue
                        self?.errorMessage = ""
                        
                        // If recognition was cancelled during recording, finish the clip
                        if self?.isRecordingClip == true {
                            self?.finishCurrentClip()
                        }
                    } else {
                        // For other errors, show briefly then clear
                        self?.errorMessage = "Speech recognition error: \(errorMessage)"
                        
                        // Clear error after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            self?.errorMessage = ""
                        }
                        
                        // For serious errors during recording, finish the clip instead of canceling
                        // to preserve long recordings that may have speech recognition timeouts
                        if self?.isRecordingClip == true {
                            print("🔄 Speech recognition error during recording - finishing clip to preserve recording")
                            self?.finishCurrentClip()
                        }
                    }
                    
                    // Try to restart recognition if we're still supposed to be listening
                    if self?.isListening == true {
                        print("🔄 Restarting speech recognition due to error")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.restartSpeechRecognition()
                        }
                    }
                }
            }
        }
    }
    
    private func restartSpeechRecognition() {
        guard isListening else { return }
        
        // Clean up old recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Start new recognition
        startSpeechRecognition()
    }
    
    private func handleSpeechRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let now = Date()
        let transcription = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !transcription.isEmpty {
            print("🎤 Speech detected: '\(transcription)' at \(now)")
            DispatchQueue.main.async {
                self.isSpeechDetected = true
                self.lastSpeechTime = now
                self.hasMeaningfulSpeech = true
                
                if !self.isRecordingClip {
                    print("🔴 Starting new recording clip")
                    self.startRecordingClip()
                }
                
                self.resetSilenceTimer()
            }
        }
    }
    
    private func startRecordingClip() {
        guard !isRecordingClip else { return }
        
        speechStartTime = Date()
        lastSpeechTime = Date()
        // Don't reset hasMeaningfulSpeech - it was set by speech detection that triggered this
        
        print("🎯 Starting clip with hasMeaningfulSpeech: \(hasMeaningfulSpeech)")
        
        // Start streaming to temp file
        let tempFileName = "temp_recording_\(UUID().uuidString).pcm"
        activeRecordingFileURL = recordingsURL.appendingPathComponent(tempFileName)
        
        if let fileURL = activeRecordingFileURL {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        isRecordingToFile = true
        
        DispatchQueue.main.async {
            self.isRecordingClip = true
            self.statusMessage = "Recording speech clip..."
            self.currentClipDuration = 0
        }
        
        // Start clip duration timer
        clipUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.speechStartTime else { return }
            
            DispatchQueue.main.async {
                self.currentClipDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            print("⏰ Silence timer triggered after \(self?.silenceThreshold ?? 0)s - finishing clip")
            DispatchQueue.main.async {
                self?.isSpeechDetected = false
                self?.finishCurrentClip()
            }
        }
    }
    
    private func finishCurrentClip() {
        guard let startTime = speechStartTime,
              let endTime = lastSpeechTime else { 
            print("❌ Missing timestamps - start: \(speechStartTime?.description ?? "nil"), end: \(lastSpeechTime?.description ?? "nil")")
            resetRecordingState()
            return 
        }
        
        clipUpdateTimer?.invalidate()
        isRecordingToFile = false
        
        let actualSpeechDuration = endTime.timeIntervalSince(startTime)
        let clipDuration = actualSpeechDuration + 4.0  // 2 seconds before + 2 seconds after
        print("🎯 Finishing clip - Speech: \(String(format: "%.1f", actualSpeechDuration))s, Total: \(String(format: "%.1f", clipDuration))s, HasSpeech: \(hasMeaningfulSpeech)")
        print("🔍 Save conditions - HasSpeech: \(hasMeaningfulSpeech), Speech > 3.0s: \(actualSpeechDuration > 3.0)")
        
        // Always save if we're actively recording (isRecordingClip was true) OR have meaningful speech
        // This ensures long recordings don't get lost due to speech recognition restarts
        let shouldSave = hasMeaningfulSpeech || isRecordingClip
        print("🔍 Final save decision - ShouldSave: \(shouldSave) (HasSpeech: \(hasMeaningfulSpeech), WasRecording: \(isRecordingClip))")
        
        if shouldSave {
            // Get pre-recording audio from circular buffer (if available)
            let preRecordingStart = startTime.addingTimeInterval(-preRecordingDuration)
            let preAudioData = audioBuffer.extractAudio(from: preRecordingStart, duration: preRecordingDuration)
            
            if let tempFileURL = activeRecordingFileURL {
                print("🔍 Pre-audio size: \(preAudioData?.count ?? 0) bytes")
                
                // Check if temp file exists and get its size
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    do {
                        let mainAudioData = try Data(contentsOf: tempFileURL)
                        print("🔍 Main audio size: \(mainAudioData.count) bytes")
                        
                        if !mainAudioData.isEmpty {
                            // Combine pre-recording + main recording + post silence
                            if let preAudio = preAudioData {
                                let combinedAudio = combineAudioData(preAudio: preAudio, mainAudio: mainAudioData)
                                saveClipToDisk(audioData: combinedAudio, startTime: startTime)
                                print("✅ Saved combined audio: \(combinedAudio.count) bytes")
                            } else {
                                // No pre-audio available (too old), just save main recording
                                let audioData = createWAVFile(from: mainAudioData)
                                saveClipToDisk(audioData: audioData, startTime: startTime)
                                print("✅ Saved main audio only: \(audioData.count) bytes")
                            }
                        } else {
                            // Fall back to just pre-audio if main recording is empty
                            if let preAudio = preAudioData {
                                print("⚠️ Main recording empty, using pre-audio only")
                                saveClipToDisk(audioData: preAudio, startTime: startTime)
                            } else {
                                print("❌ No audio data available to save")
                            }
                        }
                        
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: tempFileURL)
                        activeRecordingFileURL = nil
                        
                        DispatchQueue.main.async {
                            self.statusMessage = "Clip saved (\(String(format: "%.1f", clipDuration))s) - Listening for speech..."
                        }
                    } catch {
                        print("❌ Error reading temp file: \(error)")
                        // Fall back to pre-audio only
                        if let preAudio = preAudioData {
                            saveClipToDisk(audioData: preAudio, startTime: startTime)
                        }
                        try? FileManager.default.removeItem(at: tempFileURL)
                        activeRecordingFileURL = nil
                        
                        DispatchQueue.main.async {
                            self.statusMessage = "Clip saved (fallback) - Listening for speech..."
                        }
                    }
                } else {
                    if let preAudio = preAudioData {
                        print("❌ Temp file doesn't exist, using pre-audio only")
                        saveClipToDisk(audioData: preAudio, startTime: startTime)
                        activeRecordingFileURL = nil
                        
                        DispatchQueue.main.async {
                            self.statusMessage = "Clip saved (pre-audio only) - Listening for speech..."
                        }
                    } else {
                        print("❌ No audio data available to save")
                        activeRecordingFileURL = nil
                        
                        DispatchQueue.main.async {
                            self.statusMessage = "No audio data to save - Listening for speech..."
                        }
                    }
                }
            }
        } else {
            print("❌ NOT SAVING - Speech: \(String(format: "%.1f", actualSpeechDuration))s, HasSpeech: \(hasMeaningfulSpeech), WasRecording: \(isRecordingClip) - No speech detected")
            DispatchQueue.main.async {
                self.statusMessage = "No speech detected - Listening for speech..."
            }
        }
        
        // Reset state
        resetRecordingState()
    }
    
    private func combineAudioData(preAudio: Data, mainAudio: Data) -> Data {
        // Extract PCM data from WAV files and combine
        let preAudioPCM = extractPCMData(from: preAudio)
        
        // Create new WAV file with combined audio
        return createWAVFile(from: preAudioPCM + mainAudio)
    }
    
    private func extractPCMData(from wavData: Data) -> Data {
        // Skip WAV header (44 bytes) and return just PCM data
        guard wavData.count > 44 else { return Data() }
        return wavData.subdata(in: 44..<wavData.count)
    }
    
    private func createWAVFile(from pcmData: Data) -> Data {
        let sampleRate: UInt32 = 44_100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let frameSize = channels * bitsPerSample / 8
        let byteRate = sampleRate * UInt32(frameSize)
        let dataSize = UInt32(pcmData.count)
        let fileSize = dataSize + 36
        
        var header = Data()
        
        // RIFF header
        header.append("RIFF".data(using: .ascii)!)
        var fileSizeLE = fileSize.littleEndian
        header.append(Data(bytes: &fileSizeLE, count: 4))
        header.append("WAVE".data(using: .ascii)!)
        
        // Format chunk
        header.append("fmt ".data(using: .ascii)!)
        let fmtSize: UInt32 = 16
        var fmtSizeLE = fmtSize.littleEndian
        header.append(Data(bytes: &fmtSizeLE, count: 4))
        let audioFormat: UInt16 = 1
        var audioFormatLE = audioFormat.littleEndian
        header.append(Data(bytes: &audioFormatLE, count: 2))
        var channelsLE = channels.littleEndian
        header.append(Data(bytes: &channelsLE, count: 2))
        var sampleRateLE = sampleRate.littleEndian
        header.append(Data(bytes: &sampleRateLE, count: 4))
        var byteRateLE = byteRate.littleEndian
        header.append(Data(bytes: &byteRateLE, count: 4))
        var frameSizeLE = frameSize.littleEndian
        header.append(Data(bytes: &frameSizeLE, count: 2))
        var bitsPerSampleLE = bitsPerSample.littleEndian
        header.append(Data(bytes: &bitsPerSampleLE, count: 2))
        
        // Data chunk
        header.append("data".data(using: .ascii)!)
        var dataSizeLE = dataSize.littleEndian
        header.append(Data(bytes: &dataSizeLE, count: 4))
        
        return header + pcmData
    }
    
    private func resetRecordingState() {
        isRecordingClip = false
        speechStartTime = nil
        lastSpeechTime = nil
        currentClipDuration = 0
        hasMeaningfulSpeech = false
    }
    
    private func cancelCurrentRecording() {
        clipUpdateTimer?.invalidate()
        silenceTimer?.invalidate()
        
        DispatchQueue.main.async {
            self.resetRecordingState()
            if self.isListening {
                self.statusMessage = "Listening for speech..."
            } else {
                self.statusMessage = "Ready"
            }
        }
    }
    
    private func saveClipToDisk(audioData: Data, startTime: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: startTime)
        
        let filename = "speech_\(timestamp).wav"
        let fileURL = recordingsURL.appendingPathComponent(filename)
        
        do {
            // audioData already includes WAV header from CircularAudioBuffer
            try audioData.write(to: fileURL)
            
            DispatchQueue.main.async {
                self.clipsCount += 1
                self.refreshRecordings()
                print("Saved clip: \(fileURL.path)")
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to save clip: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - File Management
    func refreshRecordings() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: recordingsURL, includingPropertiesForKeys: [.creationDateKey], options: [])
            let audioFiles = files.filter { $0.pathExtension.lowercased() == "wav" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
            
            DispatchQueue.main.async {
                self.savedRecordings = audioFiles
                self.clipsCount = audioFiles.count
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load recordings: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteRecording(_ url: URL) {
        // Stop playback if this file is currently playing
        if currentlyPlayingURL == url {
            stopPlayback()
        }
        
        do {
            try FileManager.default.removeItem(at: url)
            DispatchQueue.main.async {
                self.refreshRecordings()
                self.statusMessage = "Recording deleted"
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to delete recording: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Audio Playback
    func playRecording(_ url: URL) {
        stopPlayback() // Stop any current playback
        
        #if os(iOS)
        // Ensure audio session is active for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to activate audio session for playback: \(error.localizedDescription)"
            }
            return
        }
        #endif
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            DispatchQueue.main.async {
                self.currentlyPlayingURL = url
                self.statusMessage = "Playing: \(url.lastPathComponent)"
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to play recording: \(error.localizedDescription)"
            }
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        DispatchQueue.main.async {
            self.currentlyPlayingURL = nil
            if self.isListening {
                self.statusMessage = "Listening for speech..."
            } else {
                self.statusMessage = "Ready"
            }
        }
    }
    
    // MARK: - Sharing
    func shareRecording(_ url: URL) {
        // For iOS, we'll print the path and show in status
        DispatchQueue.main.async {
            self.statusMessage = "File location: \(url.path)"
        }
        print("Recording location: \(url.path)")
        
        // Share functionality - platform specific
        #if canImport(UIKit)
        UIPasteboard.general.string = url.path
        #elseif canImport(AppKit)
        NSPasteboard.general.setString(url.path, forType: .string)
        #endif
    }
    
    // MARK: - Helper Methods
    func clearError() {
        errorMessage = ""
    }
    
    // MARK: - Audio Interruption Handling
    @objc private func handleAudioInterruption(notification: Notification) {
        #if os(iOS)
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began, pause recording
            if isListening {
                DispatchQueue.main.async {
                    self.statusMessage = "Audio interrupted..."
                }
            }
        case .ended:
            // Interruption ended, resume if needed
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                // Resume recording if we were listening before
                if isListening {
                    DispatchQueue.main.async {
                        self.statusMessage = "Resuming listening..."
                    }
                    // Restart audio engine
                    try? startAudioEngine()
                }
            }
        @unknown default:
            break
        }
        #endif
    }
    
    @objc private func appDidEnterBackground() {
        #if os(iOS)
        DispatchQueue.main.async {
            self.statusMessage = "Listening in background..."
        }
        #endif
    }
    
    @objc private func appWillEnterForeground() {
        #if os(iOS)
        if isListening {
            DispatchQueue.main.async {
                self.statusMessage = "Listening for speech..."
            }
        }
        #endif
    }
}

// MARK: - Speech Recognizer Delegate
extension VoiceActivityRecorder: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if available {
                self.statusMessage = "Speech recognizer available"
            } else {
                self.errorMessage = "Speech recognizer unavailable"
            }
        }
    }
}

// MARK: - Audio Player Delegate
extension VoiceActivityRecorder: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.currentlyPlayingURL = nil
            if self.isListening {
                self.statusMessage = "Listening for speech..."
            } else {
                self.statusMessage = "Ready"
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.currentlyPlayingURL = nil
            self.errorMessage = "Playback error: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}
