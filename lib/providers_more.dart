part of 'providers.dart';

// Sources that publish HTML pages or simple feeds. Each parser was written
// against a real response saved by tools/probe.sh, and is checked in CI by
// test/providers_test.dart using those saved responses.

final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos|nbsp);');

String _unescape(String s) => s.replaceAllMapped(_entity, (m) {
      final e = m.group(1)!;
      if (e.startsWith('#x')) return String.fromCharCode(int.parse(e.substring(2), radix: 16));
      if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
      return const {
            'amp': '&',
            'lt': '<',
            'gt': '>',
            'quot': '"',
            'apos': "'",
            'nbsp': ' ',
          }[e] ??
          m.group(0)!;
    });

String _stripTags(String s) => _unescape(s.replaceAll(RegExp(r'<[^>]*>'), '')).trim();

String? _first(RegExp re, String s, [int group = 1]) => re.firstMatch(s)?.group(group);

/// e.g. "4/18/2019"
DateTime? _parseMdy(String? s) {
  if (s == null) return null;
  final m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
  if (m == null) return null;
  return DateTime(int.parse(m.group(3)!), int.parse(m.group(1)!), int.parse(m.group(2)!));
}

Future<String> _getText(http.Client client, Uri uri) async {
  final res = await client.get(uri, headers: {
    ..._headers,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  });
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  return utf8.decode(res.bodyBytes, allowMalformed: true);
}

/// BitSearch (formerly SolidTorrents): large DHT-backed index.
class BitSearchProvider extends SearchProvider {
  @override
  String get id => 'bitsearch';
  @override
  String get name => 'BitSearch';
  @override
  String get defaultBaseUrl => 'https://bitsearch.eu';
  @override
  Set<Category> get categories => {Category.all};

  static final _title = RegExp(r'<a href="(/torrent/[^"]*)"[^>]*>\s*([^<]+?)\s*</a>');
  static final _size = RegExp(r'fa-download"></i>\s*<span>([^<]+)</span>');
  static final _date = RegExp(r'fa-calendar"></i>\s*<span>([^<]+)</span>');
  static final _seed = RegExp(r'<span class="font-medium">([\d,]+)</span>\s*<span>seeders');
  static final _leech = RegExp(r'<span class="font-medium">([\d,]+)</span>\s*<span>leechers');
  static final _magnet = RegExp(r'href="(magnet:[^"]+)"');

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final base = _trimSlash(baseUrl);
    final html = await _getText(
        client, Uri.parse('$base/search').replace(queryParameters: {'q': query}));
    final out = <TorrentResult>[];
    for (final block in html.split('<!-- Torrent Info -->').skip(1)) {
      final magnet = _first(_magnet, block);
      final hash = _hashFromMagnet(magnet == null ? null : _unescape(magnet));
      final t = _title.firstMatch(block);
      if (hash == null || t == null) continue;
      out.add(TorrentResult(
        name: _unescape(t.group(2)!),
        infoHash: hash,
        sizeBytes: _parseSize(_first(_size, block) ?? ''),
        seeders: int.tryParse((_first(_seed, block) ?? '').replaceAll(',', '')) ?? 0,
        leechers: int.tryParse((_first(_leech, block) ?? '').replaceAll(',', '')) ?? 0,
        added: _parseMdy(_first(_date, block)),
        source: name,
        pageUrl: '$base${t.group(1)}',
      ));
    }
    return out;
  }
}

/// LimeTorrents: general index; info hash is in each row's .torrent link.
class LimeTorrentsProvider extends SearchProvider {
  @override
  String get id => 'limetorrents';
  @override
  String get name => 'LimeTorrents';
  @override
  String get defaultBaseUrl => 'https://www.limetorrents.fun';
  @override
  Set<Category> get categories => {Category.all};

  static final _row = RegExp(r'<tr bgcolor="[^"]*">(.*?)</tr>', dotAll: true);
  static final _hash = RegExp(r'/torrent/([A-Fa-f0-9]{40})\.torrent');
  static final _title = RegExp(r'<a href="(/[^"]+-torrent-\d+\.html)">([^<]+)</a>');
  static final _cell = RegExp(r'<td class="tdnormal">([^<]+)</td>');
  static final _seed = RegExp(r'<td class="tdseed">([\d,]+)</td>');
  static final _leech = RegExp(r'<td class="tdleech">([\d,]+)</td>');

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final base = _trimSlash(baseUrl);
    final html = await _getText(client,
        Uri.parse('$base/search/all/${Uri.encodeComponent(query)}/seeds/1/'));
    final out = <TorrentResult>[];
    for (final m in _row.allMatches(html)) {
      final row = m.group(1)!;
      final hash = _first(_hash, row);
      final t = _title.firstMatch(row);
      if (hash == null || t == null) continue;
      final size = _cell
          .allMatches(row)
          .map((c) => c.group(1)!)
          .firstWhere((c) => RegExp(r'\d\s*[KMGT]?B', caseSensitive: false).hasMatch(c),
              orElse: () => '');
      out.add(TorrentResult(
        name: _unescape(t.group(2)!.trim()),
        infoHash: hash.toLowerCase(),
        sizeBytes: _parseSize(size),
        seeders: int.tryParse((_first(_seed, row) ?? '').replaceAll(',', '')) ?? 0,
        leechers: int.tryParse((_first(_leech, row) ?? '').replaceAll(',', '')) ?? 0,
        source: name,
        pageUrl: '$base${t.group(1)}',
      ));
    }
    return out;
  }
}

/// Rutor: large Russian-run index with international releases.
class RutorProvider extends SearchProvider {
  @override
  String get id => 'rutor';
  @override
  String get name => 'Rutor';
  @override
  String get defaultBaseUrl => 'https://rutor.info';
  @override
  Set<Category> get categories => {Category.all};

  static final _row = RegExp(r'<tr class="(?:gai|tum)">(.*?)</tr>', dotAll: true);
  static final _magnet = RegExp(r'href="(magnet:[^"]+)"');
  static final _title = RegExp(r'<a href="(/torrent/[^"]+)">([^<]+)</a>');
  static final _size = RegExp(r'<td align="right">([\d.,]+(?:&nbsp;|\s)[KMGT]?B)</td>');
  static final _seed = RegExp(r'<span class="green">.*?(\d+)</span>', dotAll: true);
  static final _leech = RegExp(r'<span class="red">(?:&nbsp;|\s)*(\d+)</span>');
  static final _date = RegExp(r'<td>(\d{1,2})&nbsp;([^&]+)&nbsp;(\d{2})</td>');
  static const _months = {
    'Янв': 1, 'Фев': 2, 'Мар': 3, 'Апр': 4, 'Май': 5, 'Июн': 6,
    'Июл': 7, 'Авг': 8, 'Сен': 9, 'Окт': 10, 'Ноя': 11, 'Дек': 12,
  };

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final base = _trimSlash(baseUrl);
    final html =
        await _getText(client, Uri.parse('$base/search/${Uri.encodeComponent(query)}'));
    final out = <TorrentResult>[];
    for (final m in _row.allMatches(html)) {
      final row = m.group(1)!;
      final hash = _hashFromMagnet(_first(_magnet, row));
      final t = _title.firstMatch(row);
      if (hash == null || t == null) continue;
      DateTime? added;
      final d = _date.firstMatch(row);
      if (d != null && _months[d.group(2)] != null) {
        added = DateTime(2000 + int.parse(d.group(3)!), _months[d.group(2)]!,
            int.parse(d.group(1)!));
      }
      out.add(TorrentResult(
        name: _unescape(t.group(2)!.trim()),
        infoHash: hash,
        sizeBytes: _parseSize(_unescape(_first(_size, row) ?? '')),
        seeders: int.tryParse(_first(_seed, row) ?? '') ?? 0,
        leechers: int.tryParse(_first(_leech, row) ?? '') ?? 0,
        added: added,
        source: name,
        pageUrl: '$base${t.group(1)}',
      ));
    }
    return out;
  }
}

/// BT4G: DHT search engine with an RSS feed. No seeder counts.
class Bt4gProvider extends SearchProvider {
  @override
  String get id => 'bt4g';
  @override
  String get name => 'BT4G';
  @override
  String get defaultBaseUrl => 'https://bt4gprx.com';
  @override
  Set<Category> get categories => {Category.all};
  @override
  String? get note => 'DHT index — seeder counts not available';

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final base = _trimSlash(baseUrl);
    final body = await _getText(client,
        Uri.parse('$base/search').replace(queryParameters: {'q': query, 'page': 'rss'}));
    final doc = XmlDocument.parse(body);
    final out = <TorrentResult>[];
    for (final item in doc.findAllElements('item')) {
      String field(String n) => item.getElement(n)?.innerText.trim() ?? '';
      final hash = _hashFromMagnet(field('link'));
      if (hash == null) continue;
      final parts = field('description').split(RegExp(r'<br\s*/?>'));
      DateTime? added;
      try {
        added = _parseRfc822(field('pubDate'));
      } catch (_) {}
      out.add(TorrentResult(
        name: field('title'),
        infoHash: hash,
        sizeBytes: parts.length > 1 ? _parseSize(parts[1]) : 0,
        seeders: -1,
        leechers: -1,
        added: added,
        source: name,
        pageUrl: field('guid').isEmpty ? null : field('guid'),
      ));
    }
    return out;
  }
}

/// Internet Archive: public-domain and freely licensed media, software and
/// books. Every item is web-seeded by archive.org.
class InternetArchiveProvider extends SearchProvider {
  @override
  String get id => 'archive';
  @override
  String get name => 'Internet Archive';
  @override
  String get defaultBaseUrl => 'https://archive.org';
  @override
  Set<Category> get categories =>
      {Category.all, Category.video, Category.audio, Category.apps, Category.books};
  @override
  String? get note => 'Free, legal public-domain content';

  static const _media = {
    Category.video: 'movies',
    Category.audio: 'audio',
    Category.apps: 'software',
    Category.books: 'texts',
  };

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final base = _trimSlash(baseUrl);
    final media = _media[category];
    final q = media == null ? query : '($query) AND mediatype:$media';
    final uri = Uri.parse('$base/advancedsearch.php').replace(queryParameters: {
      'q': q,
      'fl[]': ['identifier', 'title', 'btih', 'item_size', 'publicdate'],
      'rows': '100',
      'output': 'json',
    });
    final res = await client.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final resp = data is Map ? data['response'] : null;
    final List docs = resp is Map && resp['docs'] is List ? resp['docs'] as List : const [];
    final out = <TorrentResult>[];
    for (final d in docs) {
      if (d is! Map) continue;
      final hash = (d['btih'] ?? '').toString();
      if (hash.length != 40) continue;
      final title = d['title'];
      out.add(TorrentResult(
        name: (title is List ? title.join(' ') : (title ?? d['identifier'])).toString(),
        infoHash: hash.toLowerCase(),
        sizeBytes: _toInt(d['item_size']),
        seeders: -1,
        leechers: -1,
        added: _toDate(d['publicdate']),
        source: name,
        pageUrl: '$base/details/${d['identifier']}',
      ));
    }
    return out;
  }
}

/// SubsPlease: subtitled anime episodes. No seeder counts.
class SubsPleaseProvider extends SearchProvider {
  @override
  String get id => 'subsplease';
  @override
  String get name => 'SubsPlease';
  @override
  String get defaultBaseUrl => 'https://subsplease.org';
  @override
  Set<Category> get categories => {Category.all, Category.anime};

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final uri = Uri.parse('${_trimSlash(baseUrl)}/api/')
        .replace(queryParameters: {'f': 'search', 'tz': 'UTC', 's': query});
    final res = await client.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! Map) return [];
    final out = <TorrentResult>[];
    for (final e in data.values) {
      if (e is! Map) continue;
      DateTime? added;
      try {
        added = _parseRfc822((e['release_date'] ?? '').toString());
      } catch (_) {}
      for (final dl in (e['downloads'] as List? ?? const [])) {
        if (dl is! Map) continue;
        final magnet = dl['magnet']?.toString();
        final hash = _hashFromMagnet(magnet);
        if (hash == null) continue;
        final xl = RegExp(r'[?&]xl=(\d+)').firstMatch(magnet!)?.group(1);
        out.add(TorrentResult(
          name: '[SubsPlease] ${e['show']} - ${e['episode']} (${dl['res']}p)',
          infoHash: hash,
          sizeBytes: int.tryParse(xl ?? '') ?? 0,
          seeders: -1,
          leechers: -1,
          added: added,
          source: name,
          category: 'Anime',
        ));
      }
    }
    return out;
  }
}

/// TokyoTosho: long-running anime / Japanese media tracker index.
class TokyoToshoProvider extends SearchProvider {
  @override
  String get id => 'tokyotosho';
  @override
  String get name => 'TokyoTosho';
  @override
  String get defaultBaseUrl => 'https://www.tokyotosho.info';
  @override
  Set<Category> get categories => {Category.all, Category.anime};

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final body = await _getText(client,
        Uri.parse('${_trimSlash(baseUrl)}/rss.php').replace(queryParameters: {'terms': query}));
    final doc = XmlDocument.parse(body);
    final out = <TorrentResult>[];
    for (final item in doc.findAllElements('item')) {
      String field(String n) => item.getElement(n)?.innerText.trim() ?? '';
      final desc = field('description');
      final hash = _hashFromMagnet(_first(RegExp(r'href="(magnet:[^"]+)"'), desc));
      if (hash == null) continue;
      DateTime? added;
      try {
        added = _parseRfc822(field('pubDate'));
      } catch (_) {}
      out.add(TorrentResult(
        name: field('title'),
        infoHash: hash,
        sizeBytes: _parseSize(_first(RegExp(r'Size:\s*([\d.]+\s*[KMGT]?i?B)'), desc) ?? ''),
        seeders: -1,
        leechers: -1,
        added: added,
        source: name,
        category: field('category').isEmpty ? 'Anime' : field('category'),
        pageUrl: field('guid').isEmpty ? null : field('guid'),
      ));
    }
    return out;
  }
}
