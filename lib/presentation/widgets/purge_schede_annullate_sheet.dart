import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/prelievo.dart';
import '../providers/prelievi_provider.dart';

/// Modal BottomSheet per l'eliminazione definitiva (Purge) delle schede annullate.
/// Consente di rimuovere i record fisicamente dal database SQLite locale,
/// cancellare i file allegati associati e facoltativamente pulire anche Google Sheets.
class PurgeSchedeAnnullateSheet extends ConsumerStatefulWidget {
  /// Se specificate, effettua il purge solo di queste schede.
  /// Se null, effettua il purge di tutte le schede annullate presenti nel DB.
  final List<Prelievo>? prelieviDaEliminare;

  /// Callback invocata al completamento con successo del purge
  final VoidCallback? onPurgeCompletato;

  const PurgeSchedeAnnullateSheet({
    super.key,
    this.prelieviDaEliminare,
    this.onPurgeCompletato,
  });

  /// Metodo statico di utilità per mostrare la BottomSheet
  static Future<void> mostra(
    BuildContext context, {
    List<Prelievo>? prelievi,
    VoidCallback? onPurgeCompletato,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PurgeSchedeAnnullateSheet(
        prelieviDaEliminare: prelievi,
        onPurgeCompletato: onPurgeCompletato,
      ),
    );
  }

  @override
  ConsumerState<PurgeSchedeAnnullateSheet> createState() =>
      _PurgeSchedeAnnullateSheetState();
}

class _PurgeSchedeAnnullateSheetState
    extends ConsumerState<PurgeSchedeAnnullateSheet> {
  bool _eliminaAncheSuSheets = true;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Se la lista è passata dall'esterno usa quella, altrimenti ascolta schedeAnnullateProvider
    if (widget.prelieviDaEliminare != null) {
      return _buildContent(context, widget.prelieviDaEliminare!, theme);
    }

    final annullateAsync = ref.watch(schedeAnnullateProvider);

    return annullateAsync.when(
      data: (schede) => _buildContent(context, schede, theme),
      loading: () => const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text('Errore nel recupero schede annullate: $err'),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Prelievo> schede,
    ThemeData theme,
  ) {
    final count = schede.length;
    final conteggioAllegati =
        schede.where((p) => p.allegatoPath != null).length;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle di trascinamento
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header con icona Cestino
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Eliminazione Definitiva (Purge)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        count == 1
                            ? '1 scheda annullata selezionata'
                            : '$count schede annullate selezionate',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            if (count == 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 48,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nessuna scheda annullata presente.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Il database locale è già pulito.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Chiudi'),
              ),
            ] else ...[
              // Box di avviso irreversibilità
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Questa operazione eliminerà fisicamente i record dal database SQLite '
                        'e cancellerà per sempre i relativi file allegati dalla memoria del telefono. Non è possibile annullarla.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade900,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Lista schede interessate (scrollabile se molte)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: schede.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final p = schede[idx];
                    final dateStr =
                        '${p.dataPrelievo.day.toString().padLeft(2, '0')}/${p.dataPrelievo.month.toString().padLeft(2, '0')}/${p.dataPrelievo.year}';
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFF3F4F6),
                        child: Icon(Icons.cancel_outlined,
                            size: 16, color: Colors.grey),
                      ),
                      title: Text(
                        p.luogoGrotta,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$dateStr • Resp: ${p.responsabile}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: p.allegatoPath != null
                          ? const Tooltip(
                              message: 'Contiene file allegato',
                              child: Icon(Icons.attach_file,
                                  size: 18, color: Colors.blueGrey),
                            )
                          : null,
                    );
                  },
                ),
              ),

              if (conteggioAllegati > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.folder_delete_outlined,
                        size: 16, color: Colors.deepOrange),
                    const SizedBox(width: 6),
                    Text(
                      '$conteggioAllegati ${conteggioAllegati == 1 ? 'file allegato verrà eliminato' : 'file allegati verranno eliminati'} per liberare spazio.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Switch eliminazione remota su Google Sheets
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: theme.colorScheme.primary,
                title: const Text(
                  'Elimina definitivamente anche da Google Sheets',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Rimuove le righe annullate dal foglio per evitare che vengano riscaricate',
                  style: TextStyle(fontSize: 12),
                ),
                value: _eliminaAncheSuSheets,
                onChanged: (val) => setState(() => _eliminaAncheSuSheets = val),
              ),

              const SizedBox(height: 16),

              // Pulsanti azione (min 48x48dp)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isDeleting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Annulla'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                        onPressed: _isDeleting
                            ? null
                            : () => _confermaEEseguiPurge(context, schede),
                        icon: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.delete_forever_rounded),
                        label: Text(
                          _isDeleting
                              ? 'Eliminazione...'
                              : (count == 1
                                  ? 'ELIMINA PER SEMPRE'
                                  : 'ELIMINA TUTTE ($count)'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confermaEEseguiPurge(
    BuildContext sheetContext,
    List<Prelievo> schede,
  ) async {
    final count = schede.length;
    final confermato = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Conferma Eliminazione Definitiva'),
        content: Text(
          count == 1
              ? 'Sei sicuro di voler eliminare per sempre questa scheda annullata e tutti i suoi dati dal dispositivo?'
              : 'Sei sicuro di voler eliminare per sempre tutte le $count schede annullate e i relativi dati dal dispositivo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Indietro'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sì, elimina definitivamente'),
          ),
        ],
      ),
    );

    if (confermato != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      final ids = schede.map((p) => p.id).toList();
      final eliminati = await ref
          .read(prelieviControllerProvider.notifier)
          .purgeSchedeAnnullate(
            prelievoIds: ids,
            purgeRemote: _eliminaAncheSuSheets,
          );

      if (mounted) {
        Navigator.of(context).pop();

        widget.onPurgeCompletato?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    eliminati == 1
                        ? 'Scheda annullata eliminata definitivamente!'
                        : '$eliminati schede annullate eliminate definitivamente!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Errore durante l\'eliminazione: $e'),
          ),
        );
      }
    }
  }
}
