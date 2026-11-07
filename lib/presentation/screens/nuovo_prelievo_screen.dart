import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/catalogo.dart';
import '../../domain/models/dettaglio_prelievo.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import '../providers/catalogo_provider.dart';
import '../providers/database_providers.dart';
import '../providers/prelievi_provider.dart';
import '../widgets/quantity_stepper.dart';

/// Schermata per la compilazione, registrazione e modifica di un prelievo di materiale.
/// Ottimizzata per l'uso ad una mano con touch target minimi di 48x48dp.
class NuovoPrelievoScreen extends ConsumerStatefulWidget {
  final String? editPrelievoId;

  const NuovoPrelievoScreen({super.key, this.editPrelievoId});

  @override
  ConsumerState<NuovoPrelievoScreen> createState() => _NuovoPrelievoScreenState();
}

class _NuovoPrelievoScreenState extends ConsumerState<NuovoPrelievoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _luogoController = TextEditingController();
  final _responsabileController = TextEditingController();
  final _parereController = TextEditingController();

  DateTime _dataPrelievo = DateTime.now();

  // Mappa dei materiali selezionati: idMateriale -> {Catalogo, quantita}
  final Map<String, _MaterialeSelezionato> _materialiScelti = {};

  final _uuid = const Uuid();
  bool _caricamentoInizialeCompletato = false;

  bool get isEditing => widget.editPrelievoId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _caricaDatiPrelievoDaModificare();
      });
    } else {
      _caricamentoInizialeCompletato = true;
    }
  }

  Future<void> _caricaDatiPrelievoDaModificare() async {
    final repository = ref.read(prelievoRepositoryProvider);
    final p = await repository.getPrelievoById(widget.editPrelievoId!);
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prelievo non trovato.')),
      );
      Navigator.of(context).pop();
      return;
    }
    if (!p.isModificabile) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Modifica non consentita'),
          content: Text(
            p.stato != StatoPrelievo.inAttesa
                ? 'Questo prelievo è già concluso (${p.stato.label}) e non può essere modificato.'
                : 'La spunta rientro per questo prelievo è già stata avviata: la scheda è bloccata.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ho capito'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _luogoController.text = p.luogoGrotta;
      _responsabileController.text = p.responsabile;
      _parereController.text = p.parere ?? '';
      _dataPrelievo = p.dataPrelievo;
      _materialiScelti.clear();
      for (final d in p.dettagli) {
        _materialiScelti[d.materialeId] = _MaterialeSelezionato(
          materiale: Catalogo(
            idMateriale: d.materialeId,
            categoria: d.categoriaMateriale ?? '',
            nomeOggetto: d.nomeMateriale ?? d.materialeId,
          ),
          quantita: d.quantitaPrelevata,
        );
      }
      _caricamentoInizialeCompletato = true;
    });
  }

  @override
  void dispose() {
    _luogoController.dispose();
    _responsabileController.dispose();
    _parereController.dispose();
    super.dispose();
  }

  void _aggiungiOIncrementaMateriale(Catalogo materiale) {
    setState(() {
      if (_materialiScelti.containsKey(materiale.idMateriale)) {
        final current = _materialiScelti[materiale.idMateriale]!;
        _materialiScelti[materiale.idMateriale] = current.copyWith(
          quantita: current.quantita + 1,
        );
      } else {
        _materialiScelti[materiale.idMateriale] = _MaterialeSelezionato(
          materiale: materiale,
          quantita: 1,
        );
      }
    });
  }

  void _rimuoviMateriale(String idMateriale) {
    setState(() {
      _materialiScelti.remove(idMateriale);
    });
  }

  void _aggiornaQuantita(String idMateriale, int nuovaQta) {
    if (nuovaQta <= 0) {
      _rimuoviMateriale(idMateriale);
    } else {
      setState(() {
        final current = _materialiScelti[idMateriale]!;
        _materialiScelti[idMateriale] = current.copyWith(quantita: nuovaQta);
      });
    }
  }

  /// Mostra il BottomSheet di selezione dal catalogo SQLite
  Future<void> _mostraBottomSheetCatalogo() async {
    // Assicura il ricaricamento del catalogo aggiornato
    ref.invalidate(catalogoListProvider);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        String selectedCategory = 'Tutti';
        String searchQuery = '';

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.88,
              child: Column(
                children: [
                  // Handle di trascinamento
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Seleziona dal Catalogo',
                            style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(bottomSheetContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Campo di ricerca rapida
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cerca materiale speleo...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val.trim();
                        });
                      },
                    ),
                  ),
                  // Chip orizzontali per filtro categorie
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        'Tutti',
                        'Corde',
                        'Armo',
                        'Trapano',
                        'Disostr.',
                        'Attrezzature',
                        'Rilievo',
                      ].map((cat) {
                        final isSelected = selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(cat),
                            onSelected: (_) {
                              setModalState(() {
                                selectedCategory = cat;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Consumer(
                      builder: (consumerContext, ref, _) {
                        final catalogoAsync = ref.watch(catalogoListProvider);
                        return catalogoAsync.when(
                          data: (materiali) {
                            final materialiFiltrati = materiali.where((m) {
                              final matchCat = selectedCategory == 'Tutti' ||
                                  m.categoria.toLowerCase() == selectedCategory.toLowerCase();
                              final matchSearch = searchQuery.isEmpty ||
                                  m.nomeOggetto
                                      .toLowerCase()
                                      .contains(searchQuery.toLowerCase());
                              return matchCat && matchSearch;
                            }).toList();

                            if (materialiFiltrati.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('Nessun materiale corrisponde ai filtri.'),
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: materialiFiltrati.length,
                              itemBuilder: (itemContext, index) {
                                final mat = materialiFiltrati[index];
                                final isGiaPresente =
                                    _materialiScelti.containsKey(mat.idMateriale);
                                final qtaSelezionata =
                                    _materialiScelti[mat.idMateriale]?.quantita ?? 0;

                                return Card(
                                  elevation: 0.5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isGiaPresente
                                          ? Theme.of(itemContext).colorScheme.primary
                                          : Colors.grey.shade300,
                                      width: isGiaPresente ? 1.5 : 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      _aggiungiOIncrementaMateriale(mat);
                                      Navigator.pop(bottomSheetContext);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          // Icona Categoria con dimensioni fisse (48x48dp)
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isGiaPresente
                                                  ? Theme.of(itemContext).colorScheme.primary
                                                  : Theme.of(itemContext).colorScheme.surfaceContainerHighest,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _iconaPerCategoria(mat.categoria),
                                              color: isGiaPresente
                                                  ? Colors.white
                                                  : Theme.of(itemContext).colorScheme.onSurfaceVariant,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Dettagli testo (titolo e categoria/quantità)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  mat.nomeOggetto,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  isGiaPresente
                                                      ? '${mat.categoria.toUpperCase()} • Quantità: $qtaSelezionata'
                                                      : mat.categoria.toUpperCase(),
                                                  style: TextStyle(
                                                    color: isGiaPresente
                                                        ? Theme.of(itemContext).colorScheme.primary
                                                        : Colors.grey.shade600,
                                                    fontSize: 12,
                                                    fontWeight: isGiaPresente
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Pulsante grande Aggiungi rapido (touch target 48x48dp)
                                          SizedBox(
                                            height: 48,
                                            width: 48,
                                            child: IconButton(
                                              iconSize: 28,
                                              icon: Icon(
                                                isGiaPresente
                                                    ? Icons.add_circle
                                                    : Icons.add_circle_outline,
                                                color: Theme.of(itemContext).colorScheme.primary,
                                              ),
                                              onPressed: () {
                                                _aggiungiOIncrementaMateriale(mat);
                                                setModalState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (err, stack) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline, size: 40, color: Colors.red),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Errore caricamento catalogo:\n$err',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: () => ref.refresh(catalogoListProvider),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Riprova'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconaPerCategoria(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'corde':
        return Icons.linear_scale;
      case 'armo':
        return Icons.link;
      case 'trapano':
        return Icons.build;
      case 'rilievo':
        return Icons.square_foot;
      case 'disostr.':
        return Icons.hardware;
      default:
        return Icons.handyman;
    }
  }

  Future<void> _salvaPrelievo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_materialiScelti.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Aggiungi almeno un materiale prima di salvare!'),
        ),
      );
      return;
    }

    final prelievoId = isEditing ? widget.editPrelievoId! : _uuid.v4();

    // Costruzione righe di dettaglio con is_synced = 0
    final List<DettaglioPrelievo> dettagli = _materialiScelti.values.map((item) {
      return DettaglioPrelievo(
        idDettaglio: _uuid.v4(),
        prelievoId: prelievoId,
        materialeId: item.materiale.idMateriale,
        quantitaPrelevata: item.quantita,
        spuntaRientro: false,
        qtaTornata: null,
        noteRientro: null,
        isSynced: false, // is_synced = 0
        nomeMateriale: item.materiale.nomeOggetto,
        categoriaMateriale: item.materiale.categoria,
      );
    }).toList();

    // Costruzione testata con is_synced = 0
    final prelievo = Prelievo(
      id: prelievoId,
      dataPrelievo: _dataPrelievo,
      luogoGrotta: _luogoController.text.trim(),
      responsabile: _responsabileController.text.trim(),
      stato: StatoPrelievo.inAttesa,
      parere: _parereController.text.trim().isEmpty
          ? null
          : _parereController.text.trim(),
      isSynced: false, // is_synced = 0
      dettagli: dettagli,
    );

    if (isEditing) {
      await ref
          .read(prelieviControllerProvider.notifier)
          .aggiornaPrelievo(prelievo);
    } else {
      await ref
          .read(prelieviControllerProvider.notifier)
          .salvaNuovoPrelievo(prelievo);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade800,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                isEditing
                    ? 'Prelievo aggiornato con successo!'
                    : 'Prelievo registrato con successo!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controllerState = ref.watch(prelieviControllerProvider);
    final isLoading = controllerState.isLoading;

    if (isEditing && !_caricamentoInizialeCompletato) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Modifica Prelievo'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifica Prelievo' : 'Nuovo Prelievo'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Card Dati Testata
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
                            Text(
                              'Dati Testata',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Campo Luogo / Grotta
                            TextFormField(
                              controller: _luogoController,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Luogo / Grotta *',
                                hintText: 'Es. Grotta del Fiume, Pozzo Comune',
                                prefixIcon: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(Icons.terrain_rounded, size: 28),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Inserisci il luogo o la grotta';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Campo Responsabile
                            TextFormField(
                              controller: _responsabileController,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Responsabile Prelievo *',
                                hintText: 'Nome e Cognome',
                                prefixIcon: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(Icons.person_rounded, size: 28),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Inserisci il responsabile';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Selettore Data Prelievo (Touch target ampio)
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dataPrelievo,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setState(() => _dataPrelievo = picked);
                                }
                              },
                              child: Container(
                                height: 56,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 26),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Data: ${_dataPrelievo.day.toString().padLeft(2, '0')}/${_dataPrelievo.month.toString().padLeft(2, '0')}/${_dataPrelievo.year}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.arrow_drop_down, size: 28),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Campo Note / Parere (opzionale)
                            TextFormField(
                              controller: _parereController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Note / Parere (opzionale)',
                                hintText: 'Es. Destinazione armo ramo nord',
                                prefixIcon: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(Icons.notes_rounded, size: 26),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Intestazione Sezione Materiali
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Materiali da Prelevare (${_materialiScelti.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Pulsante grande per aprire BottomSheet catalogo (min 48dp)
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(120, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _mostraBottomSheetCatalogo,
                          icon: const Icon(Icons.add_shopping_cart, size: 22),
                          label: const Text(
                            'Aggiungi',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lista dinamica dei materiali scelti
                    if (_materialiScelti.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 36, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.backpack_outlined,
                              size: 48,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nessun materiale ancora selezionato.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tocca "Aggiungi" per pescare dal catalogo.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._materialiScelti.values.map((item) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 1.5,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Icon(
                                    _iconaPerCategoria(item.materiale.categoria),
                                    size: 20,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.materiale.nomeOggetto,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        item.materiale.categoria,
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Stepper ergonomico a grande touch target (48x48)
                                QuantityStepper(
                                  value: item.quantita,
                                  minValue: 1,
                                  onChanged: (newVal) => _aggiornaQuantita(
                                    item.materiale.idMateriale,
                                    newVal,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Pulsante Cancella (touch target 48x48)
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 24,
                                    ),
                                    onPressed: () => _rimuoviMateriale(
                                      item.materiale.idMateriale,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),

              // Bottom Bar ergonomica con pulsante di salvataggio (altezza 56dp per uso con una sola mano)
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
                  height: 56, // Touch target grande per il pollice
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isLoading ? null : _salvaPrelievo,
                    icon: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isEditing ? Icons.save : Icons.check_circle_outline,
                            size: 26,
                          ),
                    label: Text(
                      isLoading
                          ? 'Salvataggio in corso...'
                          : (isEditing
                              ? 'SALVA MODIFICHE (${_materialiScelti.values.fold(0, (sum, i) => sum + i.quantita)} PEZZI)'
                              : 'REGISTRA PRELIEVO (${_materialiScelti.values.fold(0, (sum, i) => sum + i.quantita)} PEZZI)'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialeSelezionato {
  final Catalogo materiale;
  final int quantita;

  _MaterialeSelezionato({
    required this.materiale,
    required this.quantita,
  });

  _MaterialeSelezionato copyWith({
    Catalogo? materiale,
    int? quantita,
  }) {
    return _MaterialeSelezionato(
      materiale: materiale ?? this.materiale,
      quantita: quantita ?? this.quantita,
    );
  }
}
