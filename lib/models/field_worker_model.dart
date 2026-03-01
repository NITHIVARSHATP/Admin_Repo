// lib/models/field_worker_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FieldWorkerModel {
  final String id;
  final String name;
  final String role;
  final String section; // e.g., "Peelamedu Section" [cite: 10]
  final String contact;
  final bool isAvailable;

  FieldWorkerModel({
    required this.id,
    required this.name,
    required this.role,
    required this.section,
    required this.contact,
    this.isAvailable = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'section': section,
      'contact': contact,
      'isAvailable': isAvailable,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}