import 'package:flutter/foundation.dart';

/// Rappresenta un elemento dell'anagrafica di magazzino (catalogo di sola lettura).
@immutable
class Catalogo {
  final String idMateriale;
  final String categoria;
  final String nomeOggetto;

  const Catalogo({
    required this.idMateriale,
    required this.categoria,
    required this.nomeOggetto,
  });

  /// Indica se il materiale è una corda o materiale lineare misurato in metri (m)
  bool get isMetri {
    final catLower = categoria.toLowerCase().trim();
    final nomeLower = nomeOggetto.toLowerCase().trim();
    final idLower = idMateriale.toLowerCase().trim();

    // Cordini, sacchi e guaine sono sempre trattati a pezzi (pz)
    if (nomeLower.contains('cordin') ||
        nomeLower.contains('sacch') ||
        nomeLower.contains('guain') ||
        idLower == 'c_002' ||
        idLower == 'c_003' ||
        idLower == 'c_004') {
      return false;
    }

    if (idLower == 'c_001' || idLower == 'r_003') {
      return true;
    }
    if (catLower == 'corde') {
      return true;
    }
    if (nomeLower.contains('corda') ||
        nomeLower.contains('corde') ||
        nomeLower.contains('fettucci') ||
        nomeLower.contains('spezzon')) {
      return true;
    }
    return false;
  }

  /// Restituisce l'unità di misura ('m' per metri, 'pz' per pezzi)
  String get unitaMisura => isMetri ? 'm' : 'pz';

  Catalogo copyWith({
    String? idMateriale,
    String? categoria,
    String? nomeOggetto,
  }) {
    return Catalogo(
      idMateriale: idMateriale ?? this.idMateriale,
      categoria: categoria ?? this.categoria,
      nomeOggetto: nomeOggetto ?? this.nomeOggetto,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_materiale': idMateriale,
      'categoria': categoria,
      'nome_oggetto': nomeOggetto,
    };
  }

  factory Catalogo.fromMap(Map<String, dynamic> map) {
    return Catalogo(
      idMateriale: map['id_materiale'] as String,
      categoria: map['categoria'] as String,
      nomeOggetto: map['nome_oggetto'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Catalogo &&
          runtimeType == other.runtimeType &&
          idMateriale == other.idMateriale &&
          categoria == other.categoria &&
          nomeOggetto == other.nomeOggetto;

  @override
  int get hashCode =>
      idMateriale.hashCode ^ categoria.hashCode ^ nomeOggetto.hashCode;

  @override
  String toString() {
    return 'Catalogo(idMateriale: $idMateriale, categoria: $categoria, nomeOggetto: $nomeOggetto)';
  }
}
