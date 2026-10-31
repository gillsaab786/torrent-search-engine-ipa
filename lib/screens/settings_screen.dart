import 'package:flutter/material.dart';

import '../appearance.dart';
import '../cloudflare.dart';
import '../main.dart';
import '../providers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          children: [
            _Header('Sources (${store.enabledProviders.length} of ${allProviders.length} on)'),
            for (final p in allProviders)
              SwitchListTile(
                title: Text(p.name),
                subtitle: Text(
                  [
                    if (p.usesCloudflare)
                      CloudflareSession.instance.isVerified(
                              Uri.parse(store.baseUrls[p.id] ?? p.defaultBaseUrl).host)
                          ? 'Verified ✓'
                          : 'Protected by Cloudflare — not verified yet'
                    else if (p.note != null)
                      p.note!,
                    (store.baseUrls[p.id] ?? '').isNotEmpty
                        ? store.baseUrls[p.id]!
                        : (p.needsSetup ? 'Not set up — tap ✎ to add' : p.defaultBaseUrl),
                  ].join('\n'),
                  style: const TextStyle(color: Colors.white54),
                ),
                isThreeLine: p.note != null || p.usesCloudflare,
                value: store.enabledProviders.contains(p.id),
                onChanged: (v) => store.setProviderEnabled(p.id, v),
                secondary: p.usesCloudflare
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'Options',
                        onSelected: (v) =>
                            v == 'verify' ? _verify(context, p) : _editMirror(context, p),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'verify', child: Text('Verify now')),
                          PopupMenuItem(value: 'mirror', child: Text('Set mirror URL')),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Set mirror URL',
                        onPressed: () => _editMirror(context, p),
                      ),
              ),
            const _Header('Results'),
            ListTile(
              title: const Text('Minimum seeders'),
              subtitle: Slider(
                value: store.minSeeders.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '${store.minSeeders}',
                onChanged: (v) => store.setMinSeeders(v.round()),
              ),
              trailing: Text('${store.minSeeders}'),
            ),
            SwitchListTile(
              title: const Text('Save search history'),
              value: store.saveHistory,
              onChanged: store.setSaveHistory,
            ),
            ListTile(
              title: const Text('Clear search history'),
              leading: const Icon(Icons.delete_sweep_outlined),
              onTap: () {
                store.clearHistory();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('History cleared'), behavior: SnackBarBehavior.floating));
              },
            ),
            const _Header('Magnet links'),
            ListTile(
              title: const Text('Trackers'),
              subtitle: Text('${store.trackers.length} added to every magnet link',
                  style: const TextStyle(color: Colors.white54)),
              leading: const Icon(Icons.hub_outlined),
              onTap: () => _editTrackers(context),
            ),
            const _Header('About'),
            const ListTile(
              title: Text('Torrent Search Engine'),
              subtitle: Text(
                'No ads. All features included. Results come from public indexes; '
                'you are responsible for what you download.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            const _Header('Appearance'),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('Accent colour', style: TextStyle(fontSize: 16)),
            ),
            AccentPicker(
              selected: store.accentIndex,
              onSelected: (i) async {
                store.setAccent(i);
                if (store.matchIcon) await applyAppIcon(accents[i]);
              },
            ),
            SwitchListTile(
              title: const Text('Match app icon'),
              subtitle: const Text('Home-screen icon uses the same colour',
                  style: TextStyle(color: Colors.white54)),
              value: store.matchIcon,
              onChanged: (v) async {
                store.setMatchIcon(v);
                await applyAppIcon(v ? accents[store.accentIndex] : accents.first);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _verify(BuildContext context, SearchProvider p) async {
    final base = (store.baseUrls[p.id] ?? '').isNotEmpty ? store.baseUrls[p.id]! : p.defaultBaseUrl;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VerifyScreen(siteName: p.name, homepage: Uri.parse('$base/')),
      ),
    );
    if (ok == true) store.setProviderEnabled(p.id, true); // refreshes the list
  }

  Future<void> _editMirror(BuildContext context, SearchProvider p) async {
    final c = TextEditingController(text: store.baseUrls[p.id] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${p.name} mirror'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(hintText: p.defaultBaseUrl),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Reset')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null) store.setBaseUrl(p.id, result);
  }

  Future<void> _editTrackers(BuildContext context) async {
    final c = TextEditingController(text: store.trackers.join('\n'));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trackers (one per line)'),
        content: TextField(
          controller: c,
          maxLines: 10,
          autocorrect: false,
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, defaultTrackers.join('\n')),
              child: const Text('Defaults')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null) store.setTrackers(result.split('\n'));
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600)),
      );
}
