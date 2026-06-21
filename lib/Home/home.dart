import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/channel.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';

final channelsProvider = FutureProvider<List<Channel>>((ref) async {
  final snapshot = await FirebaseDatabase.instance.ref('sync/global/managedPlaylist').get();
  if (!snapshot.exists || snapshot.value == null) return [];
  
  final List<Channel> channels = [];
  final data = snapshot.value as List<dynamic>;
  
  for (var item in data) {
    if (item != null) {
      channels.add(Channel.fromMap(item as Map<dynamic, dynamic>));
    }
  }
  return channels;
});

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  int _navIndex = 0; // 0: Live, 1: Movies, 2: Series, 3: Settings
  String? _selectedCategory;

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
            onTap: () => setState(() { _navIndex = 0; _selectedCategory = null; }),
          ),
          _SidebarItem(
            icon: Icons.movie_creation_rounded,
            label: 'MOVIES',
            isSelected: _navIndex == 1,
            onFocus: () => setState(() { _navIndex = 1; _selectedCategory = null; }),
            onTap: () => setState(() { _navIndex = 1; _selectedCategory = null; }),
          ),
          _SidebarItem(
            icon: Icons.video_library_rounded,
            label: 'SERIES',
            isSelected: _navIndex == 2,
            onFocus: () => setState(() { _navIndex = 2; _selectedCategory = null; }),
            onTap: () => setState(() { _navIndex = 2; _selectedCategory = null; }),
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('LOGOUT', style: TextStyle(color: Colors.white, fontSize: 18)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_code');
              ref.read(authStateProvider.notifier).state = false;
              ref.read(authCodeProvider.notifier).state = null;
            },
          )
        ],
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        if (focused) widget.onFocus();
      },
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
    );
  }
}

class _CategoryItem extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  const _CategoryItem({
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        if (focused) widget.onFocus();
      },
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onTap: () {
        // TODO: Navigate to player
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isFocused ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFocused ? Colors.amber : Colors.white.withOpacity(0.1),
            width: _isFocused ? 3 : 1,
          ),
          boxShadow: _isFocused ? [const BoxShadow(color: Colors.amber, blurRadius: 12, spreadRadius: 1)] : [],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Container(
                  color: Colors.white.withOpacity(0.05),
                  padding: const EdgeInsets.all(16),
                  child: CachedNetworkImage(
                    imageUrl: widget.channel.logo,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(Icons.tv, color: Colors.white24, size: 40),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isFocused ? Colors.amber : Colors.black87,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Center(
                child: Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isFocused ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
