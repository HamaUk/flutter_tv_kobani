import 'package:cached_network_image/cached_network_image.dart';
import 'package:dpad/dpad.dart'; // Ensure this package is exactly 'dpad' in pubspec
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart'; // FIXED: Added this

import '../models/channel.dart';
import '../Player/player.dart';
import '../services/settings_provider.dart';
import '../services/localization.dart';
// TODO: Import the file where authStateProvider is defined, for example:
// import '../services/auth_provider.dart'; 

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  int _navIndex = 0; 
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Use Future.delayed or ref.listen to avoid side effects during build if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      if (settings.startupScreen == 'movies') {
        setState(() => _navIndex = 1);
      }
    });
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

    Color themeColor = Colors.amber;
    if (settings.theme == 'red') themeColor = Colors.redAccent;
    if (settings.theme == 'blue') themeColor = Colors.blueAccent;
    if (settings.theme == 'green') themeColor = Colors.greenAccent;

    return Dpad.wrap(
      debugOverlay: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF17262A),
        body: channelsAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: themeColor)),
          error: (err, stack) => Center(
            child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
          ),
          data: (allChannels) {
            final tabChannels = _getFilteredChannels(allChannels);
            final managedGroups = groupsAsync.asData?.value ?? [];

            final categories = tabChannels.map((c) => c.group).toSet().toList()
              ..sort((a, b) {
                // Sorting logic
                final ga = managedGroups.firstWhere((g) => g.name == a, 
                    orElse: () => ChannelGroup(key: '', name: a, order: 9999));
                final gb = managedGroups.firstWhere((g) => g.name == b, 
                    orElse: () => ChannelGroup(key: '', name: b, order: 9999));
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
                  _buildSidebar(themeColor, lang),
                  if (_navIndex < 2) _buildCategories(categories, themeColor, lang),
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
      ),
    );
  }

  Widget _buildSidebar(Color themeColor, String lang) {
    return DpadRegion(
      memoryKey: 'home_sidebar',
      child: Container(
        width: 100,
        color: Colors.black.withOpacity(0.5),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.flash_on, size: 40, color: Colors.white), // Placeholder for image
            const SizedBox(height: 50),
            _sidebarTile(Icons.live_tv, Localization.t('live_tv', lang), 0, themeColor),
            _sidebarTile(Icons.movie, Localization.t('movies', lang), 1, themeColor),
            const Spacer(),
            _sidebarTile(Icons.settings, Localization.t('settings', lang), 2, themeColor),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _sidebarTile(IconData icon, String label, int index, Color themeColor) {
    final isSelected = _navIndex == index;
    return DpadFocusable(
      onSelect: () => setState(() {
        _navIndex = index;
        _selectedCategory = null;
      }),
      effects: const [DpadScaleEffect(scale: 1.1)],
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 15),
        color: isSelected ? themeColor.withOpacity(0.2) : Colors.transparent,
        child: Column(
          children: [
            Icon(icon, color: isSelected ? themeColor : Colors.white70),
            Text(label, style: TextStyle(color: isSelected ? themeColor : Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(List<String> categories, Color themeColor, String lang) {
    return DpadRegion(
      memoryKey: 'home_categories',
      child: SizedBox(
        width: 260,
        child: ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return DpadFocusable(
              onSelect: () => setState(() => _selectedCategory = cat),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: _selectedCategory == cat ? themeColor : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(cat, style: const TextStyle(color: Colors.white)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChannelsGrid(List<Channel> channels, Color themeColor, String lang, bool hardwareDecoding) {
    return DpadRegion(
      memoryKey: 'home_channels',
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 0.8,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
        ),
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return DpadFocusable(
            onSelect: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => Player(
                channels: channels,
                initialIndex: index,
                themeColor: themeColor,
                hardwareDecoding: hardwareDecoding,
                lang: lang,
              ),
            )),
            effects: const [DpadScaleEffect(scale: 1.05)],
            child: Column(
              children: [
                Expanded(
                  child: CachedNetworkImage(
                    imageUrl: channel.logo ?? '',
                    errorWidget: (context, url, error) => const Icon(Icons.tv, color: Colors.white),
                  ),
                ),
                Text(channel.name, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettings(SettingsState settings, Color themeColor, String lang) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(Localization.t('settings', lang), style: const TextStyle(color: Colors.white, fontSize: 30)),
        const SizedBox(height: 20),
        DpadFocusable(
          onSelect: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('auth_code');
            // Ensure authStateProvider is imported or change this line:
            // ref.read(authStateProvider.notifier).state = false;
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            color: Colors.red,
            child: const Text("Logout"),
          ),
        ),
      ],
    );
  }
}
