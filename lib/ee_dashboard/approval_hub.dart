import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';

class ApprovalHub extends StatefulWidget {
  final ComplaintModel complaint;
  const ApprovalHub({super.key, required this.complaint});

  @override
  State<ApprovalHub> createState() => _ApprovalHubState();
}

class _ApprovalHubState extends State<ApprovalHub> {
  final _budgetController = TextEditingController();
  bool _saving = false;

  String _normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'aee') return 'aee';
    if (normalized == 'ee') return 'ee';
    return 'ae';
  }

  Future<void> _runEeAction({
    required String successMessage,
    required Map<String, dynamic> Function(Map<String, dynamic> data) buildUpdate,
  }) async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaint.complaintId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          throw StateError('Complaint not found.');
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        final currentRole = _normalizeRole(
          (data['assignedRole'] ?? data['currentOwnerRole'] ?? 'ae').toString(),
        );

        if (currentRole != 'ee') {
          throw StateError('Ownership changed. EE actions are now read-only.');
        }

        final updates = buildUpdate(data);
        updates['assignedRole'] = 'ee';
        updates['currentOwnerRole'] = 'EE';
        updates['escalationLevel'] = 3;
        updates['lastUpdated'] = FieldValue.serverTimestamp();

        transaction.update(ref, updates);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _normalizeStatus(String status) {
    return status
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  String _prettyStatus(String status) {
    final normalized = _normalizeStatus(status);
    return normalized
        .split('_')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Color _priorityColor(String priority) {
    final normalized = priority.trim().toLowerCase();
    if (normalized == 'high') return const Color(0xFFC62828);
    if (normalized == 'medium') return const Color(0xFFEF6C00);
    return const Color(0xFF2E7D32);
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _approveAction(String actionLabel) async {
    final parsedBudget = double.tryParse(_budgetController.text.trim()) ?? 0.0;
    return _runEeAction(
      successMessage: 'Executive action approved successfully',
      buildUpdate: (_) => {
        'allocatedBudget': parsedBudget,
        'eeActionTaken': actionLabel,
        'status': 'approved',
      },
    );
  }

  Future<void> _markResolved() async {
    return _runEeAction(
      successMessage: 'Complaint marked as resolved',
      buildUpdate: (_) => {
        'status': 'resolved',
      },
    );
  }

  Future<void> _reopenToAe() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaint.complaintId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          throw StateError('Complaint not found.');
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        final currentRole = _normalizeRole(
          (data['assignedRole'] ?? data['currentOwnerRole'] ?? 'ae').toString(),
        );

        if (currentRole != 'ee') {
          throw StateError('Ownership changed. EE actions are now read-only.');
        }

        transaction.update(ref, {
          'status': 'reopened',
          'assignedRole': 'ae',
          'currentOwnerRole': 'AE',
          'escalationLevel': 1,
          'assignedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint reopened to AE workflow')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reopen complaint: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    final normalizedStatus = _normalizeStatus(complaint.status);
    final isProactive = normalizedStatus == 'escalated';
    final statusText = _prettyStatus(complaint.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive War Room'),
        backgroundColor: isProactive ? Colors.orange[800] : Colors.red[900],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .doc(complaint.complaintId)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final liveAssignedRole = _normalizeRole(
            (data['assignedRole'] ?? complaint.assignedRole).toString(),
          );
          final canEdit = !_saving && liveAssignedRole == 'ee';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (liveAssignedRole != 'ee')
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE57373)),
                    ),
                    child: const Text(
                      'Ownership changed from EE. This screen is now read-only.',
                      style: TextStyle(
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            if (isProactive) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'EXECUTIVE ESCALATION: SLA exceeded and complaint reached level 3 for final action.',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(complaint.category),
                          backgroundColor: const Color(0xFFFFEBEE),
                        ),
                        Chip(
                          label: Text('Priority: ${complaint.priority}'),
                          backgroundColor:
                              _priorityColor(complaint.priority).withValues(alpha: 0.14),
                        ),
                        Chip(
                          label: Text('Status: $statusText'),
                          backgroundColor: const Color(0xFFF3E5F5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      complaint.description,
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Allocate Emergency Budget',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _budgetController,
                      enabled: canEdit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount (INR)',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Executive Sanctions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.flash_on),
                        onPressed: canEdit
                            ? () => _approveAction('Sanction Emergency Repair')
                            : null,
                        label: const Text('Sanction Emergency Repair'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.groups),
                        onPressed: canEdit
                            ? () => _approveAction('Deploy Special Team')
                            : null,
                        label: const Text('Deploy Special Team'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style:
                            ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                        icon: const Icon(Icons.settings_input_component),
                        onPressed: canEdit
                          ? () =>
                            _approveAction('Approve Equipment Replacement')
                          : null,
                        label: const Text('Approve Equipment Replacement'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canEdit ? _markResolved : null,
                    icon: const Icon(Icons.verified),
                    label: const Text('Mark Resolved'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canEdit ? _reopenToAe : null,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reopen to AE'),
                  ),
                ),
              ],
            ),
          ],
          ),
          );
        },
      ),
    );
  }
}