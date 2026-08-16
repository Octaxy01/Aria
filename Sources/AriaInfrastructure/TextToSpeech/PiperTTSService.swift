import Foundation
import AriaDomain

/// Piper TTS service implementation.
/// Uses external Piper TTS process for text-to-speech synthesis.
/// Acts as a fallback provider when preferred voice engines are unavailable.
public actor PiperTTSService: TextToSpeeching {
    
    private let piperPath: String
    private let modelDirectory: URL
    private let audioDirectory: URL
    private var currentProcess: Process?
    
    public init(piperPath: String? = nil, modelDirectory: URL? = nil, audioDirectory: URL? = nil) throws {
        // Try to find Piper in known locations
        let piperLocations = [
            piperPath,
            "/Users/salmansalim/Library/Python/3.11/bin/piper",
            "/usr/local/bin/piper",
            "/opt/homebrew/bin/piper"
        ].compactMap { $0 }
        
        guard let foundPiper = piperLocations.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw TTSError.externalProcessUnavailable
        }
        
        self.piperPath = foundPiper
        
        // Set up model directory
        let defaultModelDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local")
            .appendingPathComponent("share")
            .appendingPathComponent("piper")
            .appendingPathComponent("voices")
        
        self.modelDirectory = modelDirectory ?? defaultModelDir
        
        // Set up audio output directory
        let defaultAudioDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("aria_tts")
        
        self.audioDirectory = audioDirectory ?? defaultAudioDir
        
        // Create audio directory if needed
        try FileManager.default.createDirectory(at: self.audioDirectory, withIntermediateDirectories: true)
    }
    
    public nonisolated var providerName: String {
        return "Piper TTS"
    }
    
    public func isAvailable() async -> Bool {
        return FileManager.default.fileExists(atPath: piperPath)
    }
    
    public func synthesize(text: String, language: Language, voice: VoiceConfiguration, style: SpeechStyle? = nil) async throws -> URL? {
        // Validate inputs
        guard !text.isEmpty else { return nil }
        
        // Create output file path
        let outputFileName = "aria_tts_\(UUID().uuidString).wav"
        let outputFile = audioDirectory.appendingPathComponent(outputFileName)
        
        // Find model file
        let modelPath = modelDirectory.appendingPathComponent("\(voice.voiceId).onnx")
        let configPath = modelDirectory.appendingPathComponent("\(voice.voiceId).onnx.json")
        
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw TTSError.voiceUnavailable(voice: voice)
        }
        
        // Prepare Piper command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: piperPath)
        
        var arguments = [
            "-m", modelPath.path,
            "-c", configPath.path,
            "-f", outputFile.path
        ]
        
        // Add speed parameter (length_scale is inverse of speed)
        let lengthScale = 1.0 / voice.speed
        arguments.append(contentsOf: ["--length-scale", String(lengthScale)])
        
        if let speaker = voice.speaker {
            arguments.append(contentsOf: ["-s", String(speaker)])
        }
        
        process.arguments = arguments
        
        // Setup pipes for input/output
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        // Write text to input
        inputPipe.fileHandleForWriting.write(text.data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()
        
        // Execute process
        self.currentProcess = process
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                let errorData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorMessage = String(data: errorData, encoding: .utf8), !errorMessage.isEmpty {
                    throw TTSError.synthesisFailed(reason: errorMessage)
                }
                throw TTSError.synthesisFailed(reason: "Unknown Piper error")
            }
            
            self.currentProcess = nil
            
            // Verify output file exists
            guard FileManager.default.fileExists(atPath: outputFile.path) else {
                throw TTSError.audioFileCreationFailed
            }
            
            return outputFile
            
        } catch {
            self.currentProcess = nil
            throw error
        }
    }
    
    public func cancel() async {
        currentProcess?.terminate()
        currentProcess = nil
    }
    
    public func synthesizeSegmented(segments: [String], pauses: [TimeInterval], language: Language, voice: VoiceConfiguration, style: SpeechStyle? = nil) async throws -> URL? {
        // Piper doesn't support segmented synthesis, fall back to direct synthesis
        // Join segments with spaces for basic readability
        let combinedText = segments.joined(separator: " ")
        return try await synthesize(text: combinedText, language: language, voice: voice, style: style)
    }
    
    /// Checks if a voice model is available.
    public func isVoiceAvailable(_ voice: VoiceConfiguration) -> Bool {
        let modelPath = modelDirectory.appendingPathComponent("\(voice.voiceId).onnx")
        let configPath = modelDirectory.appendingPathComponent("\(voice.voiceId).onnx.json")
        return FileManager.default.fileExists(atPath: modelPath.path) &&
               FileManager.default.fileExists(atPath: configPath.path)
    }
    
    /// Lists available voice models.
    public func availableVoices() -> [VoiceConfiguration] {
        var voices: [VoiceConfiguration] = []
        
        guard let enumerator = FileManager.default.enumerator(at: modelDirectory, includingPropertiesForKeys: nil) else {
            return voices
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "onnx" && !fileURL.lastPathComponent.contains("_quantized") {
                let modelName = fileURL.deletingPathExtension().lastPathComponent
                let language = Language.allCases.first { modelName.hasPrefix($0.rawValue) } ?? .english
                voices.append(VoiceConfiguration(
                    provider: .piper,
                    language: language,
                    voiceId: modelName
                ))
            }
        }
        
        return voices
    }
}