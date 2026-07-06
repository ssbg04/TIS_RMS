import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  double _calculateStrength() {
    if (password.isEmpty) return 0.0;
    double strength = 0.0;
    if (password.length > 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password) || RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) strength += 0.25;
    return strength;
  }

  Color _getStrengthColor(double strength) {
    if (strength == 0.0) return Colors.transparent;
    if (strength <= 0.25) return Colors.red;
    if (strength <= 0.5) return Colors.orange;
    if (strength <= 0.75) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _getStrengthText(double strength) {
    if (strength == 0.0) return 'Enter a password';
    if (strength <= 0.25) return 'Weak';
    if (strength <= 0.5) return 'Fair';
    if (strength <= 0.75) return 'Good';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength();
    final color = _getStrengthColor(strength);
    final text = _getStrengthText(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: strength == 0.0 ? 0.0 : strength,
                  backgroundColor: Colors.grey.shade200,
                  color: color,
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 50,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: strength == 0.0 ? Colors.grey : color,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
