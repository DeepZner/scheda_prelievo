import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import '../providers/prelievi_provider.dart';
import '../widgets/stato_badge.dart';
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
        title: Text(
          _currentIndex == 0 ? 'Spunta Rientro' : 'Storico Prelievi',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: const [
          SyncStatusButton(),
          SizedBox(width: 8),
        ],
      ),
      body: _currentIndex == 0
          ? const _SpuntaRientroTab()
          : const _StoricoTab(),
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
            icon: Icon(Icons.assignment_return_outlined),
            selectedIcon: Icon(Icons.assignment_return),
            label: 'Spunta Rientro',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Storico',
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
      data: (prelievi) {
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: prelievi.length,
          itemBuilder: (context, index) {
            final prelievo = prelievi[index];
            return _PrelievoCard(
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

class _StoricoTab extends ConsumerWidget {
  const _StoricoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tuttiAsync = ref.watch(prelieviListProvider);

    return tuttiAsync.when(
      data: (prelievi) {
        if (prelievi.isEmpty) {
          return const Center(
            child: Text('Nessun prelievo registrato.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: prelievi.length,
          itemBuilder: (context, index) {
            final prelievo = prelievi[index];
            return _PrelievoCard(
              prelievo: prelievo,
              onTap: () {
                context.go('/prelievo/${prelievo.id}');
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

class _PrelievoCard extends StatelessWidget {
  final Prelievo prelievo;
  final VoidCallback onTap;

  const _PrelievoCard({
    required this.prelievo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totMetri = prelievo.dettagli
        .where((d) => d.isMetri)
        .fold<int>(0, (sum, d) => sum + d.quantitaPrelevata);
    final totPezzi = prelievo.dettagli
        .where((d) => !d.isMetri)
        .fold<int>(0, (sum, d) => sum + d.quantitaPrelevata);
    final infoMateriali = [
      if (totMetri > 0) '$totMetri m corde',
      if (totPezzi > 0) '$totPezzi pz attrezzature',
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      prelievo.luogoGrotta,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration:
                            prelievo.stato == StatoPrelievo.annullato
                                ? TextDecoration.lineThrough
                                : null,
                        color: prelievo.stato == StatoPrelievo.annullato
                            ? Colors.grey.shade600
                            : null,
                      ),
                    ),
                  ),
                  StatoBadge(stato: prelievo.stato),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    prelievo.responsabile,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${prelievo.dataPrelievo.day.toString().padLeft(2, '0')}/${prelievo.dataPrelievo.month.toString().padLeft(2, '0')}/${prelievo.dataPrelievo.year}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (prelievo.haSpuntaInCorso) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending_actions_rounded,
                          size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Text(
                        'Spunta in corso (${prelievo.articoliSpuntatiCount}/${prelievo.dettagli.length} articoli)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    infoMateriali.isNotEmpty
                        ? infoMateriali
                        : '${prelievo.dettagli.length} materiali',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: totMetri > 0
                          ? Colors.deepOrange.shade900
                          : Colors.grey.shade800,
                    ),
                  ),
                  Row(
                    children: const [
                      Text(
                        'Dettagli',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.deepOrange,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
