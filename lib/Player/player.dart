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

  // Configurable Menu Items (Easy to customize)
  final List<MenuAction> _menuActions = [
    MenuAction(icon: Icons.search, label: 'Search', onSelect: null),
    MenuAction(icon: Icons.favorite, label: 'Favorites', onSelect: null),
    MenuAction(icon: Icons.category, label: 'Categories', onSelect: null),
    MenuAction(icon: Icons.schedule, label: 'Schedule', onSelect: null),
    MenuAction(icon: Icons.skip_previous, label: 'Previous', onSelect: null),
    MenuAction(icon: Icons.skip_next, label: 'Next', onSelect: null),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _scrollController = ScrollController(
      initialScrollOffset: (_currentIndex * 68.0) - (68.0 * 2),
    );
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
        useAsmsSubtitles: true,
        useAsmsTracks: true,
        useAsmsAudioTracks: true,
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
    return Dpad.wrap(
      debugOverlay: false, // Set to true only while testing
      onBack: () {
        if (_isOverlayVisible) {
          _toggleOverlay();
          return true;
        }
        return false;
      },
      child: WillPopScope(
        onWillPop: () async {
          if (_isOverlayVisible) {
            _toggleOverlay();
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Fullscreen Video Player
              ExcludeFocus(
                child: BetterPlayer(controller: _betterPlayerController),
              ),

              // Overlay (Channel Zap + Menu)
              if (_isOverlayVisible)
                Container(
                  color: Colors.black.withOpacity(0.92),
                  child: Row(
                    children: [
                      // Left: Channel List (Zap)
                      Expanded(
                        flex: 3,
                        child: DpadRegion(
                          memoryKey: 'player_channel_list',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Back Button
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: DpadFocusable(
                                  autofocus: true,
                                  onSelect: () => Navigator.pop(context),
                                  effects: const [DpadScaleEffect(scale: 1.08)],
                                  child: _buildBackButton(),
                                ),
                              ),

                              // Channels
                              Expanded(
                                child: ListView.builder(
                                  controller: _scrollController,
                                  itemCount: widget.channels.length,
                                  itemBuilder: (context, index) =>
                                      _buildChannelItem(index),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right: Modern Menu Bar
                      Container(
                        width: 110,
                        color: Colors.black87,
                        child: DpadRegion(
                          memoryKey: 'player_menu',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _menuActions.map(_buildMenuItem).toList(),
                          ),
                        ),
                      ),

                      // Spacer
                      const Expanded(flex: 4, child: SizedBox()),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.themeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back, color: Colors.black, size: 28),
          SizedBox(width: 12),
          Text(
            'Back to Dashboard',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
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
      effects: const [
        DpadScaleEffect(scale: 1.04),
        DpadGlowEffect(),
      ],
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: isPlaying ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isPlaying
              ? Border.all(color: widget.themeColor, width: 2)
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isPlaying ? widget.themeColor : Colors.white70,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  color: isPlaying ? widget.themeColor : Colors.white,
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isPlaying)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(Icons.play_circle, color: widget.themeColor, size: 28),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(MenuAction action) {
    final onSelect = action.onSelect ?? () {}; // Default empty action

    return DpadFocusable(
      onSelect: () {
        onSelect();
        // Optional: close overlay after action
        // _toggleOverlay();
      },
      effects: const [DpadScaleEffect(scale: 1.12)],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(action.icon, color: Colors.white, size: 34),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for configurable menu
class MenuAction {
  final IconData icon;
  final String label;
  final VoidCallback? onSelect;

  MenuAction({
    required this.icon,
    required this.label,
    this.onSelect,
  });
}
