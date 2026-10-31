part of 'providers.dart';

// Sources added by the user: paste a site's address and the app works out
// how to search it, then reads results without knowing the site's layout:
//   1. magnet links on the results page (name from the magnet's dn= field), or
//   2. links that look like result pages, opened a few at a time to read
//      their magnet link.
// Seeder counts aren't known for these, so they show as "?".

class CustomProvider extends SearchProvider {
  @override
  final String id;
  @override
  final String name;

  /// Search address with {q} where the query goes.
  final String template;

  CustomProvider({required this.id, required this.name, required this.template});

  factory CustomProvider.fromJson(Map<String, dynamic> j) => CustomProvider(
      id: j['id'] as String, name: j['name'] as String, template: j['template'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'template': template};

  @override
  bool get isCustom => true;
  @override
  String get defaultBaseUrl => Uri.parse(template.replaceAll('{q}', 'q')).origin;
  @override
  Set<Category> get categories => {Category.all};
  @override
  String? get note => 'Added by you';

  Uri searchUri(String base, String query) {
    final own = Uri.parse(template.replaceAll('{q}', 'q')).origin;
    final t = base == own || base.isEmpty ? template : template.replaceFirst(own, _trimSlash(base));
    final inQuery = t.indexOf('{q}') > t.indexOf('?') && t.contains('?');
    final q = inQuery ? Uri.encodeQueryComponent(query) : Uri.encodeComponent(query);
    return Uri.parse(t.replaceAll('{q}', q));
  }

  @override
  Future<List<TorrentResult>> search(
      http.Client client, String baseUrl, String query, Category category) async {
    final uri = searchUri(baseUrl, query);
    final home = Uri.parse('${uri.origin}/');
    final html = await CloudflareSession.instance.fetch(client, uri, homepage: home);
    final direct = harvest(html, uri.host);
    if (direct.isNotEmpty) return direct.map((r) => _toResult(r)).toList();

    final links = detailLinks(html, uri, query).take(12).toList();
    final found = await _pooled(links, 4, (l) async {
      try {
        final page = await CloudflareSession.instance.fetch(client, Uri.parse(l.$1), homepage: home);
        final rows = harvest(page, uri.host);
        if (rows.isEmpty) return null;
        final r = rows.first;
        return _Row(l.$2.isNotEmpty ? l.$2 : r.name, page: l.$1, hash: r.hash, size: r.size);
      } catch (_) {
        return null;
      }
    });
    final seen = <String>{};
    return [
      for (final r in found.whereType<_Row>())
        if (seen.add(r.hash!)) _toResult(r),
    ];
  }

  TorrentResult _toResult(_Row r) => TorrentResult(
        name: r.name,
        infoHash: r.hash!,
        sizeBytes: r.size,
        seeders: r.seeders,
        leechers: r.leechers,
        source: name,
        pageUrl: r.page,
      );

  static final _torrentFile = RegExp(r'''["'/]([A-Fa-f0-9]{40})\.torrent(?:\?[^"']*)?["']''');

  /// Every distinct magnet (or .torrent link carrying a hash) on a page.
  static List<_Row> harvest(String html, String host) {
    final seen = <String>{};
    final out = <_Row>[];
    for (final m in _magnetAny.allMatches(html)) {
      final mg = _unescape(m.group(1)!);
      final hash = _hashFromMagnet(mg);
      if (hash == null || !seen.add(hash)) continue;
      final xl = RegExp(r'[?&]xl=(\d+)').firstMatch(mg)?.group(1);
      out.add(_Row(_dn(mg) ?? 'Result from $host', hash: hash, size: int.tryParse(xl ?? '') ?? 0));
    }
    for (final m in _torrentFile.allMatches(html)) {
      final hash = m.group(1)!.toLowerCase();
      if (!seen.add(hash)) continue;
      final title = RegExp(r'title=([^&"]+)').firstMatch(m.group(0)!)?.group(1);
      out.add(_Row(
          title == null ? 'Result from $host' : Uri.decodeQueryComponent(title).replaceAll('-', ' '),
          hash: hash));
    }
    return out;
  }

  static final _anchor = RegExp(r'<a\s[^>]*href="([^"#]+)"[^>]*>(.*?)</a>', dotAll: true);
  static final _detailPath = RegExp(
      r'/(torrent|torrents|details?|t|tor|post-detail|view|item|file|download|magnet)[/\-_.?=]',
      caseSensitive: false);

  /// Links on a results page that probably lead to individual results:
  /// same site, a result-like path, and link text containing a search word.
  static List<(String, String)> detailLinks(String html, Uri page, String query) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toList();
    final seen = <String>{};
    final out = <(String, String)>[];
    for (final m in _anchor.allMatches(html)) {
      final href = _unescape(m.group(1)!);
      final text = _stripTags(m.group(2)!).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.length < 6) continue;
      final lower = text.toLowerCase();
      if (words.isNotEmpty && !words.any(lower.contains)) continue;
      Uri u;
      try {
        u = page.resolve(href);
      } catch (_) {
        continue;
      }
      if (u.host != page.host || !_detailPath.hasMatch('${u.path}/')) continue;
      if (u.path == page.path && u.query == page.query) continue;
      if (seen.add(u.toString())) out.add((u.toString(), text));
    }
    return out;
  }

  /// Search-address patterns to try for a pasted link.
  static List<String> candidateTemplates(String input) {
    var s = input.trim();
    if (s.isEmpty) return [];
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
    final Uri u;
    try {
      u = Uri.parse(s);
    } catch (_) {
      return [];
    }
    if (u.host.isEmpty) return [];
    if (s.contains('{q}')) return [s];
    final origin = u.origin;
    // A pasted results page for "test" (or "ubuntu"): put {q} where the word is.
    final rest = s.substring(origin.length);
    for (final w in const ['test', 'ubuntu']) {
      final i = rest.toLowerCase().indexOf(w);
      if (i >= 0) return ['$origin${rest.substring(0, i)}{q}${rest.substring(i + w.length)}'];
    }
    return [
      '$origin/search?q={q}',
      '$origin/search/{q}/1/',
      '$origin/search/{q}/',
      '$origin/search/?q={q}',
      '$origin/?s={q}',
      '$origin/search.php?q={q}',
      '$origin/search.php?search={q}',
      '$origin/usearch/{q}/',
      '$origin/torrents.php?search={q}',
      '$origin/browse?t={q}',
      '$origin/search?search={q}',
      '$origin/find/?q={q}',
      '$origin/s/?q={q}',
      '$origin/?q={q}',
    ];
  }
}

/// Outcome of trying to add a site.
class DetectResult {
  final CustomProvider? provider;
  final int found;
  final CloudflareChallenge? challenge;
  final String? error;
  const DetectResult({this.provider, this.found = 0, this.challenge, this.error});
}

/// Works out how to search [input] by trying each likely search address with
/// a test query and keeping the first that returns results.
Future<DetectResult> detectCustomSource(String input, {String? name, void Function(String)? progress}) async {
  final templates = CustomProvider.candidateTemplates(input);
  if (templates.isEmpty) return const DetectResult(error: "That doesn't look like a web address.");
  final host = Uri.parse(templates.first.replaceAll('{q}', 'q')).host.replaceFirst(RegExp(r'^www\.'), '');
  final client = Net.client();
  try {
    for (final t in templates) {
      final p = CustomProvider(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: (name ?? '').trim().isNotEmpty ? name!.trim() : host,
          template: t);
      progress?.call(Uri.parse(t.replaceAll('{q}', 'ubuntu')).path);
      try {
        final r = await p.search(client, '', 'ubuntu', Category.all).timeout(const Duration(seconds: 40));
        if (r.isNotEmpty) return DetectResult(provider: p, found: r.length);
      } on CloudflareChallenge catch (e) {
        return DetectResult(challenge: e);
      } on SourceUnreachable catch (e) {
        // Same site for every pattern, so stop unless this pattern simply 404'd.
        if (!e.reason.startsWith('HTTP')) {
          return DetectResult(error: '$host is ${e.reason}.');
        }
      } catch (_) {
        // try the next pattern
      }
    }
  } finally {
    client.close();
  }
  return DetectResult(
      error: "Couldn't find a search page on $host. In Safari, search that site for "
          '"test", then copy the results page address and paste it here.');
}
