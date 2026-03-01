import 'package:flutter/material.dart';

import '../services/complaint_service.dart';

class AssignStaffScreen extends StatefulWidget {
  const AssignStaffScreen({
    super.key,
    required this.complaintId,
    ComplaintService? complaintService,
  }) : _complaintService = complaintService;

  final String complaintId;
  final ComplaintService? _complaintService;

  ComplaintService get complaintService => _complaintService ?? ComplaintService();

  @override
  State<AssignStaffScreen> createState() => _AssignStaffScreenState();
}

class _AssignStaffScreenState extends State<AssignStaffScreen> {
  static const roles = ['Line Inspector', 'Foreman'];

  final TextEditingController _nameController = TextEditingController();
  String _selectedRole = roles.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Field Staff')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Assignment Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: roles
                      .map(
                        (role) => DropdownMenuItem<String>(
                      value: role,
                      child: Text(role),
                    ),
                  )
                      .toList(growable: false),
                  onChanged: _saving
                      ? null
                      : (value) {
                    if (value != null) {
                      setState(() => _selectedRole = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Staff Name',
                    hintText: 'Enter assignee name',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveAssignment,
                    child: const Text('Save Assignment'),
                  ),
                ),
                if (_saving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAssignment() async {
    setState(() => _saving = true);
    try {
      await widget.complaintService.assignFieldStaff(
        complaintId: widget.complaintId,
        assignedTo: _nameController.text,
        assignedRole: _selectedRole,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Field staff assignment saved')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save assignment: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}