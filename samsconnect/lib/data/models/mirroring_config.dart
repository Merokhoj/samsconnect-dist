enum MirrorQuality { low, medium, high, original }

class MirroringConfig {
  final int bitrate;
  final int maxSize;
  final int maxFps;
  final bool showTouches;
  final bool stayAwake;
  final bool turnScreenOff;
  final bool recordScreen;
  final String? recordFilePath;
  final bool fullscreen;
  final bool borderless;
  final bool alwaysOnTop;
  final MirrorQuality quality;

  const MirroringConfig({
    this.bitrate = 8000000, // 8 Mbps
    this.maxSize = 0, // 0 means original size
    this.maxFps = 60,
    this.showTouches = false,
    this.stayAwake = true,
    this.turnScreenOff = false,
    this.recordScreen = false,
    this.recordFilePath,
    this.fullscreen = false,
    this.borderless = false,
    this.alwaysOnTop = false,
    this.quality = MirrorQuality.high,
  });

  factory MirroringConfig.fromQuality(MirrorQuality quality) {
    switch (quality) {
      case MirrorQuality.low:
        return const MirroringConfig(
          bitrate: 2000000, // 2 Mbps
          maxSize: 720,
          maxFps: 30,
          quality: MirrorQuality.low,
        );
      case MirrorQuality.medium:
        return const MirroringConfig(
          bitrate: 4000000, // 4 Mbps
          maxSize: 1080,
          maxFps: 60,
          quality: MirrorQuality.medium,
        );
      case MirrorQuality.high:
        return const MirroringConfig(
          bitrate: 8000000,
          maxSize: 0, // Native resolution for high quality
          maxFps: 60,
          quality: MirrorQuality.high,
        );
      case MirrorQuality.original:
        return const MirroringConfig(
          bitrate: 16000000, // 16 Mbps
          maxSize: 0, // Original size
          maxFps: 60,
          quality: MirrorQuality.original,
        );
    }
  }

  MirroringConfig copyWith({
    int? bitrate,
    int? maxSize,
    int? maxFps,
    bool? showTouches,
    bool? stayAwake,
    bool? turnScreenOff,
    bool? recordScreen,
    String? recordFilePath,
    bool? fullscreen,
    bool? borderless,
    bool? alwaysOnTop,
    MirrorQuality? quality,
  }) {
    return MirroringConfig(
      bitrate: bitrate ?? this.bitrate,
      maxSize: maxSize ?? this.maxSize,
      maxFps: maxFps ?? this.maxFps,
      showTouches: showTouches ?? this.showTouches,
      stayAwake: stayAwake ?? this.stayAwake,
      turnScreenOff: turnScreenOff ?? this.turnScreenOff,
      recordScreen: recordScreen ?? this.recordScreen,
      recordFilePath: recordFilePath ?? this.recordFilePath,
      fullscreen: fullscreen ?? this.fullscreen,
      borderless: borderless ?? this.borderless,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      quality: quality ?? this.quality,
    );
  }

  List<String> toMirroringArgs() {
    final args = <String>[];

    // Bitrate
    args.addAll(['--video-bit-rate', bitrate.toString()]);

    // Max size
    if (maxSize > 0) {
      args.addAll(['--max-size', maxSize.toString()]);
    }

    // Max FPS
    args.addAll(['--max-fps', maxFps.toString()]);

    // Show touches
    if (showTouches) {
      args.add('--show-touches');
    }

    // Stay awake
    if (stayAwake) {
      args.add('--stay-awake');
    }

    // Turn screen off
    if (turnScreenOff) {
      args.add('--turn-screen-off');
    }

    // Fullscreen
    if (fullscreen) {
      args.add('--fullscreen');
    }

    // Borderless
    if (borderless) {
      args.add('--window-borderless');
    }

    // Always on top
    if (alwaysOnTop) {
      args.add('--always-on-top');
    }

    return args;
  }

  Map<String, dynamic> toMap() {
    return {
      'bitrate': bitrate,
      'maxSize': maxSize,
      'maxFps': maxFps,
      'showTouches': showTouches,
      'stayAwake': stayAwake,
      'turnScreenOff': turnScreenOff,
      'recordScreen': recordScreen,
      'recordFilePath': recordFilePath,
      'fullscreen': fullscreen,
      'borderless': borderless,
      'alwaysOnTop': alwaysOnTop,
      'quality': quality.index,
    };
  }

  @override
  String toString() {
    return 'MirroringConfig(quality: $quality, bitrate: ${bitrate ~/ 1000000}Mbps, maxSize: $maxSize, maxFps: $maxFps)';
  }
}
