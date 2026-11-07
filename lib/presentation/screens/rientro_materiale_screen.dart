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

  @override
  void initState() {
    super.initState();
    _selectedPrelievoId = widget.initialPrelievoId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inAttesaAsync = ref.watch(prelieviInAttesaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rientro Materiale'),
        centerTitle: true,
      ),
      body: inAttesaAsync.when(
        data: (prelieviInAttesa) {
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
                              return DropdownMenuItem<String>(
                                value: p.id,
                                child: Text(
                                  '${p.luogoGrotta} - ${p.responsabile}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (nuovoId) {
                              if (nuovoId != null) {
                                setState(() => _selectedPrelievoId = nuovoId);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Data: ${prelievoCorrente.dataPrelievo.day.toString().padLeft(2, '0')}/${prelievoCorrente.dataPrelievo.month.toString().padLeft(2, '0')}/${prelievoCorrente.dataPrelievo.year}',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const Spacer(),
                          StatoBadge(stato: prelievoCorrente.stato),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _DettagliListView(
                    key: ValueKey(prelievoCorrente.id),
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
  late Map<String, TextEditingController> _noteControllers;
  final Map<String, Timer?> _debounceTimers = {};

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    _spunte = {};
    _qtaTornate = {};
    _noteControllers = {};

    for (final d in widget.prelievo.dettagli) {
      _spunte[d.idDettaglio] = d.spuntaRientro;
      _qtaTornate[d.idDettaglio] = d.qtaTornata ?? d.quantitaPrelevata;
      _noteControllers[d.idDettaglio] =
          TextEditingController(text: d.noteRientro ?? '');
    }
  }

  @override
  void didUpdateWidget(covariant _DettagliListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prelievo.id != widget.prelievo.id) {
      _disposeControllers();
      _initValues();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final timer in _debounceTimers.values) {
      timer?.cancel();
    }
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
  }

  Future<void> _aggiornaRigaImmediatamente({
    required String idDettaglio,
    required bool spunta,
    required int qtaTornata,
    required String note,
  }) async {
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
      setState(() {
        _spunte[d.idDettaglio] = true;
        _qtaTornate[d.idDettaglio] = d.quantitaPrelevata;
      });
      await _aggiornaRigaImmediatamente(
        idDettaglio: d.idDettaglio,
        spunta: true,
        qtaTornata: d.quantitaPrelevata,
        note: _noteControllers[d.idDettaglio]?.text ?? '',
      );
    }
  }

  Future<void> _concludiRiconsegna() async {
    final timestampConclusione = DateTime.now();

    bool tuttoRientrato = true;
    final List<DettaglioPrelievo> dettagliAggiornati = [];
    int totPrelevati = 0;
    int totRientrati = 0;
    final List<String> materialiMancanti = [];

    for (final d in widget.prelievo.dettagli) {
      final spuntato = _spunte[d.idDettaglio] ?? false;
      final qta = _qtaTornate[d.idDettaglio] ?? 0;
      final nota = _noteControllers[d.idDettaglio]?.text.trim();

      totPrelevati += d.quantitaPrelevata;
      final qtaEffettiva = spuntato ? qta : 0;
      totRientrati += qtaEffettiva;

      if (!spuntato || qta < d.quantitaPrelevata) {
        tuttoRientrato = false;
        final nome = d.nomeMateriale ?? d.materialeId;
        final ammanco = d.quantitaPrelevata - qtaEffettiva;
        materialiMancanti.add('$nome: mancanti $ammanco pz');
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

    final operatoreController = TextEditingController(text: ultimoOperatore);
    final magazzinieriController = TextEditingController(text: defaultMagazzino);
    final formKey = GlobalKey<FormState>();

    final dateStr =
        '${timestampConclusione.day.toString().padLeft(2, '0')}/${timestampConclusione.month.toString().padLeft(2, '0')}/${timestampConclusione.year} ${timestampConclusione.hour.toString().padLeft(2, '0')}:${timestampConclusione.minute.toString().padLeft(2, '0')}:${timestampConclusione.second.toString().padLeft(2, '0')}';

    final confermato = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
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
                        tuttoRientrato
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        color: tuttoRientrato ? Colors.green : Colors.orange.shade800,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tuttoRientrato
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
                            const Icon(Icons.access_time_filled, size: 18, color: Colors.indigo),
                            const SizedBox(width: 6),
                            Text(
                              'Timestamp chiusura: $dateStr',
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
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📦 Materiali rientrati: $totRientrati su $totPrelevati pz',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tuttoRientrato ? Colors.green.shade800 : Colors.deepOrange,
                          ),
                        ),
                        if (materialiMancanti.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Ammanchi segnalati:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                          ...materialiMancanti.map(
                            (m) => Text(
                              '• $m',
                              style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campo Operatore
                  TextFormField(
                    controller: operatoreController,
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
                    controller: magazzinieriController,
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
                      const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'La notifica email di riepilogo verrà inviata tramite Google Apps Script alla sincronizzazione.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
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
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annulla'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: tuttoRientrato
                                ? Colors.green.shade800
                                : Colors.deepOrange.shade800,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(ctx, true);
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
      },
    );

    if (confermato != true) {
      operatoreController.dispose();
      magazzinieriController.dispose();
      return;
    }

    final operatoreEmail = operatoreController.text.trim();
    final magazzinieriEmail = magazzinieriController.text.trim();
    operatoreController.dispose();
    magazzinieriController.dispose();

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

    await ref.read(prelieviControllerProvider.notifier).confermaRiconsegna(
          prelievoId: widget.prelievo.id,
          dettagli: dettagliAggiornati,
          nuovoStato: nuovoStato,
          dataRientro: timestampConclusione,
          operatoreRientro: operatoreEmail.isEmpty ? null : operatoreEmail,
          emailMagazzinieri: magazzinieriEmail.isEmpty ? null : magazzinieriEmail,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Righe Materiale (${dettagli.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.done_all_rounded, size: 20),
                label: const Text(
                  'SPUNTA TUTTI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _spuntaTutto,
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
              final controllerNota = _noteControllers[d.idDettaglio]!;
              final isMancante = isSpuntato && qtaTornata < d.quantitaPrelevata;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSpuntato
                        ? (isMancante
                            ? Colors.orange.shade800
                            : Colors.green.shade600)
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
                              onChanged: (val) {
                                setState(() {
                                  _spunte[d.idDettaglio] = val;
                                  if (val && _qtaTornate[d.idDettaglio] == 0) {
                                    _qtaTornate[d.idDettaglio] =
                                        d.quantitaPrelevata;
                                  }
                                });
                                _aggiornaRigaImmediatamente(
                                  idDettaglio: d.idDettaglio,
                                  spunta: val,
                                  qtaTornata: _qtaTornate[d.idDettaglio]!,
                                  note: controllerNota.text,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                final nuovoVal = !isSpuntato;
                                setState(() {
                                  _spunte[d.idDettaglio] = nuovoVal;
                                });
                                _aggiornaRigaImmediatamente(
                                  idDettaglio: d.idDettaglio,
                                  spunta: nuovoVal,
                                  qtaTornata: _qtaTornate[d.idDettaglio]!,
                                  note: controllerNota.text,
                                );
                              },
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
                                    'Prelevati originariamente: ${d.quantitaPrelevata} pz',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
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
                            const Text(
                              'Q.tà Tornata:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            QuantityStepper(
                              value: qtaTornata,
                              minValue: 0,
                              maxValue: d.quantitaPrelevata,
                              onChanged: (newVal) {
                                setState(() {
                                  _qtaTornate[d.idDettaglio] = newVal;
                                });
                                _aggiornaRigaImmediatamente(
                                  idDettaglio: d.idDettaglio,
                                  spunta: isSpuntato,
                                  qtaTornata: newVal,
                                  note: controllerNota.text,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: controllerNota,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: isMancante
                                ? 'Note rientro (Ammanco di ${d.quantitaPrelevata - qtaTornata} pz)'
                                : 'Note rientro / Condizioni (opzionale)',
                            hintText: 'Es. 1 moschettone bloccato, corda integra',
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
                          onChanged: (text) {
                            _debounceTimers[d.idDettaglio]?.cancel();
                            _debounceTimers[d.idDettaglio] =
                                Timer(const Duration(milliseconds: 300), () {
                              _aggiornaRigaImmediatamente(
                                idDettaglio: d.idDettaglio,
                                spunta: isSpuntato,
                                qtaTornata: _qtaTornate[d.idDettaglio]!,
                                note: text,
                              );
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
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
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _concludiRiconsegna,
              icon: const Icon(Icons.done_all, size: 26),
              label: const Text(
                'CONCLUDI RICONSEGNA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
