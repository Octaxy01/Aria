#!/usr/bin/env swift

import Foundation

// Simple script to test baseline synthesis
print("=== TEST 1: NATIVE BASELINE ===")
print("This script demonstrates the baseline test setup.")
print("Please run the diagnostic test with the flag enabled:")
print()
print("swift test --filter VoiceVoxTTSServiceTests.testApplySpeechStyleWithDisabledMutations")
print()
print("Then manually test synthesis with the disableSpeechStyleMutations flag set to true")
print("by calling VoiceVoxTTSService.diagnosticTest() from your main app.")
print()
print("The flag is currently set to: true (baseline mode)")
print("=== END TEST 1 SETUP ===")
