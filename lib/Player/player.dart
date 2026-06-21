import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player/better_player.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../models/channel.dart';
import '../services/localization.dart';

class Player extends StatefulWidget {
  final List<Channel> channels;
  final int initialIndex;
  final Color themeColor;
  final bool hardwareDecoding;
  final String lang;

  const Player({
    super.key,
    required this.channels,
    required this.initialIndex,
    required this.themeColor,
    required this.hardwareDecoding,
    required this.lang,
  });

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  late BetterPlayerController _betterPlayerController;
  late int _currentIndex;
  bool _isZapping = false;
  String? _zappingChannelName;
  String? _zappingChannelLogo;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _setupPlayer(widget.channels[_currentIndex].url);
  }

  void _setupPlayer(String url) {
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      useAsmsSubtitles: true,
      useAsmsTracks: true,
      useAsmsAudioTracks: true,
    );

    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        allowedScreenSleep: false,
        fullScreenByDefault: true,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          textColor: Colors.white,
          iconsColor: Colors.white,
          enableFullscreen: false,
          enableQualities: true,
          enablePlaybackSpeed: false,
          enableSubtitles: true,
          enableAudioTracks: true,
          overflowModalColor: Colors.black87,
          backgroundColor: Colors.transparent,
          loadingWidget: Center(
            child: LoadingAnimationWidget.fourRotatingDots(
                color: widget.themeColor, size: 40),
          ),
          showControlsOnInitialize: true,
          showControls: true,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );
  }

  void _zap(int direction) {
    int newIndex = _currentIndex + direction;
    if (newIndex < 0) {
      newIndex = widget.channels.length - 1;
    } else if (newIndex >= widget.channels.length) {
      newIndex = 0;
    }

    setState(() {
      _currentIndex = newIndex;
      _isZapping = true;
      _zappingChannelName = widget.channels[_currentIndex].name;
      _zappingChannelLogo = widget.channels[_currentIndex].logo;
    });

    _betterPlayerController.setupDataSource(BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.channels[_currentIndex].url,
      useAsmsSubtitles: true,
      useAsmsTracks: true,
      useAsmsAudioTracks: true,
    ));

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isZapping = false);
    });
  }

  KeyEventResult _handleKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.channelUp) {
        _zap(1);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.channelDown) {
        _zap(-1);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.gameButtonX) {
        // Change aspect ratio mapping
        final fit = _betterPlayerController.betterPlayerConfiguration.fit;
        BoxFit nextFit = BoxFit.contain;
        if (fit == BoxFit.contain) nextFit = BoxFit.fill;
        else if (fit == BoxFit.fill) nextFit = BoxFit.cover;
        _betterPlayerController.setOverriddenFit(nextFit);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Focus(
        autofocus: true,
        onKey: _handleKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                child: BetterPlayer(controller: _betterPlayerController),
              ),
              if (_isZapping)
                Positioned(
                  bottom: 50,
                  left: 50,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.themeColor, width: 2),
                    ),
                    child: Row(
                      children: [
                        if (_zappingChannelLogo != null && _zappingChannelLogo!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Image.network(_zappingChannelLogo!, width: 50, height: 50, errorBuilder: (_,__,___) => const SizedBox()),
                          ),
                        Text(
                          _zappingChannelName ?? '',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
