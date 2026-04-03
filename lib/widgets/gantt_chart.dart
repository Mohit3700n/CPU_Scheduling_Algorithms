import 'package:flutter/material.dart';
import '../models/gantt_block.dart';

class GanttChartWidget extends StatelessWidget {
  final List<GanttBlock> timeline;

  const GanttChartWidget({super.key, required this.timeline});

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Gantt Chart',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Container(
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: timeline.map((block) {
              return Expanded(
                flex: block.duration,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getColor(block.processId).withValues(alpha: 0.8),
                    border: const Border(right: BorderSide(color: Colors.black54, width: 2)),
                  ),
                  child: Center(
                    child: Text(
                      block.processId,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _buildTimeMarkers(),
        ),
      ],
    );
  }

  List<Widget> _buildTimeMarkers() {
    List<Widget> markers = [];

    markers.add(_timeText(timeline.first.startTime.toString()));

    for (var block in timeline) {
      markers.add(
        Expanded(
          flex: block.duration,
          child: Align(
            alignment: Alignment.centerRight,
            child: _timeText(block.endTime.toString()),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _timeText(String text) {
    return Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12));
  }

  Color _getColor(String id) {
    List<Color> colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF00C9A7),
      const Color(0xFFFF9066),
      const Color(0xFFFF5C8D),
      const Color(0xFF4D8AF0),
    ];
    int index = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    return colors[(index - 1) % colors.length];
  }
}