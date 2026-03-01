import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';

class HeatmapService {
  HeatmapService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<List<WeightedLatLng>> getRoleHeatPoints({
    required String role,
    String? priorityFilter,
  }) async {
    final normalizedRole = role.trim().toLowerCase();
    final normalizedPriority = priorityFilter?.trim().toLowerCase();

    final snapshot = await _db.collection('complaints').get();

    final buckets = <String, _BucketAccumulator>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final complaintRole = _resolveComplaintRole(data);
      if (complaintRole != normalizedRole) continue;

      final lat = _toDouble(data['latitude']);
      final lng = _toDouble(data['longitude']);
      if (lat == null || lng == null) continue;

      final priority = (data['priority'] ?? '').toString().trim().toLowerCase();
      if (normalizedPriority != null &&
          normalizedPriority.isNotEmpty &&
          normalizedPriority != 'all' &&
          priority != normalizedPriority) {
        continue;
      }

      final bucketLat = (lat * 100).round() / 100;
      final bucketLng = (lng * 100).round() / 100;
      final key = '$bucketLat,$bucketLng';

      final accumulator =
          buckets.putIfAbsent(key, () => _BucketAccumulator(bucketLat, bucketLng));
      accumulator.count += 1;
      accumulator.priorityWeight += _priorityWeight(priority);
    }

    return buckets.values
        .map(
          (bucket) => WeightedLatLng(
            LatLng(bucket.bucketLat, bucket.bucketLng),
            _heatIntensity(bucket.count, bucket.priorityWeight),
          ),
        )
        .toList(growable: false);
  }

  Future<List<LatLng>> getComplaintPoints() async {
    final snapshot = await _db.collection('complaints').get();

    return snapshot.docs
        .map((doc) {
      final data = doc.data();

          final lat = _toDouble(data['latitude']);
          final lng = _toDouble(data['longitude']);
          if (lat == null || lng == null) return null;

          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList(growable: false);
  }

  double _heatIntensity(int count, int priorityWeight) {
    final base = switch (count) {
      <= 5 => 8.0,
      <= 15 => 16.0,
      _ => 28.0,
    };

    return (base + priorityWeight).clamp(6.0, 45.0);
  }

  int _priorityWeight(String priority) {
    switch (priority.trim().toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 1;
    }
  }

  String _resolveComplaintRole(Map<String, dynamic> data) {
    final assignedRoleRaw = (data['assignedRole'] ?? '').toString().trim();
    final currentOwnerRoleRaw = (data['currentOwnerRole'] ?? '').toString().trim();

    final assignedRole = assignedRoleRaw.toLowerCase();
    if (assignedRole == 'ae' || assignedRole == 'aee' || assignedRole == 'ee') {
      return assignedRole;
    }

    final ownerRole = currentOwnerRoleRaw.toLowerCase();
    if (ownerRole == 'ae' || ownerRole == 'aee' || ownerRole == 'ee') {
      return ownerRole;
    }

    return 'ae';
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class _BucketAccumulator {
  _BucketAccumulator(this.bucketLat, this.bucketLng);

  final double bucketLat;
  final double bucketLng;
  int count = 0;
  int priorityWeight = 0;
}