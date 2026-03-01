import 'package:flutter/material.dart';

import '../services/complaint_service.dart';

class ResolutionEntryScreen extends StatefulWidget {
  const ResolutionEntryScreen({
    super.key,
    required this.complaintId,
    ComplaintService? complaintService,
  }) : _complaintService = complaintService;

  final String complaintId;
  final ComplaintService? _complaintService;

  ComplaintService get complaintService => _complaintService ?? ComplaintService();

  @override
  State<ResolutionEntryScreen> createState() => _ResolutionEntryScreenState();
}

class _ResolutionEntryScreenState extends State<ResolutionEntryScreen> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _proofController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    _proofController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resolution Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resolution Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 4,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Resolution Note',
                    hintText: 'Describe the fix done on-site',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proofController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Proof Image URL (Optional)',
                    hintText: 'https://example.com/proof.jpg',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submitResolution,
                    child: const Text('Mark Resolved'),
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

  Future<void> _submitResolution() async {
    setState(() => _saving = true);
    try {
      await widget.complaintService.markResolved(
        complaintId: widget.complaintId,
        resolutionNote: _noteController.text,
        proofImage: _proofController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint marked as Resolved')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save resolution: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}