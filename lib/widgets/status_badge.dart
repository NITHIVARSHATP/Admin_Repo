import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _color() {
    switch (_normalizedStatus()) {
      case 'pending':
        return Colors.blueGrey;

      case 'classified':
        return Colors.blue;

      case 'under_review':
        return Colors.deepPurple;

      case 'in_progress':
        return Colors.orange;

      case 'escalated':
        return Colors.red;

      case 'approved':
        return Colors.teal;

      case 'resolved':
        return Colors.green;

      case 'reopened':
        return Colors.redAccent;

      default:
        return Colors.blueGrey;
    }
  }

  String _normalizedStatus() {
    return status
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  String _formatLabel() {
    return status
        .replaceAll('_', ' ')
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_formatLabel()),
      backgroundColor: _color().withValues(alpha: .12),
      labelStyle: TextStyle(
        color: _color(),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}