import 'package:flutter/material.dart';
import '../../domain/models/stato_prelievo.dart';

class StatoBadge extends StatelessWidget {
  final StatoPrelievo stato;

  const StatoBadge({super.key, required this.stato});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (stato) {
      case StatoPrelievo.inAttesa:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        icon = Icons.hourglass_top_rounded;
        break;
      case StatoPrelievo.rientrato:
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        icon = Icons.check_circle_rounded;
        break;
      case StatoPrelievo.mancante:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        icon = Icons.warning_rounded;
        break;
      case StatoPrelievo.annullato:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            stato.label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
