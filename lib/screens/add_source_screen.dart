import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../appearance.dart';
import '../cloudflare.dart';
import '../main.dart';
import '../providers.dart';
import '../widgets/ios.dart';

/// Paste a site's address; the app finds its search page and adds it.
class AddSourceScreen extends StatefulWidget {
  const AddSourceScreen({super.key});

  @override
  State<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends State<AddSourceScreen> {
  final _url = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _step;
  String? _error;
  CloudflareChallenge? _challenge;

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _challenge = null;
      _step = 'Looking for the search page…';
    });
    final r = await detectCustomSource(
      _url.text,
      name: _name.text,
      progress: (s) {
        if (mounted) setState(() => _step = 'Trying $s');
      },
    );
    if (!mounted) return;
    if (r.provider != null) {
      store.addCustomSource(r.provider!);
      setState(() => _busy = false);
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text('${r.provider!.name} added'),
          content: Text('Found ${r.found} results in a test search. It will be included in every search.'),
          actions: [
            CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = false;
      _challenge = r.challenge;
      _error = r.challenge != null
          ? '${r.challenge!.host} is protected by Cloudflare. Verify it once, then tap Add again.'
          : r.error;
    });
  }

  Future<void> _verify() async {
    final c = _challenge!;
    await Navigator.push<Uri?>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VerifyScreen(siteName: c.host, candidates: [Uri.parse('${c.homepage.origin}/')]),
      ),
    );
    if (mounted) _add();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(CupertinoIcons.xmark), onPressed: () => Navigator.pop(context)),
        title: const Text('Add Source'),
      ),
      body: ListView(children: [
        const SizedBox(height: 12),
        IosSection(
          header: 'Website',
          footer: 'Paste the site\'s address, e.g. https://example-torrents.com. '
              'For best results, search the site for "test" in Safari and paste that results page link instead.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: CupertinoTextField(
                controller: _url,
                placeholder: 'https://',
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: null,
                style: const TextStyle(color: Colors.white, fontSize: 17),
                padding: const EdgeInsets.symmetric(vertical: 10),
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
            ),
          ],
        ),
        IosSection(header: 'Name (optional)', children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: CupertinoTextField(
              controller: _name,
              placeholder: 'Shown in results',
              decoration: null,
              style: const TextStyle(color: Colors.white, fontSize: 17),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton(
            onPressed: _busy ? null : _add,
            child: _busy
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text('Add source'),
          ),
        ),
        if (_busy && _step != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_step!, textAlign: TextAlign.center, style: const TextStyle(color: Ios.secondaryLabel)),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Ios.grouped, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_error!, style: const TextStyle(fontSize: 15)),
                if (_challenge != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _verify,
                      child: Text('Verify ${_challenge!.host}', style: TextStyle(color: accent)),
                    ),
                  ),
              ]),
            ),
          ),
        const SizedBox(height: 40),
      ]),
    );
  }
}
