import XCTest
@testable import MediaRemoteSupportCore

final class MediaRemoteSourceResolverTests: XCTestCase {
    func testAutoDetectAcceptsExplicitSource() {
        let resolver = MediaRemoteSourceResolver(profile: .autoDetect)

        let decision = resolver.resolve(
            parentBundleIdentifier: "com.apple.Music",
            bundleIdentifier: nil,
            isDiff: false
        )

        XCTAssertEqual(decision, .accept("com.apple.Music"))
    }

    func testFilteredProfileRejectsNonMatchingExplicitSource() {
        let profile = MediaSourceProfile(
            identifier: "neteaseCloudMusic",
            displayName: "NetEase Cloud Music",
            bundleIdentifiers: ["com.netease.163music"],
            mode: .filtered
        )
        let resolver = MediaRemoteSourceResolver(profile: profile)

        let decision = resolver.resolve(
            parentBundleIdentifier: "com.apple.Music",
            bundleIdentifier: nil,
            isDiff: false
        )

        XCTAssertEqual(decision, .idle)
    }

    func testFilteredProfileAcceptsMatchingBundleIdentifierWhenParentIsMissing() {
        let profile = MediaSourceProfile(
            identifier: "qqMusic",
            displayName: "QQ Music",
            bundleIdentifiers: ["com.tencent.QQMusicMac"],
            mode: .filtered
        )
        let resolver = MediaRemoteSourceResolver(profile: profile)

        let decision = resolver.resolve(
            parentBundleIdentifier: nil,
            bundleIdentifier: "com.tencent.QQMusicMac",
            isDiff: false
        )

        XCTAssertEqual(decision, .accept("com.tencent.QQMusicMac"))
    }

    func testFilteredProfileFallsBackToBundleIdentifierWhenParentIsBlank() {
        let profile = MediaSourceProfile(
            identifier: "qqMusic",
            displayName: "QQ Music",
            bundleIdentifiers: ["com.tencent.QQMusicMac"],
            mode: .filtered
        )
        let resolver = MediaRemoteSourceResolver(profile: profile)

        let decision = resolver.resolve(
            parentBundleIdentifier: "",
            bundleIdentifier: "com.tencent.QQMusicMac",
            isDiff: false
        )

        XCTAssertEqual(decision, .accept("com.tencent.QQMusicMac"))
    }

    func testFilteredProfileAcceptsMatchingBundleIdentifierWhenParentDoesNotMatch() {
        let profile = MediaSourceProfile(
            identifier: "qqMusic",
            displayName: "QQ Music",
            bundleIdentifiers: ["com.tencent.QQMusicMac"],
            mode: .filtered
        )
        let resolver = MediaRemoteSourceResolver(profile: profile)

        let decision = resolver.resolve(
            parentBundleIdentifier: "com.apple.Music",
            bundleIdentifier: "com.tencent.QQMusicMac",
            isDiff: false
        )

        XCTAssertEqual(decision, .accept("com.tencent.QQMusicMac"))
    }

    func testFilteredProfileKeepsAcceptedSourceForDiffWithoutSource() {
        let profile = MediaSourceProfile(
            identifier: "amazonMusic",
            displayName: "Amazon Music",
            bundleIdentifiers: ["com.amazon.music"],
            mode: .filtered
        )
        let resolver = MediaRemoteSourceResolver(profile: profile)

        _ = resolver.resolve(
            parentBundleIdentifier: "com.amazon.music",
            bundleIdentifier: nil,
            isDiff: false
        )
        let decision = resolver.resolve(
            parentBundleIdentifier: nil,
            bundleIdentifier: nil,
            isDiff: true
        )

        XCTAssertEqual(decision, .accept("com.amazon.music"))
    }

    func testFilteredProfileIdlesForDiffWithExplicitNonMatchingSource() {
        let profile = MediaSourceProfile(
            identifier: "amazonMusic",
            displayName: "Amazon Music",
            bundleIdentifiers: ["com.amazon.music"],
            mode: .filtered
        )
        let resolver = MediaRemoteSourceResolver(profile: profile)

        _ = resolver.resolve(
            parentBundleIdentifier: "com.amazon.music",
            bundleIdentifier: nil,
            isDiff: false
        )
        let decision = resolver.resolve(
            parentBundleIdentifier: "com.apple.Music",
            bundleIdentifier: nil,
            isDiff: true
        )

        XCTAssertEqual(decision, .idle)
    }

    func testAutoDetectIdlesForNonDiffUpdateWithoutSource() {
        let resolver = MediaRemoteSourceResolver(profile: .autoDetect)

        let decision = resolver.resolve(
            parentBundleIdentifier: nil,
            bundleIdentifier: nil,
            isDiff: false
        )

        XCTAssertEqual(decision, .idle)
    }
}
