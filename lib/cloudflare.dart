import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance.dart';

/// The site shows Cloudflare's "checking your browser" page; the user needs to
/// pass it once in the in-app browser.
class CloudflareChallenge implements Exception {
  final String host;
  final Uri homepage;
  CloudflareChallenge(this.host, this.homepage);
  @override
  String toString() => 'Needs verification: $host';
}

/// The site could not be reached at all (blocked by the network, offline,
/// moved, or timed out). Verifying would not help; a mirror might.
class SourceUnreachable implements Exception {
  final String reason;
  SourceUnreachable(this.reason);
  @override
  String toString() => reason;
}

final _markers = [
  'Just a moment...',
  'cf-chl-',
  'challenge-platform',
  'cf_chl_opt',
  'Attention Required! | Cloudflare',
  'Checking your browser',
  'Verify you are human',
];

bool looksLikeChallenge(String html) {
  final head = html.length > 20000 ? html.substring(0, 20000) : html;
  return _markers.any(head.contains);
}

String _shortReason(Object e) {
  final s = e.toString();
  if (e is TimeoutException || s.contains('Timeout') || s.contains('timed out')) return 'timed out';
  if (s.contains('Failed host lookup') || s.contains('lookup')) return 'blocked or offline';
  if (s.contains('Connection refused') || s.contains('Connection reset')) return 'connection refused';
  if (s.contains('Handshake') || s.contains('CERTIFICATE')) return 'blocked (bad certificate)';
  return 'unreachable';
}

/// Remembers which sites have been verified and the browser identity used,
/// so later searches can reuse it. Cookies live in the system web view store,
/// which the hidden fetcher shares.
class CloudflareSession {
  CloudflareSession._();
  static final instance = CloudflareSession._();

  String? userAgent;
  final Map<String, DateTime> verifiedAt = {};
  final Map<String, String> _cookieHeader = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    userAgent = p.getString('cf_ua');
    final v = p.getString('cf_verified');
    if (v != null) {
      (jsonDecode(v) as Map).forEach((k, t) =>
          verifiedAt[k as String] = DateTime.fromMillisecondsSinceEpoch(t as int));
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (userAgent != null) p.setString('cf_ua', userAgent!);
    p.setString('cf_verified',
        jsonEncode(verifiedAt.map((k, t) => MapEntry(k, t.millisecondsSinceEpoch))));
  }

  bool isVerified(String host) => verifiedAt.containsKey(host);

  Future<void> markVerified(String host, String ua) async {
    if (ua.isNotEmpty) userAgent = ua;
    verifiedAt[host] = DateTime.now();
    _cookieHeader.remove(host);
    await _save();
  }

  Future<String?> _cookiesFor(Uri uri) async {
    final cached = _cookieHeader[uri.host];
    if (cached != null) return cached;
    try {
      final cookies = await CookieManager.instance().getCookies(url: WebUri.uri(uri));
      if (cookies.isEmpty) return null;
      final header = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      _cookieHeader[uri.host] = header;
      return header;
    } catch (_) {
      return null;
    }
  }

  /// Fetches a page, handling Cloudflare:
  /// 1. a normal request (with saved verification cookies, if any);
  /// 2. if Cloudflare challenges it, a hidden browser that shares the
  ///    cookies from the Verify screen.
  /// Throws [SourceUnreachable] when the site can't be reached at all, and
  /// [CloudflareChallenge] when the user needs to verify.
  Future<String> fetch(http.Client client, Uri uri, {Uri? homepage}) async {
    final home = homepage ?? uri.replace(path: '/', query: '');
    try {
      final headers = <String, String>{
        'User-Agent': userAgent ??
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      };
      final cookie = await _cookiesFor(uri);
      if (cookie != null) headers['Cookie'] = cookie;
      final res = await client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      final challenged = looksLikeChallenge(body);
      if (res.statusCode == 200 && !challenged) return body;
      if (!challenged && res.statusCode != 403 && res.statusCode != 503) {
        throw SourceUnreachable('HTTP ${res.statusCode}');
      }
    } on SourceUnreachable {
      rethrow;
    } catch (e) {
      throw SourceUnreachable(_shortReason(e));
    }
    _cookieHeader.remove(uri.host);
    try {
      return await _browserFetch(uri);
    } on SourceUnreachable {
      rethrow;
    } catch (_) {
      throw CloudflareChallenge(uri.host, home);
    }
  }

  Future<String> _browserFetch(Uri uri) async {
    final done = Completer<String>();
    final view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
      initialSettings: InAppWebViewSettings(
        userAgent: userAgent,
        javaScriptEnabled: true,
        sharedCookiesEnabled: true,
      ),
      onLoadStop: (c, _) async {
        // Cloudflare may redirect a couple of times after a short wait.
        for (var i = 0; i < 12 && !done.isCompleted; i++) {
          final html = await c.evaluateJavascript(
              source: 'document.documentElement.outerHTML') as String?;
          if (html != null && !looksLikeChallenge(html)) {
            if (!done.isCompleted) done.complete(html);
            return;
          }
          await Future.delayed(const Duration(milliseconds: 750));
        }
        if (!done.isCompleted) done.completeError(CloudflareChallenge(uri.host, uri));
      },
      onReceivedError: (c, req, err) {
        if (req.isForMainFrame == true && !done.isCompleted) {
          done.completeError(SourceUnreachable(_shortReason(err.description)));
        }
      },
    );
    await view.run();
    try {
      return await done.future.timeout(const Duration(seconds: 25));
    } finally {
      await view.dispose();
    }
  }
}

/// Full-screen browser where the user passes the Cloudflare check once.
/// Tries each address in [candidates] (the site, then its mirrors) and pops
/// with the address that worked, or null.
class VerifyScreen extends StatefulWidget {
  final String siteName;
  final List<Uri> candidates;
  VerifyScreen({super.key, required this.siteName, Uri? homepage, List<Uri>? candidates})
      : candidates = candidates ?? [homepage!];

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  InAppWebViewController? _web;
  int _index = 0;
  bool _passed = false;
  bool _loading = true;
  String? _error;
  double _progress = 0;

  Uri get _current => widget.candidates[_index];

  Future<void> _check(InAppWebViewController c) async {
    if (_passed || _error != null) return;
    final html =
        await c.evaluateJavascript(source: 'document.documentElement.outerHTML') as String?;
    if (html == null || html.length < 500 || looksLikeChallenge(html)) return;
    final ua = await c.evaluateJavascript(source: 'navigator.userAgent') as String?;
    await CloudflareSession.instance.markVerified(_current.host, ua ?? '');
    if (!mounted) return;
    setState(() => _passed = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context, _current);
  }

  void _open(int i) {
    setState(() {
      _index = i;
      _error = null;
      _loading = true;
      _progress = 0;
    });
    _web?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(_current)));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          Text('Verify ${widget.siteName}'),
          Text(_current.host, style: const TextStyle(fontSize: 12, color: Ios.secondaryLabel)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: () => _open(_index),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _loading
              ? LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress, minHeight: 2, color: accent)
              : const SizedBox(height: 2),
        ),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: _passed ? accent.withValues(alpha: 0.2) : Ios.grouped,
          child: Text(
            _passed
                ? 'Verified ✓  Returning to your search…'
                : 'If a check appears, tick the box. This screen closes by itself once the site loads.',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: Stack(children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri.uri(_current)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                sharedCookiesEnabled: true,
                transparentBackground: true,
              ),
              onWebViewCreated: (c) => _web = c,
              onProgressChanged: (_, p) => setState(() => _progress = p / 100),
              onLoadStop: (c, _) async {
                if (mounted) setState(() => _loading = false);
                // The check page reloads itself, so look again for a few seconds.
                for (var i = 0; i < 10 && mounted && !_passed && _error == null; i++) {
                  await _check(c);
                  await Future.delayed(const Duration(seconds: 1));
                }
              },
              onReceivedError: (c, req, err) {
                if (req.isForMainFrame != true || !mounted) return;
                setState(() {
                  _loading = false;
                  _error = _shortReason(err.description);
                });
              },
            ),
            if (_error != null) _errorPanel(accent),
          ]),
        ),
      ]),
    );
  }

  Widget _errorPanel(Color accent) {
    final others = [
      for (var i = 0; i < widget.candidates.length; i++)
        if (i != _index) i,
    ];
    return Container(
      color: Ios.background,
      padding: const EdgeInsets.all(20),
      child: ListView(children: [
        const SizedBox(height: 20),
        Icon(CupertinoIcons.wifi_exclamationmark, size: 48, color: accent),
        const SizedBox(height: 14),
        Text("Couldn't open ${_current.host}",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'The site is $_error. Many torrent sites are blocked by Australian internet '
          'providers, or move to new addresses. Try another address below.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Ios.secondaryLabel, fontSize: 15),
        ),
        const SizedBox(height: 22),
        for (final i in others)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton(
              onPressed: () => _open(i),
              child: Text('Try ${widget.candidates[i].host}'),
            ),
          ),
        CupertinoButton(
          onPressed: () => _open(_index),
          child: Text('Retry ${_current.host}', style: TextStyle(color: accent)),
        ),
      ]),
    );
  }
}
