import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/catalogo.dart';
import '../../domain/models/dettaglio_prelievo.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import 'sync_service.dart';

class GoogleSheetsPingResult {
  final bool isSuccess;
  final String? spreadsheetName;
  final String? errorMessage;

  const GoogleSheetsPingResult({
    required this.isSuccess,
    this.spreadsheetName,
    this.errorMessage,
  });
}

class GoogleSheetsUploadResult {
  final bool isSuccess;
  final int prelieviSynced;
  final int dettagliSynced;
  final String? errorMessage;

  const GoogleSheetsUploadResult({
    required this.isSuccess,
    this.prelieviSynced = 0,
    this.dettagliSynced = 0,
    this.errorMessage,
  });
}

class GoogleSheetsDownloadResult {
  final bool isSuccess;
  final List<Prelievo> prelievi;
  final List<DettaglioPrelievo> dettagli;
  final String? errorMessage;

  const GoogleSheetsDownloadResult({
    required this.isSuccess,
    this.prelievi = const [],
    this.dettagli = const [],
    this.errorMessage,
  });
}

class GoogleSheetsClient {
  final http.Client _client;

  GoogleSheetsClient({http.Client? client}) : _client = client ?? http.Client();

  /// Pulisce l'URL inserito rimuovendo apici, spazi accidentali o ritorni a capo
  static String sanitizeUrl(String rawUrl) {
    var url = rawUrl.trim();
    if ((url.startsWith('"') && url.endsWith('"')) ||
        (url.startsWith("'") && url.endsWith("'"))) {
      url = url.substring(1, url.length - 1).trim();
    }
    url = url.replaceAll(RegExp(r'\s+'), '');
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  String _formatNetworkError(dynamic e) {
    final str = e.toString();
    if (str.contains('Failed host lookup') || str.contains('SocketException') || str.contains('errno = 7')) {
      return 'Impossibile raggiungere Google Sheets (Failed host lookup).\n'
          'Verifica che il dispositivo sia connesso a Internet (Wi-Fi o Dati mobili) '
          'e che l\'URL della Web App sia corretto (deve terminare con /exec).';
    }
    if (str.contains('TimeoutException')) {
      return 'Timeout connessione: Google Sheets non ha risposto in tempo.';
    }
    return 'Connessione fallita: $str';
  }

  /// Esegue un ping di test verso l'URL della Web App di Google Apps Script
  Future<GoogleSheetsPingResult> testConnection(String webAppUrl) async {
    try {
      final cleanUrl = sanitizeUrl(webAppUrl);
      if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) {
        return const GoogleSheetsPingResult(
          isSuccess: false,
          errorMessage: 'URL Web App non valido. Deve iniziare con https://',
        );
      }

      if (cleanUrl.contains('docs.google.com/spreadsheets')) {
        return const GoogleSheetsPingResult(
          isSuccess: false,
          errorMessage: 'Hai inserito l\'URL del Foglio Google anziché della Web App!\n'
              'Nel foglio apri: Estensioni > Apps Script > Distribuisci > Nuova distribuzione (o Gestisci distribuzioni) '
              'e copia l\'URL che termina con /exec.',
        );
      }

      if (cleanUrl.endsWith('/dev')) {
        return const GoogleSheetsPingResult(
          isSuccess: false,
          errorMessage: 'Hai inserito l\'URL di test (/dev) anziché quello ufficiale (/exec).\n'
              'L\'URL /dev non è accessibile per la condivisione. Usa l\'URL della distribuzione ufficiale che termina con /exec.',
        );
      }

      final uri = Uri.parse(cleanUrl).replace(queryParameters: {'action': 'ping'});
      final response = await _getWithRedirect(uri);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'ok') {
          return GoogleSheetsPingResult(
            isSuccess: true,
            spreadsheetName: data['spreadsheet_name']?.toString(),
          );
        } else {
          return GoogleSheetsPingResult(
            isSuccess: false,
            errorMessage: data['message']?.toString() ?? 'Risposta non valida da Google Sheets.',
          );
        }
      } else {
        return GoogleSheetsPingResult(
          isSuccess: false,
          errorMessage: 'Errore HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return GoogleSheetsPingResult(
        isSuccess: false,
        errorMessage: _formatNetworkError(e),
      );
    }
  }

  /// Invia il payload di prelievi e dettagli verso Google Sheets (con gestione redirect 302 di Apps Script)
  Future<GoogleSheetsUploadResult> uploadSyncPayload(
    String webAppUrl,
    SyncPayload payload,
  ) async {
    try {
      final cleanUrl = sanitizeUrl(webAppUrl);
      if (cleanUrl.isEmpty) {
        return const GoogleSheetsUploadResult(
          isSuccess: false,
          errorMessage: 'URL Web App non configurato.',
        );
      }

      final uri = Uri.parse(cleanUrl);
      final bodyStr = payload.toJson(pretty: false);

      // Invia POST
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = bodyStr
        ..followRedirects = false; // Gestiamo manualmente i redirect 302 di Google Apps Script

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      http.Response finalResponse = response;

      // Google Apps Script risponde con 302 Found e l'URL finale nell'header 'location'
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          finalResponse = await _client.get(Uri.parse(redirectUrl));
        }
      }

      if (finalResponse.statusCode >= 200 && finalResponse.statusCode < 300) {
        final dynamic data = jsonDecode(finalResponse.body);
        if (data is Map && data['status'] == 'success') {
          return GoogleSheetsUploadResult(
            isSuccess: true,
            prelieviSynced: (data['prelievi_synced'] as num?)?.toInt() ?? payload.prelievi.length,
            dettagliSynced: (data['dettagli_synced'] as num?)?.toInt() ?? payload.dettagli.length,
          );
        } else {
          return GoogleSheetsUploadResult(
            isSuccess: false,
            errorMessage: data['message']?.toString() ?? 'Errore durante la sincronizzazione su Google Sheets.',
          );
        }
      } else {
        return GoogleSheetsUploadResult(
          isSuccess: false,
          errorMessage: 'Errore HTTP ${finalResponse.statusCode} da Google Sheets.',
        );
      }
    } catch (e) {
      return GoogleSheetsUploadResult(
        isSuccess: false,
        errorMessage: _formatNetworkError(e),
      );
    }
  }

  /// Invia la richiesta di eliminazione definitiva (purge) delle schede annullate a Google Sheets
  Future<bool> purgeSchedeAnnullate(String webAppUrl, {List<String>? prelievoIds}) async {
    try {
      final cleanUrl = sanitizeUrl(webAppUrl);
      if (cleanUrl.isEmpty) return false;

      final body = jsonEncode({
        'action': 'purge_annullati',
        'ids': prelievoIds,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final request = http.Request('POST', Uri.parse(cleanUrl))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        })
        ..body = body
        ..followRedirects = false;

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      http.Response finalResponse = response;

      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          finalResponse = await _client.get(Uri.parse(redirectUrl));
        }
      }

      if (finalResponse.statusCode >= 200 && finalResponse.statusCode < 300) {
        final dynamic data = jsonDecode(finalResponse.body);
        return data is Map && data['status'] == 'success';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Scarica tutti i prelievi e i dettagli salvati nel foglio Google
  Future<GoogleSheetsDownloadResult> fetchPrelieviEDettagli(String webAppUrl) async {
    try {
      final cleanUrl = sanitizeUrl(webAppUrl);
      if (cleanUrl.isEmpty) {
        return const GoogleSheetsDownloadResult(
          isSuccess: false,
          errorMessage: 'URL Web App non configurato.',
        );
      }

      final uri = Uri.parse(cleanUrl).replace(queryParameters: {'action': 'get_prelievi'});
      final response = await _getWithRedirect(uri);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'success') {
          final rawPrelievi = data['prelievi'] as List? ?? [];
          final rawDettagli = data['dettagli_prelievo'] as List? ?? [];

          final prelievi = rawPrelievi.map((item) {
            final map = item as Map<String, dynamic>;
            final rawDate = map['data_prelievo']?.toString();
            final date = rawDate != null ? (DateTime.tryParse(rawDate) ?? DateTime.now()) : DateTime.now();
            final rawDateRientro = map['data_rientro']?.toString();
            final dateRientro = (rawDateRientro != null && rawDateRientro.isNotEmpty)
                ? DateTime.tryParse(rawDateRientro)
                : null;

            return Prelievo(
              id: map['id']?.toString() ?? '',
              dataPrelievo: date,
              luogoGrotta: map['luogo_grotta']?.toString() ?? '',
              responsabile: map['responsabile']?.toString() ?? '',
              stato: StatoPrelievo.fromString(map['stato']?.toString() ?? ''),
              parere: map['parere']?.toString().isNotEmpty == true ? map['parere']?.toString() : null,
              isSynced: true, // I dati scaricati da Google Sheets sono già allineati
              dataRientro: dateRientro,
              operatoreRientro: map['operatore_rientro']?.toString().isNotEmpty == true
                  ? map['operatore_rientro']?.toString()
                  : null,
              emailMagazzinieri: map['email_magazzinieri']?.toString().isNotEmpty == true
                  ? map['email_magazzinieri']?.toString()
                  : null,
              relazioneTesto: map['relazione_testo']?.toString().isNotEmpty == true
                  ? map['relazione_testo']?.toString()
                  : null,
              relazioneAutore: map['relazione_autore']?.toString().isNotEmpty == true
                  ? map['relazione_autore']?.toString()
                  : null,
              relazioneData: map['relazione_data']?.toString().isNotEmpty == true
                  ? DateTime.tryParse(map['relazione_data'].toString())
                  : null,
              allegatoNome: map['allegato_nome']?.toString().isNotEmpty == true
                  ? map['allegato_nome']?.toString()
                  : null,
              allegatoDriveUrl: map['allegato_drive_url']?.toString().isNotEmpty == true
                  ? map['allegato_drive_url']?.toString()
                  : null,
            );
          }).where((p) => p.id.isNotEmpty).toList();

          final dettagli = rawDettagli.map((item) {
            final map = item as Map<String, dynamic>;
            final spuntaVal = map['spunta_rientro'];
            final isSpunta = (spuntaVal == 1 || spuntaVal == true || spuntaVal == '1' || spuntaVal == 'SI');
            final qta = (map['quantita_prelevata'] as num?)?.toInt() ?? 1;
            final qtaTornata = (map['qta_tornata'] as num?)?.toInt();

            return DettaglioPrelievo(
              idDettaglio: map['id_dettaglio']?.toString() ?? '',
              prelievoId: map['prelievo_id']?.toString() ?? '',
              materialeId: map['materiale_id']?.toString() ?? '',
              categoriaMateriale: map['categoria']?.toString(),
              nomeMateriale: map['nome_materiale']?.toString(),
              quantitaPrelevata: qta,
              spuntaRientro: isSpunta,
              qtaTornata: qtaTornata,
              noteRientro: map['note_rientro']?.toString().isNotEmpty == true ? map['note_rientro']?.toString() : null,
              isSynced: true,
            );
          }).where((d) => d.idDettaglio.isNotEmpty && d.prelievoId.isNotEmpty).toList();

          return GoogleSheetsDownloadResult(
            isSuccess: true,
            prelievi: prelievi,
            dettagli: dettagli,
          );
        } else {
          return GoogleSheetsDownloadResult(
            isSuccess: false,
            errorMessage: data['message']?.toString() ?? 'Errore nel download da Google Sheets.',
          );
        }
      } else {
        return GoogleSheetsDownloadResult(
          isSuccess: false,
          errorMessage: 'Errore HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return GoogleSheetsDownloadResult(
        isSuccess: false,
        errorMessage: _formatNetworkError(e),
      );
    }
  }

  /// Scarica il catalogo aggiornato dal foglio Google Sheets
  Future<List<Catalogo>> fetchCatalogo(String webAppUrl) async {
    final cleanUrl = sanitizeUrl(webAppUrl);
    if (cleanUrl.isEmpty) return [];

    final uri = Uri.parse(cleanUrl).replace(queryParameters: {'action': 'get_catalogo'});
    final response = await _getWithRedirect(uri);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic data = jsonDecode(response.body);
      if (data is Map && data['status'] == 'success') {
        final list = data['catalogo'] as List?;
        if (list != null) {
          return list.map((item) {
            final map = item as Map<String, dynamic>;
            return Catalogo(
              idMateriale: map['id_materiale']?.toString() ?? '',
              categoria: map['categoria']?.toString() ?? '',
              nomeOggetto: map['nome_oggetto']?.toString() ?? '',
            );
          }).where((c) => c.idMateriale.isNotEmpty).toList();
        }
      }
    }
    return [];
  }

  /// Helper per eseguire GET seguendo i redirect 302 di Google Apps Script
  Future<http.Response> _getWithRedirect(Uri uri) async {
    final response = await _client.get(uri);
    if ((response.statusCode == 302 || response.statusCode == 301) &&
        response.headers['location'] != null) {
      return await _client.get(Uri.parse(response.headers['location']!));
    }
    return response;
  }
}
