import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import '../../data/services/allegati_service.dart';
import '../../data/services/pdf_service.dart';
import '../providers/prelievi_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/stato_badge.dart';
import '../widgets/sync_status_button.dart';

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

  Future<void> _mostraMenuCondivisione(
    BuildContext context,
    WidgetRef ref,
    Prelievo p,
  ) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.share_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Condividi Scheda Prelievo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${p.luogoGrotta} • ${p.responsabile}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626)),
                  ),
                  title: const Text(
                    'Condividi Scheda PDF (Ufficiale SCR)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Documento stampabile offline, apribile da qualsiasi telefono',
                  ),
                  onTap: () async {
                    Navigator.pop(bottomSheetCtx);
                    try {
                      await PdfService.sharePdf(p);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore durante la creazione del PDF: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.public, color: Color(0xFF0284C7)),
                  ),
                  title: const Text(
                    'Condividi Link Web (Senza app)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Link per consultare la scheda online da Safari, Chrome o PC',
                  ),
                  onTap: () async {
                    Navigator.pop(bottomSheetCtx);
                    final syncService = ref.read(syncServiceProvider);
                    final webUrl = await syncService.getWebShareUrl(p.id);
                    if (webUrl == null) {
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('URL Web App Mancante'),
                            content: const Text(
                              'Per condividere la scheda via web è necessario aver inserito l\'URL della Web App di Google Apps Script (creata sul tuo foglio di Google Drive e terminante con /exec).\n\n'
                              'Vuoi inserire l\'URL adesso?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx),
                                child: const Text('Annulla'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  Navigator.pop(dCtx);
                                  SyncStatusButton.mostraDialogImpostazioniUrl(context, ref);
                                },
                                child: const Text('Configura URL'),
                              ),
                            ],
                          ),
                        );
                      }
                      return;
                    }

                    final shareText =
                        '🦇 *SPELEO CLUB ROMA 1959*\n'
                        '📋 *Scheda Prelievo: ${p.luogoGrotta}*\n'
                        '👤 Responsabile: ${p.responsabile}\n'
                        '🔗 Visualizza online senza app:\n$webUrl';

                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 4),
                          content: Text(
                            p.isSynced
                                ? 'Link Web copiato negli appunti (pronto per WhatsApp o SMS)!'
                                : 'Link Web copiato! Ricorda di sincronizzare con Google Sheets affinché la scheda sia visibile online.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Icon(Icons.chat_bubble_outline, color: Color(0xFF16A34A)),
                  ),
                  title: const Text(
                    'Copia Messaggio Testuale (WhatsApp / Chat)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Riepilogo completo formattato con emoji negli appunti',
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _copiaRiepilogoTesto(context, p);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3F4F6),
                    child: Icon(Icons.print_outlined, color: Color(0xFF4B5563)),
                  ),
                  title: const Text(
                    'Stampa Scheda PDF',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Invia direttamente alla stampante Wi-Fi o anteprima di stampa',
                  ),
                  onTap: () async {
                    Navigator.pop(bottomSheetCtx);
                    try {
                      await PdfService.printPdf(p);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore di stampa: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
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

  IconData _getIconForFile(String? fileName) {
    if (fileName == null) return Icons.attach_file;
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'odt':
      case 'rtf':
      case 'txt':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'ods':
      case 'csv':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorForFile(String? fileName) {
    if (fileName == null) return Colors.blueGrey;
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'doc':
      case 'docx':
        return const Color(0xFF2563EB);
      case 'odt':
      case 'ods':
        return const Color(0xFF0D9488);
      case 'jpg':
      case 'jpeg':
      case 'png':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFF4B5563);
    }
  }

  Widget _buildRelazioneCard(BuildContext context, Prelievo p) {
    final theme = Theme.of(context);
    final haContenuto = p.haRelazione || p.haAllegato;
    final isAnnullato = p.stato == StatoPrelievo.annullato;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: haContenuto
              ? theme.colorScheme.primary.withAlpha(80)
              : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: haContenuto
                        ? theme.colorScheme.primaryContainer
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: haContenuto
                        ? theme.colorScheme.primary
                        : Colors.grey.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relazione di Esplorazione / Uscita',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        haContenuto
                            ? 'Documentazione e note post-uscita'
                            : 'Nessuna relazione allegata',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (haContenuto && !isAnnullato)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Modifica relazione o allegato',
                    onPressed: () => context.push('/prelievo/${p.id}/relazione'),
                  ),
              ],
            ),
            if (haContenuto) ...[
              const Divider(height: 20),
              if ((p.relazioneAutore != null && p.relazioneAutore!.isNotEmpty) ||
                  p.relazioneData != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (p.relazioneAutore != null && p.relazioneAutore!.isNotEmpty) ...[
                        const Icon(Icons.person_outline, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            p.relazioneAutore!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (p.relazioneAutore != null &&
                          p.relazioneAutore!.isNotEmpty &&
                          p.relazioneData != null)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('•', style: TextStyle(color: Colors.grey)),
                        ),
                      if (p.relazioneData != null) ...[
                        const Icon(Icons.event_note, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Text(
                          '${p.relazioneData!.day.toString().padLeft(2, '0')}/${p.relazioneData!.month.toString().padLeft(2, '0')}/${p.relazioneData!.year}',
                          style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                        ),
                      ],
                    ],
                  ),
                ),
              if (p.relazioneTesto != null && p.relazioneTesto!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    p.relazioneTesto!,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              if (p.haAllegato) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            _getColorForFile(p.allegatoNome).withAlpha(30),
                        child: Icon(
                          _getIconForFile(p.allegatoNome),
                          color: _getColorForFile(p.allegatoNome),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.allegatoNome ?? 'Documento Allegato',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Allegato locale offline',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Apri'),
                          onPressed: () async {
                            if (p.allegatoPath != null) {
                              final res =
                                  await AllegatiService.apriAllegato(p.allegatoPath!);
                              if (res.type != ResultType.done &&
                                  res.message.isNotEmpty &&
                                  context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Apertura: ${res.message}'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!isAnnullato) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note, size: 22),
                    label: const Text(
                      'MODIFICA RELAZIONE / ALLEGATO',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => context.push('/prelievo/${p.id}/relazione'),
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'Aggiungi note sull\'esplorazione, una relazione di uscita o un documento allegato (PDF, Word, OpenOffice, immagini fino a 20MB). Disponibile anche a materiale riconsegnato.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
              if (!isAnnullato) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text(
                      'AGGIUNGI RELAZIONE / ALLEGATO',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => context.push('/prelievo/${p.id}/relazione'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
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
              'assets/images/app_logo.png',
              height: 26,
              width: 26,
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
                    tooltip: 'Condividi scheda prelievo',
                    onPressed: () => _mostraMenuCondivisione(context, ref, p),
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

              _buildRelazioneCard(context, prelievo),
              const SizedBox(height: 16),

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
