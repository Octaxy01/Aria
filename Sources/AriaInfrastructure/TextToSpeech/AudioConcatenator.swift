import Foundation
import AVFoundation

/// Utility for concatenating audio segments with pauses.
/// Handles WAV file concatenation while preserving audio format.
public struct AudioConcatenator {
    
    /// Concatenates multiple audio files with pauses between them.
    /// - Parameters:
    ///   - audioFiles: Array of audio file URLs to concatenate
    ///   - pauses: Array of pause durations in seconds (one fewer than audio files)
    /// - Returns: URL to the concatenated audio file, or nil if concatenation fails
    public func concatenateAudioFiles(_ audioFiles: [URL], pauses: [TimeInterval]) -> URL? {
        guard !audioFiles.isEmpty else { return nil }
        
        // If only one file, return it directly
        if audioFiles.count == 1 {
            return audioFiles[0]
        }
        
        guard audioFiles.count == pauses.count + 1 else {
            print("[AudioConcatenator] Mismatch: \(audioFiles.count) files but \(pauses.count) pauses")
            return nil
        }
        
        do {
            // Read all audio files
            var audioSegments: [AVAudioPCMBuffer] = []
            var sampleRate: Double = 0
            var channels: UInt32 = 0
            
            for audioFile in audioFiles {
                let audioFile = try AVAudioFile(forReading: audioFile)
                
                // Read format from first file
                if sampleRate == 0 {
                    sampleRate = audioFile.fileFormat.sampleRate
                    channels = audioFile.fileFormat.channelCount
                }
                
                // Read audio data
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: audioFile.processingFormat,
                    frameCapacity: AVAudioFrameCount(audioFile.length)
                ) else {
                    print("[AudioConcatenator] Failed to create audio buffer")
                    return nil
                }
                
                try audioFile.read(into: buffer)
                audioSegments.append(buffer)
            }
            
            // Calculate total duration including pauses
            var totalFrames: AVAudioFrameCount = 0
            for (index, segment) in audioSegments.enumerated() {
                totalFrames += segment.frameLength
                
                // Add pause frames after each segment except the last
                if index < pauses.count {
                    let pauseFrames = AVAudioFrameCount(pauses[index] * sampleRate)
                    totalFrames += pauseFrames
                }
            }
            
            // Create output buffer
            guard let outputFormat = audioSegments.first?.format else {
                print("[AudioConcatenator] No audio format available")
                return nil
            }
            
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: totalFrames
            ) else {
                print("[AudioConcatenator] Failed to create output buffer")
                return nil
            }
            
            // Copy audio segments with pauses
            var currentFrame: AVAudioFrameCount = 0
            
            for (index, segment) in audioSegments.enumerated() {
                // Copy the segment
                let frameLength = segment.frameLength
                let sourceStart = 0
                let destStart = Int(currentFrame)
                
                for channel in 0..<Int(channels) {
                    guard let sourceChannel = segment.floatChannelData?[channel],
                          let destChannel = outputBuffer.floatChannelData?[channel] else {
                        continue
                    }
                    
                    let sourcePtr = sourceChannel.advanced(by: sourceStart)
                    let destPtr = destChannel.advanced(by: destStart)
                    
                    memcpy(
                        destPtr,
                        sourcePtr,
                        Int(frameLength) * MemoryLayout<Float>.size
                    )
                }
                
                currentFrame += frameLength
                
                // Add silence for pause after this segment (except last)
                if index < pauses.count {
                    let pauseFrames = AVAudioFrameCount(pauses[index] * sampleRate)
                    
                    for channel in 0..<Int(channels) {
                        guard let destChannel = outputBuffer.floatChannelData?[channel] else {
                            continue
                        }
                        
                        let destPtr = destChannel.advanced(by: Int(currentFrame))
                        memset(
                            destPtr,
                            0,
                            Int(pauseFrames) * MemoryLayout<Float>.size
                        )
                    }
                    
                    currentFrame += pauseFrames
                }
            }
            
            outputBuffer.frameLength = currentFrame
            
            // Write to file
            let outputFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("aria_concatenated_\(UUID().uuidString).wav")
            
            let outputFormatSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            
            let outputAudioFile = try AVAudioFile(
                forWriting: outputFile,
                settings: outputFormatSettings
            )
            
            try outputAudioFile.write(from: outputBuffer)
            
            print("[AudioConcatenator] Successfully concatenated \(audioFiles.count) audio files")
            print("[AudioConcatenator] Output: \(outputFile.path)")
            
            return outputFile
            
        } catch {
            print("[AudioConcatenator] Failed to concatenate audio: \(error)")
            return nil
        }
    }
    
    /// Generates silence audio for a given duration.
    /// - Parameters:
    ///   - duration: Duration of silence in seconds
    ///   - sampleRate: Sample rate in Hz
    ///   - channels: Number of audio channels
    /// - Returns: AVAudioPCMBuffer containing silence, or nil if creation fails
    public func generateSilence(
        duration: TimeInterval,
        sampleRate: Double,
        channels: UInt32
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        ) else {
            return nil
        }
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        // Fill with zeros (silence)
        for channel in 0..<Int(channels) {
            guard let channelData = buffer.int16ChannelData?[channel] else {
                continue
            }
            memset(channelData, 0, Int(frameCount) * MemoryLayout<Int16>.size)
        }
        
        return buffer
    }
}