import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../ae_dashboard/ae_login_screen.dart';
import '../models/complaint_model.dart';
import '../services/complaint_service.dart';
import '../widgets/complaint_heatmap_section.dart';
import '../widgets/status_badge.dart';
import 'approval_hub.dart';
import 'heatmap_dashboard.dart';

class EEHome extends StatefulWidget {
  const EEHome({super.key});

  @override
  State<EEHome> createState() => _EEHomeState();
}

class _EEHomeState extends State<EEHome> {
  bool _escalationChecked = false;
  final ComplaintService _complaintService = ComplaintService();

  @override
  void initState() {
    super.initState();
    _triggerEscalationCheck();
  }

  Future<void> _triggerEscalationCheck() async {
    if (_escalationChecked) return;
    _escalationChecked = true;
    try {
      await _complaintService.checkAndProcessEscalations();
    } catch (_) {}
  }

  Stream<List<ComplaintModel>> _streamEeComplaints() {
    return _complaintService.streamActiveComplaints().map(
      (complaints) => complaints
          .where((complaint) => complaint.assignedRole.toLowerCase() == 'ee')
          .toList(growable: false),
    );
  }

  String _normalizeStatus(String status) {
    return status
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Unknown';
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return '$dd-$mm-$yyyy';
  }

  String _actionLabel(String status) {
    final normalized = _normalizeStatus(status);
    if (normalized == 'resolved') return 'View';
    if (normalized == 'approved') return 'Resolve';
    return 'Review';
  }

  Color _priorityColor(String priority) {
    final normalized = priority.trim().toLowerCase();
    if (normalized == 'high') return const Color(0xFFC62828);
    if (normalized == 'medium') return const Color(0xFFEF6C00);
    return const Color(0xFF2E7D32);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        title: const Text('Executive Engineer Dashboard'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => const AeLoginScreen(),
                ),
                (_) => false,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Predictive Heatmap',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HeatmapDashboard()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ComplaintModel>>(
        stream: _streamEeComplaints(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load EE queue: ${snapshot.error}'),
              ),
            );
          }

          final complaints = snapshot.data ?? const <ComplaintModel>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const ComplaintHeatmapSection(role: 'ee'),
              const SizedBox(height: 12),
              Text(
                'Executive Queue (${complaints.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8E0000),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Final-level actions and approvals for EE-owned complaints',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 14),
              if (complaints.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No active EE escalations.'),
                  ),
                )
              else
                ...complaints.map((comp) {
                  final normalizedStatus = _normalizeStatus(comp.status);
                  final isProactive = normalizedStatus == 'escalated';
                  final priorityColor = _priorityColor(comp.priority);
                  final actionLabel = _actionLabel(comp.status);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      elevation: isProactive ? 7 : 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isProactive
                              ? const Color(0xFFFF9800)
                              : const Color(0xFFEF9A9A),
                          width: isProactive ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 5,
                              height: 90,
                              decoration: BoxDecoration(
                                color: isProactive
                                    ? const Color(0xFFFF9800)
                                    : priorityColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comp.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      StatusBadge(status: comp.status),
                                      Chip(
                                        label: Text(comp.category),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor:
                                            const Color(0xFFFFEBEE),
                                      ),
                                      Chip(
                                        label:
                                            Text('Priority: ${comp.priority}'),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: priorityColor
                                            .withValues(alpha: 0.14),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_outlined,
                                        size: 16,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Created: ${_formatDate(comp.createdAt)}',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isProactive) ...[
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Executive escalation requiring final-level decision.',
                                      style: TextStyle(
                                        color: Color(0xFFE65100),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isProactive
                                    ? Colors.orange[800]
                                    : Colors.red[800],
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ApprovalHub(complaint: comp),
                                ),
                              ),
                              icon: const Icon(Icons.gavel_outlined, size: 18),
                              label: Text(actionLabel),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
