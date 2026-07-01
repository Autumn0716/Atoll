import Foundation

public struct MediaSourceProfile: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        case autoDetect
        case filtered
    }

    public let identifier: String
    public let displayName: String
    public let bundleIdentifiers: [String]
    public let mode: Mode

    public static let autoDetect = MediaSourceProfile(
        identifier: "autoDetect",
        displayName: "Auto Detect",
        bundleIdentifiers: [],
        mode: .autoDetect
    )

    public static let amazonMusic = MediaSourceProfile(
        identifier: "amazonMusic",
        displayName: "Amazon Music",
        bundleIdentifiers: ["com.amazon.music"],
        mode: .filtered
    )

    public static let netEaseCloudMusic = MediaSourceProfile(
        identifier: "netEaseCloudMusic",
        displayName: "NetEase Cloud Music",
        // 网易云音乐 macOS 客户端标识，按公开 SPMediaKeyTap 列表复核。
        bundleIdentifiers: ["com.netease.163music"],
        mode: .filtered
    )

    public static let qqMusic = MediaSourceProfile(
        identifier: "qqMusic",
        displayName: "QQ Music",
        // QQ 音乐 macOS 客户端标识，按 Homebrew Cask 应用清单复核。
        bundleIdentifiers: ["com.tencent.QQMusicMac"],
        mode: .filtered
    )
}

public final class MediaRemoteSourceResolver {
    public enum Decision: Equatable {
        case accept(String)
        case idle
    }

    private let profile: MediaSourceProfile
    private var lastAcceptedSource: String?

    public init(profile: MediaSourceProfile) {
        self.profile = profile
    }

    /// 根据 MediaRemote payload 中的来源字段判断当前更新是否可以被当前音乐源接收。
    public func resolve(
        parentBundleIdentifier: String?,
        bundleIdentifier: String?,
        isDiff: Bool
    ) -> Decision {
        let explicitSources = Self.normalizedSources(parentBundleIdentifier, bundleIdentifier)
        guard !explicitSources.isEmpty || (isDiff && lastAcceptedSource != nil)
        else {
            lastAcceptedSource = nil
            return .idle
        }

        switch profile.mode {
        case .autoDetect:
            let source = explicitSources.first ?? lastAcceptedSource!
            lastAcceptedSource = source
            return .accept(source)
        case .filtered:
            if let source = explicitSources.first(where: { profile.bundleIdentifiers.contains($0) }) {
                lastAcceptedSource = source
                return .accept(source)
            }

            if !explicitSources.isEmpty {
                lastAcceptedSource = nil
                return .idle
            }

            guard isDiff,
                  let source = lastAcceptedSource,
                  profile.bundleIdentifiers.contains(source)
            else {
                lastAcceptedSource = nil
                return .idle
            }

            lastAcceptedSource = source
            return .accept(source)
        }
    }

    private static func normalizedSources(_ sources: String?...) -> [String] {
        sources.compactMap(normalizedSource)
    }

    private static func normalizedSource(_ source: String?) -> String? {
        guard let source else { return nil }
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
