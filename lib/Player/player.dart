import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player/better_player.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
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
  
  // To restore focus when overlay toggles
  FocusScopeNode _overlayFocusScopeNode = FocusScopeNode();
  late FocusNode _globalFocusNode;
  
  // Track which item in the channel list is currently playing
  late ScrollController _scrollController;
  final Map<int, FocusNode> _channelFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _globalFocusNode = FocusNode();
    _currentIndex = widget.initialIndex;
    _scrollController = ScrollController(initialScrollOffset: _currentIndex * 68.0);
    _setupPlayer(widget.channels[_currentIndex].url);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _globalFocusNode.requestFocus();
    });
  }

  void _setupPlayer(String url) {
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      useAsmsSubtitles: true,
      useAsmsTracks: true,
      useAsmsAudioTracks: true,
      headers: {"User-Agent": "VLC/3.0.9"}, // Fix for strict IPTV servers
    );

    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        allowedScreenSleep: false,
        fullScreenByDefault: true,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false, // Completely custom UI
        ),
      ),
      betterPlayerDataSource: dataSource,
    );
  }

  void _changeChannel(int index) {
    setState(() {
      _currentIndex = index;
    });

    _betterPlayerController.setupDataSource(BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.channels[_currentIndex].url,
      useAsmsSubtitles: true,
      useAsmsTracks: true,
      useAsmsAudioTracks: true,
      headers: {"User-Agent": "VLC/3.0.9"},
    ));
  }

  void _zap(int direction) {
    int newIndex = _currentIndex + direction;
    if (newIndex < 0) {
      newIndex = widget.channels.length - 1;
    } else if (newIndex >= widget.channels.length) {
      newIndex = 0;
    }
    _changeChannel(newIndex);
  }

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
    if (_isOverlayVisible) {
      _overlayFocusScopeNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // Align the selected item near the middle (subtracting a few items' height)
          double offset = (_currentIndex * 68.0) - (68.0 * 2);
          if (offset < 0) offset = 0;
          _scrollController.jumpTo(offset);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _channelFocusNodes.containsKey(_currentIndex)) {
            _channelFocusNodes[_currentIndex]?.requestFocus();
          }
        });
      });
    } else {
      _globalFocusNode.requestFocus();
    }
  }

  KeyEventResult _handleGlobalKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      
      // If overlay is hidden, OK button opens it. UP/DOWN zaps.
      if (!_isOverlayVisible) {
        if (key == LogicalKeyboardKey.select || 
            key == LogicalKeyboardKey.enter || 
            key == LogicalKeyboardKey.numpadEnter || 
            key == LogicalKeyboardKey.space || 
            key == LogicalKeyboardKey.gameButtonA) {
          _toggleOverlay();
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.channelUp) {
          _zap(-1);
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.channelDown) {
          _zap(1);
          return KeyEventResult.handled;
        }
      } else {
        // If overlay is visible, BACK button closes it
        if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.gameButtonB) {
          _toggleOverlay();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    _overlayFocusScopeNode.dispose();
    _globalFocusNode.dispose();
    _scrollController.dispose();
    for (var node in _channelFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Widget _buildChannelListItem(int index) {
    final channel = widget.channels[index];
    final isPlaying = _currentIndex == index;
    final focusNode = _channelFocusNodes.putIfAbsent(index, () => FocusNode());
    
    return _FocusableItem(
      focusNode: focusNode,
      onTap: () {
        _changeChannel(index);
        _toggleOverlay(); // Auto-hide menu when channel is selected
      },
      builder: (context, isFocused) {
        return Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isFocused ? widget.themeColor : (isPlaying ? Colors.white12 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Text(
                '${index + 1}',
                style: TextStyle(color: isFocused ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  channel.name,
                  style: TextStyle(
                    color: isFocused ? Colors.black : (isPlaying ? widget.themeColor : Colors.white),
                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPlaying)
                Icon(Icons.play_arrow, color: isFocused ? Colors.black : widget.themeColor),
              const SizedBox(width: 16),
              Icon(Icons.favorite_border, color: isFocused ? Colors.black54 : Colors.white54, size: 20),
              const SizedBox(width: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionIcon(IconData icon, String label, VoidCallback onTap) {
    return _FocusableItem(
      onTap: onTap,
      builder: (context, isFocused) {
        return Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isFocused ? widget.themeColor : Colors.transparent,
          ),
          child: Column(
            children: [
              Icon(icon, color: isFocused ? Colors.black : Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isFocused ? Colors.black : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isOverlayVisible) {
          _toggleOverlay();
          return false;
        }
        return true;
      },
      child: Focus(
        focusNode: _globalFocusNode,
        onKey: _handleGlobalKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. The Video Player
              SafeArea(
                child: ExcludeFocus(
                  child: BetterPlayer(controller: _betterPlayerController),
                ),
              ),
              
              // 2. Custom Overlay
              if (_isOverlayVisible)
                Container(
                  color: Colors.black.withOpacity(0.85), // Darker transparent background
                  child: FocusScope(
                    node: _overlayFocusScopeNode,
                    child: Row(
                      children: [
                        // Left: Channel List
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: _FocusableItem(
                                  onTap: () => Navigator.pop(context),
                                  builder: (context, isFocused) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isFocused ? widget.themeColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.arrow_back, color: isFocused ? Colors.black : Colors.white),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Back to Dashboard', 
                                            style: TextStyle(
                                              color: isFocused ? Colors.black : Colors.white, 
                                              fontSize: 18, 
                                              fontWeight: FontWeight.bold
                                            )
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  controller: _scrollController,
                                  itemCount: widget.channels.length,
                                  itemBuilder: (context, index) {
                                    return _buildChannelListItem(index);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Right: Action Menu Column
                      Container(
                        width: 90,
                        color: Colors.black87,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionIcon(Icons.menu, '', () {}),
                            _buildActionIcon(Icons.search, 'Search', () {}),
                            _buildActionIcon(Icons.category, 'Type', () {}),
                            _buildActionIcon(Icons.favorite, 'Fav', () {}),
                            _buildActionIcon(Icons.list, 'List', () {}),
                            _buildActionIcon(Icons.schedule, 'Time', () {}),
                            _buildActionIcon(Icons.skip_next, 'Next', () => _zap(1)),
                            _buildActionIcon(Icons.skip_previous, 'Prev', () => _zap(-1)),
                          ],
                        ),
                      ),
                      
                      // Empty space to right (to match ratio from picture)
                      Expanded(flex: 4, child: Container()),
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

// Helper widget for easy focus management
class _FocusableItem extends StatefulWidget {
  final Widget Function(BuildContext context, bool isFocused) builder;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const _FocusableItem({required this.builder, required this.onTap, this.focusNode});

  @override
  State<_FocusableItem> createState() => _FocusableItemState();
}

class _FocusableItemState extends State<_FocusableItem> {
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKey: (node, event) {
        if (event is RawKeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter ||
             event.logicalKey == LogicalKeyboardKey.space ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.builder(context, _isFocused),
      ),
    );
  }
}
