import Foundation
import AVFoundation
import AriaDomain

/// Handles audio playback for TTS output.
/// Provides async, cancelable audio playback for macOS.
public actor AudioPlaybackService {
    
    private var audioPlayer: AVAudioPlayer?
    private var isPlaying: Bool = false
    private var avatarStateManager: AvatarStateManager?
    private var currentPlaybackID: UUID? = nil
    private var isMuted: Bool = false
    
    public init() {}
    
    /// Sets the avatar state manager for speaking state integration.
    /// - Parameter manager: Avatar state manager to notify of playback state changes
    public func setAvatarStateManager(_ manager: AvatarStateManager) {
        self.avatarStateManager = manager
    }
    
    /// Sets the mute state for audio playback.
    /// - Parameter muted: Whether audio should be muted
    public func setMuted(_ muted: Bool) {
        self.isMuted = muted
        print("🔊 AudioPlaybackService: Mute state set to \(muted)")
        
        // If muted while playing, stop current playback
        if muted && isPlaying {
            stop()
        }
    }
    
    /// Gets the current mute state.
    public var muted: Bool {
        return isMuted
    }
    
    /// Plays the audio file asynchronously.
    public func play(_ audioFile: URL) async throws {
        // Check mute state first
        if isMuted {
            print("🔊 AudioPlaybackService: Audio is muted, skipping playback")
            return
        }
        
        // Generate unique playback ID for this session
        let playbackID = UUID()
        self.currentPlaybackID = playbackID
        
        // Stop any current playback
        stop()
        
        // Check if this session is still active (might have been invalidated by stop)
        guard self.currentPlaybackID == playbackID else {
            print("🔊 AudioPlaybackService: Playback session \(playbackID) was cancelled before starting")
            return
        }
        
        // Diagnostic logging
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioFile.path)
        let fileSize = fileAttributes[.size] as? UInt64 ?? 0
        print("🔊 AudioPlaybackService: File URL: \(audioFile.path)")
        print("🔊 AudioPlaybackService: File size: \(fileSize) bytes")
        print("🔊 AudioPlaybackService: Playback session ID: \(playbackID)")
        
        // Validate WAV file before playback
        if let fileData = try? Data(contentsOf: audioFile) {
            validateWAVFile(fileData)
        }
        
        // Load the audio file with guaranteed cleanup on error
        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: audioFile)
        } catch {
            // Ensure avatar returns to idle on load failure
            await ensureAvatarIdle()
            self.currentPlaybackID = nil
            throw error
        }
        
        self.audioPlayer = player
        
        // Diagnostic logging
        print("🔊 AudioPlaybackService: Player duration: \(player.duration) seconds")
        print("🔊 AudioPlaybackService: Sample rate: \(player.settings[AVSampleRateKey] ?? "unknown")")
        print("🔊 AudioPlaybackService: Channel count: \(player.settings[AVNumberOfChannelsKey] ?? "unknown")")
        
        // Prepare for playback
        player.prepareToPlay()
        
        // Transition avatar to talking state
        if let manager = avatarStateManager {
            try? await manager.transitionToTalking()
        }
        
        // Start playback with guaranteed cleanup
        let playbackSucceeded = player.play()
        print("🔊 AudioPlaybackService: play() returned: \(playbackSucceeded)")
        
        if !playbackSucceeded {
            // Ensure avatar returns to idle on failure
            await ensureAvatarIdle()
            self.currentPlaybackID = nil
            throw NSError(domain: "AudioPlaybackService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start playback"])
        }
        
        self.isPlaying = true
        
        // Wait for playback to complete using polling (more reliable than delegate)
        let duration = player.duration
        let startTime = Date()
        
        while player.isPlaying && Date().timeIntervalSince(startTime) < duration + 1.0 {
            // Check if this session is still active before each sleep
            guard self.currentPlaybackID == playbackID else {
                print("🔊 AudioPlaybackService: Playback session \(playbackID) was cancelled during playback")
                player.stop()
                await ensureAvatarIdle()
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms polling
        }
        
        print("🔊 AudioPlaybackService: Playback completed (player.isPlaying: \(player.isPlaying))")
        
        // Only transition to idle if this session is still the active one
        // This prevents stale completion handlers from affecting newer playback
        if self.currentPlaybackID == playbackID {
            await ensureAvatarIdle()
            self.currentPlaybackID = nil
        } else {
            print("🔊 AudioPlaybackService: Stale completion for session \(playbackID), not transitioning avatar")
        }
        
        // Cleanup
        self.isPlaying = false
        self.audioPlayer = nil
    }
    
    /// Stops current audio playback with guaranteed avatar state cleanup.
    public func stop() {
        // Invalidate the current playback session to prevent stale completions
        currentPlaybackID = nil
        
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        
        // Ensure avatar returns to idle when stopped
        // Note: This must be synchronous for proper test behavior
        // In production, this is called from async contexts so it's safe
        Task {
            if let manager = avatarStateManager {
                try? await manager.transitionToIdle()
            }
        }
    }
    
    /// Stops audio playback without avatar state cleanup (internal use).
    public func stopPlaybackOnly() {
        // Invalidate the current playback session
        currentPlaybackID = nil
        
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
    
    /// Ensures avatar returns to idle state (for error recovery).
    /// This should be called when audio playback fails or is interrupted.
    public func ensureAvatarIdle() async {
        print("[AudioPlaybackService] Recovering avatar to idle state")
        if let manager = avatarStateManager {
            try? await manager.transitionToIdle()
        }
    }
    
    /// Validates WAV file structure before playback.
    /// Uses robust chunk parsing instead of fixed offsets to handle different WAV structures.
    private func validateWAVFile(_ data: Data) {
        print("🔊 AudioPlaybackService: Validating WAV file before playback")
        
        guard data.count >= 44 else {
            print("🔊 AudioPlaybackService: ERROR: WAV file too small (\(data.count) bytes, minimum 44 bytes)")
            return
        }
        
        // Check RIFF header using proper binary comparison
        let riffHeader = data[0..<4]
        let expectedRiff = Data([0x52, 0x49, 0x46, 0x46]) // "RIFF"
        guard riffHeader == expectedRiff else {
            print("🔊 AudioPlaybackService: ERROR: Invalid RIFF header")
            return
        }
        
        // Check WAVE format using proper binary comparison
        let waveFormat = data[8..<12]
        let expectedWave = Data([0x57, 0x41, 0x56, 0x45]) // "WAVE"
        guard waveFormat == expectedWave else {
            print("🔊 AudioPlaybackService: ERROR: Invalid WAVE format")
            return
        }
        
        // FIXED: Search for fmt chunk instead of assuming fixed offset
        var sampleRate: UInt32 = 0
        var bitsPerSample: UInt16 = 0
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
                    print("🔊 AudioPlaybackService: ERROR: Not PCM format: \(audioFormat)")
                    return
                }
                
                // Read channels (offset + 10)
                let numChannels = data.withUnsafeBytes { ptr in
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
                
                print("🔊 AudioPlaybackService: WAV sample rate: \(sampleRate) Hz")
                print("🔊 AudioPlaybackService: WAV channels: \(numChannels)")
                print("🔊 AudioPlaybackService: WAV bit depth: \(bitsPerSample) bits")
                break
            }
            
            offset += 8 + Int(chunkSize)
            if offset % 2 != 0 { offset += 1 } // Pad to even boundary
        }
        
        guard fmtChunkFound else {
            print("🔊 AudioPlaybackService: ERROR: fmt chunk not found")
            return
        }
        
        // FIXED: Search for data chunk instead of assuming fixed offset
        var dataChunkFound = false
        offset = 12 // Start after WAVE header
        
        while offset < data.count - 8 {
            let chunkID = String(data: data[offset..<(offset + 4)], encoding: .ascii)
            let chunkSize = data.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset + 4, as: UInt32.self)
            }
            
            if chunkID == "data" {
                dataChunkFound = true
                print("🔊 AudioPlaybackService: Data chunk found at offset \(offset), size: \(chunkSize) bytes")
                break
            }
            
            offset += 8 + Int(chunkSize)
            if offset % 2 != 0 { offset += 1 } // Pad to even boundary
        }
        
        guard dataChunkFound else {
            print("🔊 AudioPlaybackService: ERROR: data chunk not found")
            return
        }
        
        print("🔊 AudioPlaybackService: WAV file validation passed")
    }
    
    /// Checks if audio is currently playing.
    public var currentlyPlaying: Bool {
        return isPlaying
    }
    
    /// Gets the current playback duration if playing.
    public var currentDuration: TimeInterval? {
        return audioPlayer?.duration
    }
    
    /// Gets the current playback position if playing.
    public var currentPosition: TimeInterval? {
        return audioPlayer?.currentTime
    }
}