import 'package:flutter/material.dart';

import '../models/complaint_model.dart';
import '../services/complaint_service.dart';
import 'assign_staff_screen.dart';
import 'resolution_entry_screen.dart';

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.complaintId,
    ComplaintService? complaintService,
  }) : _complaintService = complaintService;

  final String complaintId;
  final ComplaintService? _complaintService;

  ComplaintService get complaintService => _complaintService ?? ComplaintService();

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  static const String _assignedOfficialEmail = 'sakthi@gmail.com';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Detail')),
      body: StreamBuilder<ComplaintModel?>(
        stream: widget.complaintService.streamComplaintById(widget.complaintId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final complaint = snapshot.data;
          if (complaint == null) {
            return const Center(child: Text('Complaint not found.'));
          }

          final normalizedStatus = _normalizeStatus(complaint.status);
            final ownedByAe = complaint.assignedRole.trim().toLowerCase() == 'ae';
          final canMarkUnderReview =
              ownedByAe &&
                (normalizedStatus == 'classified' ||
                  normalizedStatus == 'reopened');
          final canAssignFieldStaff =
              ownedByAe &&
                (normalizedStatus == 'classified' ||
                  normalizedStatus == 'under_review');
            final canMarkInProgress = ownedByAe && normalizedStatus == 'under_review';
            final canResolutionEntry = ownedByAe && normalizedStatus == 'in_progress';
            final canReopenComplaint = ownedByAe && normalizedStatus == 'resolved';
            final canDeleteComplaint = ownedByAe && normalizedStatus == 'resolved';
          final showActions = canMarkUnderReview ||
              canAssignFieldStaff ||
              canMarkInProgress ||
              canResolutionEntry ||
              canReopenComplaint ||
              canDeleteComplaint;

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 1.5,
                        shadowColor: Colors.black12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaint.title,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Complaint ID: ${complaint.complaintId}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _pill(
                                      'Status: ${_displayStatus(complaint.status)}',
                                      _statusColor(normalizedStatus),
                                    ),
                                    const SizedBox(width: 8),
                                    _pill(
                                      'Priority: ${complaint.priority}',
                                      _priorityColor(complaint.priority),
                                    ),
                                    const SizedBox(width: 8),
                                    _pill(
                                      'Category: ${complaint.category}',
                                      const Color(0xFF4A148C),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final useTwoColumns = constraints.maxWidth >= 900;
                          const fixedTopCardHeight = 320.0;
                          final isResolved = normalizedStatus == 'resolved';
                          final escalationDuration =
                              getEscalationDuration(complaint.priority);
                          final nextRole = getNextRole(complaint.assignedRole);

                          final complaintInfoCard = _sectionCard(
                            title: 'Complaint Info',
                            height: fixedTopCardHeight,
                            centerContent: true,
                            children: [
                              _detailItem('Title', complaint.title, maxLines: 2),
                              _detailItem('Description', complaint.description, maxLines: 4),
                              _detailItem('Category', complaint.category),
                              _detailItem('Priority', complaint.priority),
                              _detailItem('Status', _displayStatus(complaint.status)),
                              if (normalizedStatus == 'resolved')
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Problem Resolved',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          );

                          final locationDetailsCard = _sectionCard(
                            title: 'Location Details',
                            height: fixedTopCardHeight,
                            centerContent: true,
                            children: [
                              _detailItem(
                                'Coordinates',
                                'Lat: ${complaint.latitude?.toStringAsFixed(5) ?? 'N/A'}, '
                                'Long: ${complaint.longitude?.toStringAsFixed(5) ?? 'N/A'}',
                                maxLines: 3,
                              ),
                              _detailItem('Ward', complaint.ward),
                            ],
                          );

                          final assignmentDetailsCard = _sectionCard(
                            title: 'Assignment Details',
                            height: fixedTopCardHeight,
                            centerContent: true,
                            children: [
                              _detailItem('Assigned Official', _assignedOfficialEmail),
                              _detailItem('Assigned Field Staff', _assignedFieldStaffText(complaint), maxLines: 3),
                              _detailItem('Assigned Staff Role', _assignedRoleText(complaint.assignedStaffRole)),
                              _detailItem('Current Assigned Role', _displayRole(complaint.assignedRole)),
                            ],
                          );

                          final resolutionDetailsCard = _sectionCard(
                            title: 'Resolution Details',
                            height: fixedTopCardHeight,
                            centerContent: true,
                            children: [
                              _detailItem('Resolution Note', complaint.resolutionNote, maxLines: 4),
                              _detailItem('Proof Image', complaint.proofImage, maxLines: 3),
                            ],
                          );

                          final topSection = useTwoColumns
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          complaintInfoCard,
                                          const SizedBox(height: 14),
                                          locationDetailsCard,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          assignmentDetailsCard,
                                          const SizedBox(height: 14),
                                          resolutionDetailsCard,
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    complaintInfoCard,
                                    const SizedBox(height: 14),
                                    locationDetailsCard,
                                    const SizedBox(height: 14),
                                    assignmentDetailsCard,
                                    const SizedBox(height: 14),
                                    resolutionDetailsCard,
                                  ],
                                );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              topSection,
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 330,
                                child: Card(
                                  elevation: 1.5,
                                  shadowColor: Colors.black12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Complaint Image',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: complaint.imageUrl.trim().isNotEmpty
                                                ? Image.network(
                                                    complaint.imageUrl,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(
                                                      color: Colors.grey.shade200,
                                                      alignment: Alignment.center,
                                                      child: const Text('Unable to load complaint image'),
                                                    ),
                                                  )
                                                : Container(
                                                    width: double.infinity,
                                                    color: Colors.grey.shade100,
                                                    alignment: Alignment.center,
                                                    child: const Text(
                                                      'No complaint image available',
                                                      style: TextStyle(
                                                        color: Color(0xFF6B7280),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 248,
                                child: Card(
                                  elevation: 1.5,
                                  shadowColor: Colors.black12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Workflow Actions',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF4A148C),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                _detailItem(
                                                  'Assigned Official',
                                                  _assignedOfficialEmail,
                                                ),
                                                _detailItem(
                                                  'Assigned Field Staff',
                                                  _assignedFieldStaffText(complaint),
                                                  maxLines: 2,
                                                ),
                                                _detailItem(
                                                  'Current Status',
                                                  _displayStatus(complaint.status),
                                                ),
                                                _detailItem(
                                                  'Current Assigned Role',
                                                  _displayRole(complaint.assignedRole),
                                                ),
                                                _detailItem(
                                                  'Assigned Time',
                                                  _formatDateTime(complaint.assignedAt),
                                                ),
                                                if (!isResolved)
                                                  _detailItem(
                                                    'Time Remaining',
                                                    _timeRemainingBeforeEscalation(
                                                      complaint.assignedAt,
                                                      escalationDuration,
                                                      complaint.assignedRole,
                                                    ),
                                                  ),
                                                if (!isResolved && complaint.assignedRole.toLowerCase() != 'ee')
                                                  _detailItem(
                                                    'Next Escalation',
                                                    '${_displayRole(complaint.assignedRole)} → ${_displayRole(nextRole)}',
                                                  ),
                                                const SizedBox(height: 4),
                                                const Divider(height: 1),
                                                const SizedBox(height: 10),
                                                _escalationHistorySection(complaint),
                                                const SizedBox(height: 10),
                                                Text(
                                                  !ownedByAe
                                                      ? 'This complaint is owned by ${_displayRole(complaint.assignedRole)}. AE actions are disabled.'
                                                      : showActions
                                                      ? 'Buttons shown are valid for this status.'
                                                      : 'This complaint is read-only for AE workflow.',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black54,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                if (showActions)
                                                  ..._buildActionButtons(complaint),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (_loading) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailItem(String label, String value, {int maxLines = 2}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final labelWidth = screenWidth >= 900 ? 160.0 : 128.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                letterSpacing: 0.2,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _statusColor(String normalizedStatus) {
    switch (normalizedStatus) {
      case 'resolved':
        return const Color(0xFF2E7D32);
      case 'in_progress':
        return const Color(0xFFEF6C00);
      case 'under_review':
        return const Color(0xFF4A148C);
      case 'reopened':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF1565C0);
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.trim().toLowerCase()) {
      case 'high':
        return const Color(0xFFC62828);
      case 'medium':
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Widget _sectionCard({
    required String title,
    required double height,
    required List<Widget> children,
    bool centerContent = false,
  }) {
    return SizedBox(
      height: height,
      child: Card(
        elevation: 1.5,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4A148C),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayStatus(String status) {
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

  List<Widget> _buildActionButtons(ComplaintModel complaint) {
    final normalizedStatus = _normalizeStatus(complaint.status);
    final canMarkUnderReview =
        normalizedStatus == 'classified' || normalizedStatus == 'reopened';
    final canAssignFieldStaff =
        normalizedStatus == 'classified' || normalizedStatus == 'under_review';
    final canMarkInProgress = normalizedStatus == 'under_review';
    final canResolutionEntry = normalizedStatus == 'in_progress';
    final canReopenComplaint = normalizedStatus == 'resolved';
    final canDeleteComplaint = normalizedStatus == 'resolved';

    final buttons = <Widget>[
      if (canMarkUnderReview)
        ElevatedButton.icon(
          onPressed: _loading
              ? null
              : () => _updateStatusUnderReview(
                    complaint.complaintId,
                  ),
          icon: const Icon(Icons.rule_folder),
          label: const Text('Mark Under Review'),
        ),
      if (canAssignFieldStaff)
        OutlinedButton.icon(
          onPressed: _loading
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AssignStaffScreen(
                        complaintId: complaint.complaintId,
                        complaintService: widget.complaintService,
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Assign Field Staff'),
        ),
      if (canMarkInProgress)
        ElevatedButton.icon(
          onPressed: _loading
              ? null
              : () => _updateStatusInProgress(
                    complaint.complaintId,
                  ),
          icon: const Icon(Icons.build_circle),
          label: const Text('Mark In Progress'),
        ),
      if (canResolutionEntry)
        OutlinedButton.icon(
          onPressed: _loading
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ResolutionEntryScreen(
                        complaintId: complaint.complaintId,
                        complaintService: widget.complaintService,
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.verified),
          label: const Text('Resolution Entry'),
        ),
      if (canReopenComplaint)
        OutlinedButton.icon(
          onPressed: _loading
              ? null
              : () => _reopenComplaint(
                    complaint.complaintId,
                  ),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reopen Complaint'),
        ),
      if (canDeleteComplaint)
        OutlinedButton.icon(
          onPressed: _loading
              ? null
              : () => _deleteComplaint(
                    complaint.complaintId,
                  ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFC62828),
            side: const BorderSide(color: Color(0xFFC62828)),
          ),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete Complaint'),
        ),
    ];

    final result = <Widget>[];
    for (var index = 0; index < buttons.length; index++) {
      result.add(
        SizedBox(
          width: double.infinity,
          child: buttons[index],
        ),
      );
      if (index != buttons.length - 1) {
        result.add(const SizedBox(height: 8));
      }
    }
    return result;
  }

  String _assignedFieldStaffText(ComplaintModel complaint) {
    final assignedTo = complaint.assignedTo.trim();
    final assignedRole = complaint.assignedStaffRole.trim();
    final normalizedAssignedTo = assignedTo.toLowerCase();
    final normalizedRole = assignedRole.toLowerCase();

    final isUnassigned = assignedTo.isEmpty ||
        normalizedAssignedTo == 'pending' ||
        normalizedAssignedTo == 'unassigned' ||
        (normalizedAssignedTo == _assignedOfficialEmail &&
            (normalizedRole.isEmpty || normalizedRole == 'pending'));

    if (isUnassigned) {
      return 'Unassigned';
    }

    if (normalizedRole.isEmpty || normalizedRole == 'pending') {
      return assignedTo;
    }

    return '$assignedTo ($assignedRole)';
  }

  String _assignedRoleText(String role) {
    final value = role.trim();
    if (value.isEmpty || value.toLowerCase() == 'pending') {
      return 'Pending';
    }
    return value;
  }

  String _displayRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'aee') return 'AEE';
    if (normalized == 'ee') return 'EE';
    return 'AE';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Not available';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.year} $hour:$minute';
  }

  String _timeRemainingBeforeEscalation(
    DateTime? assignedAt,
    Duration escalationDuration,
    String currentRole,
  ) {
    if (currentRole.trim().toLowerCase() == 'ee') {
      return 'Final escalation level reached';
    }
    if (assignedAt == null) return 'Not available';

    final deadline = assignedAt.add(escalationDuration);
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) {
      return 'Escalation overdue';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return '${hours}h ${minutes}m remaining';
  }

  Widget _escalationHistorySection(ComplaintModel complaint) {
    final history = complaint.escalationHistory;
    if (history.isEmpty) {
      return const Text(
        'Escalation History: No escalations yet.',
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF4B5563),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final entries = [...history]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Escalation History',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF4B5563),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${_displayRole(entry.fromRole)} → ${_displayRole(entry.toRole)} '
              '(${entry.reason}) • ${_formatDateTime(entry.timestamp)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF111827),
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _normalizeStatus(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  Future<void> _updateStatusUnderReview(String complaintId) async {
    setState(() => _loading = true);
    try {
      await widget.complaintService.markUnderReview(complaintId);
      _showMessage('Status updated to under_review');
    } catch (error) {
      _showMessage('Failed to update status: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateStatusInProgress(String complaintId) async {
    setState(() => _loading = true);
    try {
      await widget.complaintService.markInProgress(complaintId);
      _showMessage('Status updated to in_progress');
    } catch (error) {
      final message = error.toString();
      if (message.toLowerCase().contains('assign field staff')) {
        await _showAssignmentRequiredAlert();
      } else {
        _showMessage('Failed to update status: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reopenComplaint(String complaintId) async {
    final confirmed = await _confirmReopen();
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      await widget.complaintService.reopenComplaint(complaintId);
      _showMessage('Complaint reopened and reset to classified.');
    } catch (error) {
      _showMessage('Failed to reopen complaint: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteComplaint(String complaintId) async {
    final confirmed = await _confirmDelete();
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      await widget.complaintService.deleteComplaint(complaintId);
      if (!mounted) return;
      _showMessage('Complaint deleted successfully.');
      Navigator.of(context).pop();
    } catch (error) {
      _showMessage('Failed to delete complaint: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Complaint?'),
          content: const Text(
            'This action will permanently remove the resolved complaint. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<bool> _confirmReopen() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reopen Complaint?'),
          content: const Text(
            'This will restart workflow from classified and clear assigned field staff and resolution details. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reopen'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showAssignmentRequiredAlert() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assignment Required'),
          content: const Text(
            'Please assign field staff before marking In Progress.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}