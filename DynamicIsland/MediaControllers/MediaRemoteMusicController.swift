/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import AppKit
import Combine
import Foundation

private enum MediaRemoteCommand: Int {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

/// 通用 MediaRemote 音乐控制器。
/// Auto Detect 直接跟随系统 Now Playing owner；独立源只接受命中 profile 的 payload。
class MediaRemoteMusicController: ObservableObject, MediaControllerProtocol {
    private let profile: MediaSourceProfile
    private let playbackReducer: MediaRemotePlaybackReducer

    @Published private(set) var playbackState: PlaybackState

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.eraseToAnyPublisher()
    }

    var isWorking: Bool {
        process != nil && process?.isRunning == true
    }

    private let mediaRemoteBundle: CFBundle
    private let MRMediaRemoteSendCommandFunction: @convention(c) (Int, AnyObject?) -> Void
    private let MRMediaRemoteSetElapsedTimeFunction: @convention(c) (Double) -> Void
    private let MRMediaRemoteSetShuffleModeFunction: @convention(c) (Int) -> Void
    private let MRMediaRemoteSetRepeatModeFunction: @convention(c) (Int) -> Void

    private var process: Process?
    private var pipeHandler: JSONLinesPipeHandler?
    private var streamTask: Task<Void, Never>?

    init?(profile: MediaSourceProfile) {
        guard
            let bundle = CFBundleCreate(
                kCFAllocatorDefault,
                NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
            let MRMediaRemoteSendCommandPointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSendCommand" as CFString),
            let MRMediaRemoteSetElapsedTimePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetElapsedTime" as CFString),
            let MRMediaRemoteSetShuffleModePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetShuffleMode" as CFString),
            let MRMediaRemoteSetRepeatModePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetRepeatMode" as CFString)
        else { return nil }

        self.profile = profile
        self.playbackReducer = MediaRemotePlaybackReducer(profile: profile)
        self.playbackState = Self.makeIdlePlaybackState(bundleIdentifier: profile.bundleIdentifiers.first ?? "")
        self.mediaRemoteBundle = bundle
        MRMediaRemoteSendCommandFunction = unsafeBitCast(
            MRMediaRemoteSendCommandPointer, to: (@convention(c) (Int, AnyObject?) -> Void).self)
        MRMediaRemoteSetElapsedTimeFunction = unsafeBitCast(
            MRMediaRemoteSetElapsedTimePointer, to: (@convention(c) (Double) -> Void).self)
        MRMediaRemoteSetShuffleModeFunction = unsafeBitCast(
            MRMediaRemoteSetShuffleModePointer, to: (@convention(c) (Int) -> Void).self)
        MRMediaRemoteSetRepeatModeFunction = unsafeBitCast(
            MRMediaRemoteSetRepeatModePointer, to: (@convention(c) (Int) -> Void).self)

        Task { await setupNowPlayingObserver() }
    }

    deinit {
        streamTask?.cancel()

        if let pipeHandler {
            Task { await pipeHandler.close() }
        }

        if let process, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        process = nil
        pipeHandler = nil
    }

    func updatePlaybackInfo() async {}

    func play() async {
        await sendRemoteCommand(.play)
    }

    func pause() async {
        await sendRemoteCommand(.pause)
    }

    func togglePlay() async {
        await sendRemoteCommand(.togglePlayPause)
    }

    func nextTrack() async {
        await sendRemoteCommand(.nextTrack)
    }

    func previousTrack() async {
        await sendRemoteCommand(.previousTrack)
    }

    func seek(to time: Double) async {
        await setElapsedTimeIfAccepted(time)
    }

    func isActive() -> Bool {
        guard !profile.bundleIdentifiers.isEmpty else { return true }
        return NSWorkspace.shared.runningApplications.contains { app in
            guard let bundleIdentifier = app.bundleIdentifier else { return false }
            return profile.bundleIdentifiers.contains(bundleIdentifier)
        }
    }

    func toggleShuffle() async {
        await setShuffleModeIfAccepted()
    }

    func toggleRepeat() async {
        await setRepeatModeIfAccepted()
    }

    private func setupNowPlayingObserver() async {
        let process = Process()
        guard
            let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
            let frameworkPath = Bundle.main.resourceURL?
                .appendingPathComponent("MediaRemoteAdapter.framework")
                .path
        else {
            assertionFailure("Could not find mediaremote-adapter.pl script or framework path")
            return
        }

        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, "stream"]

        let pipeHandler = JSONLinesPipeHandler()
        process.standardOutput = await pipeHandler.getPipe()

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let message = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !message.isEmpty
            else { return }
            print("MediaRemoteMusicController [stderr]: \(message)")
        }

        self.process = process
        self.pipeHandler = pipeHandler

        do {
            try process.run()
            streamTask = Task { [weak self] in
                await self?.processJSONStream()
            }
        } catch {
            print("MediaRemoteMusicController failed to launch mediaremote-adapter.pl: \(error)")
            await applyIdleState()
        }
    }

    private func processJSONStream() async {
        guard let pipeHandler else { return }

        await pipeHandler.readJSONLines(as: NowPlayingUpdate.self) { [weak self] update in
            guard let controller = self else { return }
            await controller.handleAdapterUpdate(update)
        }
    }

    private static func makeIdlePlaybackState(bundleIdentifier: String) -> PlaybackState {
        var state = PlaybackState(bundleIdentifier: bundleIdentifier)
        state.title = "Unknown"
        state.artist = "Unknown"
        state.album = ""
        state.isPlaying = false
        state.artwork = nil
        state.duration = 0
        state.currentTime = 0
        state.isShuffled = false
        state.repeatMode = .off
        state.lastUpdated = Date()
        return state
    }

    @MainActor
    private func applyIdleState() {
        playbackState = Self.makeIdlePlaybackState(bundleIdentifier: profile.bundleIdentifiers.first ?? "")
    }

    @MainActor
    func canSendPlaybackCommand() -> Bool {
        // MediaRemote 命令是系统全局命令；只有当前流已确认属于本控制器时才发送，避免误控其他播放器。
        playbackReducer.acceptedSourceBundleIdentifier != nil
    }

    @MainActor
    private func sendRemoteCommand(_ command: MediaRemoteCommand) {
        guard canSendPlaybackCommand() else { return }
        MRMediaRemoteSendCommandFunction(command.rawValue, nil)
    }

    @MainActor
    private func setElapsedTimeIfAccepted(_ time: Double) {
        guard canSendPlaybackCommand() else { return }
        MRMediaRemoteSetElapsedTimeFunction(time)
    }

    @MainActor
    private func setShuffleModeIfAccepted() {
        guard canSendPlaybackCommand() else { return }
        let nextShuffleMode = playbackState.isShuffled ? 1 : 3
        MRMediaRemoteSetShuffleModeFunction(nextShuffleMode)
    }

    @MainActor
    private func setRepeatModeIfAccepted() {
        guard canSendPlaybackCommand() else { return }
        let nextRepeatMode = (playbackState.repeatMode == .off) ? 3 : (playbackState.repeatMode.rawValue - 1)
        MRMediaRemoteSetRepeatModeFunction(nextRepeatMode)
    }

    @MainActor
    private func handleAdapterUpdate(_ update: NowPlayingUpdate) {
        let payload = update.payload
        let diff = update.diff ?? false

        guard let snapshot = playbackReducer.reduce(
            MediaRemotePlaybackInput(
                title: payload.title,
                artist: payload.artist,
                album: payload.album,
                duration: payload.duration,
                elapsedTime: payload.elapsedTime,
                shuffleMode: payload.shuffleMode,
                repeatMode: payload.repeatMode,
                artworkData: payload.artworkData,
                timestamp: payload.timestamp,
                playbackRate: payload.playbackRate,
                playing: payload.playing,
                parentApplicationBundleIdentifier: payload.parentApplicationBundleIdentifier,
                bundleIdentifier: payload.bundleIdentifier,
                isDiff: diff
            )
        )
        else {
            applyIdleState()
            return
        }

        var newPlaybackState = PlaybackState(bundleIdentifier: snapshot.bundleIdentifier)
        newPlaybackState.title = snapshot.title
        newPlaybackState.artist = snapshot.artist
        newPlaybackState.album = snapshot.album
        newPlaybackState.duration = snapshot.duration
        newPlaybackState.currentTime = snapshot.currentTime
        newPlaybackState.isShuffled = snapshot.isShuffled
        newPlaybackState.repeatMode = RepeatMode(rawValue: snapshot.repeatModeRawValue) ?? .off
        newPlaybackState.artwork = snapshot.artwork
        newPlaybackState.lastUpdated = snapshot.timestamp
        newPlaybackState.playbackRate = snapshot.playbackRate
        newPlaybackState.isPlaying = snapshot.isPlaying
        playbackState = newPlaybackState
    }
}
