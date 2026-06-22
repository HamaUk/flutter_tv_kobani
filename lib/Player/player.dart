import 'package:better_player/better_player.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import '../models/channel.dart';

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
  bool _isOverlayVisible = false;
  late ScrollController _scrollController;

  // Configurable Menu Items
  late final List<MenuAction> _menuActions;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _scrollController = ScrollController(
      initialScrollOffset: (_currentIndex * 68.0) - (68.0 * 2),
    );
    
    _menuActions = [
      MenuAction(icon: Icons.search, label: 'Search', onSelect: null),
      MenuAction(icon: Icons.favorite, label: 'Favorites', onSelect: null),
      MenuAction(icon: Icons.category, label: 'Categories', onSelect: null),
      MenuAction(icon: Icons.schedule, label: 'Schedule', onSelect: null),
      MenuAction(icon: Icons.skip_previous, label: 'Previous', onSelect: () => _zap(-1)),
      MenuAction(icon: Icons.skip_next, label: 'Next', onSelect: () => _zap(1)),
    ];

    _setupPlayer(widget.channels[_currentIndex].url);
  }

  void _setupPlayer(String url) {
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      useAsmsSubtitles: true,
      useAsmsTracks: true,
      useAsmsAudioTracks: true,
      headers: {"User-Agent": "VLC/3.0.9"},
    );

    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        allowedScreenSleep: false,
        fullScreenByDefault: true,
        controlsConfiguration: const BetterPlayerControlsConfiguration(showControls: false),
      ),
      betterPlayerDataSource: dataSource,
    );
  }

  void _changeChannel(int index) {
    if (index < 0 || index >= widget.channels.length) return;
    setState(() => _currentIndex = index);
    _betterPlayerController.setupDataSource(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.channels[index].url,
        headers: {"User-Agent": "VLC/3.0.9"},
      ),
    );
  }

  void _zap(int direction) {
    int newIndex = _currentIndex + direction;
    if (newIndex < 0) newIndex = widget.channels.length - 1;
    if (newIndex >= widget.channels.length) newIndex = 0;
    _changeChannel(newIndex);
  }

  void _toggleOverlay() {
    setState(() => _isOverlayVisible = !_isOverlayVisible);
    if (_isOverlayVisible && _scrollController.hasClients) {
      final targetOffset = (_currentIndex * 68.0) - (68.0 * 2);
      _scrollController.jumpTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Using PopScope instead of WillPopScope (required for Flutter 3.12+)
    return PopScope(
      canPop: !_isOverlayVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isOverlayVisible) {
          _toggleOverlay();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Shortcuts(
          // Allow remote control to toggle overlay
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.center): const ActivateIntent(),
          },
          child: GestureDetector(
            onTap: _toggleOverlay,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fullscreen Video
                ExcludeFocus(
                  child: BetterPlayer(controller: _betterPlayerController),
                ),

                // Overlay
                if (_isOverlayVisible)
                  Container(
                    color: Colors.black.withOpacity(0.9),
                    child: Row(
                      children: [
                        // Left: Channel List
                        Expanded(
                          flex: 3,
                          child: DpadRegion(
                            memoryKey: 'player_channels',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: DpadFocusable(
                                    autofocus: true,
                                    onSelect: () => Navigator.pop(context),
                                    child: _buildBackButton(),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    itemCount: widget.channels.length,
                                    itemBuilder: (context, index) => _buildChannelItem(index),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Right: Menu
                        Container(
                          width: 110,
                          color: Colors.black45,
                          child: DpadRegion(
                            memoryKey: 'player_menu',
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _menuActions.map(_buildMenuItem).toList(),
                            ),
                          ),
                        ),
                        const Expanded(flex: 4, child: SizedBox()),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: widget.themeColor, borderRadius: BorderRadius.circular(12)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back, color: Colors.black),
          SizedBox(width: 12),
          Text('Back', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildChannelItem(int index) {
    final channel = widget.channels[index];
    final isPlaying = _currentIndex == index;
    return DpadFocusable(
      onSelect: () {
        _changeChannel(index);
        _toggleOverlay();
      },
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: isPlaying ? widget.themeColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: isPlaying ? Border.all(color: widget.themeColor) : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 15),
            Text('${index + 1}', style: TextStyle(color: isPlaying ? widget.themeColor : Colors.white54)),
            const SizedBox(width: 20),
            Expanded(child: Text(channel.name, style: const TextStyle(color: Colors.white))),
            if (isPlaying) Icon(Icons.play_arrow, color: widget.themeColor),
            const SizedBox(width: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(MenuAction action) {
    return DpadFocusable(
      onSelect: action.onSelect ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(
          children: [
            Icon(action.icon, color: Colors.white, size: 30),
            const SizedBox(height: 5),
            Text(action.label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class MenuAction {
  final IconData icon;
  final String label;
  final VoidCallback? onSelect;
  MenuAction({required this.icon, required this.label, this.onSelect});
}
