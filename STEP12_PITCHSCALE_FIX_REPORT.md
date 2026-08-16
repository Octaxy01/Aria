# PRODUCTION FIX REPORT: VOICEVOX PitchScale Preservation

## Summary
Fixed critical Japanese TTS articulation issue ("titititi", unclear speech) by preserving native VOICEVOX `pitchScale` values instead of overwriting them with incorrect hardcoded defaults.

## Root Cause Analysis

### The Problem
The code incorrectly assumed that `pitchScale = 1.0` was the "normal/default" value for VOICEVOX, similar to `speedScale`, `intonationScale`, and `volumeScale`. This assumption was **fundamentally wrong**.

### VOICEVOX Semantics
- **speedScale**: MULTIPLIER semantics (baseline 1.0 = normal speed)
- **intonationScale**: MULTIPLIER semantics (baseline 1.0 = normal intonation)  
- **volumeScale**: MULTIPLIER semantics (baseline 1.0 = normal volume)
- **pitchScale**: **OFFSET/ADDITIVE semantics** (baseline 0.0 = no pitch shift)

### The Native Reality
VOICEVOX `/audio_query` endpoint returns:
- `pitchScale: 0.0` (not 1.0)
- `speedScale: 1.0`
- `intonationScale: 1.0`
- `volumeScale: 1.0`

Overwriting native `pitchScale: 0.0` with hardcoded `1.0` (or any absolute value) corrupted the prosody analysis, causing the "titititi" distortion.

### Investigation Evidence
- **Native baseline** (pitchScale=0.0 preserved): ✅ NORMAL
- **TEST 2b** (pitchScale mutation skipped): ✅ NORMAL  
- **TEST 3** (pitchScale=1.0 override): ❌ BROKEN - "titititi"
- **TEST 3** (pitchScale=1.05, 1.1, 1.2, 1.5): ❌ ALL BROKEN
- **Investigation C** (pitchScale=0.0 rewrite): ✅ NORMAL

**Conclusion**: The issue was **value replacement** (0.0 → 1.0), not key assignment itself.

## Files Changed

### 1. `/Volumes/T7Sheald/Aria/Sources/AriaInfrastructure/TextToSpeech/VoiceVoxTTSService.swift`

**Changes:**
- Removed all debug flags: `disableSpeechStyleMutations`, `skipPitchScaleMutation`, `enableIdentityRoundTripLogging`, `overridePitchScale`, `enableFullDictionaryDump`
- Removed debug helper functions: `logAccentPhrasesData()`, `dumpFullDictionary()`
- Modified `mapStyleToVoiceVoxParameters()` to **never write pitchScale**
- Modified `applySpeechStyle()` to **never overwrite pitchScale** from native query
- Added comprehensive comments explaining VOICEVOX semantics

### 2. `/Volumes/T7Sheald/Aria/Tests/AriaInfrastructureTests/VoiceVoxTTSServiceTests.swift`

**Changes:**
- Updated all existing tests to validate pitchScale preservation
- Added new regression test: `testPitchScaleNeverOverwrittenWithHardcodedDefault()`
- Disabled debug-flag-dependent tests (TEST 2, 2b, 2c, 3, Investigation A/B/C) with `XCTSkip`
- These skipped tests remain as documentation of the investigation process

## Final Implementation

### Function: `mapStyleToVoiceVoxParameters()`

```swift
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
```

### Function: `applySpeechStyle()`

```swift
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
```

## Build Results

```
Building for debugging...
Build complete! (2.60s)
✅ Build successful
```

## Test Suite Results

### VoiceVoxTTSServiceTests (Primary Fix Verification)
```
Test Suite 'VoiceVoxTTSServiceTests' passed
Executed 18 tests, with 6 tests skipped and 0 failures (0 unexpected) in 1.315 seconds
```

**Passed Tests:**
- ✅ `testApplySpeechStylePreservesComplexQueryStructure` - Validates pitchScale preservation in complex queries
- ✅ `testApplySpeechStyleWithCustomPitchAndSpeed` - Ensures custom pitch doesn't overwrite native pitchScale
- ✅ `testApplySpeechStyleWithDisabledMutations` - Baseline behavior with fix applied
- ✅ `testApplySpeechStyleWithHighEmotionalExpression` - High emotion with pitchScale preserved
- ✅ `testApplySpeechStyleWithLowEmotionalExpression` - Low emotion with pitchScale preserved
- ✅ `testApplySpeechStyleWithNeutralStyle` - Neutral style with pitchScale preserved
- ✅ `testBaselineSynthesisWithDisabledMutations` - Full synthesis with fix applied
- ✅ `testPitchScaleNeverOverwrittenWithHardcodedDefault` - **Critical regression test**
- ✅ `testProviderName` - Provider name validation
- ✅ `testWAVValidationInvalidRIFFHeader` - WAV validation (Stage 2 fix preserved)
- ✅ `testWAVValidationTooSmall` - WAV validation (Stage 2 fix preserved)
- ✅ `testWAVValidationValidHeader` - WAV validation (Stage 2 fix preserved)

**Skipped Tests (Investigation Documentation):**
- ⏭️ `testIdentityRoundTripSerialization` - Used debug flags
- ⏭️ `testInvestigationADictionaryComparison` - Used debug flags
- ⏭️ `testInvestigationCNativeValueRewrite` - Used debug flags
- ⏭️ `testPitchScaleThreshold` - Used debug flags
- ⏭️ `testSpeedScaleOnlyMutation` - Used debug flags
- ⏭️ `testSpeedScaleOnlyNoPitchScaleMutation` - Used debug flags

### Full Test Suite
```
Test Suite 'All tests' - Executed 543 tests, with 44 tests skipped and 2 failures (0 unexpected)
```

**Note:** The 2 failures are in unrelated language detection tests (`LanguageDetectorTests`, `LanguageIntegrationTests`) and are not related to this fix. These are pre-existing issues.

## Regression Test Coverage

### New Critical Regression Test
**`testPitchScaleNeverOverwrittenWithHardcodedDefault()`**
- Validates that `applySpeechStyle()` NEVER overwrites `pitchScale` from native query
- Tests with non-default pitchScale value (0.5) to ensure preservation
- Verifies that other fields (speedScale, intonationScale) ARE still applied correctly
- Tests both mock query validation AND actual synthesis

### Preserved Investigation Tests
The following tests are kept (skipped) as permanent documentation of the investigation:
- TEST 1 baseline synthesis
- TEST 2 speedScale fix validation
- TEST 2b pitchScale skip validation
- TEST 2c identity round-trip validation
- TEST 3 pitchScale threshold investigation
- Investigation A full dictionary comparison
- Investigation B native pitchScale inspection
- Investigation C native value rewrite test

### Preserved Stage 1 & Stage 2 Fixes
- ✅ Stage 1: Duplicate emotional pitch/speed modification removed from `TextToSpeechService.swift`
- ✅ Stage 2: WAV validation in `VoiceVoxTTSService.swift` and `AudioPlaybackService.swift` remains intact

## End-to-End Verification

### Required Manual Testing
**PENDING**: User needs to verify end-to-end through actual Aria application

**Test Procedure:**
1. Build and run Aria application
2. Speak the problematic Japanese sentence: "今日はちょっと疲れてる。"
3. Verify audio output is clear and natural (no "titititi" distortion)
4. Test various emotional expressions to ensure intonationScale still works correctly

**Expected Result:**
- Clear, natural Japanese speech
- No "titititi" or bot-like articulation
- Emotional expression still functional via intonationScale

## Audio Paths for Verification

### Generated Test Audio
- **Baseline test (with fix)**: `/var/folders/xx/27f_8x3d1h513pm9j0h406sw0000gn/T/aria_voicevox_baseline_test/baseline_test.wav`
- **Investigation C (native 0.0 rewrite)**: `/var/folders/xx/27f_8x3d1h513pm9j0h406sw0000gn/T/aria_voicevox_baseline_test/invest_c_native_0.0.wav`

### Historical Investigation Audio (Reference)
- `baseline_test.wav` - Native baseline (TEST 1)
- `speedscale_fix_test.wav` - SpeedScale only (TEST 2)
- `test2b_speedscale_only_nopitch.wav` - No pitchScale mutation (TEST 2b)
- `test2c_identity_roundtrip.wav` - Identity round-trip (TEST 2c)
- `test3_pitchscale_1.0.wav` - pitchScale=1.0 (BROKEN)
- `test3_pitchscale_1.05.wav` - pitchScale=1.05 (BROKEN)
- `test3_pitchscale_1.1.wav` - pitchScale=1.1 (BROKEN)
- `test3_pitchscale_1.2.wav` - pitchScale=1.2 (BROKEN)
- `test3_pitchscale_1.5.wav` - pitchScale=1.5 (BROKEN)

## Future Development Guidelines

### Adding Emotional Pitch Shift (If Needed)
If future development requires emotional pitch shifting, follow this approach:

1. **Never use absolute overwrite** - Do NOT assign fixed values like 1.0, 1.2, etc.
2. **Use native baseline + delta** - Read native pitchScale from query, then add small delta
3. **Validate with threshold testing** - Test with incremental delta values (0.1, 0.2, 0.3, etc.)
4. **Manual listening verification** - Each delta must be manually verified for audio quality
5. **Add regression tests** - Lock in safe delta ranges with automated tests

**Example approach (NOT CURRENTLY IMPLEMENTED):**
```swift
// Future implementation if needed
if let nativePitchScale = query["pitchScale"] as? Double {
    let pitchDelta = voice.pitchDelta // Small delta, e.g., 0.1-0.3
    modifiedQuery["pitchScale"] = nativePitchScale + pitchDelta
}
```

### VOICEVOX Field Reference
- ✅ **speedScale**: MULTIPLIER (baseline 1.0) - Safe to modify
- ❌ **pitchScale**: OFFSET (baseline 0.0) - **NEVER overwrite absolute values**
- ✅ **intonationScale**: MULTIPLIER (baseline 1.0) - Safe to modify
- ✅ **volumeScale**: MULTIPLIER (baseline 1.0) - Safe to modify
- ❌ **lengthScale**: INVALID field - Do not use

## Conclusion

This fix resolves the Japanese TTS articulation issue by correctly respecting VOICEVOX's pitchScale semantics. The native prosody analysis is now preserved, eliminating the "titititi" distortion while maintaining emotional expression through intonationScale.

**Key Achievement:**
- ✅ Native Japanese prosody preserved
- ✅ Emotional expression still functional (via intonationScale)
- ✅ Speed control still functional (via speedScale)
- ✅ WAV validation intact (Stage 2)
- ✅ No duplicate mutations (Stage 1)
- ✅ Comprehensive regression test coverage
- ✅ Clear documentation for future development

**Status:** Ready for end-to-end application verification.