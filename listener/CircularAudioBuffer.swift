//
//  CircularAudioBuffer.swift
//  listener
//
//  Created by Mike Shaffer on 5/23/25.
//

import Foundation
import AVFoundation

class CircularAudioBuffer {
    private var buffer: Data
    private let maxSize: Int
    private var writePosition: Int = 0
    private var isFull: Bool = false
    
    private let sampleRate: Double
    private let channels: AVAudioChannelCount
    private let bytesPerSample: Int = 2 // 16-bit samples
    private var timestamps: [Date] = []
    
    private let queue = DispatchQueue(label: "audio.buffer.queue", qos: .userInitiated)
    
    init(sampleRate: Double, channels: AVAudioChannelCount, duration: TimeInterval) {
        self.sampleRate = sampleRate
        self.channels = channels
        
        // Calculate buffer size based on duration
        let samplesPerSecond = Int(sampleRate) * Int(channels)
        let totalSamples = Int(duration) * samplesPerSecond
        self.maxSize = totalSamples * bytesPerSample
        
        self.buffer = Data(count: maxSize)
        self.timestamps.reserveCapacity(Int(duration * 10)) // 10 timestamps per second
    }
    
    func append(buffer audioBuffer: AVAudioPCMBuffer) {
        guard let channelData = audioBuffer.floatChannelData?[0] else { return }
        
        queue.async { [weak self] in
            self?.appendAudioData(channelData: channelData, frameCount: Int(audioBuffer.frameLength))
        }
    }
    
    private func appendAudioData(channelData: UnsafePointer<Float>, frameCount: Int) {
        let timestamp = Date()
        
        // Convert float samples to 16-bit PCM
        var pcmData = Data()
        pcmData.reserveCapacity(frameCount * bytesPerSample)
        
        for i in 0..<frameCount {
            let sample = channelData[i]
            let pcmSample = Int16(max(-32_768, min(32_767, sample * 32_767)))
            
            withUnsafeBytes(of: pcmSample.littleEndian) { bytes in
                pcmData.append(contentsOf: bytes)
            }
        }
        
        // Add to circular buffer
        let dataSize = pcmData.count
        
        if writePosition + dataSize <= maxSize {
            // Simple case: data fits without wrapping
            buffer.replaceSubrange(writePosition..<(writePosition + dataSize), with: pcmData)
        } else {
            // Wrap around case
            let firstPartSize = maxSize - writePosition
            let secondPartSize = dataSize - firstPartSize
            
            // First part (to end of buffer)
            buffer.replaceSubrange(writePosition..<maxSize, with: pcmData.prefix(firstPartSize))
            
            // Second part (from beginning of buffer)
            buffer.replaceSubrange(0..<secondPartSize, with: pcmData.suffix(secondPartSize))
        }
        
        // Update write position
        writePosition = (writePosition + dataSize) % maxSize
        
        if writePosition < dataSize && !isFull {
            isFull = true
        }
        
        // Store timestamp for this position
        timestamps.append(timestamp)
        
        // Keep only recent timestamps (last 60 seconds)
        let cutoffTime = timestamp.addingTimeInterval(-60)
        timestamps.removeAll { $0 < cutoffTime }
    }
    
    func extractAudio(from startTime: Date, duration: TimeInterval) -> Data? {
        queue.sync { [weak self] in
            self?.extractAudioSync(from: startTime, duration: duration)
        }
    }
    
    private func extractAudioSync(from startTime: Date, duration: TimeInterval) -> Data? {
        let now = Date()
        
        // Calculate how much audio data we need
        let samplesNeeded = Int(duration * sampleRate * Double(channels))
        let bytesNeeded = samplesNeeded * bytesPerSample
        
        // Find the approximate position in buffer for start time
        let timeDiff = now.timeIntervalSince(startTime)
        let maxTimeDiff = Double(maxSize) / (sampleRate * Double(channels) * Double(bytesPerSample))
        
        // If the requested start time is too old, we can't provide it
        if timeDiff > maxTimeDiff {
            print("Requested audio too old: \(timeDiff)s ago, max available: \(maxTimeDiff)s")
            return nil
        }
        
        // Calculate approximate start position in buffer
        let samplesBack = Int(timeDiff * sampleRate * Double(channels))
        let bytesBack = samplesBack * bytesPerSample
        
        var startPosition = writePosition - bytesBack
        if startPosition < 0 {
            startPosition += maxSize
        }
        
        // Extract the audio data
        var extractedData = Data()
        extractedData.reserveCapacity(bytesNeeded)
        
        let actualBytesToExtract = min(bytesNeeded, maxSize)
        
        if startPosition + actualBytesToExtract <= maxSize {
            // Simple case: no wrapping needed
            let range = startPosition..<(startPosition + actualBytesToExtract)
            extractedData.append(buffer.subdata(in: range))
        } else {
            // Wrapping case
            let firstPartSize = maxSize - startPosition
            let secondPartSize = actualBytesToExtract - firstPartSize
            
            // First part (from start position to end of buffer)
            extractedData.append(buffer.subdata(in: startPosition..<maxSize))
            
            // Second part (from beginning of buffer)
            extractedData.append(buffer.subdata(in: 0..<secondPartSize))
        }
        
        // Create WAV header and return complete WAV file
        return createWAVFile(pcmData: extractedData)
    }
    
    private func createWAVFile(pcmData: Data) -> Data {
        var wavData = Data()
        
        let audioFormat: UInt16 = 1 // PCM
        let numChannels = UInt16(channels)
        let sampleRate32 = UInt32(sampleRate)
        let bitsPerSample: UInt16 = 16
        let blockAlign: UInt16 = numChannels * (bitsPerSample / 8)
        let byteRate: UInt32 = sampleRate32 * UInt32(blockAlign)
        let dataSize = UInt32(pcmData.count)
        let fileSize: UInt32 = 36 + dataSize
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // chunk size
        wavData.append(withUnsafeBytes(of: audioFormat.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRate32.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wavData.append(pcmData)
        
        return wavData
    }
} 
