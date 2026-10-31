import 'package:flutter/material.dart';

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
                    if (p.note != null) p.note!,
                    (store.baseUrls[p.id] ?? '').isNotEmpty
                        ? store.baseUrls[p.id]!
                        : (p.needsSetup ? 'Not set up — tap ✎ to add' : p.defaultBaseUrl),
                  ].join('\n'),
                  style: const TextStyle(color: Colors.white54),
                ),
                isThreeLine: p.note != null,
                value: store.enabledProviders.contains(p.id),
                onChanged: (v) => store.setProviderEnabled(p.id, v),
                secondary: IconButton(
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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
