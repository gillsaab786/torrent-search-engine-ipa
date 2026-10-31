import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when a site shows Cloudflare's "checking your browser" page and
/// the user needs to pass it once in the in-app browser.
class CloudflareChallenge implements Exception {
  final String host;
  final Uri homepage;
  CloudflareChallenge(this.host, this.homepage);
  @override
  String toString() => 'Needs verification: $host';
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

/// Remembers, per site, the browser identity that passed the check, so later
/// searches can reuse it. Cookies themselves live in the system web view
/// store, shared with the headless fetcher.
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
    userAgent = ua;
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

  /// Fetches a page from a Cloudflare-protected site: first as a normal
  /// request carrying the verified cookies, then through a hidden browser
  /// (same engine that passed the check). Throws [CloudflareChallenge] when
  /// the user needs to verify again.
  Future<String> fetch(http.Client client, Uri uri, {Uri? homepage}) async {
    final home = homepage ?? uri.replace(path: '/', query: '');
    final cookie = await _cookiesFor(uri);
    if (userAgent != null && cookie != null) {
      try {
        final res = await client.get(uri, headers: {
          'User-Agent': userAgent!,
          'Cookie': cookie,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        }).timeout(const Duration(seconds: 15));
        final body = utf8.decode(res.bodyBytes, allowMalformed: true);
        if (res.statusCode == 200 && !looksLikeChallenge(body)) return body;
      } catch (_) {}
      _cookieHeader.remove(uri.host);
    }
    try {
      final html = await _browserFetch(uri);
      if (!looksLikeChallenge(html)) return html;
    } on CloudflareChallenge {
      rethrow;
    } catch (_) {}
    throw CloudflareChallenge(uri.host, home);
  }

  Future<String> _browserFetch(Uri uri) async {
    final done = Completer<String>();
    HeadlessInAppWebView? view;
    view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
      initialSettings: InAppWebViewSettings(
        userAgent: userAgent,
        javaScriptEnabled: true,
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
        if (!done.isCompleted) {
          done.completeError(CloudflareChallenge(uri.host, uri.replace(path: '/', query: '')));
        }
      },
      onReceivedError: (c, req, err) {
        if (req.isForMainFrame == true && !done.isCompleted) {
          done.completeError(Exception(err.description));
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
class VerifyScreen extends StatefulWidget {
  final String siteName;
  final Uri homepage;
  const VerifyScreen({super.key, required this.siteName, required this.homepage});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  bool _passed = false;
  double _progress = 0;

  Future<void> _check(InAppWebViewController c) async {
    if (_passed) return;
    final html =
        await c.evaluateJavascript(source: 'document.documentElement.outerHTML') as String?;
    if (html == null || html.length < 500 || looksLikeChallenge(html)) return;
    final ua = await c.evaluateJavascript(source: 'navigator.userAgent') as String?;
    await CloudflareSession.instance.markVerified(widget.homepage.host, ua ?? '');
    if (!mounted) return;
    setState(() => _passed = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify ${widget.siteName}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _progress < 1
              ? LinearProgressIndicator(value: _progress, minHeight: 3)
              : const SizedBox(height: 3),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _passed
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : const Color(0xFF1C1C1E),
            child: Text(
              _passed
                  ? 'Verified ✓  Returning to your search…'
                  : 'Complete the check below if one appears (tick the box). This screen closes by itself once the site loads.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri.uri(widget.homepage)),
              initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
              onProgressChanged: (_, p) => setState(() => _progress = p / 100),
              onLoadStop: (c, _) async {
                // Re-check for a few seconds; the check page reloads itself.
                for (var i = 0; i < 8 && mounted && !_passed; i++) {
                  await _check(c);
                  await Future.delayed(const Duration(seconds: 1));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
