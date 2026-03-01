import 'dart:async';
import 'package:flutter/material.dart';

class EscalationTimer extends StatefulWidget {
  final DateTime lastUpdated;
  const EscalationTimer({super.key, required this.lastUpdated});

  @override
  State<EscalationTimer> createState() => _EscalationTimerState();
}

class _EscalationTimerState extends State<EscalationTimer> {
  late Timer _timer;
  Duration diff = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    setState(() {
      diff = DateTime.now().difference(widget.lastUpdated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = diff.inHours;
    final m = diff.inMinutes % 60;

    final urgent = h >= 48;

    return Text(
      "$h h $m m",
      style: TextStyle(
        color: urgent ? const Color(0xFFC62828) : Colors.blueGrey,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}