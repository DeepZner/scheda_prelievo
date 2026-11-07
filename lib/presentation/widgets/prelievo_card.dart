import 'package:flutter/material.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import 'stato_badge.dart';

class PrelievoCard extends StatelessWidget {
  final Prelievo prelievo;
  final VoidCallback onTap;

  const PrelievoCard({
    super.key,
    required this.prelievo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  StatoBadge(stato: prelievo.stato),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    prelievo.responsabile,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
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
                  ),
                  Row(
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
}
