import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../appearance.dart';
import '../main.dart';
import '../models.dart';
import 'ios.dart';

/// Flat list row: bold name, grey details line, chevron.
class ResultTile extends StatelessWidget {
  final TorrentResult result;
  const ResultTile({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final accent = Theme.of(context).colorScheme.primary;
    const grey = TextStyle(fontSize: 14, color: Ios.secondaryLabel);
    return InkWell(
      onTap: () => showResultSheet(context, r),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Ios.separator, width: 0.5)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25)),
              const SizedBox(height: 5),
              Row(children: [
                Icon(CupertinoIcons.arrow_up, size: 13, color: accent),
                Text(r.seeders < 0 ? '?' : '${r.seeders}',
                    style: TextStyle(fontSize: 14, color: accent, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Icon(CupertinoIcons.arrow_down, size: 13, color: Ios.secondaryLabel),
                Text(r.leechers < 0 ? '?' : '${r.leechers}', style: grey),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    [formatBytes(r.sizeBytes), r.source, formatAge(r.added)]
                        .where((e) => e.isNotEmpty && e != '—')
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: grey,
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.chevron_right, size: 16, color: Ios.tertiaryLabel),
        ]),
      ),
    );
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> showResultSheet(BuildContext context, TorrentResult r) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Ios.background,
    builder: (ctx) => ListenableBuilder(
      listenable: store,
      builder: (ctx, _) {
        final magnet = r.magnet(store.trackers);
        final fav = store.isFavourite(r);
        final accent = Theme.of(ctx).colorScheme.primary;
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SelectableText(r.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.25)),
                ),
                IosSection(children: [
                  IosRow(title: 'Size', value: formatBytes(r.sizeBytes)),
                  IosRow(title: 'Seeders', value: r.seeders < 0 ? 'Unknown' : '${r.seeders}'),
                  IosRow(title: 'Leechers', value: r.leechers < 0 ? 'Unknown' : '${r.leechers}'),
                  if (r.added != null)
                    IosRow(title: 'Added', value: r.added!.toLocal().toString().split(' ').first),
                  IosRow(title: 'Source', value: r.source),
                  if (r.category != null) IosRow(title: 'Category', value: r.category!),
                ]),
                IosSection(header: 'Info hash', children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: SelectableText(r.infoHash.toUpperCase(),
                        style: const TextStyle(fontSize: 13, fontFamily: 'Courier', color: Ios.secondaryLabel)),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: FilledButton.icon(
                    icon: const Icon(CupertinoIcons.arrow_down_circle_fill),
                    label: const Text('Open in torrent app'),
                    onPressed: () async {
                      bool ok = false;
                      try {
                        ok = await launchUrl(Uri.parse(magnet), mode: LaunchMode.externalApplication);
                      } catch (_) {}
                      if (!ok && ctx.mounted) {
                        await Clipboard.setData(ClipboardData(text: magnet));
                        if (ctx.mounted) _toast(ctx, 'No torrent app found — magnet link copied');
                      }
                    },
                  ),
                ),
                IosSection(children: [
                  IosRow(
                    title: 'Copy magnet link',
                    leading: Icon(CupertinoIcons.doc_on_doc, color: accent, size: 22),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: magnet));
                      if (ctx.mounted) _toast(ctx, 'Magnet link copied');
                    },
                  ),
                  IosRow(
                    title: 'Share',
                    leading: Icon(CupertinoIcons.share, color: accent, size: 22),
                    onTap: () => Share.share(magnet, subject: r.name),
                  ),
                  IosRow(
                    title: fav ? 'Remove from Saved' : 'Save',
                    leading: Icon(fav ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                        color: accent, size: 22),
                    onTap: () => store.toggleFavourite(r),
                  ),
                  if (r.pageUrl != null)
                    IosRow(
                      title: 'Open source page',
                      leading: Icon(CupertinoIcons.globe, color: accent, size: 22),
                      chevron: true,
                      onTap: () => launchUrl(Uri.parse(r.pageUrl!), mode: LaunchMode.externalApplication),
                    ),
                ]),
              ],
            ),
          ),
        );
      },
    ),
  );
}
