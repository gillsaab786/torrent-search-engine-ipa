import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../appearance.dart';
import '../main.dart';
import '../widgets/ios.dart';
import '../widgets/result_tile.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => CustomScrollView(slivers: [
          const SliverToBoxAdapter(child: LargeTitle('Saved')),
          const SliverToBoxAdapter(
            child: Divider(height: 0.5, thickness: 0.5, color: Ios.separator),
          ),
          if (store.favourites.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(CupertinoIcons.bookmark, size: 44, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                const Text('Nothing saved yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Tap Save on any result to keep it here.',
                    style: TextStyle(color: Ios.secondaryLabel, fontSize: 15)),
              ]),
            )
          else
            SliverList.builder(
              itemCount: store.favourites.length,
              itemBuilder: (_, i) {
                final r = store.favourites[i];
                return Dismissible(
                  key: ValueKey(r.infoHash),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: const Color(0xFFFF453A),
                    child: const Icon(CupertinoIcons.trash, color: Colors.white),
                  ),
                  onDismissed: (_) => store.toggleFavourite(r),
                  child: ResultTile(result: r),
                );
              },
            ),
        ]),
      ),
    );
  }
}
