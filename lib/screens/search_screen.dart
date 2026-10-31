import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../cloudflare.dart';
import '../main.dart';
import '../models.dart';
import '../providers.dart';
import '../widgets/result_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  Category _category = Category.all;
  bool _loading = false;
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
      _lastQuery = query;
      _errors = [];
    });
    final outcomes = await searchAll(
      query: query,
      category: _category,
      enabledIds: store.enabledProviders,
      baseUrls: store.baseUrls,
    );
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
          .map((o) => '${o.provider.name} unavailable')
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

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    }
    if (!_speechReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Voice search unavailable — allow Microphone and Speech Recognition in iOS Settings'),
            behavior: SnackBarBehavior.floating));
      }
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(onResult: (r) {
      _controller.text = r.recognizedWords;
      if (r.finalResult) {
        setState(() => _listening = false);
        _search();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final visible = _visible;
          final sources = _results.map((r) => r.source).toSet().toList()..sort();
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(child: _searchBar()),
              SliverToBoxAdapter(child: _categoryChips()),
              if (_lastQuery == null || _controller.text.isEmpty && !_loading)
                ..._historySlivers()
              else if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                SliverToBoxAdapter(child: _resultsHeader(visible.length, sources)),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        _errors.isNotEmpty && _results.isEmpty
                            ? 'Sources unreachable.\nTry again, or set a mirror in Settings.'
                            : 'No results',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54),
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
          );
        },
      ),
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: _listening ? 'Listening…' : 'Search torrents',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _controller.clear()),
                  ),
                IconButton(
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none,
                      color: _listening ? Theme.of(context).colorScheme.primary : null),
                  onPressed: _toggleVoice,
                ),
              ],
            ),
            filled: true,
            fillColor: const Color(0xFF151A21),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  Widget _categoryChips() => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            for (final c in Category.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c.label),
                  selected: _category == c,
                  onSelected: (_) {
                    setState(() => _category = c);
                    if (_lastQuery != null && _controller.text.isNotEmpty) _search();
                  },
                ),
              ),
          ],
        ),
      );

  Widget _resultsHeader(int count, List<String> sources) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('$count results', style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              PopupMenuButton<SortMode>(
                tooltip: 'Sort',
                initialValue: store.sort,
                onSelected: store.setSort,
                itemBuilder: (_) => [
                  for (final s in SortMode.values)
                    PopupMenuItem(value: s, child: Text(s.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    const Icon(Icons.sort, size: 18),
                    const SizedBox(width: 4),
                    Text(store.sort.label),
                  ]),
                ),
              ),
            ]),
            if (sources.length > 1)
              Wrap(spacing: 6, children: [
                for (final s in sources)
                  FilterChip(
                    label: Text(s),
                    selected: _sourceFilter.contains(s),
                    onSelected: (on) => setState(() =>
                        on ? _sourceFilter.add(s) : _sourceFilter.remove(s)),
                  ),
              ]),
            if (_needsVerify.isNotEmpty) _verifyBanner(),
            if (_errors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_errors.join(' · '),
                    style: const TextStyle(color: Color(0xFFFFB86B), fontSize: 12)),
              ),
          ],
        ),
      );

  Widget _verifyBanner() {
    final names = _needsVerify.map((o) => o.provider.name).join(', ');
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 12, 2),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2230),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.shield_outlined, size: 20, color: Color(0xFFFFB86B)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${_needsVerify.length} more source${_needsVerify.length == 1 ? '' : 's'} need a one-time check: $names',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        TextButton(onPressed: _verifyAll, child: const Text('Verify')),
      ]),
    );
  }

  Future<void> _verifyAll() async {
    var any = false;
    for (final o in List.of(_needsVerify)) {
      if (!mounted) return;
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              VerifyScreen(siteName: o.provider.name, homepage: o.challenge!.homepage),
        ),
      );
      if (ok == true) {
        any = true;
      } else {
        break; // user closed the screen: stop asking
      }
    }
    if (any && mounted) _search(_lastQuery);
  }

  List<Widget> _historySlivers() {
    if (store.history.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text('Search movies, shows, music, apps and more.\nNo ads, everything unlocked.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(children: [
            const Text('Recent searches', style: TextStyle(color: Colors.white70)),
            const Spacer(),
            TextButton(onPressed: store.clearHistory, child: const Text('Clear')),
          ]),
        ),
      ),
      SliverList.builder(
        itemCount: store.history.length,
        itemBuilder: (_, i) {
          final q = store.history[i];
          return ListTile(
            leading: const Icon(Icons.history, color: Colors.white38),
            title: Text(q),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.white38),
              onPressed: () => store.removeHistory(q),
            ),
            onTap: () => _search(q),
          );
        },
      ),
    ];
  }
}
