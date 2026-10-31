import 'package:flutter_test/flutter_test.dart';
import 'package:seedfinder/models.dart';

void main() {
  test('formats sizes', () {
    expect(formatBytes(0), '—');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(1073741824), '1.0 GB');
  });

  test('builds magnet link', () {
    const r = TorrentResult(
      name: 'Test file',
      infoHash: 'abc123',
      sizeBytes: 1,
      seeders: 1,
      leechers: 0,
      source: 'X',
    );
    final m = r.magnet(['udp://t.example:1/announce']);
    expect(m, startsWith('magnet:?xt=urn:btih:ABC123&dn=Test%20file'));
    expect(m, contains('&tr=udp%3A%2F%2Ft.example%3A1%2Fannounce'));
  });
}
