import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_helper.dart';
import '../../domain/models/dettaglio_prelievo.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import '../providers/prelievi_provider.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/stato_badge.dart';

class RientroMaterialeScreen extends ConsumerStatefulWidget {
  final String? initialPrelievoId;

  const RientroMaterialeScreen({
    super.key,
    this.initialPrelievoId,
  });

  @override
  ConsumerState<RientroMaterialeScreen> createState() =>
      _RientroMaterialeScreenState();
}

class _RientroMaterialeScreenState
    extends ConsumerState<RientroMaterialeScreen> {
  String? _selectedPrelievoId;
  final GlobalKey<_DettagliListViewState> _dettagliKey =
      GlobalKey<_DettagliListViewState>();

  @override
  void initState() {
    super.initState();
    _selectedPrelievoId = widget.initialPrelievoId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inAttesaAsync = ref.watch(prelieviInAttesaProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        final state = _dettagliKey.currentState;
        if (state != null && !state.isConcluso) {
          state.salvaLavoroInCorso(mostraFeedback: false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo_scr.png',
                height: 24,
              ),
              const SizedBox(width: 8),
              const Text('Rientro Materiale'),
            ],
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Torna indietro (salva)',
            onPressed: () async {
              final state = _dettagliKey.currentState;
              if (state != null && !state.isConcluso) {
                await state.salvaLavoroInCorso(mostraFeedback: false);
              }
              if (context.mounted) {
                Navigator.of(context).maybePop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Salva lavoro in corso',
              onPressed: () {
                final state = _dettagliKey.currentState;
                if (state != null && !state.isConcluso) {
                  state.salvaLavoroInCorso(mostraFeedback: true);
                }
              },
            ),
          ],
        ),
        body: inAttesaAsync.when(
          data: (prelieviRaw) {
            // Ordinamento discendente per vista spunta rientro (più recenti in alto)
            final prelieviInAttesa = [...prelieviRaw]
              ..sort((a, b) => b.dataPrelievo.compareTo(a.dataPrelievo));
            if (prelieviInAttesa.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_alt_rounded,
                        size: 72,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nessun prelievo in attesa!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tutti i materiali prelevati risultano già rientrati nel magazzino speleo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_selectedPrelievoId == null ||
                !prelieviInAttesa.any((p) => p.id == _selectedPrelievoId)) {
              _selectedPrelievoId = prelieviInAttesa.first.id;
            }

            final prelievoCorrente = prelieviInAttesa.firstWhere(
              (p) => p.id == _selectedPrelievoId,
            );

            return SafeArea(
              child: Column(
                children: [
                  // Selettore del prelievo "In attesa materiale"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.assignment_late_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Seleziona Prelievo da Riconsegnare:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedPrelievoId,
                              icon: const Icon(Icons.arrow_drop_down, size: 28),
                              items: prelieviInAttesa.map((p) {
                                final inCorso = p.haSpuntaInCorso;
                                final spuntati = p.articoliSpuntatiCount;
                                return DropdownMenuItem<String>(
                                  value: p.id,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${p.luogoGrotta} - ${p.responsabile}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (inCorso)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: Colors.amber.shade400),
                                          ),
                                          child: Text(
                                            'Bozza $spuntati/${p.dettagli.length}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (nuovoId) async {
                                if (nuovoId != null &&
                                    nuovoId != _selectedPrelievoId) {
                                  await _dettagliKey.currentState
                                      ?.salvaLavoroInCorso(mostraFeedback: false);
                                  setState(() => _selectedPrelievoId = nuovoId);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Data: ${prelievoCorrente.dataPrelievo.day.toString().padLeft(2, '0')}/${prelievoCorrente.dataPrelievo.month.toString().padLeft(2, '0')}/${prelievoCorrente.dataPrelievo.year}',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                            const Spacer(),
                            if (prelievoCorrente.haSpuntaInCorso) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.amber.shade600),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_note,
                                        size: 14, color: Colors.amber.shade900),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Spunta in corso (${prelievoCorrente.articoliSpuntatiCount}/${prelievoCorrente.dettagli.length})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            StatoBadge(stato: prelievoCorrente.stato),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: _DettagliListView(
                      key: _dettagliKey,
                      prelievo: prelievoCorrente,
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text('Errore: $err'),
          ),
        ),
      ),
    );
  }
}

class _DettagliListView extends ConsumerStatefulWidget {
  final Prelievo prelievo;

  const _DettagliListView({
    super.key,
    required this.prelievo,
  });

  @override
  ConsumerState<_DettagliListView> createState() => _DettagliListViewState();
}

class _DettagliListViewState extends ConsumerState<_DettagliListView> {
  late Map<String, bool> _spunte;
  late Map<String, int> _qtaTornate;
  late Map<String, String> _noteTexts;
  final Map<String, Timer?> _debounceTimers = {};
  bool _isSaving = false;
  bool _isConcluso = false;

  bool get isConcluso => _isConcluso;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    _spunte = {};
    _qtaTornate = {};
    _noteTexts = {};

    for (final d in widget.prelievo.dettagli) {
      _spunte[d.idDettaglio] = d.spuntaRientro;
      _qtaTornate[d.idDettaglio] = d.qtaTornata ?? d.quantitaPrelevata;
      _noteTexts[d.idDettaglio] = d.noteRientro ?? '';
    }
  }

  @override
  void didUpdateWidget(covariant _DettagliListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prelievo.id != widget.prelievo.id) {
      _flushDebounceTimers();
      _initValues();
    }
  }

  @override
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
    super.dispose();
  }

  void _flushDebounceTimers() {
    for (final entry in _debounceTimers.entries) {
      if (entry.value?.isActive ?? false) {
        entry.value!.cancel();
        final idDettaglio = entry.key;
        final note = _noteTexts[idDettaglio] ?? '';
        final spunta = _spunte[idDettaglio] ?? false;
        final qta = _qtaTornate[idDettaglio] ?? 0;
        ref.read(prelieviControllerProvider.notifier).aggiornaDettaglioRientro(
              idDettaglio: idDettaglio,
              spuntaRientro: spunta,
              qtaTornata: qta,
              noteRientro: note.trim().isEmpty ? null : note.trim(),
              invalidate: false,
            );
      }
    }
    _debounceTimers.clear();
  }

  Future<void> salvaLavoroInCorso({bool mostraFeedback = true}) async {
    if (_isSaving || _isConcluso || !mounted) return;
    _isSaving = true;

    try {
      _flushDebounceTimers();

      final List<DettaglioPrelievo> dettagliAggiornati = [];
      for (final d in widget.prelievo.dettagli) {
        final spuntato = _spunte[d.idDettaglio] ?? false;
        final qta = _qtaTornate[d.idDettaglio] ?? d.quantitaPrelevata;
        final nota = _noteTexts[d.idDettaglio]?.trim();
        final notaPulita = (nota == null || nota.isEmpty) ? null : nota;

        dettagliAggiornati.add(
          d.copyWith(
            spuntaRientro: spuntato,
            qtaTornata: spuntato ? qta : (d.qtaTornata ?? d.quantitaPrelevata),
            noteRientro: notaPulita,
            isSynced: false,
          ),
        );
      }

      await ref.read(prelieviControllerProvider.notifier).salvaBozzaSpunta(
            prelievoId: widget.prelievo.id,
            dettagli: dettagliAggiornati,
          );

      if (mostraFeedback && mounted) {
        final spuntati = _spunte.values.where((v) => v).length;
        final totale = widget.prelievo.dettagli.length;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.indigo.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lavoro salvato! ($spuntati/$totale spuntati). Puoi riprendere in qualsiasi momento.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      } else {
        _isSaving = false;
      }
    }
  }

  Future<void> _aggiornaRigaImmediatamente({
    required String idDettaglio,
    required bool spunta,
    required int qtaTornata,
    required String note,
  }) async {
    _noteTexts[idDettaglio] = note;
    final notaPulita = note.trim().isEmpty ? null : note.trim();
    await ref.read(prelieviControllerProvider.notifier).aggiornaDettaglioRientro(
          idDettaglio: idDettaglio,
          spuntaRientro: spunta,
          qtaTornata: qtaTornata,
          noteRientro: notaPulita,
          invalidate: false,
        );
  }

  Future<void> _spuntaTutto() async {
    for (final d in widget.prelievo.dettagli) {
      _spunte[d.idDettaglio] = true;
      _qtaTornate[d.idDettaglio] = d.quantitaPrelevata;
    }
    setState(() {});
    await salvaLavoroInCorso(mostraFeedback: false);
  }

  Future<void> _deselezionaTutto() async {
    for (final d in widget.prelievo.dettagli) {
      _spunte[d.idDettaglio] = false;
    }
    setState(() {});
    await salvaLavoroInCorso(mostraFeedback: false);
  }

  Future<void> _concludiRiconsegna() async {
    _flushDebounceTimers();
    final timestampConclusione = DateTime.now();

    bool tuttoRientrato = true;
    final List<DettaglioPrelievo> dettagliAggiornati = [];
    int totPrelevatiMetri = 0;
    int totPrelevatiPz = 0;
    int totRientratiMetri = 0;
    int totRientratiPz = 0;
    final List<String> materialiMancanti = [];

    for (final d in widget.prelievo.dettagli) {
      final spuntato = _spunte[d.idDettaglio] ?? false;
      final qta = _qtaTornate[d.idDettaglio] ?? 0;
      final nota = _noteTexts[d.idDettaglio]?.trim();

      final qtaEffettiva = spuntato ? qta : 0;
      if (d.isMetri) {
        totPrelevatiMetri += d.quantitaPrelevata;
        totRientratiMetri += qtaEffettiva;
      } else {
        totPrelevatiPz += d.quantitaPrelevata;
        totRientratiPz += qtaEffettiva;
      }

      if (!spuntato || qta < d.quantitaPrelevata) {
        tuttoRientrato = false;
        final nome = d.nomeMateriale ?? d.materialeId;
        final ammanco = d.quantitaPrelevata - qtaEffettiva;
        materialiMancanti.add('$nome: mancanti $ammanco ${d.unitaMisura}');
      }

      dettagliAggiornati.add(
        d.copyWith(
          spuntaRientro: spuntato,
          qtaTornata: qtaEffettiva,
          noteRientro: (nota == null || nota.isEmpty) ? null : nota,
          isSynced: false,
        ),
      );
    }

    final riepilogoRientro = [
      if (totPrelevatiMetri > 0)
        'Corde: $totRientratiMetri/$totPrelevatiMetri m',
      if (totPrelevatiPz > 0)
        'Attrezzatura: $totRientratiPz/$totPrelevatiPz pz',
    ].join(' • ');

    final nuovoStato =
        tuttoRientrato ? StatoPrelievo.rientrato : StatoPrelievo.mancante;

    // Recupera impostazioni email memorizzate
    final ultimoOperatore = await DatabaseHelper.instance.getSetting(
          DatabaseHelper.settingUltimoOperatoreEmail,
        ) ?? '';
    final defaultMagazzino = await DatabaseHelper.instance.getSetting(
          DatabaseHelper.settingEmailMagazzinieriCc,
        ) ?? 'magazzino@speleoclubroma.org';

    if (!mounted) return;

    final dateStr =
        '${timestampConclusione.day.toString().padLeft(2, '0')}/${timestampConclusione.month.toString().padLeft(2, '0')}/${timestampConclusione.year} ${timestampConclusione.hour.toString().padLeft(2, '0')}:${timestampConclusione.minute.toString().padLeft(2, '0')}:${timestampConclusione.second.toString().padLeft(2, '0')}';

    final result = await showModalBottomSheet<_ConfermaRientroResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ConfermaRientroModalSheet(
        prelievo: widget.prelievo,
        tuttoRientrato: tuttoRientrato,
        riepilogoRientro: riepilogoRientro,
        materialiMancanti: materialiMancanti,
        dateStr: dateStr,
        initialOperatore: ultimoOperatore,
        initialMagazzinieri: defaultMagazzino,
      ),
    );

    if (result == null) return;

    final operatoreEmail = result.operatoreEmail;
    final magazzinieriEmail = result.magazzinieriEmail;

    // Salva impostazioni per i prossimi rientri
    await DatabaseHelper.instance.setSetting(
      DatabaseHelper.settingUltimoOperatoreEmail,
      operatoreEmail,
    );
    if (magazzinieriEmail.isNotEmpty) {
      await DatabaseHelper.instance.setSetting(
        DatabaseHelper.settingEmailMagazzinieriCc,
        magazzinieriEmail,
      );
    }

    if (!mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    _isConcluso = true;
    for (final timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();

    await ref.read(prelieviControllerProvider.notifier).confermaRiconsegna(
          prelievoId: widget.prelievo.id,
          dettagli: dettagliAggiornati,
          nuovoStato: nuovoStato,
          dataRientro: timestampConclusione,
          operatoreRientro: operatoreEmail.isEmpty ? null : operatoreEmail,
          emailMagazzinieri: magazzinieriEmail.isEmpty ? null : magazzinieriEmail,
        );

    messenger.showSnackBar(
      SnackBar(
        backgroundColor:
            tuttoRientrato ? Colors.green.shade800 : Colors.orange.shade900,
        content: Text(
          tuttoRientrato
              ? 'Rientro concluso alle $dateStr da $operatoreEmail: tutto presente!'
              : 'Rientro archiviato alle $dateStr con MATERIALE MANCANTE.',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );

    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dettagli = widget.prelievo.dettagli;

    if (dettagli.isEmpty) {
      return const Center(
        child: Text('Nessun materiale associato a questo prelievo.'),
      );
    }

    final spuntatiCount = _spunte.values.where((v) => v).length;
    final tuttiSpuntati =
        spuntatiCount == dettagli.length && dettagli.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Materiali ($spuntatiCount/${dettagli.length} spuntati)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (spuntatiCount > 0 && !tuttiSpuntati) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'In corso',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: Icon(
                  tuttiSpuntati
                      ? Icons.clear_all_rounded
                      : Icons.done_all_rounded,
                  size: 20,
                ),
                label: Text(
                  tuttiSpuntati ? 'DESELEZIONA TUTTI' : 'SPUNTA TUTTI',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: tuttiSpuntati ? _deselezionaTutto : _spuntaTutto,
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: dettagli.length,
            itemBuilder: (context, index) {
              final d = dettagli[index];
              final isSpuntato = _spunte[d.idDettaglio] ?? false;
              final qtaTornata = _qtaTornate[d.idDettaglio] ?? d.quantitaPrelevata;
              final currentNote = _noteTexts[d.idDettaglio] ?? '';

              return _DettaglioRientroCard(
                key: ValueKey(d.idDettaglio),
                dettaglio: d,
                isSpuntato: isSpuntato,
                qtaTornata: qtaTornata,
                initialNote: currentNote,
                onSpuntaChanged: (val) {
                  setState(() {
                    _spunte[d.idDettaglio] = val;
                    if (val && _qtaTornate[d.idDettaglio] == 0) {
                      _qtaTornate[d.idDettaglio] = d.quantitaPrelevata;
                    }
                  });
                  _aggiornaRigaImmediatamente(
                    idDettaglio: d.idDettaglio,
                    spunta: val,
                    qtaTornata: _qtaTornate[d.idDettaglio]!,
                    note: _noteTexts[d.idDettaglio] ?? '',
                  );
                },
                onQtaChanged: (newVal) {
                  setState(() {
                    _qtaTornate[d.idDettaglio] = newVal;
                  });
                  _aggiornaRigaImmediatamente(
                    idDettaglio: d.idDettaglio,
                    spunta: isSpuntato,
                    qtaTornata: newVal,
                    note: _noteTexts[d.idDettaglio] ?? '',
                  );
                },
                onNoteChanged: (text) {
                  _noteTexts[d.idDettaglio] = text;
                  _debounceTimers[d.idDettaglio]?.cancel();
                  _debounceTimers[d.idDettaglio] =
                      Timer(const Duration(milliseconds: 300), () {
                    _aggiornaRigaImmediatamente(
                      idDettaglio: d.idDettaglio,
                      spunta: _spunte[d.idDettaglio] ?? false,
                      qtaTornata: _qtaTornate[d.idDettaglio]!,
                      note: text,
                    );
                  });
                },
              );
            },
          ),
        ),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                offset: const Offset(0, -3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () => salvaLavoroInCorso(mostraFeedback: true),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 22),
                    label: const Text(
                      'SALVA LAVORO',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Colors.deepOrange.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSaving ? null : _concludiRiconsegna,
                    icon: const Icon(Icons.done_all, size: 22),
                    label: const Text(
                      'CONCLUDI',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DettaglioRientroCard extends StatefulWidget {
  final DettaglioPrelievo dettaglio;
  final bool isSpuntato;
  final int qtaTornata;
  final String initialNote;
  final ValueChanged<bool> onSpuntaChanged;
  final ValueChanged<int> onQtaChanged;
  final ValueChanged<String> onNoteChanged;

  const _DettaglioRientroCard({
    super.key,
    required this.dettaglio,
    required this.isSpuntato,
    required this.qtaTornata,
    required this.initialNote,
    required this.onSpuntaChanged,
    required this.onQtaChanged,
    required this.onNoteChanged,
  });

  @override
  State<_DettaglioRientroCard> createState() => _DettaglioRientroCardState();
}

class _DettaglioRientroCardState extends State<_DettaglioRientroCard> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void didUpdateWidget(covariant _DettaglioRientroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dettaglio.idDettaglio != widget.dettaglio.idDettaglio) {
      _noteController.text = widget.initialNote;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.dettaglio;
    final isSpuntato = widget.isSpuntato;
    final qtaTornata = widget.qtaTornata;
    final isMancante = isSpuntato && qtaTornata < d.quantitaPrelevata;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSpuntato
              ? (isMancante ? Colors.orange.shade800 : Colors.green.shade600)
              : Colors.grey.shade300,
          width: isSpuntato ? 2.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 48,
                  child: Switch(
                    value: isSpuntato,
                    activeTrackColor: Colors.green.shade700,
                    onChanged: widget.onSpuntaChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => widget.onSpuntaChanged(!isSpuntato),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.nomeMateriale ?? d.materialeId,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: isSpuntato && !isMancante
                                ? TextDecoration.lineThrough
                                : null,
                            color: isSpuntato && !isMancante
                                ? Colors.grey.shade600
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Prelevati originariamente: ${d.quantitaPrelevata} ${d.unitaMisura}',
                          style: TextStyle(
                            color: d.isMetri
                                ? Colors.deepOrange
                                : theme.colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isSpuntato) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Q.tà Tornata (${d.unitaMisura}):',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  QuantityStepper(
                    value: qtaTornata,
                    minValue: 0,
                    maxValue: d.quantitaPrelevata,
                    unit: d.unitaMisura,
                    isMetri: d.isMetri,
                    itemName: d.nomeMateriale,
                    onChanged: widget.onQtaChanged,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: isMancante
                      ? 'Note rientro (Ammanco di ${d.quantitaPrelevata - qtaTornata} ${d.unitaMisura})'
                      : 'Note rientro / Condizioni (opzionale)',
                  hintText: 'Es. 1 moschettone bloccato, corda tagliata/usurata',
                  prefixIcon: Icon(
                    isMancante
                        ? Icons.warning_amber_rounded
                        : Icons.edit_note_rounded,
                    color: isMancante ? Colors.orange : Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: widget.onNoteChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfermaRientroResult {
  final String operatoreEmail;
  final String magazzinieriEmail;

  const _ConfermaRientroResult({
    required this.operatoreEmail,
    required this.magazzinieriEmail,
  });
}

class _ConfermaRientroModalSheet extends StatefulWidget {
  final Prelievo prelievo;
  final bool tuttoRientrato;
  final String riepilogoRientro;
  final List<String> materialiMancanti;
  final String dateStr;
  final String initialOperatore;
  final String initialMagazzinieri;

  const _ConfermaRientroModalSheet({
    required this.prelievo,
    required this.tuttoRientrato,
    required this.riepilogoRientro,
    required this.materialiMancanti,
    required this.dateStr,
    required this.initialOperatore,
    required this.initialMagazzinieri,
  });

  @override
  State<_ConfermaRientroModalSheet> createState() =>
      _ConfermaRientroModalSheetState();
}

class _ConfermaRientroModalSheetState
    extends State<_ConfermaRientroModalSheet> {
  late final TextEditingController _operatoreController;
  late final TextEditingController _magazzinieriController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _operatoreController =
        TextEditingController(text: widget.initialOperatore);
    _magazzinieriController =
        TextEditingController(text: widget.initialMagazzinieri);
  }

  @override
  void dispose() {
    _operatoreController.dispose();
    _magazzinieriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    widget.tuttoRientrato
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: widget.tuttoRientrato
                        ? Colors.green
                        : Colors.orange.shade800,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.tuttoRientrato
                          ? 'Conferma Rientro Completo'
                          : 'Conferma Rientro con Ammanchi',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Box Timestamp e Dati Scheda
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled,
                            size: 18, color: Colors.indigo),
                        const SizedBox(width: 6),
                        Text(
                          'Timestamp chiusura: ${widget.dateStr}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '📍 ${widget.prelievo.luogoGrotta} • 👤 ${widget.prelievo.responsabile}',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📦 Rientro: ${widget.riepilogoRientro}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.tuttoRientrato
                            ? Colors.green.shade800
                            : Colors.deepOrange,
                      ),
                    ),
                    if (widget.materialiMancanti.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Ammanchi segnalati:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                      ...widget.materialiMancanti.map(
                        (m) => Text(
                          '• $m',
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Campo Operatore
              TextFormField(
                controller: _operatoreController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Operatore spunta (Email notifica)*',
                  hintText: 'es. nome.cognome@speleoclubroma.org',
                  prefixIcon: const Icon(Icons.person_pin_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Inserisci la tua email o identificativo operatore';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Campo Email Magazzinieri (CC)
              TextFormField(
                controller: _magazzinieriController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Magazzinieri (in Copia Conoscenza)',
                  hintText: 'magazzino@speleoclubroma.org',
                  prefixIcon: const Icon(Icons.mark_email_read_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'La notifica email di riepilogo verrà inviata tramite Google Apps Script alla sincronizzazione.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pulsanti Azione (Touch target ergonomici)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, null),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: widget.tuttoRientrato
                            ? Colors.green.shade800
                            : Colors.deepOrange.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(
                            ctx,
                            _ConfermaRientroResult(
                              operatoreEmail: _operatoreController.text.trim(),
                              magazzinieriEmail:
                                  _magazzinieriController.text.trim(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.done_all, size: 22),
                      label: const Text(
                        'CONFERMA E ARCHIVIA',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
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
