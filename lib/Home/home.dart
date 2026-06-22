import 'package:cached_network_image/cached_network_image.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/channel.dart';
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

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    if (settings.startupScreen == 'movies') _navIndex = 1;
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

    // Theme Color
    Color themeColor = Colors.amber;
    if (settings.theme == 'red') themeColor = Colors.redAccent;
    if (settings.theme == 'blue') themeColor = Colors.blueAccent;
    if (settings.theme == 'green') themeColor = Colors.greenAccent;

    return Dpad.wrap(
      debugOverlay: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF17262A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background
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
              error: (err, stack) => Center(
                child: Text('Error loading channels: $err', style: const TextStyle(color: Colors.red)),
              ),
              data: (allChannels) {
                final tabChannels = _getFilteredChannels(allChannels);
                final managedGroups = groupsAsync.asData?.value ?? [];

                final categories = tabChannels.map((c) => c.group).toSet().toList()
                  ..sort((a, b) {
                    final ga = managedGroups.firstWhere((g) => g.name == a, orElse: () => ChannelGroup(key: '', name: a, order: 999999));
                    final gb = managedGroups.firstWhere((g) => g.name == b, orElse: () => ChannelGroup(key: '', name: b, order: 999999));
                    if (ga.order != gb.order) return ga.order.compareTo(gb.order);
                    return a.toLowerCase().compareTo(b.toLowerCase());
                  });

                if (_selectedCategory == null && categories.isNotEmpty) {
                  _selectedCategory = categories.first;
                }

                final displayChannels = tabChannels.where((c) => c.group == _selectedCategory).toList();

                return Directionality(
                  textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                  child: Row(
                    children: [
                      // Sidebar
                      _buildSidebar(themeColor, lang),

                      // Categories
                      if (_navIndex < 2)
                        _buildCategories(categories, themeColor, lang),

                      // Main Content
                      Expanded(
                        child: _navIndex < 2
                            ? _buildChannelsGrid(displayChannels, themeColor, lang, settings.hardwareDecoding)
                            : _buildSettings(settings, themeColor, lang),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(Color themeColor, String lang) {
    return DpadRegion(
      memoryKey: 'home_sidebar',
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Image.asset('assets/images/flut.png', width: 70, height: 70),
            const SizedBox(height: 50),
            _SidebarItem(
              icon: Icons.live_tv_rounded,
              label: Localization.t('live_tv', lang),
              isSelected: _navIndex == 0,
              themeColor: themeColor,
              onSelect: () => setState(() {
                _navIndex = 0;
                _selectedCategory = null;
              }),
            ),
            _SidebarItem(
              icon: Icons.movie_creation_rounded,
              label: Localization.t('movies', lang),
              isSelected: _navIndex == 1,
              themeColor: themeColor,
              onSelect: () => setState(() {
                _navIndex = 1;
                _selectedCategory = null;
              }),
            ),
            const Spacer(),
            _SidebarItem(
              icon: Icons.settings_rounded,
              label: Localization.t('settings', lang),
              isSelected: _navIndex == 2,
              themeColor: themeColor,
              onSelect: () => setState(() => _navIndex = 2),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(List<String> categories, Color themeColor, String lang) {
    return DpadRegion(
      memoryKey: 'home_categories',
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(28.0),
              child: Text(
                _navIndex == 0 ? Localization.t('live_tv', lang) : Localization.t('movies', lang),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = _selectedCategory == cat;
                  return _CategoryItem(
                    title: cat,
                    isSelected: isSelected,
                    themeColor: themeColor,
                    onSelect: () => setState(() => _selectedCategory = cat),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsGrid(List<Channel> channels, Color themeColor, String lang, bool hardwareDecoding) {
    if (channels.isEmpty) {
      return const Center(child: Text("No channels available", style: TextStyle(color: Colors.white54, fontSize: 18)));
    }

    return DpadRegion(
      memoryKey: 'home_channels',
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.78,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            return _ChannelCard(
              channel: channel,
              themeColor: themeColor,
              allChannels: channels,
              initialIndex: index,
              hardwareDecoding: hardwareDecoding,
              lang: lang,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettings(SettingsState settings, Color themeColor, String lang) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 90, color: themeColor.withOpacity(0.9)),
            const SizedBox(height: 30),
            Text(Localization.t('settings', lang), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 60),
            _SettingsRow(title: Localization.t('language', lang), value: settings.language.toUpperCase(), onTap: () {
              final newLang = settings.language == 'en' ? 'ar' : settings.language == 'ar' ? 'ku' : 'en';
              ref.read(settingsProvider.notifier).setLanguage(newLang);
            }, themeColor: themeColor),
            _SettingsRow(title: Localization.t('theme', lang), value: settings.theme, onTap: () {
              final themes = ['amber', 'red', 'blue', 'green'];
              final idx = themes.indexOf(settings.theme);
              ref.read(settingsProvider.notifier).setTheme(themes[(idx + 1) % themes.length]);
            }, themeColor: themeColor),
            // Add more settings rows as needed...
            const SizedBox(height: 50),
            _LogoutButton(themeColor: themeColor, lang: lang, onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_code');
              ref.read(authStateProvider.notifier).state = false;
            }),
          ],
        ),
      ),
    );
  }

  // ==================== Reusable Dpad Widgets ====================

  Widget _SidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color themeColor,
    required VoidCallback onSelect,
  }) {
    return DpadFocusable(
      onSelect: onSelect,
      effects: const [DpadScaleEffect(scale: 1.1)],
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: isSelected ? themeColor : Colors.transparent, width: 5)),
          color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? themeColor : Colors.white70, size: 32),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: isSelected ? themeColor : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _CategoryItem({
    required String title,
    required bool isSelected,
    required Color themeColor,
    required VoidCallback onSelect,
  }) {
    return DpadFocusable(
      onSelect: onSelect,
      effects: const [DpadScaleEffect(scale: 1.05)],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
    );
  }

  Widget _ChannelCard({
    required Channel channel,
    required Color themeColor,
    required List<Channel> allChannels,
    required int initialIndex,
    required bool hardwareDecoding,
    required String lang,
  }) {
    return DpadFocusable(
      onSelect: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Player(
              channels: allChannels,
              initialIndex: initialIndex,
              themeColor: themeColor,
              hardwareDecoding: hardwareDecoding,
              lang: lang,
            ),
          ),
        );
      },
      effects: const [DpadScaleEffect(scale: 1.08), DpadGlowEffect()],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.white.withOpacity(0.04)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: CachedNetworkImage(
                imageUrl: channel.logo ?? '',
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const Icon(Icons.tv, size: 60, color: Colors.white24),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                  ),
                ),
                child: Text(
                  channel.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _SettingsRow({
    required String title,
    required String value,
    required VoidCallback onTap,
    required Color themeColor,
  }) {
    return DpadFocusable(
      onSelect: onTap,
      effects: const [DpadScaleEffect(scale: 1.05)],
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, color: Colors.white)),
            Text(value, style: TextStyle(fontSize: 20, color: themeColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _LogoutButton({required Color themeColor, required String lang, required VoidCallback onPressed}) {
    return DpadFocusable(
      onSelect: onPressed,
      effects: const [DpadScaleEffect(scale: 1.1)],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout, color: Colors.white),
            const SizedBox(width: 12),
            Text(Localization.t('logout', lang), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
