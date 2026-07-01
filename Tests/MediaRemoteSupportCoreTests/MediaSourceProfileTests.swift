import XCTest
@testable import MediaRemoteSupportCore

final class MediaSourceProfileTests: XCTestCase {
    func testAmazonMusicProfileUsesFilteredMediaRemoteSource() {
        let profile = MediaSourceProfile.amazonMusic

        XCTAssertEqual(profile.identifier, "amazonMusic")
        XCTAssertEqual(profile.displayName, "Amazon Music")
        XCTAssertEqual(profile.bundleIdentifiers, ["com.amazon.music"])
        XCTAssertEqual(profile.mode, .filtered)
    }

    func testNetEaseCloudMusicProfileUsesFilteredMediaRemoteSource() {
        let profile = MediaSourceProfile.netEaseCloudMusic

        XCTAssertEqual(profile.identifier, "netEaseCloudMusic")
        XCTAssertEqual(profile.displayName, "NetEase Cloud Music")
        XCTAssertTrue(profile.bundleIdentifiers.contains("com.netease.163music"))
        XCTAssertEqual(profile.mode, .filtered)
    }

    func testQQMusicProfileUsesFilteredMediaRemoteSource() {
        let profile = MediaSourceProfile.qqMusic

        XCTAssertEqual(profile.identifier, "qqMusic")
        XCTAssertEqual(profile.displayName, "QQ Music")
        XCTAssertTrue(profile.bundleIdentifiers.contains("com.tencent.QQMusicMac"))
        XCTAssertEqual(profile.mode, .filtered)
    }
}
