import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/prelievi_provider.dart';
import '../widgets/stato_badge.dart';

class StoricoPrelieviScreen extends ConsumerWidget {
  const StoricoPrelieviScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tuttiAsync = ref.watch(prelieviListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storico Prelievi'),
      ),
      body: tuttiAsync.when(
        data: (prelievi) {
          if (prelievi.isEmpty) {
            return const Center(child: Text('Nessun prelievo registrato.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prelievi.length,
            itemBuilder: (context, index) {
              final p = prelievi[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  title: Text(
                    p.luogoGrotta,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Resp: ${p.responsabile}'),
                  trailing: StatoBadge(stato: p.stato),
                  onTap: () {
                    context.go('/prelievo/${p.id}');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Errore: $e')),
      ),
    );
  }
}
