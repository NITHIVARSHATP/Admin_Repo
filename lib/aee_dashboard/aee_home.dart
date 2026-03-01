import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/complaint_model.dart';
import '../services/complaint_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/escalation_timer.dart';
import '../widgets/complaint_heatmap_section.dart';
import '../ae_dashboard/ae_login_screen.dart';
import 'intervention.dart';

class AEEHome extends StatefulWidget {
  const AEEHome({super.key});

  @override
  State<AEEHome> createState() => _AEEHomeState();
}

class _AEEHomeState extends State<AEEHome> {
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
      await ComplaintService().checkAndProcessEscalations();
    } catch (_) {}
  }

  // Stream complaints currently owned by AEE
  Stream<List<ComplaintModel>> _streamAeeComplaints() {
    return _complaintService.streamActiveComplaints().map(
      (complaints) => complaints
          .where((complaint) => complaint.assignedRole.toLowerCase() == 'aee')
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Division Escalation Queue"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
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
        ],
      ),
      body: StreamBuilder<List<ComplaintModel>>(
        stream: _streamAeeComplaints(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final complaints = snapshot.data ?? const <ComplaintModel>[];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const ComplaintHeatmapSection(role: 'aee'),
              const SizedBox(height: 12),
              if (complaints.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No active AEE escalations.'),
                  ),
                )
              else
                ...complaints.map((comp) {
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        "${comp.category.toUpperCase()} • ${comp.title}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          EscalationTimer(lastUpdated: comp.lastUpdated),
                          const SizedBox(height: 4),
                          StatusBadge(status: comp.status),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.engineering_outlined,
                          size: 30,
                          color: Colors.deepPurple,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InterventionScreen(complaint: comp),
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
}