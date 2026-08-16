#!/usr/bin/env swift

import Foundation
@testable import AriaInfrastructure
@testable import AriaDomain

// Simple diagnostic test runner
print("Running VOICEVOX diagnostic test...")
Task {
    await VoiceVoxTTSService.diagnosticTest()
    exit(0)
}
