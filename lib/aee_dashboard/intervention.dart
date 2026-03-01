import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';

class InterventionScreen extends StatefulWidget {
  final ComplaintModel complaint;
  const InterventionScreen({super.key, required this.complaint});

  @override
  State<InterventionScreen> createState() => _InterventionScreenState();
}

class _InterventionScreenState extends State<InterventionScreen> {
  final _resourceController = TextEditingController();
  final _notesController = TextEditingController();

  static const List<String> _aeeStatuses = [
    'under_review',
    'in_progress',
    'resolved',
  ];

  late String _selectedStatus;
  DateTime? _selectedDeadline;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initialStatus = _normalizeStatus(widget.complaint.status);
    _selectedStatus = _aeeStatuses.contains(initialStatus)
        ? initialStatus
        : 'under_review';
    _selectedDeadline = widget.complaint.aeeDeadline ?? widget.complaint.slaDeadline;
  }

  @override
  void dispose() {
    _resourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'No deadline selected';
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return '$dd-$mm-$yyyy';
  }

  Color _priorityColor(String priority) {
    final normalized = priority.trim().toLowerCase();
    if (normalized == 'high') return const Color(0xFFC62828);
    if (normalized == 'medium') return const Color(0xFFEF6C00);
    return const Color(0xFF2E7D32);
  }

  Duration _durationByPriority(String priority) {
    final normalized = priority.trim().toLowerCase();
    switch (normalized) {
      case 'high':
        return const Duration(hours: 4);
      case 'medium':
        return const Duration(hours: 15);
      default:
        return const Duration(hours: 24);
    }
  }

  String _normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'aee') return 'aee';
    if (normalized == 'ee') return 'ee';
    return 'ae';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _statusLabel(String status) {
    return status
        .split('_')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
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

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  Future<void> _applyIntervention({String? statusOverride}) async {
    if (_saving) return;

    final effectiveStatus = statusOverride ?? _selectedStatus;
    if (!_aeeStatuses.contains(effectiveStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid AEE status.')),
      );
      return;
    }

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

        if (currentRole != 'aee') {
          throw StateError('Ownership changed. AEE actions are now read-only.');
        }

        final priority = (data['priority'] ?? widget.complaint.priority).toString();
        final selectedDeadline = _selectedDeadline ??
            _toDateTime(data['slaDeadline']) ??
            DateTime.now().add(_durationByPriority(priority));

        final resourceText = _resourceController.text.trim();
        final noteText = _notesController.text.trim();

        final updatePayload = <String, dynamic>{
          'assignedRole': 'aee',
          'currentOwnerRole': 'AEE',
          'status': effectiveStatus,
          'assignedAt': data['assignedAt'] ?? FieldValue.serverTimestamp(),
          'slaDeadline': Timestamp.fromDate(selectedDeadline),
          'aeeDeadline': Timestamp.fromDate(selectedDeadline),
          'assignedResources': resourceText.isEmpty ? 'Unassigned' : resourceText,
          'aeeNotes': noteText.isEmpty ? 'Not Added' : noteText,
          'escalationLevel': 2,
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (effectiveStatus == 'resolved' && noteText.isNotEmpty) {
          updatePayload['resolutionNote'] = noteText;
        }

        transaction.update(ref, updatePayload);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AEE workflow updated successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update escalation: $error')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('AEE Intervention')),
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
          final liveStatus = (data['status'] ?? complaint.status).toString();
          final canEdit = !_saving && liveAssignedRole == 'aee';

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (liveAssignedRole != 'aee')
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
                                'Ownership changed from AEE. This screen is now read-only.',
                                style: TextStyle(
                                  color: Color(0xFFC62828),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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
                                        backgroundColor: const Color(0xFFEDE7F6),
                                      ),
                                      Chip(
                                        label: Text('Priority: ${complaint.priority}'),
                                        backgroundColor: _priorityColor(complaint.priority)
                                            .withValues(alpha: 0.14),
                                      ),
                                      Chip(
                                        label: Text('Current: ${_prettyStatus(liveStatus)}'),
                                        backgroundColor: const Color(0xFFE8F5E9),
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
                                    'AEE Status Workflow',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedStatus,
                                    onChanged: canEdit
                                        ? (value) {
                                            if (value == null) return;
                                            setState(() => _selectedStatus = value);
                                          }
                                        : null,
                                    items: _aeeStatuses
                                        .map(
                                          (status) => DropdownMenuItem<String>(
                                            value: status,
                                            child: Text(_statusLabel(status)),
                                          ),
                                        )
                                        .toList(growable: false),
                                    decoration: const InputDecoration(
                                      labelText: 'Select status',
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
                                    'Set or Adjust Deadline',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: canEdit ? _pickDeadline : null,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.black26),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today_outlined),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(_formatDate(_selectedDeadline)),
                                          ),
                                        ],
                                      ),
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
                                    'Assign / Reassign Team',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _resourceController,
                                    enabled: canEdit,
                                    minLines: 2,
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Enter team names, vehicles, equipment, and assignments',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'AEE Notes / Comments',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _notesController,
                                    enabled: canEdit,
                                    minLines: 3,
                                    maxLines: 5,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter supervisory notes and decisions',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: canEdit
                              ? () => _applyIntervention(statusOverride: 'resolved')
                              : null,
                          icon: const Icon(Icons.verified),
                          label: const Text('Mark Resolved'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: canEdit ? _applyIntervention : null,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Update Workflow'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}