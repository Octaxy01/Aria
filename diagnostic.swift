#!/usr/bin/env swift

import Foundation

print("=== VOICEVOX DIAGNOSTIC TEST ===")

let baseURL = "http://localhost:50021"
let speakerID = 14
let testText = "こんにちは、私はアリアです。"

print("Test text: \(testText)")
print("Speaker ID: 14 (冥鳴ひまり)")
print("Base URL: \(baseURL)")

// Test 1: Check if VOICEVOX is available
let semaphore = DispatchSemaphore(value: 0)

if let url = URL(string: "\(baseURL)/speakers") {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 2.0
    
    URLSession.shared.dataTask(with: request) { _, response, error in
        if let error = error {
            print("❌ VOICEVOX not available: \(error)")
            exit(1)
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ VOICEVOX available (HTTP \(httpResponse.statusCode))")
            semaphore.signal()
        }
    }.resume()
    
    semaphore.wait()
}

// Test 2: Create audio query
if let url = URL(string: "\(baseURL)/audio_query") {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.queryItems = [
        URLQueryItem(name: "text", value: testText),
        URLQueryItem(name: "speaker", value: String(speakerID))
    ]
    
    guard let requestURL = components?.url else {
        print("❌ Failed to build audio_query URL")
        exit(1)
    }
    
    print("Calling audio_query: \(requestURL.absoluteString)")
    
    var request = URLRequest(url: requestURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("❌ audio_query failed: \(error)")
            exit(1)
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("❌ audio_query failed: HTTP \(statusCode)")
            exit(1)
        }
        
        guard let data = data else {
            print("❌ No data received")
            exit(1)
        }
        
        // Parse JSON response
        do {
            if let query = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("✅ audio_query succeeded")
                print("Query keys: \(query.keys)")
                
                if let kana = query["kana"] as? String {
                    print("Kana: \(kana)")
                }
                
                // Test 3: Synthesize audio
                if let synthesisURL = URL(string: "\(baseURL)/synthesis") {
                    var synthesisComponents = URLComponents(url: synthesisURL, resolvingAgainstBaseURL: false)
                    synthesisComponents?.queryItems = [
                        URLQueryItem(name: "speaker", value: String(speakerID))
                    ]
                    
                    guard let synthesisRequestURL = synthesisComponents?.url else {
                        print("❌ Failed to build synthesis URL")
                        exit(1)
                    }
                    
                    print("Calling synthesis: \(synthesisRequestURL.absoluteString)")
                    
                    var synthesisRequest = URLRequest(url: synthesisRequestURL)
                    synthesisRequest.httpMethod = "POST"
                    synthesisRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: query)
                    synthesisRequest.httpBody = jsonData
                    
                    URLSession.shared.dataTask(with: synthesisRequest) { audioData, synthesisResponse, synthesisError in
                        if let synthesisError = synthesisError {
                            print("❌ synthesis failed: \(synthesisError)")
                            exit(1)
                        }
                        
                        guard let synthesisHTTPResponse = synthesisResponse as? HTTPURLResponse,
                              synthesisHTTPResponse.statusCode == 200 else {
                            let statusCode = (synthesisResponse as? HTTPURLResponse)?.statusCode ?? 0
                            print("❌ synthesis failed: HTTP \(statusCode)")
                            exit(1)
                        }
                        
                        guard let audioData = audioData else {
                            print("❌ No audio data received")
                            exit(1)
                        }
                        
                        let contentType = synthesisHTTPResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
                        print("Response Content-Type: \(contentType)")
                        print("Audio data size: \(audioData.count) bytes")
                        
                        // Validate WAV header
                        if audioData.count >= 12 {
                            let header = String(data: audioData[0..<12], encoding: .ascii) ?? "invalid"
                            print("WAV header: \(header)")
                            
                            if header.hasPrefix("RIFF") && header.contains("WAVE") {
                                print("✅ Valid WAV header detected")
                            } else {
                                print("❌ Invalid WAV header")
                            }
                        } else {
                            print("❌ Audio data too small for valid WAV")
                        }
                        
                        // Save to file
                        let tempDir = FileManager.default.temporaryDirectory
                        let outputFile = tempDir.appendingPathComponent("voicevox_diagnostic.wav")
                        
                        do {
                            try audioData.write(to: outputFile)
                            print("✅ Audio saved to: \(outputFile.path)")
                            
                            // Verify saved file
                            if let fileData = try? Data(contentsOf: outputFile) {
                                print("File size on disk: \(fileData.count) bytes")
                                
                                if fileData.count >= 44 {
                                    let riffHeader = String(data: fileData[0..<4], encoding: .ascii) ?? "invalid"
                                    let waveHeader = String(data: fileData[8..<12], encoding: .ascii) ?? "invalid"
                                    print("File RIFF header: \(riffHeader)")
                                    print("File WAVE header: \(waveHeader)")
                                    
                                    if riffHeader == "RIFF" && waveHeader == "WAVE" {
                                        print("✅ File has valid WAV header")
                                        
                                        // Read sample rate
                                        let sampleRateData = fileData[24..<28]
                                        let sampleRate = sampleRateData.withUnsafeBytes { ptr in
                                            ptr.load(as: UInt32.self)
                                        }
                                        print("Sample rate: \(sampleRate) Hz")
                                        
                                        // Read channels
                                        let channelsData = fileData[22..<24]
                                        let channels = channelsData.withUnsafeBytes { ptr in
                                            ptr.load(as: UInt16.self)
                                        }
                                        print("Channels: \(channels)")
                                    }
                                }
                            }
                            
                            print("=== DIAGNOSTIC TEST COMPLETED ===")
                            print("Play the file manually to verify audio quality:")
                            print("afplay \(outputFile.path)")
                            print("or open in QuickTime Player")
                            
                            exit(0)
                            
                        } catch {
                            print("❌ Failed to save audio file: \(error)")
                            exit(1)
                        }
                        
                    }.resume()
                    
                } else {
                    print("❌ Failed to create synthesis URL")
                    exit(1)
                }
            }
        } catch {
            print("❌ Failed to parse audio_query JSON: \(error)")
            exit(1)
        }
        
    }.resume()
    
    semaphore.wait()
} else {
    print("❌ Invalid audio_query URL")
    exit(1)
}

RunLoop.current.run()
