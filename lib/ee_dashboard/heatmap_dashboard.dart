// lib/ee_dashboard/heatmap_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';
import '../services/heatmap_service.dart';

class HeatmapDashboard extends StatefulWidget {
  const HeatmapDashboard({super.key});

  @override
  State<HeatmapDashboard> createState() => _HeatmapDashboardState();
}

class _HeatmapDashboardState extends State<HeatmapDashboard> {
  final HeatmapService _heatmapService = HeatmapService();
  List<WeightedLatLng> _heatPoints = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _generateHeatmap();
  }

  Future<void> _generateHeatmap() async {
    try {
      final points = await _heatmapService.getComplaintPoints();

      if (!mounted) return;
      setState(() {
        _heatPoints = points.map((point) => WeightedLatLng(point, 20.0)).toList();
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Proactive Maintenance Heatmap"),
        backgroundColor: Colors.deepPurple,
      ),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(11.0168, 76.9558), // Peelamedu
          zoom: 14,
        ),
        children: [
          /// OpenStreetMap Tiles
          TileLayer(
            urlTemplate:
            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.civic_admin_app',
          ),

          /// Heatmap Layer
          if (_heatPoints.isNotEmpty)
            HeatMapLayer(
              heatMapDataSource: InMemoryHeatMapDataSource(
                data: _heatPoints,
              ),
            ),

          if (_loading)
            const Center(child: CircularProgressIndicator()),

          if (!_loading && _loadError != null)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Failed to load heatmap: $_loadError'),
                ),
              ),
            ),

          if (!_loading && _loadError == null && _heatPoints.isEmpty)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No complaint coordinates available for heatmap.'),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
              Text("Flagging High-Density Complaint Wards for Review"),
            ),
          );
        },
        label: const Text("Flag Hotspots"),
        icon: const Icon(Icons.warning_amber_rounded),
      ),
    );
  }
}