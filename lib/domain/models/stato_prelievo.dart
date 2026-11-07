/// Enum che rappresenta lo stato di un prelievo di attrezzatura speleologica.
enum StatoPrelievo {
  inAttesa('In attesa materiale'),
  rientrato('Materiale rientrato'),
  mancante('Materiale mancante'),
  annullato('Annullato');

  final String label;
  const StatoPrelievo(this.label);

  static StatoPrelievo fromString(String value) {
    final lower = value.trim().toLowerCase();
    if (lower == 'annullato' ||
        lower == 'cancellato' ||
        lower == 'eliminato') {
      return StatoPrelievo.annullato;
    }
    for (final stato in StatoPrelievo.values) {
      if (stato.label.toLowerCase() == lower ||
          stato.name.toLowerCase() == lower) {
        return stato;
      }
    }
    return StatoPrelievo.inAttesa;
  }
}
