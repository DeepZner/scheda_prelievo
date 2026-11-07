/// Enum che rappresenta lo stato di un prelievo di attrezzatura speleologica.
enum StatoPrelievo {
  inAttesa('In attesa materiale'),
  rientrato('Materiale rientrato'),
  mancante('Materiale mancante');

  final String label;
  const StatoPrelievo(this.label);

  static StatoPrelievo fromString(String value) {
    for (final stato in StatoPrelievo.values) {
      if (stato.label.toLowerCase() == value.toLowerCase() ||
          stato.name.toLowerCase() == value.toLowerCase()) {
        return stato;
      }
    }
    return StatoPrelievo.inAttesa;
  }
}
