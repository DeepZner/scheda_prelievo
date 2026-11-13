import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import '../providers/prelievi_provider.dart';
import 'prelievo_card.dart';
import 'purge_schede_annullate_sheet.dart';

/// Vista Storico con ordinamento ascendente (dal più vecchio al più recente)
/// e raggruppamento visuale per stato del prelievo.
class StoricoRaggruppatoView extends ConsumerStatefulWidget {
  final double bottomPadding;

  const StoricoRaggruppatoView({
    super.key,
    this.bottomPadding = 88.0,
  });

  @override
  ConsumerState<StoricoRaggruppatoView> createState() =>
      _StoricoRaggruppatoViewState();
}

class _StoricoRaggruppatoViewState
    extends ConsumerState<StoricoRaggruppatoView> {
  StatoPrelievo? _filtroStato; // null = Tutti
  final Set<StatoPrelievo> _sezioniAperte = {
    StatoPrelievo.inAttesa,
    StatoPrelievo.mancante,
    StatoPrelievo.rientrato,
  };

  @override
  Widget build(BuildContext context) {
    final storicoAsync = ref.watch(storicoRaggruppatoProvider);

    return storicoAsync.when(
      data: (groupedMap) {
        final totalPrelievi =
            groupedMap.values.fold<int>(0, (sum, list) => sum + list.length);

        if (totalPrelievi == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nessun prelievo registrato',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Le schede di prelievo create o sincronizzate appariranno qui nello storico.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        // Filtra i gruppi in base all'eventuale selezione del filtro
        final Map<StatoPrelievo, List<Prelievo>> gruppiDaMostrare = {};
        for (final entry in groupedMap.entries) {
          if (_filtroStato == null || _filtroStato == entry.key) {
            if (entry.value.isNotEmpty) {
              gruppiDaMostrare[entry.key] = entry.value;
            }
          }
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPadding),
          children: [
            // Barra di filtro rapido per stato
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.apps_rounded, size: 16),
                    label: Text('Tutti ($totalPrelievi)'),
                    selected: _filtroStato == null,
                    onSelected: (selected) {
                      if (selected) setState(() => _filtroStato = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ...StatoPrelievo.values.map((stato) {
                    final count = groupedMap[stato]?.length ?? 0;
                    final isSelected = _filtroStato == stato;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          _iconaPerStato(stato),
                          size: 16,
                          color: isSelected ? Colors.white : _coloreIconaStato(stato),
                        ),
                        selectedColor: _coloreBadgeStato(stato),
                        label: Text(
                          '${stato.label} ($count)',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _filtroStato = selected ? stato : null;
                            if (selected) {
                              _sezioniAperte.add(stato);
                            }
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Sottotitolo informativo ordinamento + Toggle rapido Espandi/Comprimi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.sort_by_alpha, size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Data crescente per stato',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() {
                        if (_sezioniAperte.length >= gruppiDaMostrare.keys.length &&
                            gruppiDaMostrare.keys.every((k) => _sezioniAperte.contains(k))) {
                          _sezioniAperte.clear();
                        } else {
                          _sezioniAperte.addAll(gruppiDaMostrare.keys);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _sezioniAperte.length >= gruppiDaMostrare.keys.length &&
                                    gruppiDaMostrare.keys.every((k) => _sezioniAperte.contains(k))
                                ? Icons.unfold_less_rounded
                                : Icons.unfold_more_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _sezioniAperte.length >= gruppiDaMostrare.keys.length &&
                                    gruppiDaMostrare.keys.every((k) => _sezioniAperte.contains(k))
                                ? 'Comprimi tutti'
                                : 'Espandi tutti',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            if (gruppiDaMostrare.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Nessun prelievo con stato "${_filtroStato?.label}".',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ...gruppiDaMostrare.entries.expand((entry) {
                final stato = entry.key;
                final prelieviDelGruppo = entry.value;
                final isExpanded = _sezioniAperte.contains(stato);

                return [
                  // Intestazione Sezione di Stato (Accordion Interattivo)
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    decoration: BoxDecoration(
                      color: _coloreSfondoSezione(stato),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _coloreBordoSezione(stato),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _sezioniAperte.remove(stato);
                            } else {
                              _sezioniAperte.add(stato);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _iconaPerStato(stato),
                                size: 20,
                                color: _coloreIconaStato(stato),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${stato.label.toUpperCase()} (${prelieviDelGruppo.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: _coloreTestoSezione(stato),
                                  ),
                                ),
                              ),
                              if (stato == StatoPrelievo.annullato &&
                                  prelieviDelGruppo.isNotEmpty) ...[
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    PurgeSchedeAnnullateSheet.mostra(
                                      context,
                                      prelievi: prelieviDelGruppo,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.delete_forever_rounded,
                                          size: 15,
                                          color: Colors.red.shade800,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Svuota (${prelieviDelGruppo.length})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 22,
                                color: _coloreTestoSezione(stato),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Schede dei prelievi appartenenti a questo stato (visibili solo se la sezione è aperta)
                  if (isExpanded)
                    ...prelieviDelGruppo.map((p) {
                      return PrelievoCard(
                        prelievo: p,
                        isCompact: true,
                        onTap: () {
                          context.go('/prelievo/${p.id}');
                        },
                      );
                    }),
                ];
              }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text('Errore nel caricamento storico: $err'),
      ),
    );
  }

  IconData _iconaPerStato(StatoPrelievo stato) {
    switch (stato) {
      case StatoPrelievo.inAttesa:
        return Icons.hourglass_top_rounded;
      case StatoPrelievo.rientrato:
        return Icons.check_circle_rounded;
      case StatoPrelievo.mancante:
        return Icons.warning_amber_rounded;
      case StatoPrelievo.annullato:
        return Icons.cancel_outlined;
    }
  }

  Color _coloreIconaStato(StatoPrelievo stato) {
    switch (stato) {
      case StatoPrelievo.inAttesa:
        return Colors.orange.shade800;
      case StatoPrelievo.rientrato:
        return Colors.green.shade800;
      case StatoPrelievo.mancante:
        return Colors.deepOrange.shade800;
      case StatoPrelievo.annullato:
        return Colors.grey.shade700;
    }
  }

  Color _coloreBadgeStato(StatoPrelievo stato) {
    switch (stato) {
      case StatoPrelievo.inAttesa:
        return Colors.orange.shade800;
      case StatoPrelievo.rientrato:
        return Colors.green.shade700;
      case StatoPrelievo.mancante:
        return Colors.deepOrange.shade800;
      case StatoPrelievo.annullato:
        return Colors.grey.shade700;
    }
  }

  Color _coloreSfondoSezione(StatoPrelievo stato) {
    switch (stato) {
      case StatoPrelievo.inAttesa:
        return Colors.orange.shade50;
      case StatoPrelievo.rientrato:
        return Colors.green.shade50;
      case StatoPrelievo.mancante:
        return Colors.deepOrange.shade50;
      case StatoPrelievo.annullato:
        return Colors.grey.shade100;
    }
  }

  Color _coloreBordoSezione(StatoPrelievo stato) {
    switch (stato) {
      case StatoPrelievo.inAttesa:
        return Colors.orange.shade300;
      case StatoPrelievo.rientrato:
        return Colors.green.shade300;
      case StatoPrelievo.mancante:
        return Colors.deepOrange.shade300;
      case StatoPrelievo.annullato:
        return Colors.grey.shade300;
    }
  }

  Color _coloreTestoSezione(StatoPrelievo stato) {
    switch (stato) {
      case StatoPrelievo.inAttesa:
        return Colors.orange.shade900;
      case StatoPrelievo.rientrato:
        return Colors.green.shade900;
      case StatoPrelievo.mancante:
        return Colors.deepOrange.shade900;
      case StatoPrelievo.annullato:
        return Colors.grey.shade800;
    }
  }
}
