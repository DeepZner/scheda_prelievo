import 'package:flutter/foundation.dart';
import 'dettaglio_prelievo.dart';
import 'stato_prelievo.dart';

/// Rappresenta la testata di una scheda di prelievo materiale.
@immutable
class Prelievo {
  final String id;
  final DateTime dataPrelievo;
  final String luogoGrotta;
  final String responsabile;
  final StatoPrelievo stato;
  final String? parere;
  final bool isSynced;
  final List<DettaglioPrelievo> dettagli;
  final DateTime? dataRientro;
  final String? operatoreRientro;
  final String? emailMagazzinieri;
  final String? relazioneTesto;
  final String? relazioneAutore;
  final DateTime? relazioneData;
  final String? allegatoPath;
  final String? allegatoNome;
  final String? allegatoDriveUrl;

  const Prelievo({
    required this.id,
    required this.dataPrelievo,
    required this.luogoGrotta,
    required this.responsabile,
    this.stato = StatoPrelievo.inAttesa,
    this.parere,
    this.isSynced = false,
    this.dettagli = const [],
    this.dataRientro,
    this.operatoreRientro,
    this.emailMagazzinieri,
    this.relazioneTesto,
    this.relazioneAutore,
    this.relazioneData,
    this.allegatoPath,
    this.allegatoNome,
    this.allegatoDriveUrl,
  });

  /// Un prelievo è modificabile solo se è in attesa materiale e la spunta non è ancora iniziata
  bool get isModificabile {
    if (stato != StatoPrelievo.inAttesa) return false;
    final haIniziato = dettagli.any((d) =>
        d.spuntaRientro ||
        (d.qtaTornata != null && d.qtaTornata != d.quantitaPrelevata) ||
        (d.noteRientro != null && d.noteRientro!.trim().isNotEmpty));
    return !haIniziato;
  }

  /// Numero di articoli con spunta rientro attiva
  int get articoliSpuntatiCount =>
      dettagli.where((d) => d.spuntaRientro).length;

  /// Indica se la procedura di spunta/rientro è in corso (bozza salvata o spunta avviata)
  bool get haSpuntaInCorso => !isModificabile && stato == StatoPrelievo.inAttesa;

  /// Calcola il totale complessivo dei pezzi fisici prelevati:
  /// ogni inserimento di corda in metri equivale a 1 singolo pezzo (matassa di corda),
  /// mentre gli altri materiali contano per la quantità inserita.
  int get totalePezzi =>
      dettagli.fold<int>(0, (sum, d) => sum + d.numeroPezzi);

  /// Numero di matasse / spezzoni di corda inseriti
  int get totaleMatasse => dettagli.where((d) => d.isMetri).length;

  /// Metri complessivi di corde/cordini/fettucce
  int get totaleMetri => dettagli
      .where((d) => d.isMetri)
      .fold<int>(0, (sum, d) => sum + d.quantitaPrelevata);

  /// Indica se la scheda include una relazione di uscita (testuale o allegato)
  bool get haRelazione =>
      (relazioneTesto != null && relazioneTesto!.trim().isNotEmpty) ||
      haAllegato;

  /// Indica se è presente un file/documento allegato (locale o salvato su Drive)
  bool get haAllegato =>
      (allegatoPath != null && allegatoPath!.trim().isNotEmpty) ||
      (allegatoNome != null && allegatoNome!.trim().isNotEmpty);

  Prelievo copyWith({
    String? id,
    DateTime? dataPrelievo,
    String? luogoGrotta,
    String? responsabile,
    StatoPrelievo? stato,
    String? parere,
    bool? isSynced,
    List<DettaglioPrelievo>? dettagli,
    DateTime? dataRientro,
    String? operatoreRientro,
    String? emailMagazzinieri,
    String? relazioneTesto,
    String? relazioneAutore,
    DateTime? relazioneData,
    String? allegatoPath,
    String? allegatoNome,
    String? allegatoDriveUrl,
  }) {
    return Prelievo(
      id: id ?? this.id,
      dataPrelievo: dataPrelievo ?? this.dataPrelievo,
      luogoGrotta: luogoGrotta ?? this.luogoGrotta,
      responsabile: responsabile ?? this.responsabile,
      stato: stato ?? this.stato,
      parere: parere ?? this.parere,
      isSynced: isSynced ?? this.isSynced,
      dettagli: dettagli ?? this.dettagli,
      dataRientro: dataRientro ?? this.dataRientro,
      operatoreRientro: operatoreRientro ?? this.operatoreRientro,
      emailMagazzinieri: emailMagazzinieri ?? this.emailMagazzinieri,
      relazioneTesto: relazioneTesto ?? this.relazioneTesto,
      relazioneAutore: relazioneAutore ?? this.relazioneAutore,
      relazioneData: relazioneData ?? this.relazioneData,
      allegatoPath: allegatoPath ?? this.allegatoPath,
      allegatoNome: allegatoNome ?? this.allegatoNome,
      allegatoDriveUrl: allegatoDriveUrl ?? this.allegatoDriveUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'data_prelievo': dataPrelievo.toIso8601String(),
      'luogo_grotta': luogoGrotta,
      'responsabile': responsabile,
      'stato': stato.label,
      'parere': parere,
      'is_synced': isSynced ? 1 : 0,
      'data_rientro': dataRientro?.toIso8601String(),
      'operatore_rientro': operatoreRientro,
      'email_magazzinieri': emailMagazzinieri,
      'relazione_testo': relazioneTesto,
      'relazione_autore': relazioneAutore,
      'relazione_data': relazioneData?.toIso8601String(),
      'allegato_path': allegatoPath,
      'allegato_nome': allegatoNome,
      'allegato_drive_url': allegatoDriveUrl,
    };
  }

  factory Prelievo.fromMap(
    Map<String, dynamic> map, {
    List<DettaglioPrelievo> dettagli = const [],
  }) {
    return Prelievo(
      id: map['id'] as String,
      dataPrelievo: DateTime.parse(map['data_prelievo'] as String),
      luogoGrotta: map['luogo_grotta'] as String,
      responsabile: map['responsabile'] as String,
      stato: StatoPrelievo.fromString(map['stato'] as String? ?? ''),
      parere: map['parere'] as String?,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      dettagli: dettagli,
      dataRientro: map['data_rientro'] != null
          ? DateTime.tryParse(map['data_rientro'] as String)
          : null,
      operatoreRientro: map['operatore_rientro'] as String?,
      emailMagazzinieri: map['email_magazzinieri'] as String?,
      relazioneTesto: map['relazione_testo'] as String?,
      relazioneAutore: map['relazione_autore'] as String?,
      relazioneData: map['relazione_data'] != null
          ? DateTime.tryParse(map['relazione_data'] as String)
          : null,
      allegatoPath: map['allegato_path'] as String?,
      allegatoNome: map['allegato_nome'] as String?,
      allegatoDriveUrl: map['allegato_drive_url'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Prelievo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          dataPrelievo == other.dataPrelievo &&
          luogoGrotta == other.luogoGrotta &&
          responsabile == other.responsabile &&
          stato == other.stato &&
          parere == other.parere &&
          isSynced == other.isSynced &&
          dataRientro == other.dataRientro &&
          operatoreRientro == other.operatoreRientro &&
          emailMagazzinieri == other.emailMagazzinieri &&
          relazioneTesto == other.relazioneTesto &&
          relazioneAutore == other.relazioneAutore &&
          relazioneData == other.relazioneData &&
          allegatoPath == other.allegatoPath &&
          allegatoNome == other.allegatoNome &&
          allegatoDriveUrl == other.allegatoDriveUrl &&
          listEquals(dettagli, other.dettagli);

  @override
  int get hashCode =>
      id.hashCode ^
      dataPrelievo.hashCode ^
      luogoGrotta.hashCode ^
      responsabile.hashCode ^
      stato.hashCode ^
      parere.hashCode ^
      isSynced.hashCode ^
      dataRientro.hashCode ^
      operatoreRientro.hashCode ^
      emailMagazzinieri.hashCode ^
      relazioneTesto.hashCode ^
      relazioneAutore.hashCode ^
      relazioneData.hashCode ^
      allegatoPath.hashCode ^
      allegatoNome.hashCode ^
      allegatoDriveUrl.hashCode ^
      dettagli.hashCode;

  @override
  String toString() {
    return 'Prelievo(id: $id, dataPrelievo: $dataPrelievo, luogoGrotta: $luogoGrotta, responsabile: $responsabile, stato: ${stato.label}, isSynced: $isSynced, dataRientro: $dataRientro, operatore: $operatoreRientro, haRelazione: $haRelazione, dettagli: ${dettagli.length})';
  }
}
