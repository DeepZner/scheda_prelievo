import 'package:flutter/material.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import 'stato_badge.dart';

/// Card per la visualizzazione sintetica di una scheda prelievo.
/// Supporta la modalità compatta (default) ottimizzata per mobile,
/// con accent bar laterale colorata per stato e disposizione ad alta densità.
class PrelievoCard extends StatelessWidget {
  final Prelievo prelievo;
  final VoidCallback onTap;
  final bool isCompact;

  const PrelievoCard({
    super.key,
    required this.prelievo,
    required this.onTap,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard(context);
    }
    return _buildExpandedCard(context);
  }

  /// Layout Compatto (Soluzione A - altezza ~72dp, alta densità per mobile)
  Widget _buildCompactCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAnnullato = prelievo.stato == StatoPrelievo.annullato;
    final accentColor = _coloreAccentPerStato(prelievo.stato);

    final totMetri = prelievo.totaleMetri;
    final totMatasse = prelievo.totaleMatasse;
    final totPezzi = prelievo.dettagli
        .where((d) => !d.isMetri)
        .fold<int>(0, (sum, d) => sum + d.quantitaPrelevata);

    // Sintesi compattata per non occupare troppo spazio su schermi stretti
    final List<String> partiSintesi = [];
    if (totMetri > 0) {
      partiSintesi.add('${totMetri}m${totMatasse > 0 ? " ($totMatasse)" : ""}');
    }
    if (totPezzi > 0) {
      partiSintesi.add('${totPezzi}pz');
    }
    final infoMaterialiCompatta = partiSintesi.isNotEmpty
        ? partiSintesi.join(' • ')
        : '${prelievo.dettagli.length} mat.';

    final dataStr =
        '${prelievo.dataPrelievo.day.toString().padLeft(2, '0')}/${prelievo.dataPrelievo.month.toString().padLeft(2, '0')}/${prelievo.dataPrelievo.year}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 0.8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra colorata dello stato (Accent Bar)
              Container(
                width: 5,
                color: accentColor,
              ),

              // Contenuto informativo compatto
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // RIGA 1: Nome Grotta + Data prelievo
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              prelievo.luogoGrotta,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                decoration:
                                    isAnnullato ? TextDecoration.lineThrough : null,
                                color: isAnnullato
                                    ? Colors.grey.shade600
                                    : colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dataStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // RIGA 2: Responsabile + Indicatori speciali + Sintesi Materiali
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Responsabile
                          Flexible(
                            flex: 3,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    prelievo.responsabile,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Indicatori micro (spunta in corso, relazione, allegato)
                          if (prelievo.haSpuntaInCorso) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.amber.shade400,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pending_actions_rounded,
                                    size: 11,
                                    color: Colors.amber.shade900,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${prelievo.articoliSpuntatiCount}/${prelievo.dettagli.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (prelievo.relazioneTesto?.isNotEmpty == true) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.menu_book_rounded,
                              size: 14,
                              color: Colors.teal.shade700,
                            ),
                          ],

                          if (prelievo.allegatoNome?.isNotEmpty == true) ...[
                            const SizedBox(width: 3),
                            Icon(
                              Icons.attach_file_rounded,
                              size: 14,
                              color: Colors.blue.shade700,
                            ),
                          ],

                          const SizedBox(width: 8),

                          // Sintesi Materiali e Corde a destra
                          Expanded(
                            flex: 2,
                            child: Text(
                              infoMaterialiCompatta,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: totMetri > 0
                                    ? Colors.deepOrange.shade800
                                    : Colors.blueGrey.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(width: 4),

                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Layout Esteso (Precedente - per retrocompatibilità o vista dettagliata)
  Widget _buildExpandedCard(BuildContext context) {
    final totMetri = prelievo.totaleMetri;
    final totMatasse = prelievo.totaleMatasse;
    final totPezzi = prelievo.dettagli
        .where((d) => !d.isMetri)
        .fold<int>(0, (sum, d) => sum + d.quantitaPrelevata);
    final infoMateriali = [
      if (totMetri > 0)
        '$totMetri m corde ($totMatasse ${totMatasse == 1 ? 'matassa' : 'matasse'})',
      if (totPezzi > 0) '$totPezzi pz attrezzature',
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      prelievo.luogoGrotta,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration:
                            prelievo.stato == StatoPrelievo.annullato
                                ? TextDecoration.lineThrough
                                : null,
                        color: prelievo.stato == StatoPrelievo.annullato
                            ? Colors.grey.shade600
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatoBadge(stato: prelievo.stato),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      prelievo.responsabile,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${prelievo.dataPrelievo.day.toString().padLeft(2, '0')}/${prelievo.dataPrelievo.month.toString().padLeft(2, '0')}/${prelievo.dataPrelievo.year}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (prelievo.haSpuntaInCorso) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending_actions_rounded,
                          size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Text(
                        'Spunta in corso (${prelievo.articoliSpuntatiCount}/${prelievo.dettagli.length} articoli)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      infoMateriali.isNotEmpty
                          ? infoMateriali
                          : '${prelievo.dettagli.length} materiali',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: totMetri > 0
                            ? Colors.deepOrange.shade900
                            : Colors.grey.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Dettagli',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.deepOrange,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _coloreAccentPerStato(StatoPrelievo stato) {
    switch (stato) {
      case StatoPrelievo.inAttesa:
        return Colors.orange.shade700;
      case StatoPrelievo.rientrato:
        return Colors.green.shade600;
      case StatoPrelievo.mancante:
        return Colors.deepOrange.shade800;
      case StatoPrelievo.annullato:
        return Colors.grey.shade500;
    }
  }
}
