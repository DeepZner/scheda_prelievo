import 'package:flutter/foundation.dart';

/// Rappresenta una riga di dettaglio per un prelievo di materiale.
@immutable
class DettaglioPrelievo {
  final String idDettaglio;
  final String prelievoId;
  final String materialeId;
  final int quantitaPrelevata;
  final bool spuntaRientro;
  final int? qtaTornata;
  final String? noteRientro;
  final bool isSynced;

  // Campi risolti da JOIN con la tabella catalogo
  final String? nomeMateriale;
  final String? categoriaMateriale;

  const DettaglioPrelievo({
    required this.idDettaglio,
    required this.prelievoId,
    required this.materialeId,
    required this.quantitaPrelevata,
    this.spuntaRientro = false,
    this.qtaTornata,
    this.noteRientro,
    this.isSynced = false,
    this.nomeMateriale,
    this.categoriaMateriale,
  });

  /// Indica se il materiale è una corda o materiale lineare misurato in metri (m)
  bool get isMetri {
    final catLower = (categoriaMateriale ?? '').toLowerCase().trim();
    final nomeLower = (nomeMateriale ?? materialeId).toLowerCase().trim();
    final idLower = materialeId.toLowerCase().trim();

    if (idLower == 'c_001' || idLower == 'c_002' || idLower == 'r_003') {
      return true;
    }
    if (catLower == 'corde') {
      if (nomeLower.contains('sacch') || nomeLower.contains('guain')) {
        return false;
      }
      return true;
    }
    if (nomeLower.contains('corda') ||
        nomeLower.contains('corde') ||
        nomeLower.contains('cordino') ||
        nomeLower.contains('cordini') ||
        nomeLower.contains('fettucci') ||
        nomeLower.contains('spezzon')) {
      return true;
    }
    return false;
  }

  /// Restituisce l'unità di misura ('m' per metri, 'pz' per pezzi)
  String get unitaMisura => isMetri ? 'm' : 'pz';

  DettaglioPrelievo copyWith({
    String? idDettaglio,
    String? prelievoId,
    String? materialeId,
    int? quantitaPrelevata,
    bool? spuntaRientro,
    int? qtaTornata,
    String? noteRientro,
    bool? isSynced,
    String? nomeMateriale,
    String? categoriaMateriale,
  }) {
    return DettaglioPrelievo(
      idDettaglio: idDettaglio ?? this.idDettaglio,
      prelievoId: prelievoId ?? this.prelievoId,
      materialeId: materialeId ?? this.materialeId,
      quantitaPrelevata: quantitaPrelevata ?? this.quantitaPrelevata,
      spuntaRientro: spuntaRientro ?? this.spuntaRientro,
      qtaTornata: qtaTornata ?? this.qtaTornata,
      noteRientro: noteRientro ?? this.noteRientro,
      isSynced: isSynced ?? this.isSynced,
      nomeMateriale: nomeMateriale ?? this.nomeMateriale,
      categoriaMateriale: categoriaMateriale ?? this.categoriaMateriale,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_dettaglio': idDettaglio,
      'prelievo_id': prelievoId,
      'materiale_id': materialeId,
      'quantita_prelevata': quantitaPrelevata,
      'spunta_rientro': spuntaRientro ? 1 : 0,
      'qta_tornata': qtaTornata,
      'note_rientro': noteRientro,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory DettaglioPrelievo.fromMap(Map<String, dynamic> map) {
    return DettaglioPrelievo(
      idDettaglio: map['id_dettaglio'] as String,
      prelievoId: map['prelievo_id'] as String,
      materialeId: map['materiale_id'] as String,
      quantitaPrelevata: map['quantita_prelevata'] as int,
      spuntaRientro: (map['spunta_rientro'] as int? ?? 0) == 1,
      qtaTornata: map['qta_tornata'] as int?,
      noteRientro: map['note_rientro'] as String?,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      nomeMateriale: map['nome_oggetto'] as String?,
      categoriaMateriale: map['categoria'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DettaglioPrelievo &&
          runtimeType == other.runtimeType &&
          idDettaglio == other.idDettaglio &&
          prelievoId == other.prelievoId &&
          materialeId == other.materialeId &&
          quantitaPrelevata == other.quantitaPrelevata &&
          spuntaRientro == other.spuntaRientro &&
          qtaTornata == other.qtaTornata &&
          noteRientro == other.noteRientro &&
          isSynced == other.isSynced;

  @override
  int get hashCode =>
      idDettaglio.hashCode ^
      prelievoId.hashCode ^
      materialeId.hashCode ^
      quantitaPrelevata.hashCode ^
      spuntaRientro.hashCode ^
      qtaTornata.hashCode ^
      noteRientro.hashCode ^
      isSynced.hashCode;

  @override
  String toString() {
    return 'DettaglioPrelievo(idDettaglio: $idDettaglio, prelievoId: $prelievoId, materialeId: $materialeId, quantitaPrelevata: $quantitaPrelevata, spuntaRientro: $spuntaRientro, qtaTornata: $qtaTornata, isSynced: $isSynced)';
  }
}
