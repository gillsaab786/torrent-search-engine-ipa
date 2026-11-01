import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../appearance.dart';
import '../cloudflare.dart';
import '../main.dart';
import '../models.dart';
import '../providers.dart';
import '../widgets/ios.dart';
import '../widgets/result_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  Category _category = Category.all;
  bool _loading = false;
  int _done = 0, _total = 0;
  String? _lastQuery;
  List<TorrentResult> _results = [];
  List<String> _errors = [];
  List<ProviderOutcome> _needsVerify = [];
  Set<String> _sourceFilter = {};

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search([String? q]) async {
    final query = (q ?? _controller.text).trim();
    if (query.isEmpty) return;
    _controller.text = query;
    _focus.unfocus();
    store.addHistory(query);
    setState(() {
      _loading = true;
      _done = 0;
      _total = 0;
      _lastQuery = query;
      _errors = [];
    });
    final outcomes = await searchAll(
      query: query,
      category: _category,
      enabledIds: store.enabledProviders,
      baseUrls: store.baseUrls,
      onProgress: (d, t) {
        if (mounted) setState(() => (_done, _total) = (d, t));
      },
    );
    if (!mounted) return;
    // Let the ring reach 100% before the results appear.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    // De-duplicate by info hash, keeping the entry with most seeders.
    final byHash = <String, TorrentResult>{};
    for (final o in outcomes) {
      for (final r in o.results) {
        final k = r.infoHash.toLowerCase();
        final existing = byHash[k];
        if (existing == null || r.seeders > existing.seeders) byHash[k] = r;
      }
    }
    setState(() {
      _loading = false;
      _results = byHash.values.toList();
      _needsVerify = outcomes.where((o) => o.challenge != null).toList();
      _errors = outcomes
          .where((o) => o.error != null && o.challenge == null)
          .map((o) => '${o.provider.name}: ${o.error}')
          .toList();
      _sourceFilter = {};
    });
  }

  List<TorrentResult> get _visible {
    final list = _results
        .where((r) => r.seeders < 0 || r.seeders >= store.minSeeders)
        .where((r) => _sourceFilter.isEmpty || _sourceFilter.contains(r.source))
        .toList();
    switch (store.sort) {
      case SortMode.seeders:
        list.sort((a, b) => b.seeders.compareTo(a.seeders));
      case SortMode.size:
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case SortMode.newest:
        list.sort((a, b) => (b.added ?? DateTime(1970)).compareTo(a.added ?? DateTime(1970)));
      case SortMode.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final visible = _visible;
          final sources = _results.map((r) => r.source).toSet().toList()..sort();
          final showHistory = _lastQuery == null || (_controller.text.isEmpty && !_loading);
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: showHistory
                ? null
                : (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v.abs() < 250) return;
                    final dir = v < 0 ? 1 : -1;
                    // After the last category, keep going to the next tab.
                    if (!_switchCategory(dir)) swipeTabs?.call(dir, v);
                  },
            child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: LargeTitle('Search', actions: [
                  if (!showHistory && !_loading)
                    PopupMenuButton<SortMode>(
                      tooltip: 'Sort',
                      initialValue: store.sort,
                      onSelected: store.setSort,
                      icon: Icon(CupertinoIcons.sort_down, color: accent, size: 26),
                      itemBuilder: (_) => [
                        for (final s in SortMode.values)
                          PopupMenuItem(
                            value: s,
                            child: Row(children: [
                              Expanded(child: Text(s.label)),
                              if (s == store.sort) Icon(CupertinoIcons.checkmark, size: 18, color: accent),
                            ]),
                          ),
                      ],
                    ),
                ]),
              ),
              SliverToBoxAdapter(child: _searchBar(accent)),
              SliverToBoxAdapter(
                child: PillTabs<Category>(
                  items: Category.values,
                  selected: _category,
                  label: (c) => c.label,
                  onSelected: (c) {
                    setState(() => _category = c);
                    if (_lastQuery != null && _controller.text.isNotEmpty) _search();
                  },
                ),
              ),
              const SliverToBoxAdapter(
                child: Divider(height: 0.5, thickness: 0.5, color: Ios.separator),
              ),
              if (showHistory)
                ..._historySlivers(accent)
              else if (_loading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: SearchProgress(done: _done, total: _total, accent: accent)),
                )
              else ...[
                SliverToBoxAdapter(child: _resultsHeader(visible.length, sources, accent)),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        _errors.isNotEmpty && _results.isEmpty
                            ? 'Sources unreachable.\nTry again, or set a mirror in Settings.'
                            : 'No results',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Ios.secondaryLabel, fontSize: 16),
                      ),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) => ResultTile(result: visible[i]),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
          );
        },
      ),
    );
  }

  bool _switchCategory(int step) {
    final i = Category.values.indexOf(_category) + step;
    if (i < 0 || i >= Category.values.length) return false;
    HapticFeedback.selectionClick();
    setState(() => _category = Category.values[i]);
    if (_lastQuery != null && _controller.text.isNotEmpty) _search();
    return true;
  }

  Widget _searchBar(Color accent) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: CupertinoSearchTextField(
          controller: _controller,
          focusNode: _focus,
          placeholder: 'Search torrents',
          style: const TextStyle(color: Colors.white, fontSize: 17),
          backgroundColor: Ios.fill,
          itemColor: Ios.secondaryLabel,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          onSubmitted: (_) => _search(),
          onChanged: (_) => setState(() {}),
          onSuffixTap: () => setState(() => _controller.clear()),
          suffixMode: OverlayVisibilityMode.editing,
          suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill),
        ),
      );

  Widget _resultsHeader(int count, List<String> sources, Color accent) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count results · ${store.sort.label}',
                style: const TextStyle(color: Ios.secondaryLabel, fontSize: 13)),
            if (sources.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final s in sources)
                    GestureDetector(
                      onTap: () => setState(() =>
                          _sourceFilter.contains(s) ? _sourceFilter.remove(s) : _sourceFilter.add(s)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _sourceFilter.contains(s) ? accent : Ios.fill,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(s,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _sourceFilter.contains(s) ? onAccent(accent) : Colors.white)),
                      ),
                    ),
                ]),
              ),
            if (_needsVerify.isNotEmpty) _verifyBanner(accent),
            if (_errors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_errors.join(' · '),
                    style: const TextStyle(color: Ios.tertiaryLabel, fontSize: 12)),
              ),
          ],
        ),
      );

  Widget _verifyBanner(Color accent) {
    final names = _needsVerify.map((o) => o.provider.name).join(', ');
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(color: Ios.grouped, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(CupertinoIcons.shield_lefthalf_fill, size: 22, color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${_needsVerify.length} more source${_needsVerify.length == 1 ? '' : 's'} need a one-time check\n$names',
            style: const TextStyle(fontSize: 13, color: Ios.secondaryLabel),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          onPressed: _verifyAll,
          child: Text('Verify', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Future<void> _verifyAll() async {
    var any = false;
    for (final o in List.of(_needsVerify)) {
      if (!mounted) return;
      final worked = await Navigator.push<Uri?>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => VerifyScreen(
            siteName: o.provider.name,
            candidates: [
              o.challenge!.homepage,
              ...verifyCandidates(o.provider, store.baseUrls)
                  .where((u) => u.host != o.challenge!.homepage.host),
            ],
          ),
        ),
      );
      if (worked != null) {
        if (!o.provider.isCustom && worked.origin != o.provider.defaultBaseUrl) {
          store.setBaseUrl(o.provider.id, worked.origin);
        }
        any = true;
      } else {
        break; // user closed the screen: stop asking
      }
    }
    if (any && mounted) _search(_lastQuery);
  }

  List<Widget> _historySlivers(Color accent) {
    if (store.history.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text('Search movies, shows, music, apps and more.\nNo ads, everything unlocked.',
                textAlign: TextAlign.center, style: TextStyle(color: Ios.secondaryLabel, fontSize: 16)),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
          child: Row(children: [
            const Text('Recent', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const Spacer(),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: store.clearHistory,
              child: Text('Clear', style: TextStyle(color: accent)),
            ),
          ]),
        ),
      ),
      SliverList.builder(
        itemCount: store.history.length,
        itemBuilder: (_, i) {
          final q = store.history[i];
          return Dismissible(
            key: ValueKey('history-$q'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 22),
              color: const Color(0xFFFF453A),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.trash, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
            onDismissed: (_) => store.removeHistory(q),
            child: InkWell(
            onTap: () => _search(q),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 4, 13),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Ios.separator, width: 0.5)),
              ),
              child: Row(children: [
                const Icon(CupertinoIcons.clock, size: 18, color: Ios.secondaryLabel),
                const SizedBox(width: 12),
                Expanded(child: Text(q, style: const TextStyle(fontSize: 17))),
                GestureDetector(
                  onTap: () => store.removeHistory(q),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(CupertinoIcons.xmark, size: 16, color: Ios.tertiaryLabel),
                  ),
                ),
              ]),
            ),
          ),
          );
        },
      ),
    ];
  }
}

/// Ring that fills from 0 to 100% as sources answer, in the app colour.
class SearchProgress extends StatelessWidget {
  final int done, total;
  final Color accent;
  const SearchProgress({super.key, required this.done, required this.total, required this.accent});

  @override
  Widget build(BuildContext context) {
    final target = total == 0 ? 0.0 : done / total;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => SizedBox(
          width: 132,
          height: 132,
          child: CustomPaint(
            painter: _RingPainter(v, accent),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${(v * 100).round()}',
                    style: const TextStyle(
                        fontSize: 38, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7, left: 1),
                  child: Text('%', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: accent)),
                ),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(total == 0 ? 'Starting search…' : 'Searched $done of $total sources',
          style: const TextStyle(fontSize: 14, color: Ios.secondaryLabel)),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color accent;
  _RingPainter(this.value, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, 6.2832, false,
        Paint()
          ..color = Ios.fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    if (value <= 0) return;
    // Accent shades along the arc: a lighter tint fading into the full colour.
    final light = Color.lerp(accent, Colors.white, 0.45)!;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 6.2832,
        colors: [light, accent, accent],
        stops: const [0, 0.6, 1],
        transform: const GradientRotation(-1.5708),
      ).createShader(rect);
    canvas.drawArc(r, -1.5708, 6.2832 * value.clamp(0.0, 1.0), false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.accent != accent;
}
