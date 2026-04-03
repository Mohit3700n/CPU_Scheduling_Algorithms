import 'package:cpu_scheduling_algorithm/screens/battle_mode_screen.dart';
import 'package:cpu_scheduling_algorithm/screens/io_simulation_screen.dart';
import 'package:cpu_scheduling_algorithm/screens/single_algo_screen.dart';
import 'package:cpu_scheduling_algorithm/screens/beat_the_os_screen.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<StatefulWidget> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        primaryColor: const Color(0xFF6C63FF),
        cardColor: const Color(0xFF2A2D3E),
      ),
      child: Scaffold(
        body: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CPU Scheduling Visualizer',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a mode to begin testing and visualizing algorithms.',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 40),

                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 30,
                        mainAxisSpacing: 30,
                        childAspectRatio: 3.0,
                        children: [
                          _buildModeCard(
                            title: 'Single Algorithm',
                            description: 'Visualize FCFS, SJF, SRTF, RR step-by-step with Gantt Charts.',
                            icon: Icons.play_circle_fill,
                            color: const Color(0xFF6C63FF),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SingleAlgoScreen()))
                          ),
                          _buildModeCard(
                            title: 'Algorithm Battle',
                            description: 'Run 4 algorithms simultaneously and compare performance.',
                            icon: Icons.stacked_bar_chart,
                            color: const Color(0xFF00C9A7),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BattleModeScreen()))
                          ),
                          _buildModeCard(
                            title: 'I/O Burst Simulation',
                            description: 'Advanced mode with context switching and I/O wait times.',
                            icon: Icons.developer_board,
                            color: const Color(0xFFFF9066),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const IoSimulationScreen()))
                          ),
                          _buildModeCard(
                            title: 'Beat the OS',
                            description: 'Act as the scheduler. Can you beat the optimal algorithm?',
                            icon: Icons.sports_esports,
                            color: const Color(0xFFFF5C8D),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BeatTheOsScreen()))
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D3E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}