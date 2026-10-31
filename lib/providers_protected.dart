part of 'providers.dart';

// Sites behind Cloudflare's browser check, plus TheRARBG. Several of these
// list results without magnet links, so the top results' detail pages are
// opened (a few at a time) to read the magnet.

/// A result row before its magnet is known.
class _Row {
  final String name;
  final String? page;
  final String? hash;
  final int size;
  final int seeders;
  final int leechers;
  final DateTime? added;
  _Row(this.name,
      {this.page, this.hash, this.size = 0, this.seeders = -1, this.leechers = -1, this.added});
}

final _sizeAny = RegExp(r'([\d.,]+)\s*(TB|GB|MB|KB|TiB|GiB|MiB|KiB|B)\b', caseSensitive: false);
final _magnetAny = RegExp(r'''(magnet:\?xt=urn:btih:[^"'\s<>]+)''');

int _num(String? s) => int.tryParse((s ?? '').replaceAll(RegExp(r'[^\d]'), '')) ?? -1;

String? _dn(String magnet) {
  final m = RegExp(r'[?&]dn=([^&]+)').firstMatch(magnet);
  if (m == null) return null;
  try {
    return Uri.decodeQueryComponent(m.group(1)!);
  } catch (_) {
    return m.group(1);
  }
}

/// Runs [fn] over [items] with at most [width] in flight.
Future<List<R>> _pooled<T, R>(List<T> items, int width, Future<R> Function(T) fn) async {
  final out = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (next < items.length) {
      final i = next++;
      out[i] = await fn(items[i]);
    }
  }

  await Future.wait(List.generate(width.clamp(1, items.length == 0 ? 1 : items.length), (_) => worker()));
  return out.cast<R>();
}

abstract class _ProtectedProvider extends SearchProvider {
  @override
  bool get usesCloudflare => true;
  @override
  Set<Category> get categories => {Category.all};
  @override
  String? get note => 'Protected by Cloudflare — tap Verify once';

  /// How many top results to open for their magnet link.
  int get detailLimit => 15;

  Future<String> page(http.Client client, String base, Uri uri) =>
      CloudflareSession.instance.fetch(client, uri, homepage: Uri.parse('$base/'));

  List<_Row> parse(String html, String base);
  Uri searchUri(String base, String query);

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final base = _trimSlash(baseUrl);
    final rows = parse(await page(client, base, searchUri(base, query)), base);
    final ready = rows.where((r) => r.hash != null).toList();
    final pending = rows.where((r) => r.hash == null && r.page != null).toList()
      ..sort((a, b) => b.seeders.compareTo(a.seeders));
    final fetched = await _pooled(pending.take(detailLimit).toList(), 4, (r) async {
      try {
        final html = await page(client, base, Uri.parse(r.page!));
        final h = _hashFromMagnet(_magnetAny.firstMatch(html)?.group(1));
        return h == null
            ? null
            : _Row(r.name,
                page: r.page,
                hash: h,
                size: r.size,
                seeders: r.seeders,
                leechers: r.leechers,
                added: r.added);
      } catch (_) {
        return null;
      }
    });
    return [...ready, ...fetched.whereType<_Row>()]
        .map((r) => TorrentResult(
              name: r.name,
              infoHash: r.hash!,
              sizeBytes: r.size,
              seeders: r.seeders,
              leechers: r.leechers,
              added: r.added,
              source: name,
              pageUrl: r.page,
            ))
        .toList();
  }
}

class X1337Provider extends _ProtectedProvider {
  @override
  String get id => '1337x';
  @override
  String get name => '1337x';
  @override
  String get defaultBaseUrl => 'https://1337x.to';

  @override
  Uri searchUri(String base, String query) => Uri.parse(
      '$base/sort-search/${Uri.encodeComponent(query).replaceAll('%20', '+')}/seeders/desc/1/');

  static final _row = RegExp(r'<tr>(.*?)</tr>', dotAll: true);
  static final _link = RegExp(r'<a href="(/torrent/\d+/[^"]*)">([^<]+)</a>');
  static final _seed = RegExp(r'<td class="coll-2 seeds">([\d,]+)</td>');
  static final _leech = RegExp(r'<td class="coll-3 leeches">([\d,]+)</td>');
  static final _size = RegExp(r'<td class="coll-4 size[^"]*">([^<]+)<');

  @override
  List<_Row> parse(String html, String base) => [
        for (final m in _row.allMatches(html))
          if (_link.firstMatch(m.group(1)!) case final l?)
            _Row(_unescape(l.group(2)!.trim()),
                page: '$base${l.group(1)}',
                size: _parseSize(_first(_size, m.group(1)!) ?? ''),
                seeders: _num(_first(_seed, m.group(1)!)),
                leechers: _num(_first(_leech, m.group(1)!))),
      ];
}

/// Torlock and TorrentFunk share the same page layout.
class TorlockProvider extends _ProtectedProvider {
  final String _id, _name, _base;
  TorlockProvider([this._id = 'torlock', this._name = 'Torlock', this._base = 'https://www.torlock.com']);
  @override
  String get id => _id;
  @override
  String get name => _name;
  @override
  String get defaultBaseUrl => _base;

  @override
  Uri searchUri(String base, String query) => Uri.parse(
      '$base/all/torrents/${Uri.encodeComponent(query.trim().replaceAll(RegExp(r'\s+'), '-'))}.html?sort=seeds');

  static final _row = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
  static final _link = RegExp(r'<a href="(/torrent/\d+/[^"]+\.html)"[^>]*>(.*?)</a>', dotAll: true);
  static final _date = RegExp(r'<td class="td">([^<]+)</td>');
  static final _size = RegExp(r'<td class="ts">([^<]+)</td>');
  static final _seed = RegExp(r'<td class="tul">([\d,]+)</td>');
  static final _leech = RegExp(r'<td class="tdl">([\d,]+)</td>');

  @override
  List<_Row> parse(String html, String base) => [
        for (final m in _row.allMatches(html))
          if (_link.firstMatch(m.group(1)!) case final l?)
            _Row(_stripTags(l.group(2)!),
                page: '$base${l.group(1)}',
                size: _parseSize(_first(_size, m.group(1)!) ?? ''),
                seeders: _num(_first(_seed, m.group(1)!)),
                leechers: _num(_first(_leech, m.group(1)!)),
                added: _parseMdy(_first(_date, m.group(1)!))),
      ];
}

class KickassProvider extends _ProtectedProvider {
  @override
  String get id => 'kickass';
  @override
  String get name => 'KickassTorrents';
  @override
  String get defaultBaseUrl => 'https://kickasstorrents.to';

  @override
  Uri searchUri(String base, String query) =>
      Uri.parse('$base/usearch/${Uri.encodeComponent(query)}/');

  static final _row = RegExp(r'<tr class="(?:odd|even)"[^>]*>(.*?)</tr>', dotAll: true);
  static final _link = RegExp(r'<a href="([^"]+)"\s+class="cellMainLink">(.*?)</a>', dotAll: true);
  static final _seed = RegExp(r'<td class="green center">\s*([\d,]+)');
  static final _leech = RegExp(r'<td class="red lasttd center">\s*([\d,]+)');

  @override
  List<_Row> parse(String html, String base) {
    final out = <_Row>[];
    for (final m in _row.allMatches(html)) {
      final row = m.group(1)!;
      final l = _link.firstMatch(row);
      if (l == null) continue;
      final after = row.substring(l.end);
      final href = l.group(1)!;
      final magnet = _magnetAny.firstMatch(row)?.group(1);
      out.add(_Row(_stripTags(l.group(2)!),
          page: href.startsWith('http') ? href : '$base$href',
          hash: _hashFromMagnet(magnet == null ? null : _unescape(magnet)),
          size: _parseSize(_sizeAny.firstMatch(after)?.group(0) ?? ''),
          seeders: _num(_first(_seed, row)),
          leechers: _num(_first(_leech, row))));
    }
    return out;
  }
}

class EztvProvider extends _ProtectedProvider {
  @override
  String get id => 'eztv';
  @override
  String get name => 'EZTV';
  @override
  String get defaultBaseUrl => 'https://eztvx.to';
  @override
  Set<Category> get categories => {Category.all, Category.video};

  @override
  Uri searchUri(String base, String query) => Uri.parse(
      '$base/search/${Uri.encodeComponent(query.trim().replaceAll(RegExp(r'\s+'), '-'))}');

  static final _row = RegExp(r'<tr[^>]*class="forum_header_border"[^>]*>(.*?)</tr>', dotAll: true);
  static final _magnet = RegExp(r'<a href="(magnet:[^"]+)"[^>]*class="magnet"');
  static final _info = RegExp(r'<a href="([^"]+)"[^>]*title="([^"]+)"[^>]*class="epinfo"');
  static final _seed = RegExp(r'<font color="green">([\d,]+)</font>');

  @override
  List<_Row> parse(String html, String base) {
    final out = <_Row>[];
    for (final m in _row.allMatches(html)) {
      final row = m.group(1)!;
      final magnet = _magnetAny.firstMatch(row)?.group(1) ?? _first(_magnet, row);
      final hash = _hashFromMagnet(magnet == null ? null : _unescape(magnet));
      if (hash == null) continue;
      final info = _info.firstMatch(row);
      final name = info != null
          ? _unescape(info.group(2)!).replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '')
          : (_dn(_unescape(magnet!)) ?? 'EZTV release');
      out.add(_Row(name,
          hash: hash,
          page: info == null ? null : '$base${info.group(1)}',
          size: _parseSize(_sizeAny.firstMatch(row)?.group(0) ?? ''),
          seeders: _num(_first(_seed, row))));
    }
    return out;
  }
}

class UindexProvider extends _ProtectedProvider {
  @override
  String get id => 'uindex';
  @override
  String get name => 'UIndex';
  @override
  String get defaultBaseUrl => 'https://uindex.org';

  @override
  Uri searchUri(String base, String query) =>
      Uri.parse('$base/search.php').replace(queryParameters: {'search': query, 'c': '0'});

  static final _row = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
  static final _seed = RegExp(r'''class=["']g["'][^>]*>([\d,]+)<''');
  static final _leech = RegExp(r'''class=["']b["'][^>]*>([\d,]+)<''');

  @override
  List<_Row> parse(String html, String base) {
    final out = <_Row>[];
    for (final m in _row.allMatches(html)) {
      final row = m.group(1)!;
      final magnet = _magnetAny.firstMatch(row)?.group(1);
      if (magnet == null) continue;
      final mg = _unescape(magnet);
      final hash = _hashFromMagnet(mg);
      if (hash == null) continue;
      out.add(_Row(_dn(mg) ?? 'UIndex result',
          hash: hash,
          size: _parseSize(_sizeAny.firstMatch(row)?.group(0) ?? ''),
          seeders: _num(_first(_seed, row)),
          leechers: _num(_first(_leech, row))));
    }
    return out;
  }
}

/// EXT.to: reads every magnet link on the results page.
class ExtProvider extends _ProtectedProvider {
  @override
  String get id => 'ext';
  @override
  String get name => 'EXT';
  @override
  String get defaultBaseUrl => 'https://ext.to';

  @override
  Uri searchUri(String base, String query) =>
      Uri.parse('$base/search/').replace(queryParameters: {'q': query});

  @override
  List<_Row> parse(String html, String base) {
    final seen = <String>{};
    final out = <_Row>[];
    for (final m in _magnetAny.allMatches(html)) {
      final mg = _unescape(m.group(1)!);
      final hash = _hashFromMagnet(mg);
      if (hash == null || !seen.add(hash)) continue;
      final xl = RegExp(r'[?&]xl=(\d+)').firstMatch(mg)?.group(1);
      out.add(_Row(_dn(mg) ?? 'EXT result', hash: hash, size: int.tryParse(xl ?? '') ?? 0));
    }
    return out;
  }
}

/// TheRARBG: large successor index to RARBG. Not behind Cloudflare today,
/// but magnets are on each result's page.
class TheRarbgProvider extends _ProtectedProvider {
  @override
  String get id => 'therarbg';
  @override
  String get name => 'TheRARBG';
  @override
  String get defaultBaseUrl => 'https://therarbg.com';
  @override
  bool get usesCloudflare => false;
  @override
  String? get note => null;

  @override
  Future<String> page(http.Client client, String base, Uri uri) => _getText(client, uri);

  @override
  Uri searchUri(String base, String query) => Uri.parse(
      '$base/get-posts/order:-se:keywords:${Uri.encodeComponent(query.trim())}/');

  static final _row = RegExp(r'<tr class="list-entry">(.*?)</tr>', dotAll: true);
  static final _link = RegExp(r'<a href="(/post-detail/[^"]+)"[^>]*>([^<]+)</a>');
  static final _date = RegExp(r'class="hideCell" data-order="(\d+)"');
  static final _size = RegExp(r'class="sizeCell" data-order="(\d+)"');
  static final _seed = RegExp(r'color: green">([\d,]+)<');
  static final _leech = RegExp(r'color: red">([\d,]+)<');

  @override
  List<_Row> parse(String html, String base) => [
        for (final m in _row.allMatches(html))
          if (_link.firstMatch(m.group(1)!) case final l?)
            _Row(_unescape(l.group(2)!.trim()),
                page: '$base${l.group(1)}',
                size: int.tryParse(_first(_size, m.group(1)!) ?? '') ?? 0,
                seeders: _num(_first(_seed, m.group(1)!)),
                leechers: _num(_first(_leech, m.group(1)!)),
                added: _toDate(int.tryParse(_first(_date, m.group(1)!) ?? ''))),
      ];
}
