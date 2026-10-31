import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models.dart';

class ResultTile extends StatelessWidget {
  final TorrentResult result;
  const ResultTile({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showResultSheet(context, r),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Stat(icon: Icons.arrow_upward, value: '${r.seeders}', color: const Color(0xFF2EE6A6)),
                  const SizedBox(width: 12),
                  _Stat(icon: Icons.arrow_downward, value: '${r.leechers}', color: const Color(0xFFFF6B6B)),
                  const SizedBox(width: 12),
                  Text(formatBytes(r.sizeBytes), style: muted),
                  const Spacer(),
                  Text([r.source, formatAge(r.added)].where((e) => e.isNotEmpty).join(' · '),
                      style: muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _Stat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      );
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

Future<void> showResultSheet(BuildContext context, TorrentResult r) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF12161C),
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: store,
      builder: (ctx, _) {
        final magnet = r.magnet(store.trackers);
        final fav = store.isFavourite(r);
        Widget row(String k, String v) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 90, child: Text(k, style: const TextStyle(color: Colors.white54))),
                Expanded(child: SelectableText(v)),
              ]),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                row('Size', formatBytes(r.sizeBytes)),
                row('Seeders', '${r.seeders}'),
                row('Leechers', '${r.leechers}'),
                if (r.added != null) row('Added', r.added!.toLocal().toString().split('.').first),
                row('Source', r.source),
                if (r.category != null) row('Category', r.category!),
                row('Hash', r.infoHash.toUpperCase()),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in torrent app'),
                    onPressed: () async {
                      bool ok = false;
                      try {
                        ok = await launchUrl(Uri.parse(magnet),
                            mode: LaunchMode.externalApplication);
                      } catch (_) {}
                      if (!ok && ctx.mounted) {
                        await Clipboard.setData(ClipboardData(text: magnet));
                        if (ctx.mounted) {
                          _toast(ctx, 'No torrent app found — magnet link copied instead');
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: magnet));
                        if (ctx.mounted) _toast(ctx, 'Magnet link copied');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('Share'),
                      onPressed: () => Share.share(magnet, subject: r.name),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(fav ? Icons.bookmark : Icons.bookmark_border, size: 18),
                      label: Text(fav ? 'Saved' : 'Save'),
                      onPressed: () => store.toggleFavourite(r),
                    ),
                  ),
                ]),
                if (r.pageUrl != null) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.public, size: 18),
                    label: const Text('Open source page'),
                    onPressed: () => launchUrl(Uri.parse(r.pageUrl!),
                        mode: LaunchMode.externalApplication),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
