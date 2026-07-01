import XCTest
@testable import MediaRemoteSupportCore

final class MediaRemotePlaybackReducerTests: XCTestCase {
    func testAcceptedPayloadMapsMetadataAndPlaybackFields() {
        let reducer = MediaRemotePlaybackReducer(profile: .amazonMusic)
        let snapshot = reducer.reduce(
            MediaRemotePlaybackInput(
                title: "Song",
                artist: "Artist",
                album: "Album",
                duration: 240,
                elapsedTime: 12,
                shuffleMode: 3,
                repeatMode: 2,
                artworkData: nil,
                timestamp: nil,
                playbackRate: 1,
                playing: true,
                parentApplicationBundleIdentifier: "com.amazon.music",
                bundleIdentifier: nil,
                isDiff: false
            )
        )

        XCTAssertEqual(snapshot?.bundleIdentifier, "com.amazon.music")
        XCTAssertEqual(snapshot?.title, "Song")
        XCTAssertEqual(snapshot?.artist, "Artist")
        XCTAssertEqual(snapshot?.album, "Album")
        XCTAssertEqual(snapshot?.duration, 240)
        XCTAssertEqual(snapshot?.currentTime, 12)
        XCTAssertEqual(snapshot?.isShuffled, true)
        XCTAssertEqual(snapshot?.repeatModeRawValue, 2)
        XCTAssertEqual(snapshot?.isPlaying, true)
    }

    func testDiffPayloadKeepsPreviousMetadataWhenFieldsAreMissing() {
        let reducer = MediaRemotePlaybackReducer(profile: .amazonMusic)
        _ = reducer.reduce(
            MediaRemotePlaybackInput(
                title: "Song",
                artist: "Artist",
                album: "Album",
                duration: 240,
                elapsedTime: 12,
                shuffleMode: 3,
                repeatMode: 2,
                artworkData: nil,
                timestamp: nil,
                playbackRate: 1,
                playing: true,
                parentApplicationBundleIdentifier: "com.amazon.music",
                bundleIdentifier: nil,
                isDiff: false
            )
        )

        let snapshot = reducer.reduce(
            MediaRemotePlaybackInput(
                title: nil,
                artist: nil,
                album: nil,
                duration: nil,
                elapsedTime: 20,
                shuffleMode: nil,
                repeatMode: nil,
                artworkData: nil,
                timestamp: nil,
                playbackRate: nil,
                playing: nil,
                parentApplicationBundleIdentifier: nil,
                bundleIdentifier: nil,
                isDiff: true
            )
        )

        XCTAssertEqual(snapshot?.title, "Song")
        XCTAssertEqual(snapshot?.artist, "Artist")
        XCTAssertEqual(snapshot?.album, "Album")
        XCTAssertEqual(snapshot?.duration, 240)
        XCTAssertEqual(snapshot?.currentTime, 20)
        XCTAssertEqual(snapshot?.isShuffled, true)
        XCTAssertEqual(snapshot?.repeatModeRawValue, 2)
        XCTAssertEqual(snapshot?.isPlaying, true)
    }

    func testExplicitNonMatchingDiffClearsAcceptedCommandSource() {
        let reducer = MediaRemotePlaybackReducer(profile: .amazonMusic)
        _ = reducer.reduce(
            MediaRemotePlaybackInput(
                title: "Song",
                artist: "Artist",
                album: "Album",
                duration: 240,
                elapsedTime: 12,
                shuffleMode: 3,
                repeatMode: 2,
                artworkData: nil,
                timestamp: nil,
                playbackRate: 1,
                playing: true,
                parentApplicationBundleIdentifier: "com.amazon.music",
                bundleIdentifier: nil,
                isDiff: false
            )
        )

        XCTAssertEqual(reducer.acceptedSourceBundleIdentifier, "com.amazon.music")

        let snapshot = reducer.reduce(
            MediaRemotePlaybackInput(
                title: nil,
                artist: nil,
                album: nil,
                duration: nil,
                elapsedTime: 20,
                shuffleMode: nil,
                repeatMode: nil,
                artworkData: nil,
                timestamp: nil,
                playbackRate: nil,
                playing: nil,
                parentApplicationBundleIdentifier: "com.apple.Music",
                bundleIdentifier: nil,
                isDiff: true
            )
        )

        XCTAssertNil(snapshot)
        XCTAssertNil(reducer.acceptedSourceBundleIdentifier)
    }
}
