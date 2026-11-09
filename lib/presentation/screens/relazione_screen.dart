import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/allegati_service.dart';
import '../../domain/models/prelievo.dart';
import '../providers/prelievi_provider.dart';

class RelazioneScreen extends ConsumerStatefulWidget {
  final String prelievoId;

  const RelazioneScreen({super.key, required this.prelievoId});

  @override
  ConsumerState<RelazioneScreen> createState() => _RelazioneScreenState();
}

class _RelazioneScreenState extends ConsumerState<RelazioneScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _autoreController;
  late TextEditingController _testoController;
  late DateTime _dataRelazione;

  String? _allegatoPath;
  String? _allegatoNome;
  String? _allegatoDriveUrl;
  bool _allegatoModificato = false;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _autoreController = TextEditingController();
    _testoController = TextEditingController();
    _dataRelazione = DateTime.now();
  }

  void _initFromPrelievo(Prelievo p) {
    if (_initialized) return;
    _initialized = true;
    _autoreController.text =
        p.relazioneAutore ?? (p.responsabile.isNotEmpty ? p.responsabile : '');
    _testoController.text = p.relazioneTesto ?? '';
    _dataRelazione = p.relazioneData ?? DateTime.now();
    _allegatoPath = p.allegatoPath;
    _allegatoNome = p.allegatoNome;
    _allegatoDriveUrl = p.allegatoDriveUrl;
  }

  @override
  void dispose() {
    _autoreController.dispose();
    _testoController.dispose();
    super.dispose();
  }

  Future<void> _selezionaData(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataRelazione,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      setState(() {
        _dataRelazione = picked;
      });
    }
  }

  Future<void> _scegliAllegato() async {
    try {
      final info = await AllegatiService.scegliDocumento();
      if (info == null) return;

      setState(() {
        _allegatoPath = info.path;
        _allegatoNome = info.name;
        _allegatoModificato = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento selezionato: ${info.name} (${info.sizeFormatted})'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore selezione file: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  void _rimuoviAllegato() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Rimuovi Allegato'),
        content: const Text('Sei sicuro di voler rimuovere il documento allegato a questa relazione?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dCtx);
              setState(() {
                _allegatoPath = null;
                _allegatoNome = null;
                _allegatoModificato = true;
              });
            },
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
  }

  Future<void> _apriAllegatoCorrente() async {
    if (_allegatoPath == null) return;
    final res = await AllegatiService.apriAllegato(_allegatoPath!);
    if (res.type != ResultType.done && res.message.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apertura file: ${res.message}')),
      );
    }
  }

  Future<void> _salvaRelazione(Prelievo p) async {
    final testo = _testoController.text.trim();
    final autore = _autoreController.text.trim();

    if (testo.isEmpty && (_allegatoPath == null || _allegatoPath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci una descrizione testuale oppure allega un documento per salvare la relazione.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? finalAllegatoPath = _allegatoPath;

      // Se l'allegato è stato appena selezionato o modificato, copialo nella memoria sicura permanente dell'app
      if (_allegatoModificato && _allegatoPath != null && _allegatoNome != null) {
        finalAllegatoPath = await AllegatiService.salvaAllegatoPermanente(
          prelievoId: p.id,
          sourceFilePath: _allegatoPath!,
          originalFileName: _allegatoNome!,
        );
      } else if (_allegatoModificato && _allegatoPath == null && p.allegatoPath != null) {
        // Se è stato rimosso l'allegato precedentemente memorizzato, elimina la copia locale
        await AllegatiService.eliminaAllegatoLocale(p.allegatoPath!);
      }

      await ref.read(prelieviControllerProvider.notifier).salvaRelazione(
        prelievoId: p.id,
        relazioneTesto: testo.isNotEmpty ? testo : null,
        relazioneAutore: autore.isNotEmpty ? autore : null,
        relazioneData: _dataRelazione,
        allegatoPath: finalAllegatoPath,
        allegatoNome: _allegatoNome,
        allegatoDriveUrl: _allegatoDriveUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Relazione salvata con successo!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file_outlined;
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (ext.endsWith('.doc') || ext.endsWith('.docx')) return Icons.description_outlined;
    if (ext.endsWith('.odt') || ext.endsWith('.ods') || ext.endsWith('.odp')) {
      return Icons.article_outlined;
    }
    if (ext.endsWith('.txt') || ext.endsWith('.rtf')) return Icons.text_snippet_outlined;
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png')) {
      return Icons.image_outlined;
    }
    return Icons.attach_file_rounded;
  }

  Color _getFileColor(String? fileName) {
    if (fileName == null) return Colors.blueGrey;
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.pdf')) return Colors.red.shade700;
    if (ext.endsWith('.doc') || ext.endsWith('.docx')) return Colors.blue.shade700;
    if (ext.endsWith('.odt') || ext.endsWith('.ods')) return Colors.orange.shade700;
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png')) {
      return Colors.green.shade700;
    }
    return Colors.blueGrey.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final prelievoAsync = ref.watch(prelievoDetailProvider(widget.prelievoId));

    return prelievoAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Caricamento...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Errore')),
        body: Center(child: Text('Errore: $err')),
      ),
      data: (prelievo) {
        if (prelievo == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Non trovato')),
            body: const Center(child: Text('Scheda prelievo non trovata.')),
          );
        }

        _initFromPrelievo(prelievo);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Relazione di Esplorazione',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${prelievo.luogoGrotta} • ${prelievo.responsabile}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner informativo
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueGrey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blueGrey.shade800, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'La relazione documenta l\'uscita, i lavori svolti e le condizioni della grotta. '
                            'Può essere compilata o arricchita con documenti in qualsiasi momento, anche a materiale già rientrato.',
                            style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Card 1: Dati Redazione (Autore e Data)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_pin_outlined, color: Theme.of(context).primaryColor, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Dati Redazione',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          TextFormField(
                            controller: _autoreController,
                            decoration: const InputDecoration(
                              labelText: 'Autore della Relazione',
                              hintText: 'Es. Mario Rossi',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: () => _selezionaData(context),
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Data della Relazione',
                                prefixIcon: Icon(Icons.calendar_month_outlined),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                '${_dataRelazione.day.toString().padLeft(2, '0')}/${_dataRelazione.month.toString().padLeft(2, '0')}/${_dataRelazione.year}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 2: Testo della Relazione
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.edit_note_rounded, color: Theme.of(context).primaryColor, size: 22),
                              const SizedBox(width: 8),
                              const Text(
                                'Resoconto dell\'Uscita',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Descrivi l\'esplorazione, rilievi, disostruzioni, armi lasciati o anomalie riscontrate:',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _testoController,
                            maxLines: 10,
                            minLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Scrivi qui la relazione di uscita...',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 3: Documento / File Allegato
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.attachment_rounded, color: Theme.of(context).primaryColor, size: 22),
                              const SizedBox(width: 8),
                              const Text(
                                'Documento Allegato',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Formati supportati: PDF, Word (DOC/DOCX), OpenOffice (ODT/ODS), Google Docs/Testo (TXT/RTF), Immagini (max 20 MB).',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 14),

                          if (_allegatoNome != null && _allegatoNome!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: _getFileColor(_allegatoNome).withAlpha(38),
                                        child: Icon(
                                          _getFileIcon(_allegatoNome),
                                          color: _getFileColor(_allegatoNome),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _allegatoNome!,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (_allegatoPath != null)
                                              Text(
                                                File(_allegatoPath!).existsSync()
                                                    ? 'File memorizzato localmente'
                                                    : 'File selezionato',
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (_allegatoPath != null && File(_allegatoPath!).existsSync())
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 44),
                                            ),
                                            icon: const Icon(Icons.open_in_new, size: 18),
                                            label: const Text('Apri File'),
                                            onPressed: _apriAllegatoCorrente,
                                          ),
                                        ),
                                      if (_allegatoPath != null && File(_allegatoPath!).existsSync())
                                        const SizedBox(width: 8),
                                      IconButton.filledTonal(
                                        tooltip: 'Sostituisci documento',
                                        icon: const Icon(Icons.sync_rounded),
                                        onPressed: _scegliAllegato,
                                      ),
                                      IconButton.filledTonal(
                                        tooltip: 'Rimuovi allegato',
                                        style: IconButton.styleFrom(foregroundColor: Colors.red.shade800),
                                        icon: const Icon(Icons.delete_outline_rounded),
                                        onPressed: _rimuoviAllegato,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.upload_file_rounded, size: 22),
                                label: const Text(
                                  'ALLEGA DOCUMENTO O IMMAGINE',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                onPressed: _scegliAllegato,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pulsante Salva Relazione
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 22),
                      label: Text(
                        _isSaving ? 'SALVATAGGIO IN CORSO...' : 'SALVA RELAZIONE',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: _isSaving ? null : () => _salvaRelazione(prelievo),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
