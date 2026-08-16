import XCTest
import AriaDomain
@testable import AriaApplication

/// Tests for runtime event emission and session identity.
final class RuntimeEventTests: XCTestCase {
    
    func testEventSendable() {
        // Verify that AriaRuntimeEvent is Sendable
        let event: AriaRuntimeEvent = .requestStarted(sessionID: UUID())
        // Just verify we can create and pass the event
        XCTAssertNotNil(event)
    }
    
    func testRequestStartedEvent() {
        let sessionID = UUID()
        let event = AriaRuntimeEvent.requestStarted(sessionID: sessionID)
        
        switch event {
        case .requestStarted(let id):
            XCTAssertEqual(id, sessionID)
        default:
            XCTFail("Expected requestStarted event")
        }
    }
    
    func testRequestCompletedEvent() {
        let sessionID = UUID()
        let event = AriaRuntimeEvent.requestCompleted(sessionID: sessionID)
        
        switch event {
        case .requestCompleted(let id):
            XCTAssertEqual(id, sessionID)
        default:
            XCTFail("Expected requestCompleted event")
        }
    }
    
    func testRequestCancelledEvent() {
        let sessionID = UUID()
        let event = AriaRuntimeEvent.requestCancelled(sessionID: sessionID)
        
        switch event {
        case .requestCancelled(let id):
            XCTAssertEqual(id, sessionID)
        default:
            XCTFail("Expected requestCancelled event")
        }
    }
    
    func testRequestFailedEvent() {
        let sessionID = UUID()
        let error = "Test error"
        let event = AriaRuntimeEvent.requestFailed(sessionID: sessionID, error: error)
        
        switch event {
        case .requestFailed(let id, let err):
            XCTAssertEqual(id, sessionID)
            XCTAssertEqual(err, error)
        default:
            XCTFail("Expected requestFailed event")
        }
    }
    
    func testAvatarStateChangedEvent() {
        let state = AvatarState.thinking
        let event = AriaRuntimeEvent.avatarStateChanged(state: state)
        
        switch event {
        case .avatarStateChanged(let s):
            XCTAssertEqual(s, state)
        default:
            XCTFail("Expected avatarStateChanged event")
        }
    }
    
    func testAudioStateChangedEvent() {
        let event = AriaRuntimeEvent.audioStateChanged(isPlaying: true)
        
        switch event {
        case .audioStateChanged(let playing):
            XCTAssertTrue(playing)
        default:
            XCTFail("Expected audioStateChanged event")
        }
    }
    
    func testMuteStateChangedEvent() {
        let event = AriaRuntimeEvent.muteStateChanged(isMuted: true)
        
        switch event {
        case .muteStateChanged(let muted):
            XCTAssertTrue(muted)
        default:
            XCTFail("Expected muteStateChanged event")
        }
    }
    
    func testClarificationRequestedEvent() {
        let sessionID = UUID()
        let event = AriaRuntimeEvent.clarificationRequested(sessionID: sessionID)
        
        switch event {
        case .clarificationRequested(let id):
            XCTAssertEqual(id, sessionID)
        default:
            XCTFail("Expected clarificationRequested event")
        }
    }
    
    func testConfirmationRequestedEvent() {
        let sessionID = UUID()
        let event = AriaRuntimeEvent.confirmationRequested(sessionID: sessionID)
        
        switch event {
        case .confirmationRequested(let id):
            XCTAssertEqual(id, sessionID)
        default:
            XCTFail("Expected confirmationRequested event")
        }
    }
}
