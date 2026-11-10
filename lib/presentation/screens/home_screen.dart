import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/prelievi_provider.dart';
import '../widgets/prelievo_card.dart';
import '../widgets/storico_raggruppato_view.dart';
import '../widgets/sync_status_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go('/credits'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/app_logo.png',
                  height: 28,
                  width: 28,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _currentIndex == 0 ? 'Storico Prelievi' : 'Spunta Rientro',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Info & Credits',
            onPressed: () => context.go('/credits'),
          ),
          const SyncStatusButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: _currentIndex == 0
          ? const _StoricoTab()
          : const _SpuntaRientroTab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        elevation: 4,
        onPressed: () {
          context.go('/nuovo-prelievo');
        },
        icon: const Icon(Icons.add, size: 28),
        label: const Text(
          'NUOVO PRELIEVO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Storico',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_return_outlined),
            selectedIcon: Icon(Icons.assignment_return),
            label: 'Spunta Rientro',
          ),
        ],
      ),
    );
  }
}

class _SpuntaRientroTab extends ConsumerWidget {
  const _SpuntaRientroTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inAttesaAsync = ref.watch(prelieviInAttesaProvider);

    return inAttesaAsync.when(
      data: (prelieviRaw) {
        // Ordinamento discendente per vista spunta rientro (più recenti in alto)
        final prelievi = [...prelieviRaw]
          ..sort((a, b) => b.dataPrelievo.compareTo(a.dataPrelievo));

        if (prelievi.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nessun materiale in sospeso!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tutti i prelievi effettuati sono rientrati in magazzino.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          itemCount: prelievi.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ordinamento discendente (più recenti in alto)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        '${prelievi.length} in attesa',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final prelievo = prelievi[index - 1];
            return PrelievoCard(
              prelievo: prelievo,
              onTap: () {
                context.go('/rientro/${prelievo.id}');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text('Errore: $err'),
      ),
    );
  }
}

class _StoricoTab extends StatelessWidget {
  const _StoricoTab();

  @override
  Widget build(BuildContext context) {
    return const StoricoRaggruppatoView(bottomPadding: 88.0);
  }
}
