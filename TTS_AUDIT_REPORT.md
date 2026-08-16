# TTS AUDIT REPORT - Why Aria Sounds Worse After SpeechStyle Integration

## TEST INPUT
「今日はちょっと疲れてる。」

## 1. FINAL TEXT BEFORE TTS

### LLM Output (assumed)
「今日はちょっと疲れてる。」

### After TextSanitizer
「今日はちょっと疲れてる。」 
- No markdown/json to remove
- Text remains unchanged

### After JapaneseConversationalTransformer
「今日はちょっと疲れてる。」
- No character-specific transformations match
- No exact phrase transformations match
- No grammatical pattern transformations match
- No safe sentence-ending transformations match
- Text remains unchanged

### After JapaneseConversationalFillerService
「今日はちょっと疲れてる。」
- Default tone: .casual (no emotional markers in input)
- No filler added for casual tone
- Text remains unchanged

### After JapaneseTTSSegmenter
Segment 1: 「今日はちょっと疲れてる。」
- Single sentence, no segmentation needed

### Final segment sent to VOICEVOX
「今日はちょっと疲れてる。」

## 2. ACTUAL SPEECHSTYLE

### ConversationTone Classification
Input: "今日はちょっと疲れてる。"
- Contains "疲れてる" (tired) → matches emotionalMarkers
- **Tone: .emotional**

### SpeechStyle Resolution
For tone .emotional:
```swift
SpeechStyle(
    sentenceLengthPreference: 0.5,
    emojiUsageLevel: 0.2,
    casualMarkerUsage: 0.4,
    emotionalExpressionLevel: 0.8,  // HIGH emotional expression
    reactionBeforeAnswer: true,
    avoidFormalLanguage: true
)
```

### VoiceConfiguration Mapping
Starting from base: VoiceConfiguration.ariaJapanese (pitch: 1.0, speed: 1.0)

TextToSpeechService.mapStyleToVoice() adjustments:
- emotionalExpressionLevel = 0.8 (> 0.7)
- pitchAdjustment = +0.1
- speedAdjustment = -0.1

Final VoiceConfiguration:
- pitch: 1.0 + 0.1 = 1.1
- speed: 1.0 - 0.1 = 0.9
- style: .warm

## 3. ACTUAL AUDIOQUERY VALUES

### VOICEVOX Default AudioQuery (from /audio_query)
- lengthScale: 1.0 (VOICEVOX default)
- pitchScale: 1.0 (VOICEVOX default)
- intonationScale: 1.0 (VOICEVOX default)
- prePhonemeLength: 0.1 (VOICEVOX default)
- postPhonemeLength: 0.1 (VOICEVOX default)
- accent_phrases: [complex mora structure from VOICEVOX]
- [other VOICEVOX-generated prosody data]

### After applySpeechStyle()
VoiceVoxTTSService.mapStyleToVoiceVoxParameters():
- lengthScale = 1.0 / voice.speed = 1.0 / 0.9 = 1.11
- pitchScale = voice.pitch = 1.1
- intonationScale based on emotionalExpressionLevel = 0.8 (> 0.7) → 1.2

### Final AudioQuery before /synthesis
- lengthScale: 1.11 (was 1.0)
- pitchScale: 1.1 (was 1.0)
- intonationScale: 1.2 (was 1.0)
- prePhonemeLength: 0.1 (unchanged)
- postPhonemeLength: 0.1 (unchanged)
- accent_phrases: [unchanged VOICEVOX structure]
- moras: [unchanged VOICEVOX structure]

## 4. BEFORE vs AFTER SpeechStyle Integration

### BEFORE (VOICEVOX defaults only)
- lengthScale: 1.0
- pitchScale: 1.0
- intonationScale: 1.0
- Result: Natural VOICEVOX delivery with speaker 14 defaults

### AFTER (SpeechStyle applied)
- lengthScale: 1.11 (11% slower)
- pitchScale: 1.1 (10% higher pitch)
- intonationScale: 1.2 (20% more expressive)
- Result: Modified delivery that may sound exaggerated

### Changes Summary
- **3 separate parameters modified**
- **All modifications increase expressiveness**: slower, higher pitch, more intonation
- **No parameter decreases expressiveness** for this input

## 5. UNINTENDED INTERACTION ANALYSIS

### Double Emotional Expression Application
The system applies emotional expression TWICE:

1. **TextToSpeechService.mapStyleToVoice()**:
   - emotionalExpressionLevel > 0.7 → pitch += 0.1, speed -= 0.1
   - This changes VoiceConfiguration.pitch and VoiceConfiguration.speed

2. **VoiceVoxTTSService.mapStyleToVoiceVoxParameters()**:
   - emotionalExpressionLevel > 0.7 → intonationScale = 1.2
   - This also uses the same emotionalExpressionLevel

### Tone Classification Issue
Input "今日はちょっと疲れてる。" (I'm a bit tired) is classified as:
- **.emotional** (because "疲れてる" matches emotionalMarkers)
- This triggers the HIGH emotional expression path (0.8)

### The Problem
Even a simple statement of being "a bit tired" triggers:
- +10% pitch
- -10% speed (slower)
- +20% intonation
- Result: Exaggerated "breathy/hehe" style delivery

### Speaker 14 Compatibility
冥鳴ひまり (speaker 14) may not be designed for:
- Combined pitch + intonation increases
- The 1.2 intonationScale may be too aggressive for this speaker
- Base VOICEVOX defaults for speaker 14 may already be expressive

## 6. ACTUAL LOGIC INSPECTION

### mapStyleToVoiceVoxParameters() Logic
```swift
if style.emotionalExpressionLevel > 0.7 {
    parameters["intonationScale"] = 1.2 // More expressive
}
```
- **Binary threshold**: > 0.7 or not
- **No gradation**: 0.71 and 1.0 both get 1.2
- **Aggressive multiplier**: 1.2 is a 20% increase

### applySpeechStyle() Logic
```swift
if let intonationScale = parameters["intonationScale"] {
    modifiedQuery["intonationScale"] = intonationScale
}
```
- **Overwrites VOICEVOX defaults** completely
- **No blending** with VOICEVOX's own intonation analysis
- **Destroys** VOICEVOX's mora-level pitch contours

### SpeechStyleResolver Logic
For .emotional tone:
```swift
emotionalExpressionLevel: 0.8
```
- **Very high** for a simple tired statement
- **No gradation** based on intensity of emotion
- **Same value** for "a bit tired" and "very upset"

### TextToSpeechService.mapStyleToVoice() Logic
```swift
if style.emotionalExpressionLevel > 0.7 {
    pitchAdjustment = 0.1  // Slightly higher for emotional
    speedAdjustment = -0.1 // Slightly slower for emotional
}
```
- **Also applies** based on same 0.7 threshold
- **Compounds** the intonationScale change
- **Creates triple modification**: pitch + speed + intonation

## 7. MOST LIKELY REGRESSION

**Classification: E. Multiple interacting changes**

### Evidence:
1. **Double emotional application**: Both TextToSpeechService and VoiceVoxTTSService modify based on emotionalExpressionLevel
2. **Tone misclassification**: Simple "tired" statement triggers .emotional tone with 0.8 expression
3. **Aggressive intonation**: 1.2 intonationScale overwrites VOICEVOX's careful mora-level analysis
4. **Compounding effects**: pitch (1.1) + speed (0.9 → lengthScale 1.11) + intonation (1.2) all increase expressiveness
5. **No gradation**: Binary thresholds create exaggerated delivery for moderate emotions

### Root Cause:
The combination of:
- Aggressive tone classification (.emotional for "tired")
- High fixed emotionalExpressionLevel (0.8)
- Triple parameter modification (pitch + speed + intonation)
- Binary intonationScale threshold (1.2 for anything > 0.7)

creates exaggerated "breathy/hehe" delivery even for simple conversational statements.

## 8. RECOMMENDED NEXT ACTION

**Investigate the intonationScale threshold and mapping logic**

Specifically:
1. Test whether reducing intonationScale from 1.2 to 1.1 (or 1.05) reduces the exaggerated delivery
2. Test whether removing the TextToSpeechService pitch/speed adjustments (keeping only intonationScale) improves naturalness
3. Test whether gradating the intonationScale (e.g., 1.0-1.2 based on emotionalExpressionLevel) rather than binary threshold improves expressiveness without exaggeration

**Do NOT implement this change** - this is a diagnostic recommendation only.

The most likely bottleneck is the **aggressive 1.2 intonationScale** combined with **double emotional expression application**.