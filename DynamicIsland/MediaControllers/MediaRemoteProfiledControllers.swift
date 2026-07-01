/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import Foundation

/// 自动识别控制器：复用 MediaRemote 流，跟随当前系统 Now Playing 来源。
final class AutoDetectMediaController: MediaRemoteMusicController {
    init?() {
        super.init(profile: .autoDetect)
    }
}

/// 网易云音乐控制器：只接收网易云音乐 bundle 标识匹配的 MediaRemote 更新。
final class NetEaseCloudMusicController: MediaRemoteMusicController {
    init?() {
        super.init(profile: .netEaseCloudMusic)
    }
}

/// QQ 音乐控制器：只接收 QQ 音乐 bundle 标识匹配的 MediaRemote 更新。
final class QQMusicController: MediaRemoteMusicController {
    init?() {
        super.init(profile: .qqMusic)
    }
}
