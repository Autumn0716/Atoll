import Foundation

public struct MediaRemotePlaybackInput: Equatable, Sendable {
    public let title: String?
    public let artist: String?
    public let album: String?
    public let duration: Double?
    public let elapsedTime: Double?
    public let shuffleMode: Int?
    public let repeatMode: Int?
    public let artworkData: String?
    public let timestamp: String?
    public let playbackRate: Double?
    public let playing: Bool?
    public let parentApplicationBundleIdentifier: String?
    public let bundleIdentifier: String?
    public let isDiff: Bool

    public init(
        title: String?,
        artist: String?,
        album: String?,
        duration: Double?,
        elapsedTime: Double?,
        shuffleMode: Int?,
        repeatMode: Int?,
        artworkData: String?,
        timestamp: String?,
        playbackRate: Double?,
        playing: Bool?,
        parentApplicationBundleIdentifier: String?,
        bundleIdentifier: String?,
        isDiff: Bool
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.shuffleMode = shuffleMode
        self.repeatMode = repeatMode
        self.artworkData = artworkData
        self.timestamp = timestamp
        self.playbackRate = playbackRate
        self.playing = playing
        self.parentApplicationBundleIdentifier = parentApplicationBundleIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.isDiff = isDiff
    }
}

public struct MediaRemotePlaybackSnapshot: Equatable, Sendable {
    public let bundleIdentifier: String
    public var title: String
    public var artist: String
    public var album: String
    public var duration: Double
    public var currentTime: Double
    public var isShuffled: Bool
    public var repeatModeRawValue: Int
    public var artwork: Data?
    public var timestamp: Date
    public var playbackRate: Double
    public var isPlaying: Bool
}

public final class MediaRemotePlaybackReducer {
    private let sourceResolver: MediaRemoteSourceResolver
    private var lastSnapshot: MediaRemotePlaybackSnapshot?
    public private(set) var acceptedSourceBundleIdentifier: String?

    public init(profile: MediaSourceProfile) {
        self.sourceResolver = MediaRemoteSourceResolver(profile: profile)
    }

    /// 将 MediaRemote 原始 payload 转成稳定快照；不匹配当前 source 时返回 nil。
    public func reduce(_ input: MediaRemotePlaybackInput) -> MediaRemotePlaybackSnapshot? {
        let decision = sourceResolver.resolve(
            parentBundleIdentifier: input.parentApplicationBundleIdentifier,
            bundleIdentifier: input.bundleIdentifier,
            isDiff: input.isDiff
        )

        guard case let .accept(sourceBundleIdentifier) = decision else {
            lastSnapshot = nil
            acceptedSourceBundleIdentifier = nil
            return nil
        }

        let previous = input.isDiff ? lastSnapshot : nil
        let snapshot = MediaRemotePlaybackSnapshot(
            bundleIdentifier: sourceBundleIdentifier,
            title: input.title ?? previous?.title ?? "",
            artist: input.artist ?? previous?.artist ?? "",
            album: input.album ?? previous?.album ?? "",
            duration: input.duration ?? previous?.duration ?? 0,
            currentTime: input.elapsedTime ?? previous?.currentTime ?? 0,
            isShuffled: input.shuffleMode.map { $0 != 1 } ?? previous?.isShuffled ?? false,
            repeatModeRawValue: input.repeatMode ?? previous?.repeatModeRawValue ?? 1,
            artwork: input.artworkData.flatMap { Data(base64Encoded: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                ?? previous?.artwork,
            timestamp: input.timestamp.flatMap { ISO8601DateFormatter().date(from: $0) } ?? previous?.timestamp ?? Date(),
            playbackRate: input.playbackRate ?? previous?.playbackRate ?? 1.0,
            isPlaying: input.playing ?? previous?.isPlaying ?? false
        )
        lastSnapshot = snapshot
        acceptedSourceBundleIdentifier = sourceBundleIdentifier
        return snapshot
    }
}
