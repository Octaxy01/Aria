import XCTest
@testable import AriaApplication
@testable import AriaDomain

final class ConversationToneClassifierTests: XCTestCase {
    func test_classifiesAffectionateMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("I love you Aria"), .affectionate)
    }

    func test_classifiesRudeMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("you are so stupid"), .rude)
    }

    func test_classifiesJokingMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("haha that's so random"), .joking)
    }

    func test_classifiesSeriousMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("I need help, this is urgent"), .serious)
    }

    func test_defaultsToCasualForOrdinaryMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("what's up, how's your day"), .casual)
    }

    func test_rudeMarkerTakesPriorityOverJokingMarker() {
        XCTAssertEqual(ConversationToneClassifier.classify("haha you're so stupid lol"), .rude)
    }
    
    func test_classifiesAchievementMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("I finally finished my project"), .achievement)
    }
    
    func test_classifiesIndonesianAchievement() {
        XCTAssertEqual(ConversationToneClassifier.classify("alhamdulillah selesai berhasil"), .achievement)
    }

    func test_classifiesTiredMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("Aku capek banget"), .emotional)
    }

    func test_classifiesSadMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("Aku lagi sedih"), .emotional)
    }

    func test_classifiesStressedMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("Aku stres banget"), .emotional)
    }

    func test_classifiesAngryMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("Aku lagi kesel"), .emotional)
    }

    func test_classifiesTechnicalSwiftActor() {
        XCTAssertEqual(ConversationToneClassifier.classify("Jelaskan Swift Actor"), .technical)
    }

    func test_classifiesTechnicalDebugging() {
        XCTAssertEqual(ConversationToneClassifier.classify("Bantu debug kode ini"), .technical)
    }

    func test_classifiesTechnicalError() {
        XCTAssertEqual(ConversationToneClassifier.classify("Kenapa kode Swift-ku error?"), .technical)
    }

    func test_classifiesAffectionateLucu() {
        XCTAssertEqual(ConversationToneClassifier.classify("Aria kamu lucu"), .affectionate)
    }

    func test_classifiesAffectionateCantik() {
        XCTAssertEqual(ConversationToneClassifier.classify("Aria cantik"), .affectionate)
    }

    func test_classifiesCasualMessage() {
        XCTAssertEqual(ConversationToneClassifier.classify("lagi apa?"), .casual)
    }

    func test_emotionalTakesPriorityOverCasual() {
        XCTAssertEqual(ConversationToneClassifier.classify("lagi apa aku capek banget"), .emotional)
    }

    func test_technicalTakesPriorityOverCasual() {
        XCTAssertEqual(ConversationToneClassifier.classify("lagi apa jelaskan Swift Actor"), .technical)
    }

    func test_affectionateTakesPriorityOverCasual() {
        XCTAssertEqual(ConversationToneClassifier.classify("lagi apa Aria kamu lucu"), .affectionate)
    }
}