import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'models.dart';

/// Content categories shown as filter chips. Each provider maps these to
/// its own category codes (or ignores them when it only has one kind).
enum Category { all, video, audio, apps, games, books, anime }

extension CategoryLabel on Category {
  String get label => switch (this) {
        Category.all => 'All',
        Category.video => 'Video',
        Category.audio => 'Audio',
        Category.apps => 'Apps',
        Category.games => 'Games',
        Category.books => 'Books',
        Category.anime => 'Anime',
      };
}

abstract class SearchProvider {
  /// Stable id used in settings.
  String get id;
  String get name;
  String get defaultBaseUrl;

  /// Categories this provider can return. Providers are skipped when the
  /// selected category isn't in this set.
  Set<Category> get categories;

  Future<List<TorrentResult>> search(
    http.Client client,
    String baseUrl,
    String query,
    Category category,
  );
}

const _headers = {
  'User-Agent':
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
  'Accept': 'application/json, application/xml, text/xml, */*',
};

String _trimSlash(String s) =>
    s.endsWith('/') ? s.substring(0, s.length - 1) : s;

/// General index with a public JSON API (q.php).
class ApiBayProvider extends SearchProvider {
  @override
  String get id => 'apibay';
  @override
  String get name => 'ApiBay';
  @override
  String get defaultBaseUrl => 'https://apibay.org';
  @override
  Set<Category> get categories => {
        Category.all,
        Category.video,
        Category.audio,
        Category.apps,
        Category.games,
        Category.books,
      };

  static const _catCodes = {
    Category.audio: '100',
    Category.video: '200',
    Category.apps: '300',
    Category.games: '400',
    Category.books: '601',
  };

  static const _catNames = {
    '1': 'Audio',
    '2': 'Video',
    '3': 'Apps',
    '4': 'Games',
    '6': 'Other',
  };

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final params = {'q': query, 'cat': _catCodes[category] ?? ''};
    final uri =
        Uri.parse('${_trimSlash(baseUrl)}/q.php').replace(queryParameters: params);
    final res = await client.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    final out = <TorrentResult>[];
    for (final e in data) {
      if (e is! Map) continue;
      final hash = (e['info_hash'] ?? '').toString();
      if (hash.isEmpty || RegExp(r'^0+$').hasMatch(hash)) continue;
      final cat = (e['category'] ?? '').toString();
      final added = int.tryParse((e['added'] ?? '').toString());
      out.add(TorrentResult(
        name: (e['name'] ?? '').toString(),
        infoHash: hash,
        sizeBytes: int.tryParse((e['size'] ?? '0').toString()) ?? 0,
        seeders: int.tryParse((e['seeders'] ?? '0').toString()) ?? 0,
        leechers: int.tryParse((e['leechers'] ?? '0').toString()) ?? 0,
        added: added == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(added * 1000),
        source: name,
        category: cat.isEmpty ? null : _catNames[cat[0]],
      ));
    }
    return out;
  }
}

/// Movie index with a public JSON API.
class YtsProvider extends SearchProvider {
  @override
  String get id => 'yts';
  @override
  String get name => 'YTS';
  @override
  String get defaultBaseUrl => 'https://yts.mx';
  @override
  Set<Category> get categories => {Category.all, Category.video};

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/api/v2/list_movies.json')
        .replace(queryParameters: {'query_term': query, 'limit': '50'});
    final res = await client.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(res.body);
    final inner = data is Map ? data['data'] : null;
    final List movies =
        inner is Map && inner['movies'] is List ? inner['movies'] as List : const [];
    final out = <TorrentResult>[];
    for (final m in movies) {
      if (m is! Map) continue;
      final title = (m['title_long'] ?? m['title'] ?? '').toString();
      final page = m['url']?.toString();
      for (final t in (m['torrents'] as List? ?? [])) {
        if (t is! Map) continue;
        final hash = (t['hash'] ?? '').toString();
        if (hash.isEmpty) continue;
        final up = int.tryParse((t['date_uploaded_unix'] ?? '').toString());
        out.add(TorrentResult(
          name: '$title [${t['quality'] ?? ''} ${t['type'] ?? ''}]'.trim(),
          infoHash: hash,
          sizeBytes: int.tryParse((t['size_bytes'] ?? '0').toString()) ?? 0,
          seeders: int.tryParse((t['seeds'] ?? '0').toString()) ?? 0,
          leechers: int.tryParse((t['peers'] ?? '0').toString()) ?? 0,
          added: up == null ? null : DateTime.fromMillisecondsSinceEpoch(up * 1000),
          source: name,
          category: 'Movie',
          pageUrl: page,
        ));
      }
    }
    return out;
  }
}

/// Anime / East Asian media index with a public RSS feed.
class NyaaProvider extends SearchProvider {
  @override
  String get id => 'nyaa';
  @override
  String get name => 'Nyaa';
  @override
  String get defaultBaseUrl => 'https://nyaa.si';
  @override
  Set<Category> get categories =>
      {Category.all, Category.anime, Category.video, Category.audio, Category.books};

  static const _catCodes = {
    Category.anime: '1_0',
    Category.video: '1_0',
    Category.audio: '2_0',
    Category.books: '3_0',
  };

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/').replace(queryParameters: {
      'page': 'rss',
      'q': query,
      'c': _catCodes[category] ?? '0_0',
      'f': '0',
    });
    final res = await client.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final doc = XmlDocument.parse(utf8.decode(res.bodyBytes));
    final out = <TorrentResult>[];
    for (final item in doc.findAllElements('item')) {
      String field(String local) {
        for (final el in item.childElements) {
          if (el.name.local == local) return el.innerText.trim();
        }
        return '';
      }

      final hash = field('infoHash');
      if (hash.isEmpty) continue;
      DateTime? added;
      try {
        added = _parseRfc822(field('pubDate'));
      } catch (_) {}
      out.add(TorrentResult(
        name: field('title'),
        infoHash: hash,
        sizeBytes: _parseSize(field('size')),
        seeders: int.tryParse(field('seeders')) ?? 0,
        leechers: int.tryParse(field('leechers')) ?? 0,
        added: added,
        source: name,
        category: field('category').isEmpty ? 'Anime' : field('category'),
        pageUrl: field('guid').isEmpty ? null : field('guid'),
      ));
    }
    return out;
  }
}

int _parseSize(String s) {
  final m = RegExp(r'([\d.]+)\s*([KMGT]?i?B)', caseSensitive: false).firstMatch(s);
  if (m == null) return 0;
  final v = double.tryParse(m.group(1)!) ?? 0;
  final u = m.group(2)!.toUpperCase();
  const mult = {
    'B': 1,
    'KIB': 1024,
    'KB': 1024,
    'MIB': 1048576,
    'MB': 1048576,
    'GIB': 1073741824,
    'GB': 1073741824,
    'TIB': 1099511627776,
    'TB': 1099511627776,
  };
  return (v * (mult[u] ?? 1)).round();
}

DateTime _parseRfc822(String s) {
  // e.g. "Sat, 01 Nov 2026 10:20:30 -0000"
  const months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  final p = s.split(RegExp(r'[\s,:]+')).where((e) => e.isNotEmpty).toList();
  // [Sat, 01, Nov, 2026, 10, 20, 30, -0000]
  return DateTime.utc(int.parse(p[3]), months[p[2]] ?? 1, int.parse(p[1]),
      int.parse(p[4]), int.parse(p[5]), int.parse(p[6]));
}

final List<SearchProvider> allProviders = [
  ApiBayProvider(),
  YtsProvider(),
  NyaaProvider(),
];

const defaultTrackers = [
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://open.stealth.si:80/announce',
  'udp://tracker.torrent.eu.org:451/announce',
  'udp://exodus.desync.com:6969/announce',
  'udp://tracker.openbittorrent.com:6969/announce',
  'udp://open.demonii.com:1337/announce',
];

class ProviderOutcome {
  final SearchProvider provider;
  final List<TorrentResult> results;
  final String? error;
  ProviderOutcome(this.provider, this.results, this.error);
}

/// Runs all enabled providers in parallel; one failing provider doesn't
/// break the others.
Future<List<ProviderOutcome>> searchAll({
  required String query,
  required Category category,
  required Set<String> enabledIds,
  required Map<String, String> baseUrls,
}) async {
  final client = http.Client();
  try {
    final active = allProviders
        .where((p) => enabledIds.contains(p.id) && p.categories.contains(category))
        .toList();
    return await Future.wait(active.map((p) async {
      try {
        final r = await p
            .search(client, baseUrls[p.id] ?? p.defaultBaseUrl, query, category)
            .timeout(const Duration(seconds: 20));
        return ProviderOutcome(p, r, null);
      } catch (e) {
        return ProviderOutcome(p, const [], e.toString());
      }
    }));
  } finally {
    client.close();
  }
}
