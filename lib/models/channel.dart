import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kChannelCache = 'channels_cache_v1';

class Channel {
  final String name;
  final String url;
  final String group;
  final String? logo;
  final String? backdrop;
  final String? subtitleUrl;
  final String? description;
  final String type; // 'live' or 'movie'
  final bool featured;
  final int order;
  final int featuredOrder;
  final String? userAgent;
  final String? url2;
  final String? url2Name;
  final String? url3;
  final String? url3Name;

  Channel({
    required this.name,
    required this.url,
    this.group = 'General',
    this.logo,
    this.backdrop,
    this.subtitleUrl,
    this.description,
    this.type = 'live',
    this.featured = false,
    this.order = 999999,
    this.featuredOrder = 999999,
    this.userAgent,
    this.url2,
    this.url2Name,
    this.url3,
    this.url3Name,
  });

  factory Channel.fromMap(Map<dynamic, dynamic> map) {
    return Channel(
      name: map['name'] ?? 'Unknown',
      url: map['url'] ?? '',
      group: map['group'] ?? map['category'] ?? 'General',
      logo: map['logo'] ?? map['icon_url'],
      backdrop: map['backdrop'] as String?,
      subtitleUrl: map['subtitleUrl'] as String?,
      description: map['description'] as String?,
      type: map['type'] as String? ?? 'live',
      featured: map['featured'] == true,
      order: map['order'] is int ? map['order'] as int : 999999,
      featuredOrder: map['featured_order'] is int ? map['featured_order'] as int : 999999,
      userAgent: map['userAgent'] as String? ?? map['user_agent'] as String?,
      url2: map['url2'] as String?,
      url2Name: map['url2Name'] as String?,
      url3: map['url3'] as String?,
      url3Name: map['url3Name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'url': url,
    'group': group,
    'logo': logo,
    'backdrop': backdrop,
    'subtitleUrl': subtitleUrl,
    'description': description,
    'type': type,
    'featured': featured,
    'order': order,
    'featured_order': featuredOrder,
    'userAgent': userAgent,
    'url2': url2,
    'url2Name': url2Name,
    'url3': url3,
    'url3Name': url3Name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel && name == other.name && url == other.url;

  @override
  int get hashCode => Object.hash(name, url);
}

List<Channel> _parseChannelData(dynamic data) {
  List<Channel> channels = [];
  if (data == null) return channels;
  if (data is List) {
    channels = data
        .where((item) => item != null)
        .map((item) => Channel.fromMap(item as Map))
        .toList();
  } else if (data is Map) {
    channels = data.values
        .map((item) => Channel.fromMap(item as Map))
        .toList();
  }
  channels.sort((a, b) {
    if (a.order != b.order) return a.order.compareTo(b.order);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return channels;
}

Future<List<Channel>> _loadCachedChannels() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kChannelCache);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Channel.fromMap(e as Map)).toList();
  } catch (_) {
    return [];
  }
}

Future<void> _saveChannelCache(List<Channel> channels) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kChannelCache,
      jsonEncode(channels.map((c) => c.toMap()).toList()),
    );
  } catch (_) {}
}

final channelsProvider = StreamProvider<List<Channel>>((ref) {
  final controller = StreamController<List<Channel>>();

  _loadCachedChannels().then((cached) {
    if (!controller.isClosed && cached.isNotEmpty) {
      controller.add(cached);
    }
  });

  final dbRef = FirebaseDatabase.instance.ref('sync/global/managedPlaylist');
  final sub = dbRef.onValue.listen(
    (event) {
      final channels = _parseChannelData(event.snapshot.value);
      if (!controller.isClosed) {
        controller.add(channels);
        _saveChannelCache(channels);
      }
    },
    onError: (Object e) {
      if (!controller.isClosed) controller.addError(e);
    },
  );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

class ChannelGroup {
  final String key;
  final String name;
  final int order;

  ChannelGroup({
    required this.key,
    required this.name,
    this.order = 999999,
  });

  factory ChannelGroup.fromMap(String key, Map<dynamic, dynamic> map) {
    return ChannelGroup(
      key: key,
      name: map['name'] ?? 'Unknown',
      order: map['order'] is int ? map['order'] as int : 999999,
    );
  }
}

final groupsProvider = StreamProvider<List<ChannelGroup>>((ref) {
  final dbRef = FirebaseDatabase.instance.ref('sync/global/channelGroups');

  return dbRef.onValue.map((event) {
    final data = event.snapshot.value;
    if (data is! Map) return [];

    final list = data.entries.map((e) {
      return ChannelGroup.fromMap(e.key.toString(), e.value as Map);
    }).toList();

    list.sort((a, b) {
      if (a.order != b.order) return a.order.compareTo(b.order);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return list;
  });
});
