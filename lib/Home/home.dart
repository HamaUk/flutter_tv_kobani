import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/channel.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Player/player.dart';

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  int _navIndex = 0; // 0: Live, 1: Movies, 2: Series, 3: Settings
  String? _selectedCategory;
  final FocusNode _firstCategoryFocusNode = FocusNode();

  @override
  void dispose() {
    _firstCategoryFocusNode.dispose();
    super.dispose();
  }

  List<Channel> _getFilteredChannels(List<Channel> all) {
    if (_navIndex == 0) {
      return all.where((c) => c.type != 'movie' && c.type != 'series').toList();
    } else if (_navIndex == 1) {
      return all.where((c) => c.type == 'movie').toList();
    } else if (_navIndex == 2) {
      return all.where((c) => c.type == 'series').toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF17262A), // Dark theme from template
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF17262A), Color(0xFF213333), Color(0xFF17262A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          channelsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
            error: (err, stack) => Center(child: Text('Error loading channels: $err', style: const TextStyle(color: Colors.red))),
            data: (allChannels) {
              final tabChannels = _getFilteredChannels(allChannels);
              final managedGroups = groupsAsync.asData?.value ?? [];
              
              // Extract unique categories and sort them by managedGroups order
              final categories = tabChannels.map((c) => c.group).toSet().toList()
                ..sort((a, b) {
                  final ga = managedGroups.firstWhere((g) => g.name == a, orElse: () => ChannelGroup(key: '', name: a, order: 999999));
                  final gb = managedGroups.firstWhere((g) => g.name == b, orElse: () => ChannelGroup(key: '', name: b, order: 999999));
                  if (ga.order != gb.order) return ga.order.compareTo(gb.order);
                  return a.toLowerCase().compareTo(b.toLowerCase());
                });
              if (_selectedCategory == null && categories.isNotEmpty) {
                // Auto-select first category
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedCategory = categories.first);
                });
              }

              final displayChannels = tabChannels.where((c) => c.group == _selectedCategory).toList();

              return Row(
                children: [
                  // 1. Sidebar Menu
                  _buildSidebar(),
                  
                  // 2. Categories List
                  if (_navIndex < 3) 
                    _buildCategories(categories),

                  // 3. Channels Grid
                  if (_navIndex < 3)
                    Expanded(
                      child: _buildChannelsGrid(displayChannels),
                    ),
                    
                  // Settings View
                  if (_navIndex == 3)
                    Expanded(
                      child: _buildSettings(),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Icon(Icons.tv_rounded, color: Colors.amber, size: 40),
          const SizedBox(height: 40),
          _SidebarItem(
            icon: Icons.live_tv_rounded,
            label: 'LIVE',
            isSelected: _navIndex == 0,
            onFocus: () => setState(() { _navIndex = 0; _selectedCategory = null; }),
            onTap: () {
              setState(() { _navIndex = 0; _selectedCategory = null; });
              _firstCategoryFocusNode.requestFocus();
            },
          ),
          _SidebarItem(
            icon: Icons.movie_creation_rounded,
            label: 'MOVIES',
            isSelected: _navIndex == 1,
            onFocus: () => setState(() { _navIndex = 1; _selectedCategory = null; }),
            onTap: () {
              setState(() { _navIndex = 1; _selectedCategory = null; });
              _firstCategoryFocusNode.requestFocus();
            },
          ),
          _SidebarItem(
            icon: Icons.video_library_rounded,
            label: 'SERIES',
            isSelected: _navIndex == 2,
            onFocus: () => setState(() { _navIndex = 2; _selectedCategory = null; }),
            onTap: () {
              setState(() { _navIndex = 2; _selectedCategory = null; });
              _firstCategoryFocusNode.requestFocus();
            },
          ),
          const Spacer(),
          _SidebarItem(
            icon: Icons.settings_rounded,
            label: 'SETTINGS',
            isSelected: _navIndex == 3,
            onFocus: () => setState(() => _navIndex = 3),
            onTap: () => setState(() => _navIndex = 3),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategories(List<String> categories) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _navIndex == 0 ? 'LIVE TV' : _navIndex == 1 ? 'MOVIES' : 'SERIES',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return _CategoryItem(
                  focusNode: index == 0 ? _firstCategoryFocusNode : null,
                  title: cat,
                  isSelected: _selectedCategory == cat,
                  onFocus: () => setState(() => _selectedCategory = cat),
                  onTap: () => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsGrid(List<Channel> channels) {
    if (channels.isEmpty) {
      return const Center(child: Text('No content available', style: TextStyle(color: Colors.white54)));
    }
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return _ChannelCard(channel: channel);
        },
      ),
    );
  }

  Widget _buildSettings() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.settings, size: 80, color: Colors.white24),
          const SizedBox(height: 24),
          const Text('Settings', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 40),
          _TvSettingsButton(
            icon: Icons.logout,
            label: 'LOGOUT',
            color: Colors.redAccent,
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_code');
              ref.read(authStateProvider.notifier).state = false;
              ref.read(authCodeProvider.notifier).state = null;
            },
          ),
        ],
      ),
    );
  }
}

class _TvSettingsButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _TvSettingsButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_TvSettingsButton> createState() => _TvSettingsButtonState();
}

class _TvSettingsButtonState extends State<_TvSettingsButton> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.space) {
        widget.onPressed();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKey: _handleKey,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused ? [BoxShadow(color: widget.color, blurRadius: 15, spreadRadius: 2)] : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white),
              const SizedBox(width: 12),
              Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onFocus,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isFocused = false;

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.space) {
        widget.onTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        if (focused) widget.onFocus();
      },
      onKey: _handleKey,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: widget.isSelected ? Colors.amber : Colors.transparent,
                width: 4,
              ),
            ),
            color: _isFocused ? Colors.white.withOpacity(0.1) : Colors.transparent,
          ),
          child: Column(
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected || _isFocused ? Colors.amber : Colors.white54,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected || _isFocused ? Colors.amber : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryItem extends StatefulWidget {
  final FocusNode? focusNode;
  final String title;
  final bool isSelected;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  const _CategoryItem({
    this.focusNode,
    required this.title,
    required this.isSelected,
    required this.onFocus,
    required this.onTap,
  });

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem> {
  bool _isFocused = false;
  late FocusNode _localFocusNode;

  @override
  void initState() {
    super.initState();
    _localFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _localFocusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.space) {
        widget.onTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _localFocusNode,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        if (focused) widget.onFocus();
      },
      onKey: _handleKey,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _isFocused 
                ? Colors.amber 
                : (widget.isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              color: _isFocused ? Colors.black : (widget.isSelected ? Colors.amber : Colors.white70),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelCard extends StatefulWidget {
  final Channel channel;

  const _ChannelCard({required this.channel});

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _isFocused = false;

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.space) {
        _navigateToPlayer();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _navigateToPlayer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Player(video_url: widget.channel.url),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKey: _handleKey,
      child: GestureDetector(
        onTap: _navigateToPlayer,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: _isFocused ? (Matrix4.identity()..scale(1.08)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: _isFocused ? 3 : 0,
            ),
            boxShadow: _isFocused 
                ? [const BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))] 
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Glassmorphism Background
                Container(color: Colors.white.withOpacity(0.03)),
                
                // Channel Image
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: CachedNetworkImage(
                    imageUrl: widget.channel.logo ?? '',
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(Icons.tv, color: Colors.white12, size: 50),
                  ),
                ),

                // Bottom Gradient Overlay for text readability
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: 80,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          _isFocused ? Colors.blueGrey.shade900 : Colors.black.withOpacity(0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Channel Name Text
                Positioned(
                  bottom: 12, left: 12, right: 12,
                  child: Text(
                    widget.channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isFocused ? Colors.white : Colors.white70,
                      fontWeight: _isFocused ? FontWeight.bold : FontWeight.w500,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
