import 'package:flutter/material.dart';

/// Selettore di quantità ergonomico con touch target >= 48x48dp,
/// ottimizzato per l'uso rapido con una sola mano anche con guanti da grotta.
class QuantityStepper extends StatelessWidget {
  final int value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 0,
    this.maxValue = 999,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsante Sottrai (48x48dp)
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: value > minValue
                ? theme.colorScheme.primaryContainer
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: value > minValue ? () => onChanged(value - 1) : null,
              child: Center(
                child: Icon(
                  Icons.remove,
                  size: 24,
                  color: value > minValue
                      ? theme.colorScheme.onPrimaryContainer
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ),
        // Visualizzazione Valore
        Container(
          constraints: const BoxConstraints(minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        // Pulsante Aggiungi (48x48dp)
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: value < maxValue ? theme.colorScheme.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: value < maxValue ? () => onChanged(value + 1) : null,
              child: Center(
                child: Icon(
                  Icons.add,
                  size: 24,
                  color: value < maxValue
                      ? theme.colorScheme.onPrimary
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
