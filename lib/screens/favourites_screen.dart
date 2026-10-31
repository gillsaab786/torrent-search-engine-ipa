import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/result_tile.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.favourites.isEmpty) {
            return const Center(
              child: Text('Tap Save on any result to keep it here.',
                  style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView.builder(
            itemCount: store.favourites.length,
            itemBuilder: (_, i) {
              final r = store.favourites[i];
              return Dismissible(
                key: ValueKey(r.infoHash),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: const Color(0x33FF6B6B),
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => store.toggleFavourite(r),
                child: ResultTile(result: r),
              );
            },
          );
        },
      ),
    );
  }
}
