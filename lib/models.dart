/// A single search result from any provider.
class TorrentResult {
  final String name;
  final String infoHash;
  final int sizeBytes;
  final int seeders;
  final int leechers;
  final DateTime? added;
  final String source;
  final String? category;
  final String? pageUrl;

  const TorrentResult({
    required this.name,
    required this.infoHash,
    required this.sizeBytes,
    required this.seeders,
    required this.leechers,
    required this.source,
    this.added,
    this.category,
    this.pageUrl,
  });

  String magnet(List<String> trackers) {
    final buf = StringBuffer('magnet:?xt=urn:btih:${infoHash.toUpperCase()}')
      ..write('&dn=${Uri.encodeComponent(name)}');
    for (final t in trackers) {
      buf.write('&tr=${Uri.encodeComponent(t)}');
    }
    return buf.toString();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'infoHash': infoHash,
        'sizeBytes': sizeBytes,
        'seeders': seeders,
        'leechers': leechers,
        'added': added?.millisecondsSinceEpoch,
        'source': source,
        'category': category,
        'pageUrl': pageUrl,
      };

  factory TorrentResult.fromJson(Map<String, dynamic> j) => TorrentResult(
        name: j['name'] as String,
        infoHash: j['infoHash'] as String,
        sizeBytes: (j['sizeBytes'] as num).toInt(),
        seeders: (j['seeders'] as num).toInt(),
        leechers: (j['leechers'] as num).toInt(),
        added: j['added'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((j['added'] as num).toInt()),
        source: j['source'] as String,
        category: j['category'] as String?,
        pageUrl: j['pageUrl'] as String?,
      );
}

enum SortMode { seeders, size, newest, name }

extension SortModeLabel on SortMode {
  String get label => switch (this) {
        SortMode.seeders => 'Most seeders',
        SortMode.size => 'Largest',
        SortMode.newest => 'Newest',
        SortMode.name => 'Name A–Z',
      };
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  int i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

String formatAge(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inDays >= 365) return '${diff.inDays ~/ 365}y ago';
  if (diff.inDays >= 30) return '${diff.inDays ~/ 30}mo ago';
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  return 'just now';
}
