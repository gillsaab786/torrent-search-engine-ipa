import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seedfinder/cloudflare.dart';
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

  protectedParserTests();

  test('every source has a unique id', () {
    final ids = allProviders.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}

// Parsers for the Cloudflare-protected sites. These pages can't be fetched
// from a build server, so the samples below are small hand-written rows that
// follow each site's documented result layout.
void protectedParserTests() {
  const hash = '0123456789abcdef0123456789abcdef01234567';

  test('1337x list rows', () {
    const html = '''<table><tbody>
<tr><td class="coll-1 name"><a href="/sub/1/0/" class="icon"><i class="flaticon-x"></i></a><a href="/torrent/123/Example-Release/">Example Release 1080p</a></td>
<td class="coll-2 seeds">812</td><td class="coll-3 leeches">40</td><td class="coll-date">Oct. 30th '26</td>
<td class="coll-4 size mob-uploader">2.4 GB<span class="seeds">812</span></td></tr>
</tbody></table>''';
    final r = X1337Provider().parse(html, 'https://1337x.to');
    expect(r.length, 1);
    expect(r.first.name, 'Example Release 1080p');
    expect(r.first.page, 'https://1337x.to/torrent/123/Example-Release/');
    expect(r.first.seeders, 812);
    expect(r.first.leechers, 40);
    expect(r.first.size, greaterThan(2000000000));
  });

  test('Torlock / TorrentFunk list rows', () {
    const html = '''<article><table>
<tr><td><div><a href="/torrent/987/example-release.html"><b>Example</b> Release</a></div></td>
<td class="td">10/30/2026</td><td class="ts">700 MB</td><td class="tul">55</td><td class="tdl">3</td></tr>
</table></article>''';
    final r = TorlockProvider().parse(html, 'https://www.torlock.com');
    expect(r.single.name, 'Example Release');
    expect(r.single.seeders, 55);
    expect(r.single.added, DateTime(2026, 10, 30));
  });

  test('KickassTorrents list rows', () {
    const html = '''<table><tr class="odd"><td><div class="torrentname">
<a href="/example-release-t1.html" class="cellMainLink">Example <strong>Release</strong></a></div></td>
<td class="nobr center">1.5 GB</td><td class="center">2</td><td class="center">1 day</td>
<td class="green center">120</td><td class="red lasttd center">9</td></tr></table>''';
    final r = KickassProvider().parse(html, 'https://kickasstorrents.to');
    expect(r.single.name, 'Example Release');
    expect(r.single.page, 'https://kickasstorrents.to/example-release-t1.html');
    expect(r.single.seeders, 120);
    expect(r.single.size, greaterThan(1500000000));
  });

  test('EZTV list rows carry magnets', () {
    const html = '''<table><tr name="hover" class="forum_header_border">
<td><a href="/ep/1/example-s01e01/" title="Example S01E01 720p (350.00 MB)" alt="x" class="epinfo">Example S01E01</a></td>
<td><a href="magnet:?xt=urn:btih:$hash&amp;dn=Example" class="magnet" title="Magnet"></a></td>
<td class="forum_thread_post">350.00 MB</td><td class="forum_thread_post">1h</td>
<td class="forum_thread_post_end"><font color="green">77</font></td></tr></table>''';
    final r = EztvProvider().parse(html, 'https://eztvx.to');
    expect(r.single.hash, hash);
    expect(r.single.name, 'Example S01E01 720p');
    expect(r.single.seeders, 77);
  });

  test('UIndex and EXT read magnets from the page', () {
    const html = '''<table><tr><td><a href="magnet:?xt=urn:btih:$hash&amp;dn=Example.Release&amp;xl=1048576">M</a>
<a href="/details.php?id=1">Example.Release</a></td><td>1.0 MB</td><td class="sub">1 day</td>
<td><span class="g">31</span></td><td><span class="b">2</span></td></tr></table>''';
    final u = UindexProvider().parse(html, 'https://uindex.org');
    expect(u.single.name, 'Example.Release');
    expect(u.single.seeders, 31);
    final e = ExtProvider().parse(html, 'https://ext.to');
    expect(e.single.hash, hash);
    expect(e.single.size, 1048576);
  });

  test('TheRARBG list rows', () {
    final html = File('test/fixtures/therarbg.html').readAsStringSync();
    final r = TheRarbgProvider().parse(html, 'https://therarbg.com');
    expect(r.length, 2);
    expect(r.first.page, startsWith('https://therarbg.com/post-detail/'));
    expect(r.first.size, greaterThan(0));
    expect(r.first.seeders, greaterThan(0));
    expect(r.first.added, isNotNull);
  });

  test('Cloudflare challenge pages are recognised', () {
    expect(looksLikeChallenge('<title>Just a moment...</title>'), isTrue);
    expect(looksLikeChallenge('<html><body>results</body></html>'), isFalse);
  });
}
