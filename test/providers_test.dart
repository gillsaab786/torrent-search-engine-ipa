import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seedfinder/models.dart';
import 'package:seedfinder/providers.dart';

/// Serves a saved response for every request, so each parser is checked
/// against what the real site returned (see tools/probe.sh).
http.Client fixture(String file) => MockClient((req) async => http.Response.bytes(
      File('test/fixtures/$file').readAsBytesSync(),
      200,
      headers: {'content-type': 'text/plain; charset=utf-8'},
    ));

final hex40 = RegExp(r'^[0-9a-fA-F]{40}$');

Future<List<TorrentResult>> run(SearchProvider p, String file, [String q = 'ubuntu']) =>
    p.search(fixture(file), p.defaultBaseUrl, q, Category.all);

void expectValid(List<TorrentResult> r, {bool seeded = true, int min = 1}) {
  expect(r.length, greaterThanOrEqualTo(min));
  for (final t in r) {
    expect(t.name.trim(), isNotEmpty);
    expect(t.infoHash, matches(hex40), reason: t.name);
    if (seeded) {
      expect(t.seeders, greaterThanOrEqualTo(0), reason: t.name);
    } else {
      expect(t.seeders, -1, reason: t.name);
    }
  }
}

void main() {
  test('Knaben', () async {
    final r = await run(KnabenProvider(), 'knaben.json');
    expectValid(r, min: 3);
    expect(r.first.sizeBytes, greaterThan(0));
    expect(r.first.source, isNot('Knaben')); // shows the underlying site
  });

  test('ApiBay', () async => expectValid(await run(ApiBayProvider(), 'apibay.json'), min: 3));

  test('BitSearch', () async {
    final r = await run(BitSearchProvider(), 'bitsearch.html');
    expectValid(r, min: 3);
    expect(r.every((t) => t.sizeBytes > 0), isTrue);
    expect(r.any((t) => t.seeders > 0), isTrue);
  });

  test('Torrents-CSV', () async =>
      expectValid(await run(TorrentsCsvProvider(), 'torrentscsv.json'), min: 3));

  test('LimeTorrents skips ad rows', () async {
    final r = await run(LimeTorrentsProvider(), 'limetorrents.html');
    expectValid(r, min: 3);
    expect(r.length, 3);
    expect(r.every((t) => t.sizeBytes > 0), isTrue);
  });

  test('TorrentDownloads', () async {
    final r = await run(TorrentDownloadsProvider(), 'torrentdownloads.xml');
    expectValid(r, min: 3);
    expect(r.first.seeders, greaterThan(0));
  });

  test('Rutor', () async {
    final r = await run(RutorProvider(), 'rutor.html');
    expectValid(r, min: 3);
    expect(r.every((t) => t.sizeBytes > 0), isTrue);
    expect(r.every((t) => t.added != null), isTrue);
  });

  test('BT4G', () async {
    final r = await run(Bt4gProvider(), 'bt4g.xml');
    expectValid(r, seeded: false, min: 3);
    expect(r.first.sizeBytes, greaterThan(0));
  });

  test('Internet Archive keeps only items with torrents', () async {
    final r = await run(InternetArchiveProvider(), 'archive.json');
    expectValid(r, seeded: false);
    expect(r.every((t) => t.pageUrl!.contains('/details/')), isTrue);
  });

  test('YTS', () async {
    final r = await run(YtsProvider(), 'yts.json', 'inception');
    expectValid(r);
    expect(r.first.name, contains('Inception'));
  });

  test('Nyaa', () async => expectValid(await run(NyaaProvider(), 'nyaa.xml', 'one piece'), min: 3));

  test('SubsPlease converts base32 hashes', () async {
    final r = await run(SubsPleaseProvider(), 'subsplease.json', 'one piece');
    expectValid(r, seeded: false, min: 2);
    expect(r.first.sizeBytes, greaterThan(0));
  });

  test('TokyoTosho', () async {
    final r = await run(TokyoToshoProvider(), 'tokyotosho.xml', 'one piece');
    expectValid(r, seeded: false, min: 3);
    expect(r.first.sizeBytes, greaterThan(0));
  });

  test('Jackett / Prowlarr (Torznab)', () async {
    const feed = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:torznab="http://torznab.com/schemas/2015/feed">
<channel><item>
  <title>Example.Release.1080p</title>
  <jackettindexer id="x">ExampleTracker</jackettindexer>
  <size>1073741824</size>
  <pubDate>Sat, 31 Oct 2026 10:00:00 +0000</pubDate>
  <link>http://localhost/dl/1</link>
  <torznab:attr name="seeders" value="42" />
  <torznab:attr name="peers" value="50" />
  <torznab:attr name="infohash" value="0123456789abcdef0123456789abcdef01234567" />
</item></channel></rss>''';
    final p = TorznabProvider();
    final r = await p.search(
      MockClient((req) async {
        expect(req.url.queryParameters['apikey'], 'k');
        expect(req.url.queryParameters['t'], 'search');
        return http.Response(feed, 200);
      }),
      'http://localhost:9117/api/v2.0/indexers/all/results/torznab/api?apikey=k',
      'example',
      Category.all,
    );
    expectValid(r);
    expect(r.first.seeders, 42);
    expect(r.first.leechers, 8);
    expect(r.first.source, 'ExampleTracker');
  });

  test('every source has a unique id', () {
    final ids = allProviders.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
