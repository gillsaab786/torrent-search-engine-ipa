import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../appearance.dart';
import '../cloudflare.dart';
import '../main.dart';
import '../providers.dart';
import '../widgets/ios.dart';
import 'add_source_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _status(SearchProvider p) {
    final custom = (store.baseUrls[p.id] ?? '').isNotEmpty ? store.baseUrls[p.id]! : null;
    if (p.usesCloudflare) {
      final host = Uri.parse(custom ?? p.defaultBaseUrl).host;
      return CloudflareSession.instance.isVerified(host) ? 'Verified ✓' : 'Needs a one-time Verify';
    }
    if (p.needsSetup && custom == null) return 'Not set up — tap to add your server';
    if (p.isCustom) return 'Added by you · ${Uri.parse(p.defaultBaseUrl).host}';
    return custom ?? p.note ?? Uri.parse(p.defaultBaseUrl).host;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          children: [
            const LargeTitle('Settings'),
            const SizedBox(height: 8),
            IosSection(
              header: 'Sources · ${store.enabledProviders.length} of ${allProviders.length} on',
              footer: 'Tap a source for options. Cloudflare sources need a one-time Verify.',
              children: [
                for (final p in allProviders)
                  IosRow(
                    title: p.name,
                    subtitle: _status(p),
                    onTap: () => _sourceOptions(context, p),
                    trailing: IosSwitch(
                      value: store.enabledProviders.contains(p.id),
                      onChanged: (v) => store.setProviderEnabled(p.id, v),
                    ),
                  ),
                IosRow(
                  title: 'Add source…',
                  leading: Icon(CupertinoIcons.plus_circle_fill,
                      color: Theme.of(context).colorScheme.primary, size: 22),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AddSourceScreen()),
                  ),
                ),
              ],
            ),
            IosSection(
              header: 'Network',
              footer: 'Looks up sites over encrypted DNS (Cloudflare / Google) instead of your '
                  "network's own, which helps when sources show as blocked or offline. Falls back automatically.",
              children: [
                IosRow(
                  title: 'Encrypted DNS',
                  trailing: IosSwitch(value: store.encryptedDns, onChanged: store.setEncryptedDns),
                ),
              ],
            ),
            IosSection(header: 'Results', children: [
              IosRow(title: 'Minimum seeders', value: '${store.minSeeders}'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Slider(
                  value: store.minSeeders.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (v) => store.setMinSeeders(v.round()),
                ),
              ),
              IosRow(
                title: 'Save search history',
                trailing: IosSwitch(value: store.saveHistory, onChanged: store.setSaveHistory),
              ),
              IosRow(
                title: 'Clear search history',
                destructive: true,
                onTap: () {
                  store.clearHistory();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('History cleared')));
                },
              ),
            ]),
            IosSection(header: 'Magnet links', children: [
              IosRow(
                title: 'Trackers',
                value: '${store.trackers.length}',
                chevron: true,
                onTap: () => _editTrackers(context),
              ),
            ]),
            const IosSection(
              header: 'About',
              footer: 'No ads. All features included. Results come from public indexes; '
                  'you are responsible for what you download.',
              children: [IosRow(title: 'Torrent Search Engine', value: '1.0')],
            ),
            IosSection(
              header: 'Appearance',
              footer: 'One colour tints the whole app. With Match app icon on, the '
                  'home-screen icon changes too — iOS will confirm the change.',
              children: [
                AccentPicker(
                  selected: store.accentIndex,
                  onSelected: (i) async {
                    store.setAccent(i);
                    if (store.matchIcon) await applyAppIcon(accents[i]);
                  },
                ),
                IosRow(
                  title: 'Match app icon',
                  trailing: IosSwitch(
                    value: store.matchIcon,
                    onChanged: (v) async {
                      store.setMatchIcon(v);
                      await applyAppIcon(v ? accents[store.accentIndex] : accents.first);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _sourceOptions(BuildContext context, SearchProvider p) async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(p.name),
        message: Text(_status(p)),
        actions: [
          if (p.usesCloudflare || p.isCustom)
            CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx, 'verify'), child: const Text('Verify now')),
          if (!p.isCustom)
            CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx, 'mirror'),
                child: Text(p.needsSetup ? 'Set server URL' : 'Set mirror URL')),
          if (p.isCustom)
            CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: const Text('Delete source')),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'verify') await _verify(context, p);
    if (choice == 'mirror') await _editMirror(context, p);
    if (choice == 'delete') store.removeCustomSource(p.id);
  }

  Future<void> _verify(BuildContext context, SearchProvider p) async {
    final worked = await Navigator.push<Uri?>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VerifyScreen(siteName: p.name, candidates: verifyCandidates(p, store.baseUrls)),
      ),
    );
    if (worked == null) return;
    if (!p.isCustom && worked.origin != p.defaultBaseUrl) store.setBaseUrl(p.id, worked.origin);
    store.setProviderEnabled(p.id, true); // also refreshes the list
  }

  Future<void> _editMirror(BuildContext context, SearchProvider p) async {
    final c = TextEditingController(text: store.baseUrls[p.id] ?? '');
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(p.needsSetup ? '${p.name} server' : '${p.name} mirror'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: c,
            keyboardType: TextInputType.url,
            autocorrect: false,
            placeholder: p.defaultBaseUrl.isEmpty ? 'Feed URL with API key' : p.defaultBaseUrl,
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Reset')),
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null) store.setBaseUrl(p.id, result);
  }

  Future<void> _editTrackers(BuildContext context) async {
    final c = TextEditingController(text: store.trackers.join('\n'));
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Trackers'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: c,
            maxLines: 8,
            autocorrect: false,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            placeholder: 'One tracker per line',
          ),
        ),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, defaultTrackers.join('\n')),
              child: const Text('Defaults')),
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null) store.setTrackers(result.split('\n'));
  }
}
