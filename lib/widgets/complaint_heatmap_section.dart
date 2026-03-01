import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';

import '../services/heatmap_service.dart';

class ComplaintHeatmapSection extends StatefulWidget {
  const ComplaintHeatmapSection({
    super.key,
    required this.role,
    this.title = 'Complaint Heatmap',
  });

  final String role;
  final String title;

  @override
  State<ComplaintHeatmapSection> createState() => _ComplaintHeatmapSectionState();
}

class _ComplaintHeatmapSectionState extends State<ComplaintHeatmapSection> {
  final HeatmapService _heatmapService = HeatmapService();
  List<WeightedLatLng> _heatPoints = const [];
  bool _loading = true;
  bool _enabled = true;
  String? _error;
  String _priorityFilter = 'All';

  static const List<String> _priorityOptions = ['All', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _loadHeatmap();
  }

  Future<void> _loadHeatmap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final points = await _heatmapService.getRoleHeatPoints(
        role: widget.role,
        priorityFilter: _priorityFilter,
      );

      if (!mounted) return;
      setState(() {
        _heatPoints = points;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  LatLng get _mapCenter {
    if (_heatPoints.isEmpty) {
      return const LatLng(11.0168, 76.9558);
    }

    final latitudeAvg =
        _heatPoints.map((point) => point.latLng.latitude).reduce((a, b) => a + b) /
            _heatPoints.length;
    final longitudeAvg =
        _heatPoints.map((point) => point.latLng.longitude).reduce((a, b) => a + b) /
            _heatPoints.length;

    return LatLng(latitudeAvg, longitudeAvg);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A148C),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Show',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: (value) {
                        setState(() => _enabled = value);
                      },
                    ),
                  ],
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: _priorityFilter,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: _priorityOptions
                        .map(
                          (priority) => DropdownMenuItem<String>(
                            value: priority,
                            child: Text(priority),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _priorityFilter = value);
                      _loadHeatmap();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _buildMapBody(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _LegendItem(color: Colors.red, text: 'High (16+)'),
                _LegendItem(color: Colors.orange, text: 'Medium (6-15)'),
                _LegendItem(color: Colors.green, text: 'Low (0-5)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBody() {
    if (!_enabled) {
      return const Center(
        child: Text(
          'Heatmap is turned off',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Failed to load heatmap: $_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_heatPoints.isEmpty) {
      return const Center(
        child: Text(
          'No complaint coordinates available for this role.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.civic_admin_app',
        ),
        HeatMapLayer(
          heatMapDataSource: InMemoryHeatMapDataSource(data: _heatPoints),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.text,
  });

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }
}
