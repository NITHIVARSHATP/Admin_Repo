import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/complaint_model.dart';
import '../services/complaint_service.dart';
import '../widgets/complaint_heatmap_section.dart';
import 'ae_login_screen.dart';
import 'complaint_details_screen.dart';

class AeDashboardScreen extends StatefulWidget {
  const AeDashboardScreen({
    super.key,
    ComplaintService? complaintService,
  }) : _complaintService = complaintService;

  final ComplaintService? _complaintService;

  @override
  State<AeDashboardScreen> createState() => _AeDashboardScreenState();
}

class _AeDashboardScreenState extends State<AeDashboardScreen> {
  bool _runningMigration = false;
  bool _escalationChecked = false;

  ComplaintService get _complaintService =>
      widget._complaintService ?? ComplaintService();

  bool _isAdminRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    return normalized == 'ae' || normalized == 'aee' || normalized == 'ee';
  }

  Future<String?> _getCurrentUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    return userDoc.data()?['role']?.toString();
  }

  Future<void> _runEscalationMigration() async {
    if (_runningMigration) return;

    setState(() => _runningMigration = true);
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('normalizeComplaintEscalationFields');
      final result = await callable.call();

      final payload = result.data;
      int scannedCount = 0;
      int updatedCount = 0;

      if (payload is Map) {
        scannedCount = (payload['scannedCount'] as num?)?.toInt() ?? 0;
        updatedCount = (payload['updatedCount'] as num?)?.toInt() ?? 0;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Migration complete: $scannedCount scanned, $updatedCount updated',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Migration failed: ${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Migration failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _runningMigration = false);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final complaintService = _complaintService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AE Dashboard'),
        actions: [
          IconButton(
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
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<ComplaintModel>>(
        stream: complaintService.streamActiveComplaints(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load complaints: ${snapshot.error}'),
              ),
            );
          }

            final complaints = (snapshot.data ?? <ComplaintModel>[])
              .where((complaint) => complaint.assignedRole.toLowerCase() == 'ae')
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FutureBuilder<String?>(
                future: _getCurrentUserRole(),
                builder: (context, roleSnapshot) {
                  if (!_isAdminRole(roleSnapshot.data)) {
                    return const SizedBox.shrink();
                  }

                  return Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _runningMigration ? null : _runEscalationMigration,
                      icon: _runningMigration
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.admin_panel_settings_outlined, size: 16),
                      label: const Text('Run Escalation Migration'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              const ComplaintHeatmapSection(role: 'ae'),
              const SizedBox(height: 14),
              if (complaints.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No active complaints.'),
                  ),
                )
              else
                ...complaints.map((complaint) {
                  final isResolved = _normalizeStatus(complaint.status) == 'resolved';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ComplaintDetailScreen(
                                complaintId: complaint.complaintId,
                                complaintService: complaintService,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      complaint.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isResolved
                                            ? const Color(0xFF1B5E20)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (isResolved)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF2E7D32),
                                      size: 20,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Category: ${complaint.category}',
                                style: const TextStyle(color: Colors.black87),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _priorityChip(complaint.priority),
                                  _statusChip(complaint.status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Created: ${_formatDate(complaint.createdAt)}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
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

  static String _formatDate(DateTime? value) {
    if (value == null) return 'N/A';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }

  static Widget _statusChip(String status) {
    final normalized = _normalizeStatus(status);
    Color background;
    Color foreground;

    switch (normalized) {
      case 'resolved':
        background = const Color(0xFFE8F5E9);
        foreground = const Color(0xFF2E7D32);
        break;
      case 'reopened':
        background = const Color(0xFFFFF8E1);
        foreground = const Color(0xFFF57F17);
        break;
      case 'in_progress':
        background = const Color(0xFFE3F2FD);
        foreground = const Color(0xFF1565C0);
        break;
      case 'under_review':
        background = const Color(0xFFEDE7F6);
        foreground = const Color(0xFF4A148C);
        break;
      case 'classified':
      default:
        background = const Color(0xFFF3E5F5);
        foreground = const Color(0xFF6A1B9A);
        break;
    }

    return Chip(
      label: Text(_displayStatus(status)),
      visualDensity: VisualDensity.compact,
      backgroundColor: background,
      labelStyle: TextStyle(
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static String _normalizeStatus(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  static String _displayStatus(String status) {
    final normalized = status.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return status;

    return normalized
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
    )
        .join(' ');
  }

  static Widget _priorityChip(String priority) {
    final value = priority.trim().toLowerCase();
    Color background;
    Color foreground;

    if (value == 'high') {
      background = const Color(0xFFFFEBEE);
      foreground = const Color(0xFFC62828);
    } else if (value == 'medium') {
      background = const Color(0xFFFFF3E0);
      foreground = const Color(0xFFEF6C00);
    } else {
      background = const Color(0xFFE8F5E9);
      foreground = const Color(0xFF2E7D32);
    }

    return Chip(
      label: Text(priority),
      visualDensity: VisualDensity.compact,
      backgroundColor: background,
      labelStyle: TextStyle(
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}