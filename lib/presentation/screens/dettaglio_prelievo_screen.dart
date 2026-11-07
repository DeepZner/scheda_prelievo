import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import '../providers/prelievi_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/stato_badge.dart';

class DettaglioPrelievoScreen extends ConsumerWidget {
  final String prelievoId;

  const DettaglioPrelievoScreen({super.key, required this.prelievoId});

  void _copiaRiepilogoTesto(BuildContext context, Prelievo p) {
    final buffer = StringBuffer();
    buffer.writeln('📋 *SCHEDA PRELIEVO SPELEO CLUB ROMA*');
    buffer.writeln('📍 Luogo / Grotta: ${p.luogoGrotta}');
    buffer.writeln('👤 Responsabile: ${p.responsabile}');
    buffer.writeln(
      '📅 Data: ${p.dataPrelievo.day.toString().padLeft(2, '0')}/${p.dataPrelievo.month.toString().padLeft(2, '0')}/${p.dataPrelievo.year}',
    );
    buffer.writeln('🏷️ Stato: ${p.stato.label}');
    if (p.parere != null && p.parere!.isNotEmpty) {
      buffer.writeln('📝 Note: ${p.parere}');
    }
    buffer.writeln('\n📦 *Materiali:*');
    for (final d in p.dettagli) {
      final nome = d.nomeMateriale ?? d.materialeId;
      buffer.write('• $nome: prelevati ${d.quantitaPrelevata} ${d.unitaMisura}');
      if (d.spuntaRientro) {
        buffer.write(' | rientrati ${d.qtaTornata ?? d.quantitaPrelevata} ${d.unitaMisura}');
      }
      if (d.noteRientro != null && d.noteRientro!.isNotEmpty) {
        buffer.write(' (${d.noteRientro})');
      }
      buffer.writeln();
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Riepilogo copiato negli appunti (pronto per WhatsApp)!'),
      ),
    );
  }

  Future<void> _confermaEliminazione(BuildContext context, WidgetRef ref) async {
    final confermato = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annullare questa scheda prelievo?'),
        content: const Text(
          'La scheda verrà contrassegnata come "Annullato" (cancellazione logica). Rimarrà tracciata nello storico e lo stato verrà sincronizzato sul foglio Google Sheets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Indietro'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annulla Scheda'),
          ),
        ],
      ),
    );

    if (confermato == true) {
      await ref.read(prelieviControllerProvider.notifier).eliminaPrelievo(prelievoId);
      try {
        await ref.read(syncControllerProvider.notifier).sincronizza();
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scheda contrassegnata come Annullata (cancellazione logica).'),
          ),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prelievoAsync = ref.watch(prelievoDetailProvider(prelievoId));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo_scr.png',
              height: 22,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Scheda Prelievo',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          prelievoAsync.maybeWhen(
            data: (p) => p != null && p.isModificabile
                ? IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Modifica scheda prelievo',
                    onPressed: () => context.push('/modifica-prelievo/${p.id}'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          prelievoAsync.maybeWhen(
            data: (p) => p != null
                ? IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Copia riepilogo testuale',
                    onPressed: () => _copiaRiepilogoTesto(context, p),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          prelievoAsync.maybeWhen(
            data: (p) => p != null && p.stato != StatoPrelievo.annullato
                ? IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Annulla scheda prelievo (cancellazione logica)',
                    onPressed: () => _confermaEliminazione(context, ref),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: prelievoAsync.when(
        data: (prelievo) {
          if (prelievo == null) {
            return const Center(child: Text('Prelievo non trovato.'));
          }

          final isInAttesa = prelievo.stato == StatoPrelievo.inAttesa;
          final totPrelevatiMetri = prelievo.totaleMetri;
          final matasseCount = prelievo.totaleMatasse;
          final totPrelevatiPz = prelievo.dettagli
              .where((d) => !d.isMetri)
              .fold<int>(0, (sum, d) => sum + d.quantitaPrelevata);
          final totalePezziFisici = prelievo.totalePezzi;
          final riepilogoMateriali = [
            if (totPrelevatiMetri > 0)
              '$totPrelevatiMetri m corde ($matasseCount ${matasseCount == 1 ? 'matassa' : 'matasse'})',
            if (totPrelevatiPz > 0) '$totPrelevatiPz pz',
          ].join(' • ');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatoBadge(stato: prelievo.stato),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              prelievo.responsabile,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Data: ${prelievo.dataPrelievo.day.toString().padLeft(2, '0')}/${prelievo.dataPrelievo.month.toString().padLeft(2, '0')}/${prelievo.dataPrelievo.year}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: prelievo.isSynced
                                  ? Colors.green.shade50
                                  : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: prelievo.isSynced
                                    ? Colors.green.shade300
                                    : Colors.amber.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  prelievo.isSynced
                                      ? Icons.cloud_done
                                      : Icons.cloud_upload_outlined,
                                  size: 14,
                                  color: prelievo.isSynced
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  prelievo.isSynced ? 'Sincronizzato' : 'Offline',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: prelievo.isSynced
                                        ? Colors.green.shade800
                                        : Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (prelievo.dataRientro != null) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.event_available, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Riconsegnato: ${prelievo.dataRientro!.day.toString().padLeft(2, '0')}/${prelievo.dataRientro!.month.toString().padLeft(2, '0')}/${prelievo.dataRientro!.year} ${prelievo.dataRientro!.hour.toString().padLeft(2, '0')}:${prelievo.dataRientro!.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (prelievo.operatoreRientro != null && prelievo.operatoreRientro!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 18, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Operatore: ${prelievo.operatoreRientro}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (prelievo.parere != null && prelievo.parere!.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          'Note:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prelievo.parere!,
                          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (prelievo.stato == StatoPrelievo.annullato) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined,
                          color: Colors.grey.shade800, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Questa scheda di prelievo è stata annullata. Rimane archiviata nello storico e sul foglio Google Sheets.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (isInAttesa) ...[
                if (prelievo.isModificabile) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note, size: 24),
                      label: const Text(
                        'MODIFICA PRELIEVO E MATERIALI',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () => context.push('/modifica-prelievo/${prelievo.id}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_clock, color: Colors.amber.shade900, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Spunta rientro già avviata: la lista dei materiali è bloccata.',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.assignment_turned_in, size: 24),
                    label: Text(
                      prelievo.haSpuntaInCorso
                          ? 'CONTINUA SPUNTA RIENTRO (${prelievo.articoliSpuntatiCount}/${prelievo.dettagli.length})'
                          : 'PROCEDI CON LA SPUNTA RIENTRO',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () => context.go('/rientro/${prelievo.id}'),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Text(
                'Materiali (${prelievo.dettagli.length} voci • $totalePezziFisici pezzi${riepilogoMateriali.isNotEmpty ? ' • $riepilogoMateriali' : ''})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              ...prelievo.dettagli.map((d) {
                final isCompletamenteRientrato =
                    d.spuntaRientro && (d.qtaTornata ?? 0) >= d.quantitaPrelevata;
                final isParziale =
                    d.spuntaRientro && (d.qtaTornata ?? 0) < d.quantitaPrelevata;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              !d.spuntaRientro
                                  ? Icons.hourglass_empty
                                  : (isCompletamenteRientrato
                                      ? Icons.check_circle
                                      : Icons.warning_amber_rounded),
                              color: !d.spuntaRientro
                                  ? Colors.grey
                                  : (isCompletamenteRientrato
                                      ? Colors.green
                                      : Colors.orange),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.nomeMateriale ?? d.materialeId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    d.categoriaMateriale ?? '',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Prelevati: ${d.quantitaPrelevata} ${d.unitaMisura}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: d.isMetri ? Colors.deepOrange.shade900 : null,
                                  ),
                                ),
                                if (d.spuntaRientro)
                                  Text(
                                    'Rientrati: ${d.qtaTornata ?? d.quantitaPrelevata} ${d.unitaMisura}',
                                    style: TextStyle(
                                      color: isParziale ? Colors.red : Colors.green.shade800,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (d.noteRientro != null && d.noteRientro!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Nota rientro: ${d.noteRientro}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
      ),
    );
  }
}
