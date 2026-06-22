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
import '../services/settings_provider.dart';
import '../services/localization.dart';

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  int _navIndex = 0; // 0: Live, 1: Movies, 2: Settings
  String? _selectedCategory;

  final Map<String, FocusNode> _categoryNodes = {};
  final FocusNode _liveTvFocusNode = FocusNode();
  final FocusNode _moviesFocusNode = FocusNode();
  final FocusNode _settingsFocusNode = FocusNode();
  bool _initialized = false;

  @override
  void dispose() {
    for (var node in _categoryNodes.values) {
      node.dispose();
    }
    _liveTvFocusNode.dispose();
    _moviesFocusNode.dispose();
    _settingsFocusNode.dispose();
    super.dispose();
  }

  List<Channel> _getFilteredChannels(List<Channel> all) {
    if (_navIndex == 0) {
      return all.where((c) => c.type != 'movie' && c.type != 'series').toList();
    } else if (_navIndex == 1) {
      return all.where((c) => c.type == 'movie').toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final settings = ref.watch(settingsProvider);
    final String lang = settings.language;
    
    // Theme Color Mapping
    Color themeColor = Colors.amber;
    if (settings.theme == 'red') themeColor = Colors.redAccent;
    if (settings.theme == 'blue') themeColor = Colors.blueAccent;
    if (settings.theme == 'green') themeColor = Colors.greenAccent;

    // Handle Startup Screen
    if (!_initialized) {
      _initialized = true;
      if (settings.startupScreen == 'movies') _navIndex = 1;
    }

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
            loading: () => Center(child: CircularProgressIndicator(color: themeColor)),
            error: (err, stack) => Center(child: Text('${Localization.t('error_loading', lang)} $err', style: const TextStyle(color: Colors.red))),
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

              return Directionality(
                textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                child: Row(
                  children: [
                    // 1. Sidebar Menu
                    _buildSidebar(lang, themeColor),
                    
                    // 2. Categories List
                    if (_navIndex < 2) 
                      _buildCategories(categories, lang, themeColor),

                    // 3. Channels Grid
                    if (_navIndex < 2)
                      Expanded(
                        child: _buildChannelsGrid(displayChannels, themeColor, lang, settings.hardwareDecoding),
                      ),
                      
                    // Settings View
                    if (_navIndex == 2)
                      Expanded(
                        child: _buildSettings(settings, lang, themeColor),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(String lang, Color themeColor) {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Image.asset('assets/images/flut.png', width: 60, height: 60),
          const SizedBox(height: 40),
          _SidebarItem(
            focusNode: _liveTvFocusNode,
            themeColor: themeColor,
            icon: Icons.live_tv_rounded,
            label: Localization.t('live_tv', lang),
            isSelected: _navIndex == 0,
            onFocus: () => setState(() { _navIndex = 0; _selectedCategory = null; }),
            onTap: () {
              setState(() { _navIndex = 0; _selectedCategory = null; });
              if (_categoryNodes.isNotEmpty) _categoryNodes.values.first.requestFocus();
            },
            onMoveRight: () {
              if (_categoryNodes.isNotEmpty) _categoryNodes.values.first.requestFocus();
            },
          ),
          _SidebarItem(
            focusNode: _moviesFocusNode,
            themeColor: themeColor,
            icon: Icons.movie_creation_rounded,
            label: Localization.t('movies', lang),
            isSelected: _navIndex == 1,
            onFocus: () => setState(() { _navIndex = 1; _selectedCategory = null; }),
            onTap: () {
              setState(() { _navIndex = 1; _selectedCategory = null; });
              if (_categoryNodes.isNotEmpty) _categoryNodes.values.first.requestFocus();
            },
            onMoveRight: () {
              if (_categoryNodes.isNotEmpty) _categoryNodes.values.first.requestFocus();
            },
          ),
          const Spacer(),
          _SidebarItem(
            focusNode: _settingsFocusNode,
            themeColor: themeColor,
            icon: Icons.settings_rounded,
            label: Localization.t('settings', lang),
            isSelected: _navIndex == 2,
            onFocus: () => setState(() => _navIndex = 2),
            onTap: () => setState(() => _navIndex = 2),
            onMoveRight: () {},
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategories(List<String> categories, String lang, Color themeColor) {
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
              _navIndex == 0 ? Localization.t('live_tv', lang) : Localization.t('movies', lang),
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
                final isSelected = _selectedCategory == cat;
                return _CategoryItem(
                  themeColor: themeColor,
                  focusNode: _categoryNodes.putIfAbsent(cat, () => FocusNode()),
                  title: cat,
                  isSelected: isSelected,
                  onFocus: () => setState(() => _selectedCategory = cat),
                  onTap: () => setState(() => _selectedCategory = cat),
                  onMoveLeft: () {
                    if (_navIndex == 0) _liveTvFocusNode.requestFocus();
                    else if (_navIndex == 1) _moviesFocusNode.requestFocus();
                    else _settingsFocusNode.requestFocus();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsGrid(List<Channel> channels, Color themeColor, String lang, bool hardwareDecoding) {
    if (channels.isEmpty) {
      return Center(child: Text(Localization.t('no_content', lang), style: const TextStyle(color: Colors.white54)));
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
          return _ChannelCard(
            channel: channel, 
            themeColor: themeColor,
            channels: channels,
            initialIndex: index,
            hardwareDecoding: hardwareDecoding,
            lang: lang,
            onMoveLeft: (index % 5 == 0) ? () {
              if (_selectedCategory != null && _categoryNodes.containsKey(_selectedCategory)) {
                _categoryNodes[_selectedCategory]!.requestFocus();
              } else if (_categoryNodes.isNotEmpty) {
                _categoryNodes.values.first.requestFocus();
              }
            } : null,
          );
        },
      ),
    );
  }

  Widget _buildSettings(SettingsState settings, String lang, Color themeColor) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 80, color: themeColor.withOpacity(0.8)),
            const SizedBox(height: 24),
            Text(Localization.t('settings', lang), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 40),
            
            // Language
            _SettingsRow(
              themeColor: themeColor,
              title: Localization.t('language', lang),
              value: Localization.t(settings.language, lang),
              onTap: () {
                final newLang = settings.language == 'en' ? 'ar' : settings.language == 'ar' ? 'ku' : 'en';
                ref.read(settingsProvider.notifier).setLanguage(newLang);
              },
            ),
            
            // Theme
            _SettingsRow(
              themeColor: themeColor,
              title: Localization.t('theme', lang),
              value: Localization.t(settings.theme, lang),
              onTap: () {
                final newTheme = settings.theme == 'amber' ? 'red' : settings.theme == 'red' ? 'blue' : settings.theme == 'blue' ? 'green' : 'amber';
                ref.read(settingsProvider.notifier).setTheme(newTheme);
              },
            ),

            // Startup Screen
            _SettingsRow(
              themeColor: themeColor,
              title: Localization.t('startup_screen', lang),
              value: Localization.t(settings.startupScreen == 'live' ? 'live_tv' : settings.startupScreen, lang),
              onTap: () {
                final newScreen = settings.startupScreen == 'live' ? 'movies' : 'live';
                ref.read(settingsProvider.notifier).setStartupScreen(newScreen);
              },
            ),

            // Hardware Decoding
            _SettingsRow(
              themeColor: themeColor,
              title: Localization.t('hardware_decoding', lang),
              value: settings.hardwareDecoding ? Localization.t('enabled', lang) : Localization.t('disabled', lang),
              onTap: () {
                ref.read(settingsProvider.notifier).setHardwareDecoding(!settings.hardwareDecoding);
              },
            ),

            const SizedBox(height: 40),
            _TvSettingsButton(
              icon: Icons.logout,
              label: Localization.t('logout', lang),
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
      ),
    );
  }
}

class _SettingsRow extends StatefulWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color themeColor;

  const _SettingsRow({required this.title, required this.value, required this.onTap, required this.themeColor});

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKey: (node, event) {
        if (event is RawKeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _isFocused ? widget.themeColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? widget.themeColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 20)),
              Text(widget.value, style: TextStyle(color: _isFocused ? widget.themeColor : Colors.white70, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
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
          duration: const Duration(milliseconds: 50),
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
  final Color themeColor;
  final VoidCallback? onMoveRight;
  final FocusNode? focusNode;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onFocus,
    required this.onTap,
    required this.themeColor,
    this.onMoveRight,
    this.focusNode,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isFocused = false;

  late FocusNode _localFocusNode;

  @override
  void initState() {
    super.initState();
    _localFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _localFocusNode.dispose();
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
      } else if (key == LogicalKeyboardKey.arrowRight && widget.onMoveRight != null) {
        widget.onMoveRight!();
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
          duration: const Duration(milliseconds: 50),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: widget.isSelected ? widget.themeColor : Colors.transparent,
                width: 4,
              ),
            ),
            color: _isFocused ? Colors.white.withOpacity(0.1) : Colors.transparent,
          ),
          child: Column(
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected || _isFocused ? widget.themeColor : Colors.white54,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected || _isFocused ? widget.themeColor : Colors.white54,
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
  final String title;
  final bool isSelected;
  final VoidCallback onFocus;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final Color themeColor;
  final VoidCallback? onMoveLeft;

  const _CategoryItem({
    required this.title,
    required this.isSelected,
    required this.onFocus,
    required this.onTap,
    required this.themeColor,
    this.focusNode,
    this.onMoveLeft,
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
      } else if (key == LogicalKeyboardKey.arrowLeft && widget.onMoveLeft != null) {
        widget.onMoveLeft!();
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
          duration: const Duration(milliseconds: 50),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _isFocused 
                ? widget.themeColor 
                : (widget.isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              color: _isFocused ? Colors.black : (widget.isSelected ? widget.themeColor : Colors.white70),
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
  final Color themeColor;
  final List<Channel> channels;
  final int initialIndex;
  final bool hardwareDecoding;
  final String lang;
  final VoidCallback? onMoveLeft;

  const _ChannelCard({
    required this.channel, 
    required this.themeColor,
    required this.channels,
    required this.initialIndex,
    required this.hardwareDecoding,
    required this.lang,
    this.onMoveLeft,
  });

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
      } else if (key == LogicalKeyboardKey.arrowLeft && widget.onMoveLeft != null) {
        widget.onMoveLeft!();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _navigateToPlayer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Player(
          channels: widget.channels,
          initialIndex: widget.initialIndex,
          themeColor: widget.themeColor,
          hardwareDecoding: widget.hardwareDecoding,
          lang: widget.lang,
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
          duration: const Duration(milliseconds: 50),
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
