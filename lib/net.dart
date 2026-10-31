import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Network setup for source requests.
///
/// With encrypted DNS on, site names are looked up over HTTPS (Cloudflare,
/// then Google) instead of the network's own DNS, and the TLS certificate is
/// still checked against the real site name. If that fails for any reason the
/// request is retried with normal DNS, so turning it on never makes things
/// worse.
class Net {
  static bool encryptedDns = true;

  static final _cache = <String, (InternetAddress, DateTime)>{};

  static Future<InternetAddress?> resolve(String host) async {
    final literal = InternetAddress.tryParse(host);
    if (literal != null) return literal;
    final hit = _cache[host];
    if (hit != null && hit.$2.isAfter(DateTime.now())) return hit.$1;
    for (final server in const ['https://1.1.1.1/dns-query', 'https://8.8.8.8/resolve']) {
      final hc = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      try {
        final req = await hc.getUrl(Uri.parse(server).replace(queryParameters: {'name': host, 'type': 'A'}));
        req.headers.set('accept', 'application/dns-json');
        final res = await req.close().timeout(const Duration(seconds: 6));
        final body = await res.transform(utf8.decoder).join();
        final answers = (jsonDecode(body) as Map)['Answer'] as List? ?? const [];
        for (final a in answers) {
          if (a is Map && a['type'] == 1) {
            final ip = InternetAddress(a['data'] as String);
            final ttl = max(60, (a['TTL'] as num? ?? 300).toInt());
            _cache[host] = (ip, DateTime.now().add(Duration(seconds: ttl)));
            return ip;
          }
        }
      } catch (_) {
        // try the next resolver
      } finally {
        hc.close(force: true);
      }
    }
    return null;
  }

  static HttpClient _dohHttpClient() {
    final hc = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    hc.connectionFactory = (uri, proxyHost, proxyPort) async {
      final ip = await resolve(uri.host);
      if (ip == null) throw SocketException('Encrypted DNS lookup failed for ${uri.host}');
      if (uri.scheme == 'https') {
        final Future<Socket> secured = () async {
          final raw = await Socket.connect(ip, uri.port, timeout: const Duration(seconds: 10));
          return SecureSocket.secure(raw, host: uri.host);
        }();
        return ConnectionTask.fromSocket(secured, () {});
      }
      return Socket.startConnect(ip, uri.port);
    };
    return hc;
  }

  /// HTTP client for source requests.
  static http.Client client() => encryptedDns ? _FallbackClient(IOClient(_dohHttpClient()), http.Client()) : http.Client();
}

/// Sends with [primary]; on a connection-level failure retries with [backup].
class _FallbackClient extends http.BaseClient {
  final http.Client primary, backup;
  _FallbackClient(this.primary, this.backup);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await primary.send(_copy(request));
    } on SocketException {
      return backup.send(_copy(request));
    } on HandshakeException {
      return backup.send(_copy(request));
    } on http.ClientException {
      return backup.send(_copy(request));
    }
  }

  http.BaseRequest _copy(http.BaseRequest r) {
    final c = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..followRedirects = r.followRedirects
      ..maxRedirects = r.maxRedirects;
    if (r is http.Request && r.bodyBytes.isNotEmpty) c.bodyBytes = r.bodyBytes;
    return c;
  }

  @override
  void close() {
    primary.close();
    backup.close();
  }
}
