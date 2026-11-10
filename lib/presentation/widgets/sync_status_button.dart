import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database_helper.dart';
import '../providers/catalogo_provider.dart';
import '../providers/prelievi_provider.dart';
import '../providers/sync_provider.dart';

class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);
    final syncState = ref.watch(syncControllerProvider);
    final isSyncing = syncState.isLoading;

    return pendingCountAsync.when(
      data: (count) {
        final hasPending = count > 0;

        return SizedBox(
          height: 48,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: isSyncing
                  ? Colors.blue
                  : (hasPending ? Colors.amber.shade900 : Colors.green.shade800),
            ),
            icon: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    hasPending
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_done_rounded,
                    size: 20,
                  ),
            label: Text(
              isSyncing
                  ? 'Sincronizzazione...'
                  : (hasPending ? '$count da inviare' : 'Sincronizzato'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: isSyncing
                ? null
                : () => _mostraDettagliSincronizzazione(context, ref, count),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, s) => const Icon(Icons.cloud_off, color: Colors.red),
    );
  }

  void _mostraDettagliSincronizzazione(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) {
    final currentUrlAsync = ref.read(googleSheetsUrlProvider);
    final configuredUrl = currentUrlAsync.valueOrNull ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    count > 0 ? Icons.sync_problem : Icons.cloud_done,
                    size: 28,
                    color: count > 0 ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sincronizzazione Google Sheets',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Configura URL Web App',
                    onPressed: () {
                      Navigator.pop(ctx);
                      mostraDialogImpostazioniUrl(context, ref);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                count > 0
                    ? 'Ci sono $count record (testate o dettagli) registrati in locale con "is_synced = 0" pronti per essere inviati al foglio Drive.'
                    : 'Tutti i dati locali sono sincronizzati con il foglio Google Sheets.',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              if (configuredUrl.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Nessun URL configurato. Tocca l\'ingranaggio per inserire l\'URL della Web App di Google.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              if (count > 0) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  icon: const Icon(Icons.code_rounded),
                  label: const Text('Anteprima JSON per Google Sheets'),
                  onPressed: () {
                    final payloadAsync = ref.read(pendingPayloadProvider);
                    payloadAsync.whenData((payload) {
                      showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Payload Google Sheets (JSON)'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                payload.toJson(),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx),
                              child: const Text('Chiudi'),
                            ),
                          ],
                        ),
                      );
                    });
                  },
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (configuredUrl.isEmpty) {
                      Navigator.pop(ctx);
                      mostraDialogImpostazioniUrl(context, ref);
                      return;
                    }

                    Navigator.pop(ctx);
                    final result = await ref
                        .read(syncControllerProvider.notifier)
                        .sincronizza();
                    if (context.mounted && result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: result.isSuccess
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          content: Text(
                            result.isSuccess
                                ? 'Sincronizzazione completata: ${result.prelieviSyncedCount} testate e ${result.dettagliSyncedCount} dettagli inviati'
                                : 'Errore: ${result.errorMessage}',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('INVIA DATI A GOOGLE SHEETS'),
                ),
              ),
              const SizedBox(height: 10),
              // Pulsante per scaricare i prelievi da Google Sheets in SQLite
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('SCARICA PRELIEVI DA SHEETS'),
                  onPressed: () async {
                    if (configuredUrl.isEmpty) {
                      Navigator.pop(ctx);
                      mostraDialogImpostazioniUrl(context, ref);
                      return;
                    }

                    Navigator.pop(ctx);
                    final dlResult = await ref
                        .read(syncControllerProvider.notifier)
                        .scaricaPrelieviDaGoogleSheets();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: dlResult.isSuccess
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          content: Text(
                            dlResult.isSuccess
                                ? 'Download completato: ${dlResult.prelieviScaricati} prelievi e ${dlResult.dettagliScaricati} dettagli importati nel database locale!'
                                : 'Errore download: ${dlResult.errorMessage}',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Pulsante per aggiornare il catalogo materiali da Google Sheets
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('AGGIORNA CATALOGO DA SHEETS'),
                  onPressed: () async {
                    if (configuredUrl.isEmpty) {
                      Navigator.pop(ctx);
                      mostraDialogImpostazioniUrl(context, ref);
                      return;
                    }

                    Navigator.pop(ctx);
                    final count = await ref
                        .read(syncControllerProvider.notifier)
                        .sincronizzaCatalogoDaGoogleSheets();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: count > 0
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                          content: Text(
                            count > 0
                                ? 'Catalogo aggiornato: $count materiali e categorie caricati da Google Sheets!'
                                : 'Nessun nuovo materiale trovato o catalogo già allineato.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Pulsante per reinizializzare il database SQLite locale (reset and seed)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text(
                    'REINIZIALIZZA DATABASE LOCALE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _confermaReinizializzazione(context, ref);
                  },
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confermaReinizializzazione(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confermato = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Reinizializzare il DB?'),
          ],
        ),
        content: const Text(
          'Questa operazione azzererà tutte le schede prelievo salvate localmente '
          'e ripopolerà il catalogo con i 40 materiali ufficiali del Speleo Club Roma.\n\n'
          'Se hai schede non sincronizzate su Google Sheets, andranno perse.\n\n'
          'Vuoi procedere?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Reinizializza'),
          ),
        ],
      ),
    );

    if (confermato == true) {
      await DatabaseHelper.instance.resetAndSeed();
      // Invalida tutti i provider per aggiornare immediatamente la UI
      ref.invalidate(catalogoListProvider);
      ref.invalidate(prelieviListProvider);
      ref.invalidate(prelieviInAttesaProvider);
      ref.invalidate(storicoRaggruppatoProvider);
      ref.invalidate(pendingSyncCountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.indigo.shade800,
            content: const Text(
              'Database locale reinizializzato con successo! Catalogo ufficiale ripristinato.',
            ),
          ),
        );
      }
    }
  }

  static void mostraDialogImpostazioniUrl(BuildContext context, WidgetRef ref) {
    final currentUrlAsync = ref.read(googleSheetsUrlProvider);
    final textController = TextEditingController(
      text: currentUrlAsync.valueOrNull ?? '',
    );
    String? statusMessage;
    bool isSuccess = false;
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.link, color: Colors.deepOrange),
                  SizedBox(width: 8),
                  Text('Google Sheets Web App'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Incolla l\'URL della Web App di Google Apps Script creata sul tuo foglio di Google Drive (termina con /exec):',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'URL Web App Google Apps Script',
                        hintText: 'https://script.google.com/macros/s/.../exec',
                        prefixIcon: Icon(Icons.http),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    if (statusMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSuccess ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Text(
                          statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: isTesting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.network_check, size: 18),
                            label: const Text('Test Connessione'),
                            onPressed: isTesting
                                ? null
                                : () async {
                                    if (!dialogContext.mounted) return;
                                    setDialogState(() {
                                      isTesting = true;
                                      statusMessage = null;
                                    });
                                    final testRes = await ref
                                        .read(syncControllerProvider.notifier)
                                        .testConnessione(textController.text);
                                    if (!dialogContext.mounted) return;
                                    setDialogState(() {
                                      isTesting = false;
                                      isSuccess = testRes.isSuccess;
                                      statusMessage = testRes.isSuccess
                                          ? 'OK! Connesso a: "${testRes.spreadsheetName}"'
                                          : 'Fallito: ${testRes.errorMessage}';
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.sync_alt, size: 18),
                            label: const Text('Aggiorna Catalogo da Sheet'),
                            onPressed: () async {
                              final count = await ref
                                  .read(syncControllerProvider.notifier)
                                  .sincronizzaCatalogoDaGoogleSheets(textController.text);
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                isSuccess = count > 0;
                                statusMessage = count > 0
                                    ? 'Aggiornati $count materiali dal foglio Google!'
                                    : 'Nessun nuovo materiale trovato nel foglio.';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    await ref
                        .read(syncControllerProvider.notifier)
                        .salvaUrlGoogleSheets(textController.text);
                    if (context.mounted) {
                      Navigator.pop(dCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL Google Sheets salvato con successo!'),
                        ),
                      );
                    }
                  },
                  child: const Text('Salva URL'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() => textController.dispose());
  }
}
