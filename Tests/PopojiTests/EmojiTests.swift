import XCTest
@testable import Popoji

final class EmojiTests: XCTestCase {
    private let crossedFingers = Emoji(
        symbol: "🫰",
        name: "hand with index finger and thumb crossed",
        aliases: ["love"]
    )

    func testMatchesTermsInOrderWithTextBetweenThem() {
        XCTAssertTrue(crossedFingers.matches("hand finger"))
    }

    func testDoesNotMatchTermsInReverseOrder() {
        XCTAssertFalse(crossedFingers.matches("finger hand"))
    }

    func testStillIgnoresWhitespaceWithinSearchText() {
        XCTAssertTrue(crossedFingers.matches("indexfinger"))
    }

    func testMatchesOrderedTermsInAlias() {
        let emoji = Emoji(symbol: "🤞", name: "crossed fingers", aliases: ["wish me luck"])

        XCTAssertTrue(emoji.matches("wish luck"))
        XCTAssertFalse(emoji.matches("luck wish"))
    }

    func testEmptyQueryDoesNotMatch() {
        XCTAssertFalse(crossedFingers.matches("   "))
    }
}
