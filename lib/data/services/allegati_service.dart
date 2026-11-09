import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

export 'package:open_filex/open_filex.dart' show OpenResult, ResultType;

class AllegatoInfo {
  final String path;
  final String name;
  final int sizeBytes;

  const AllegatoInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class AllegatiService {
  static const int maxFileSizeBytes = 20 * 1024 * 1024; // 20 MB

  /// Estensioni permesse: PDF, Word, OpenOffice/LibreOffice, Text, Immagini
  static const List<String> defaultAllowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'odt',
    'ods',
    'odp',
    'txt',
    'rtf',
    'jpg',
    'jpeg',
    'png',
  ];

  /// Seleziona un documento o file dal dispositivo
  static Future<AllegatoInfo?> scegliDocumento({
    List<String> allowedExtensions = defaultAllowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final path = file.path;
    if (path == null) return null;

    final ioFile = File(path);
    final size = await ioFile.length();

    if (size > maxFileSizeBytes) {
      final sizeMb = (size / (1024 * 1024)).toStringAsFixed(1);
      throw Exception(
        'Il file selezionato ($sizeMb MB) supera il limite massimo consentito di 20 MB.',
      );
    }

    return AllegatoInfo(
      path: path,
      name: file.name,
      sizeBytes: size,
    );
  }

  /// Copia il file selezionato all'interno della memoria sicura e permanente dell'app
  static Future<String> salvaAllegatoPermanente({
    required String prelievoId,
    required String sourceFilePath,
    required String originalFileName,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(appDir.path, 'relazioni', prelievoId));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetPath = p.join(targetDir.path, originalFileName);
    final sourceFile = File(sourceFilePath);
    
    // Se il file sorgente è già nella cartella di destinazione, evita copie inutili
    if (sourceFile.path != targetPath) {
      await sourceFile.copy(targetPath);
    }
    return targetPath;
  }

  /// Apre il file allegato con l'applicazione di sistema predefinita
  static Future<OpenResult> apriAllegato(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return OpenResult(
        type: ResultType.fileNotFound,
        message: 'Il file allegato non è presente su questo dispositivo.',
      );
    }
    return OpenFilex.open(filePath);
  }

  /// Elimina il file allegato salvato localmente
  static Future<void> eliminaAllegatoLocale(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
