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

  // Single root FocusNode that captures ALL key events when overlay is hidden
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'PlayerRoot');

  // FocusScope node that owns all overlay focus when overlay is visible
  final FocusScopeNode _overlayScopeNode = FocusScopeNode(debugLabel: 'OverlayScope');

  late ScrollController _scrollController;

  // Stable per-channel focus nodes – created once, never recreated
  late final List<FocusNode> _channelFocusNodes;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // Pre-allocate all channel focus nodes so they are stable across rebuilds
    _channelFocusNodes = List.generate(
      widget.channels.length,
      (i) => FocusNode(debugLabel: 'Channel_$i'),
    );

    _scrollController = ScrollController(
      initialScrollOffset: _safeScrollOffset(_currentIndex),
    );

    _setupPlayer(widget.channels[_currentIndex].url);

    // Give focus to the root node after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rootFocusNode.requestFocus();
    });
  }

  double _safeScrollOffset(int index) {
    const itemHeight = 68.0;
    final offset = (index * itemHeight) - (itemHeight * 2);
    return offset < 0 ? 0 : offset;
  }

  // ──────────────────────────────────────────────────────
  // Player setup
  // ──────────────────────────────────────────────────────

  void _setupPlayer(String url) {
    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        allowedScreenSleep: false,
        fullScreenByDefault: true,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
      ),
      betterPlayerDataSource: _buildDataSource(url),
    );
  }

  BetterPlayerDataSource _buildDataSource(String url) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      useAsmsSubtitles: true,
      useAsmsTracks: true,
      useAsmsAudioTracks: true,
      headers: {'User-Agent': 'VLC/3.0.9'},
    );
  }

  // ──────────────────────────────────────────────────────
  // Channel switching
  // ──────────────────────────────────────────────────────

  void _changeChannel(int index) {
    if (index < 0 || index >= widget.channels.length) return;
    setState(() => _currentIndex = index);
    _betterPlayerController.setupDataSource(_buildDataSource(widget.channels[index].url));
  }

  void _zap(int direction) {
    int next = (_currentIndex + direction) % widget.channels.length;
    if (next < 0) next = widget.channels.length - 1;
    _changeChannel(next);
  }

  // ──────────────────────────────────────────────────────
  // Overlay toggle – the key place where focus bugs live
  // ──────────────────────────────────────────────────────

  void _showOverlay() {
    setState(() => _isOverlayVisible = true);

    // Two-frame delay: first frame builds the overlay, second ensures
    // the ListView has laid out so scrolling + focus work reliably.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Scroll to bring current channel near the top
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_safeScrollOffset(_currentIndex));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Request focus on the currently playing channel
        _channelFocusNodes[_currentIndex].requestFocus();
      });
    });
  }

  void _hideOverlay() {
    setState(() => _isOverlayVisible = false);
    // Return focus to root so key events are captured again immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rootFocusNode.requestFocus();
    });
  }

  void _toggleOverlay() {
    if (_isOverlayVisible) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  // ──────────────────────────────────────────────────────
  // Global key handler (fires only when overlay is hidden)
  // ──────────────────────────────────────────────────────

  KeyEventResult _handleRootKey(FocusNode node, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_isOverlayVisible) {
      // While overlay is visible, only BACK closes it (channel list handles its own keys)
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack ||
          key == LogicalKeyboardKey.gameButtonB) {
        _hideOverlay();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Overlay hidden: handle all remote-control keys here
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      _showOverlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.channelUp) {
      _zap(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.channelDown) {
      _zap(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ──────────────────────────────────────────────────────
  // Dispose
  // ──────────────────────────────────────────────────────

  @override
  void dispose() {
    _betterPlayerController.dispose();
    _rootFocusNode.dispose();
    _overlayScopeNode.dispose();
    _scrollController.dispose();
    for (final node in _channelFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // ──────────────────────────────────────────────────────
  // Build helpers
  // ──────────────────────────────────────────────────────

  Widget _buildChannelListItem(int index) {
    final channel = widget.channels[index];
    final isPlaying = _currentIndex == index;
    final focusNode = _channelFocusNodes[index];

    return _FocusableItem(
      key: ValueKey('channel_$index'),
      focusNode: focusNode,
      onTap: () {
        _changeChannel(index);
        _hideOverlay();
      },
      builder: (context, isFocused) {
        return Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isFocused
                ? widget.themeColor
                : (isPlaying ? Colors.white12 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              SizedBox(
                width: 36,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isFocused ? Colors.black : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  channel.name,
                  style: TextStyle(
                    color: isFocused
                        ? Colors.black
                        : (isPlaying ? widget.themeColor : Colors.white),
                    fontWeight:
                        isPlaying ? FontWeight.bold : FontWeight.normal,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPlaying)
                Icon(Icons.play_arrow,
                    color: isFocused ? Colors.black : widget.themeColor,
                    size: 20),
              const SizedBox(width: 12),
              Icon(Icons.favorite_border,
                  color: isFocused ? Colors.black54 : Colors.white38,
                  size: 18),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: isFocused ? Colors.black : Colors.white, size: 26),
              if (label.isNotEmpty) ...[
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
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // PopScope replaces the deprecated WillPopScope
    return PopScope(
      canPop: !_isOverlayVisible,
      onPopInvoked: (didPop) {
        if (!didPop && _isOverlayVisible) {
          _hideOverlay();
        }
      },
      child: Focus(
        focusNode: _rootFocusNode,
        onKey: _handleRootKey,
        // autofocus: false – we manually request focus in initState
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Video Player ──────────────────────────────────
              ExcludeFocus(
                child: BetterPlayer(controller: _betterPlayerController),
              ),

              // ── Overlay ───────────────────────────────────────
              if (_isOverlayVisible) _buildOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.88),
      child: FocusScope(
        node: _overlayScopeNode,
        child: Row(
          children: [
            // ── Left: Channel List ──────────────────────────
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: _FocusableItem(
                      onTap: () => Navigator.pop(context),
                      builder: (context, isFocused) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? widget.themeColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back,
                                  color: isFocused
                                      ? Colors.black
                                      : Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Back to Dashboard',
                                style: TextStyle(
                                  color: isFocused
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Channel list
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: widget.channels.length,
                      // cacheExtent keeps off-screen items alive so their
                      // FocusNodes don't disappear when scrolling fast
                      cacheExtent: 500,
                      itemBuilder: (context, index) =>
                          _buildChannelListItem(index),
                    ),
                  ),
                ],
              ),
            ),

            // ── Right: Action Icons ─────────────────────────
            Container(
              width: 90,
              color: Colors.black87,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionIcon(Icons.close, 'Close', _hideOverlay),
                  _buildActionIcon(Icons.search, 'Search', () {}),
                  _buildActionIcon(Icons.category, 'Type', () {}),
                  _buildActionIcon(Icons.favorite, 'Fav', () {}),
                  _buildActionIcon(Icons.list, 'List', () {}),
                  _buildActionIcon(Icons.schedule, 'Time', () {}),
                  _buildActionIcon(
                      Icons.skip_next, 'Next', () => _zap(1)),
                  _buildActionIcon(
                      Icons.skip_previous, 'Prev', () => _zap(-1)),
                ],
              ),
            ),

            // ── Spacer (right preview area) ─────────────────
            const Expanded(flex: 4, child: SizedBox()),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FocusableItem
//
// A stable focus-aware widget. Pass an external FocusNode when you need to
// control focus from outside (e.g. channel list items). If no node is passed
// one is created and owned internally.
// ─────────────────────────────────────────────────────────────────────────────

class _FocusableItem extends StatefulWidget {
  final Widget Function(BuildContext context, bool isFocused) builder;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const _FocusableItem({
    super.key,
    required this.builder,
    required this.onTap,
    this.focusNode,
  });

  @override
  State<_FocusableItem> createState() => _FocusableItemState();
}

class _FocusableItemState extends State<_FocusableItem> {
  bool _isFocused = false;
  late FocusNode _node;
  bool _ownsNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _node = widget.focusNode!;
    } else {
      _node = FocusNode();
      _ownsNode = true;
    }
  }

  @override
  void dispose() {
    if (_ownsNode) _node.dispose();
    super.dispose();
  }

  static bool _isConfirm(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.gameButtonA;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onFocusChange: (focused) {
        if (mounted) setState(() => _isFocused = focused);
      },
      onKey: (node, event) {
        if (event is RawKeyDownEvent && _isConfirm(event.logicalKey)) {
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
