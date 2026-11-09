import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/models/dettaglio_prelievo.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';

class PdfService {
  /// Genera il documento PDF ufficiale per una scheda di prelievo
  static Future<Uint8List> generatePrelievoPdf(Prelievo prelievo) async {
    final pdf = pw.Document(
      title: 'Scheda Prelievo - ${prelievo.luogoGrotta}',
      author: 'Speleo Club Roma',
    );

    // Carica il logo se disponibile
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/app_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      try {
        final logoBytes = await rootBundle.load('assets/images/logo_scr.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        logoImage = null;
      }
    }

    final dataFormattata =
        '${prelievo.dataPrelievo.day.toString().padLeft(2, '0')}/${prelievo.dataPrelievo.month.toString().padLeft(2, '0')}/${prelievo.dataPrelievo.year}';

    final dataRiconsegnaFormattata = prelievo.dataRientro != null
        ? '${prelievo.dataRientro!.day.toString().padLeft(2, '0')}/${prelievo.dataRientro!.month.toString().padLeft(2, '0')}/${prelievo.dataRientro!.year} ${prelievo.dataRientro!.hour.toString().padLeft(2, '0')}:${prelievo.dataRientro!.minute.toString().padLeft(2, '0')}'
        : null;

    final totMetri = prelievo.totaleMetri;
    final totPezzi = prelievo.totalePezzi;
    final totMatasse = prelievo.totaleMatasse;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(prelievo, logoImage, dataFormattata),
        footer: (context) => _buildFooter(context, prelievo),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildInfoBox(prelievo, dataFormattata, dataRiconsegnaFormattata),
          pw.SizedBox(height: 16),
          pw.Text(
            'ELENCO MATERIALI PRELEVATI (${prelievo.dettagli.length} voci)',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 6),
          _buildMaterialiTable(prelievo.dettagli),
          pw.SizedBox(height: 14),
          _buildTotaliSummary(totPezzi, totMetri, totMatasse),
          pw.SizedBox(height: 24),
          _buildFirmeBox(prelievo),
        ],
      ),
    );

    return pdf.save();
  }

  /// Condivide il PDF generato tramite il foglio di condivisione di sistema (WhatsApp, Mail, Drive, ecc.)
  static Future<void> sharePdf(Prelievo prelievo) async {
    final bytes = await generatePrelievoPdf(prelievo);
    final safeGrotta = prelievo.luogoGrotta
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]+'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final filename = 'Scheda_Prelievo_${safeGrotta}_${prelievo.dataPrelievo.year}${prelievo.dataPrelievo.month.toString().padLeft(2, '0')}${prelievo.dataPrelievo.day.toString().padLeft(2, '0')}.pdf';

    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  /// Mostra l'anteprima di stampa o invia alla stampante di sistema
  static Future<void> printPdf(Prelievo prelievo) async {
    final bytes = await generatePrelievoPdf(prelievo);
    final safeGrotta = prelievo.luogoGrotta.trim().replaceAll(RegExp(r'\s+'), '_');
    await Printing.layoutPdf(
      name: 'Scheda_$safeGrotta',
      onLayout: (format) async => bytes,
    );
  }

  // --- WIDGET HELPER INTERNI ---

  static pw.Widget _buildHeader(
    Prelievo prelievo,
    pw.MemoryImage? logoImage,
    String dataFormattata,
  ) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey700, width: 1.5),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            children: [
              if (logoImage != null) ...[
                pw.Image(logoImage, width: 38, height: 38),
                pw.SizedBox(width: 10),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SPELEO CLUB ROMA',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    'Fondata nel 1959 - Gestione Magazzino Materiali',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: _coloreBackgroundStato(prelievo.stato),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  prelievo.stato.label.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _coloreTestoStato(prelievo.stato),
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Data: $dataFormattata',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoBox(
    Prelievo prelievo,
    String dataFormattata,
    String? dataRiconsegnaFormattata,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DESTINAZIONE / GROTTA:',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      prelievo.luogoGrotta,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RESPONSABILE PRELIEVO:',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      prelievo.responsabile,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (dataRiconsegnaFormattata != null ||
              (prelievo.parere != null && prelievo.parere!.trim().isNotEmpty)) ...[
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                if (dataRiconsegnaFormattata != null) ...[
                  pw.Text(
                    'Riconsegnato il: ',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    dataRiconsegnaFormattata,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (prelievo.operatoreRientro != null &&
                      prelievo.operatoreRientro!.trim().isNotEmpty) ...[
                    pw.Text(
                      ' (Op: ${prelievo.operatoreRientro})',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ],
              ],
            ),
            if (prelievo.parere != null && prelievo.parere!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'Note: ${prelievo.parere}',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey800,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildMaterialiTable(List<DettaglioPrelievo> dettagli) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.5,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2), // Categoria
        1: pw.FlexColumnWidth(4.5), // Nome Materiale
        2: pw.FlexColumnWidth(2.0), // Q.tà Prelevata
        3: pw.FlexColumnWidth(1.5), // Spunta Rientro
        4: pw.FlexColumnWidth(2.0), // Q.tà Rientrata
        5: pw.FlexColumnWidth(3.0), // Note
      },
      children: [
        // Intestazione tabella
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeaderCell('Categoria'),
            _tableHeaderCell('Materiale'),
            _tableHeaderCell('Q.tà Prel.'),
            _tableHeaderCell('Rientro'),
            _tableHeaderCell('Q.tà Rient.'),
            _tableHeaderCell('Note Riconsegna'),
          ],
        ),
        // Righe materiali
        ...dettagli.map((d) {
          final isMetri = d.isMetri;
          final unita = d.unitaMisura;
          final spunta = d.spuntaRientro ? '[X]' : '[  ]';
          final qtaRientrataStr = d.qtaTornata != null ? '${d.qtaTornata} $unita' : '-';

          return pw.TableRow(
            children: [
              _tableCell(d.categoriaMateriale ?? '-', isMuted: true),
              _tableCell(d.nomeMateriale ?? d.materialeId, isBold: true),
              _tableCell(
                '${d.quantitaPrelevata} $unita',
                align: pw.TextAlign.right,
                textColor: isMetri ? PdfColors.deepOrange900 : PdfColors.black,
              ),
              _tableCell(spunta, align: pw.TextAlign.center),
              _tableCell(qtaRientrataStr, align: pw.TextAlign.right),
              _tableCell(d.noteRientro ?? '', isMuted: true),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey900,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    bool isMuted = false,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? (isMuted ? PdfColors.grey700 : PdfColors.black),
        ),
      ),
    );
  }

  static pw.Widget _buildTotaliSummary(int totPezzi, int totMetri, int totMatasse) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Text(
            'Totale Pezzi Fisici: $totPezzi',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
          if (totMetri > 0) ...[
            pw.Text(
              'Corde: $totMetri m ($totMatasse ${totMatasse == 1 ? 'matassa' : 'matasse'})',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.deepOrange900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildFirmeBox(Prelievo prelievo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Firma Responsabile Prelievo:',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 25),
              pw.Container(
                width: 180,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.5),
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                prelievo.responsabile,
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 40),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Firma Responsabile Magazzino SCR:',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 25),
              pw.Container(
                width: 180,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.5),
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                prelievo.operatoreRientro ?? 'Magazziniere incaricato',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, Prelievo prelievo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'ID: ${prelievo.id} - Speleo Club Roma',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
          pw.Text(
            'Pagina ${context.pageNumber} di ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  static PdfColor _coloreBackgroundStato(StatoPrelievo stato) {
    switch (stato) {
      case StatoPrelievo.inAttesa:
        return PdfColors.amber100;
      case StatoPrelievo.rientrato:
        return PdfColors.green100;
      case StatoPrelievo.mancante:
        return PdfColors.red100;
      case StatoPrelievo.annullato:
        return PdfColors.grey200;
    }
  }

  static PdfColor _coloreTestoStato(StatoPrelievo stato) {
    switch (stato) {
      case StatoPrelievo.inAttesa:
        return PdfColors.amber900;
      case StatoPrelievo.rientrato:
        return PdfColors.green900;
      case StatoPrelievo.mancante:
        return PdfColors.red900;
      case StatoPrelievo.annullato:
        return PdfColors.grey800;
    }
  }
}
