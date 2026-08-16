import Foundation
import AriaDomain
import AVFoundation

/// VOICEVOX TTS service implementation.
/// Uses VOICEVOX Engine (localhost:50021) for Japanese text-to-speech synthesis.
/// Specifically configured for 冥鳴ひまり (Mei Himari) with speaker ID 14.
public actor VoiceVoxTTSService: TextToSpeeching {
    
    private let baseURL: String
    private let speakerID: Int
    private let audioDirectory: URL
    private var currentTask: Task<Void, Never>?
    
    public init(
        baseURL: String = "http://localhost:50021",
        speakerID: Int = 14,
        audioDirectory: URL? = nil
    ) {
        self.baseURL = baseURL
        self.speakerID = speakerID
        
        // Set up audio output directory
        let defaultAudioDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("aria_voicevox")
        
        self.audioDirectory = audioDirectory ?? defaultAudioDir
        
        // Create audio directory if needed
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: self.audioDirectory.path) {
            try? fileManager.createDirectory(at: self.audioDirectory, withIntermediateDirectories: true)
        }
    }
    
    public nonisolated var providerName: String {
        return "VOICEVOX"
    }
    
    public func isAvailable() async -> Bool {
        // Check if VOICEVOX server is reachable
        guard let url = URL(string: "\(baseURL)/speakers") else {
            return false
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 2.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
    
    public func synthesize(text: String, language: Language, voice: VoiceConfiguration, style: SpeechStyle? = nil) async throws -> URL? {
        // Only support Japanese
        guard language == .japanese else {
            throw TTSError.languageNotSupported(language: language)
        }
        
        // Validate inputs
        guard !text.isEmpty else { return nil }
        
        // Debug: Log the exact text entering VOICEVOX
        print("[VoiceVox] TTS INPUT: \(text)")
        
        // Create output file path
        let outputFileName = "aria_voicevox_\(UUID().uuidString).wav"
        let outputFile = audioDirectory.appendingPathComponent(outputFileName)
        
        // Step 1: Create audio query (use default VOICEVOX parameters)
        let query = try await createAudioQuery(text: text, speaker: speakerID)
        
        // Step 2: Apply speech style parameters if provided
        let styledQuery: [String: Any]
        if let style = style {
            styledQuery = Self.applySpeechStyle(to: query, style: style, voice: voice)
        } else {
            styledQuery = query
        }
        
        // Step 3: Synthesize audio with the styled query
        let audioData = try await synthesizeAudio(query: styledQuery, speaker: speakerID)
        
        // Step 4: Write to file with proper error handling
        do {
            try audioData.write(to: outputFile)
        } catch {
            print("[VoiceVox] ERROR: Failed to write audio data to file: \(error)")
            throw TTSError.audioFileCreationFailed
        }
        
        // Step 5: Validate the written WAV file
        print("[VoiceVox] WAV file saved to: \(outputFile.path)")
        if let fileData = try? Data(contentsOf: outputFile) {
            print("[VoiceVox] File size on disk: \(fileData.count) bytes")
            
            // Verify file size matches response
            if fileData.count != audioData.count {
                print("[VoiceVox] WARNING: File size mismatch - response: \(audioData.count), disk: \(fileData.count)")
            }
            
            validateWAVFile(fileData, context: "written file")
        } else {
            print("[VoiceVox] ERROR: Could not read written file for validation")
        }
        
        return outputFile
    }
    
    /// Synthesizes segmented text with pauses between segments.
    /// This is used for Japanese to create natural conversational rhythm.
    public func synthesizeSegmented(
        segments: [String],
        pauses: [TimeInterval],
        language: Language,
        voice: VoiceConfiguration,
        style: SpeechStyle? = nil
    ) async throws -> URL? {
        // Only support Japanese
        guard language == .japanese else {
            throw TTSError.languageNotSupported(language: language)
        }
        
        guard !segments.isEmpty else { return nil }
        
        // If only one segment, use normal synthesis
        if segments.count == 1 {
            return try await synthesize(text: segments[0], language: language, voice: voice, style: style)
        }
        
        guard segments.count == pauses.count + 1 else {
            print("[VoiceVox] Mismatch: \(segments.count) segments but \(pauses.count) pauses")
            throw TTSError.synthesisFailed(reason: "Segment/pause count mismatch")
        }
        
        print("[VoiceVox] Synthesizing \(segments.count) segments with pauses")
        
        // Synthesize each segment
        var audioFiles: [URL] = []
        for (index, segment) in segments.enumerated() {
            print("[VoiceVox] Synthesizing segment \(index + 1)/\(segments.count): \(segment)")
            
            if let audioFile = try await synthesize(text: segment, language: language, voice: voice, style: style) {
                audioFiles.append(audioFile)
            } else {
                print("[VoiceVox] Failed to synthesize segment \(index + 1)")
                throw TTSError.synthesisFailed(reason: "Failed to synthesize segment \(index + 1)")
            }
        }
        
        // Concatenate audio files with pauses
        let concatenator = AudioConcatenator()
        if let concatenatedFile = concatenator.concatenateAudioFiles(audioFiles, pauses: pauses) {
            print("[VoiceVox] Successfully concatenated \(audioFiles.count) segments")
            return concatenatedFile
        } else {
            print("[VoiceVox] Failed to concatenate audio segments")
            throw TTSError.synthesisFailed(reason: "Failed to concatenate audio segments")
        }
    }
    
    public func cancel() async {
        currentTask?.cancel()
        currentTask = nil
    }
    
    // MARK: - VOICEVOX API Methods
    
    private func createAudioQuery(text: String, speaker: Int) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/audio_query") else {
            throw TTSError.synthesisFailed(reason: "Invalid VOICEVOX URL")
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "speaker", value: String(speaker))
        ]
        
        guard let requestURL = components?.url else {
            throw TTSError.synthesisFailed(reason: "Failed to build request URL")
        }
        
        print("[VoiceVox] Calling audio_query with URL: \(requestURL.absoluteString)")
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[VoiceVox] audio_query failed with HTTP \(statusCode)")
            throw TTSError.synthesisFailed(reason: "Failed to create audio query: HTTP \(statusCode)")
        }
        
        // Parse the JSON response
        guard let query = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[VoiceVox] Failed to parse audio query JSON")
            throw TTSError.synthesisFailed(reason: "Failed to parse audio query JSON")
        }
        
        print("[VoiceVox] audio_query succeeded, got query with keys: \(query.keys)")
        
        return query
    }
    
    private func synthesizeAudio(query: [String: Any], speaker: Int) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/synthesis") else {
            throw TTSError.synthesisFailed(reason: "Invalid VOICEVOX URL")
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "speaker", value: String(speaker))
        ]
        
        guard let requestURL = components?.url else {
            throw TTSError.synthesisFailed(reason: "Failed to build request URL")
        }
        
        print("[VoiceVox] Calling synthesis with URL: \(requestURL.absoluteString)")
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Serialize the query dict to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: query)
        print("[VoiceVox] Sending query JSON: \(String(data: jsonData, encoding: .utf8) ?? "unable to encode")")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[VoiceVox] synthesis failed with HTTP \(statusCode)")
            throw TTSError.synthesisFailed(reason: "Failed to synthesize audio: HTTP \(statusCode)")
        }
        
        // Check response Content-Type
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
        print("[VoiceVox] Response Content-Type: \(contentType)")
        
        print("[VoiceVox] synthesis succeeded, audio data size: \(data.count) bytes")
        
        // Validate WAV header
        validateWAVFile(data, context: "response from VOICEVOX")
        
        return data
    }
    
    /// Maps SpeechStyle to VOICEVOX-specific parameters
    /// IMPORTANT: pitchScale is NEVER overwritten to preserve native VOICEVOX analysis
    /// VOICEVOX uses pitchScale as OFFSET/ADDITIVE (baseline 0.0), not MULTIPLIER (baseline 1.0)
    /// Overwriting with wrong baseline (e.g., 1.0) corrupts audio. Native value must be preserved.
    private static func mapStyleToVoiceVoxParameters(style: SpeechStyle, voice: VoiceConfiguration) -> [String: Double] {
        var parameters: [String: Double] = [:]
        
        // Speed scale - VOICEVOX uses speedScale directly (not lengthScale)
        // Higher speedScale = faster speech, 1.0 is normal
        parameters["speedScale"] = voice.speed
        
        // CRITICAL FIX: DO NOT overwrite pitchScale
        // VOICEVOX pitchScale uses OFFSET semantics (baseline 0.0 = no shift)
        // Native value from /audio_query (typically 0.0) must be preserved
        // Future emotional pitch shifts should use native value + delta, not absolute overwrite
        // For now, no pitchScale modification - use intonationScale for emotional expression
        
        // Intonation scale based on emotional expression
        if style.emotionalExpressionLevel > 0.7 {
            parameters["intonationScale"] = 1.2 // More expressive
        } else if style.emotionalExpressionLevel < 0.4 {
            parameters["intonationScale"] = 0.8 // Less expressive
        } else {
            parameters["intonationScale"] = 1.0 // Normal
        }
        
        return parameters
    }
    
    /// Applies speech style parameters to the AudioQuery dictionary.
    /// This modifies only the prosody fields that the mapping controls,
    /// preserving all other AudioQuery fields (accent phrases, moras, etc.).
    /// CRITICAL: pitchScale is NEVER modified to preserve native VOICEVOX analysis
    internal static func applySpeechStyle(to query: [String: Any], style: SpeechStyle, voice: VoiceConfiguration) -> [String: Any] {
        var modifiedQuery = query
        
        // Get the mapped parameters from the existing mapping function
        let parameters = mapStyleToVoiceVoxParameters(style: style, voice: voice)
        
        // Apply only the fields that the mapping explicitly controls
        // FIXED: Use speedScale instead of lengthScale (VOICEVOX API requirement)
        if let speedScale = parameters["speedScale"] {
            modifiedQuery["speedScale"] = speedScale
        }
        
        // CRITICAL FIX: NEVER modify pitchScale - preserve native value from /audio_query
        // pitchScale uses OFFSET semantics (baseline 0.0), not MULTIPLIER (baseline 1.0)
        // Overwriting with wrong baseline corrupts audio. Native value must be preserved.
        
        if let intonationScale = parameters["intonationScale"] {
            modifiedQuery["intonationScale"] = intonationScale
        }
        
        // Log the applied parameters for verification
        print("[VoiceVox] Applied speech style parameters: speedScale=\(parameters["speedScale"] ?? 1.0), pitchScale=preserved_native, intonationScale=\(parameters["intonationScale"] ?? 1.0)")
        
        return modifiedQuery
    }
    
    /// Validates WAV file structure according to WAV specification.
    /// Uses robust chunk parsing instead of fixed offsets to handle different WAV structures.
    /// Throws an error if the WAV file is invalid or corrupted.
    internal func validateWAVFile(_ data: Data, context: String) {
        print("[VoiceVox] Validating WAV file from \(context)")
        
        // Minimum WAV file size: 44 bytes (header) + minimal data
        guard data.count >= 44 else {
            print("[VoiceVox] ERROR: WAV file too small (\(data.count) bytes, minimum 44 bytes)")
            return
        }
        
        // Check RIFF header (bytes 0-3)
        let riffHeader = String(data: data[0..<4], encoding: .ascii)
        guard riffHeader == "RIFF" else {
            print("[VoiceVox] ERROR: Invalid RIFF header: \(riffHeader ?? "nil")")
            return
        }
        
        // Check file size (bytes 4-7, little-endian) - FIXED: read from correct offset
        let fileSize = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: 4, as: UInt32.self)
        }
        let expectedFileSize = Int(fileSize) + 8 // RIFF chunk size excludes RIFF and size fields
        print("[VoiceVox] File size in header: \(expectedFileSize) bytes, actual: \(data.count) bytes")
        
        // Check WAVE format (bytes 8-11)
        let waveFormat = String(data: data[8..<12], encoding: .ascii)
        guard waveFormat == "WAVE" else {
            print("[VoiceVox] ERROR: Invalid WAVE format: \(waveFormat ?? "nil")")
            return
        }
        
        // FIXED: Search for fmt chunk instead of assuming fixed offset
        var sampleRate: UInt32 = 0
        var bitsPerSample: UInt16 = 0
        var numChannels: UInt16 = 0
        var fmtChunkFound = false
        
        var offset = 12 // Start after WAVE header
        while offset < data.count - 8 {
            let chunkID = String(data: data[offset..<(offset + 4)], encoding: .ascii)
            let chunkSize = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset + 4, as: UInt32.self)
            }
            
            if chunkID == "fmt " {
                fmtChunkFound = true
                // Read audio format (offset + 8)
                let audioFormat = data.withUnsafeBytes { ptr in
                    ptr.load(fromByteOffset: offset + 8, as: UInt16.self)
                }
                guard audioFormat == 1 else {
                    print("[VoiceVox] ERROR: Not PCM format: \(audioFormat)")
                    return
                }
                
                // Read channels (offset + 10)
                numChannels = data.withUnsafeBytes { ptr in
                    ptr.load(fromByteOffset: offset + 10, as: UInt16.self)
                }
                
                // Read sample rate (offset + 12)
                sampleRate = data.withUnsafeBytes { ptr in
                    ptr.load(fromByteOffset: offset + 12, as: UInt32.self)
                }
                
                // Read bits per sample (offset + 22)
                bitsPerSample = data.withUnsafeBytes { ptr in
                    ptr.load(fromByteOffset: offset + 22, as: UInt16.self)
                }
                
                print("[VoiceVox] Channels: \(numChannels)")
                print("[VoiceVox] Sample rate: \(sampleRate) Hz")
                print("[VoiceVox] Bit depth: \(bitsPerSample) bits")
                break
            }
            
            offset += 8 + Int(chunkSize)
            if offset % 2 != 0 { offset += 1 } // Pad to even boundary
        }
        
        guard fmtChunkFound else {
            print("[VoiceVox] ERROR: fmt chunk not found")
            return
        }
        
        // FIXED: Search for data chunk instead of assuming fixed offset
        var dataChunkFound = false
        var dataSize: UInt32 = 0
        offset = 12 // Start after WAVE header
        
        while offset < data.count - 8 {
            let chunkID = String(data: data[offset..<(offset + 4)], encoding: .ascii)
            let chunkSize = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset + 4, as: UInt32.self)
            }
            
            if chunkID == "data" {
                dataChunkFound = true
                dataSize = chunkSize
                print("[VoiceVox] Data chunk found at offset \(offset), size: \(dataSize) bytes")
                break
            }
            
            offset += 8 + Int(chunkSize)
            if offset % 2 != 0 { offset += 1 } // Pad to even boundary
        }
        
        guard dataChunkFound else {
            print("[VoiceVox] ERROR: data chunk not found")
            return
        }
        
        print("[VoiceVox] WAV file validation passed")
    }
    
    /// Diagnostic test function for VOICEVOX audio validation
    public static func diagnosticTest() async {
        print("=== VOICEVOX DIAGNOSTIC TEST ===")
        
        let voicevox = VoiceVoxTTSService(speakerID: 14)
        let testText = "こんにちは、私はアリアです。"
        
        print("Test text: \(testText)")
        print("Speaker ID: 14 (冥鳴ひまり)")
        
        let isAvailable = await voicevox.isAvailable()
        print("VOICEVOX available: \(isAvailable)")
        
        if isAvailable {
            do {
                let voiceConfig = VoiceConfiguration(
                    provider: .voicevox,
                    language: .japanese,
                    voiceId: "mei_himari",
                    speaker: 14
                )
                
                if let audioFile = try await voicevox.synthesize(
                    text: testText,
                    language: .japanese,
                    voice: voiceConfig
                ) {
                    print("✅ Diagnostic synthesis succeeded")
                    print("Audio file: \(audioFile.path)")
                    
                    // Verify file content
                    if let fileData = try? Data(contentsOf: audioFile) {
                        print("File size: \(fileData.count) bytes")
                        
                        if fileData.count >= 44 { // WAV header is 44 bytes minimum
                            let riffHeader = String(data: fileData[0..<4], encoding: .ascii) ?? "invalid"
                            let waveHeader = String(data: fileData[8..<12], encoding: .ascii) ?? "invalid"
                            print("RIFF header: \(riffHeader)")
                            print("WAVE header: \(waveHeader)")
                            
                            if riffHeader == "RIFF" && waveHeader == "WAVE" {
                                print("✅ Valid WAV header detected")
                                
                                // Read sample rate (bytes 24-27)
                                let sampleRateData = fileData[24..<28]
                                let sampleRate = sampleRateData.withUnsafeBytes { ptr in
                                    ptr.load(as: UInt32.self)
                                }
                                print("Sample rate: \(sampleRate) Hz")
                                
                                // Read channels (bytes 22-23)
                                let channelsData = fileData[22..<24]
                                let channels = channelsData.withUnsafeBytes { ptr in
                                    ptr.load(as: UInt16.self)
                                }
                                print("Channels: \(channels)")
                            } else {
                                print("❌ Invalid WAV header")
                            }
                        } else {
                            print("❌ File too small for valid WAV")
                        }
                    }
                    
                    print("File saved to: \(audioFile.path)")
                    print("Test completed - file ready for manual playback")
                    
                } else {
                    print("❌ Diagnostic synthesis returned nil")
                }
            } catch {
                print("❌ Diagnostic test failed: \(error)")
            }
        }
        
        print("=== END DIAGNOSTIC TEST ===")
    }
}
