import 'package:cpu_scheduling_algorithm/screens/battle_mode_screen.dart';
import 'package:cpu_scheduling_algorithm/screens/io_simulation_screen.dart';
import 'package:cpu_scheduling_algorithm/screens/single_algo_screen.dart';
import 'package:cpu_scheduling_algorithm/screens/beat_the_os_screen.dart';
import 'package:cpu_scheduling_algorithm/screens/tcp_sliding_window_screen.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<StatefulWidget> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        primaryColor: const Color(0xFF6C63FF),
        cardColor: const Color(0xFF2A2D3E),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CPU Scheduling Visualizer',
                  style: TextStyle(
                    fontSize: isMobile ? 24 : 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a mode to begin testing and visualizing algorithms.',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: isMobile ? 24 : 40),

                Expanded(
                  child: isMobile
                      ? ListView(
                    children: _buildCardsList(context, isMobile)
                        .map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: card,
                    ))
                        .toList(),
                  )
                      : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 30,
                      mainAxisSpacing: 30,
                      mainAxisExtent: 140,
                    ),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return _buildCardsList(context, isMobile)[index];
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCardsList(BuildContext context, bool isMobile) {
    return [
      _buildModeCard(
        title: 'Single Algorithm',
        description: 'Visualize FCFS, SJF, SRTF, RR step-by-step with Gantt Charts.',
        icon: Icons.play_circle_fill,
        color: const Color(0xFF6C63FF),
        isMobile: isMobile,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SingleAlgoScreen())),
      ),
      _buildModeCard(
        title: 'Algorithm Battle',
        description: 'Run 4 algorithms simultaneously and compare performance.',
        icon: Icons.stacked_bar_chart,
        color: const Color(0xFF00C9A7),
        isMobile: isMobile,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BattleModeScreen())),
      ),
      _buildModeCard(
        title: 'I/O Burst Simulation',
        description: 'Advanced mode with context switching and I/O wait times.',
        icon: Icons.developer_board,
        color: const Color(0xFFFF9066),
        isMobile: isMobile,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const IoSimulationScreen())),
      ),
      _buildModeCard(
        title: 'Beat the OS',
        description: 'Act as the scheduler. Can you beat the optimal algorithm?',
        icon: Icons.sports_esports,
        color: const Color(0xFFFF5C8D),
        isMobile: isMobile,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BeatTheOsScreen())),
      ),
      _buildModeCard(
        title: 'TCP Sliding Window',
        description: 'Computer Networks Simulation. Send packets, inject loss, and watch the Go-Back-N protocol in action.',
        icon: Icons.hub,
        color: const Color(0xFFFF9066),
        isMobile: isMobile,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TcpSlidingWindowScreen())),
      ),
    ];
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isMobile,
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
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: isMobile ? 28 : 36),
            ),
            SizedBox(width: isMobile ? 16 : 24),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white54,
                              height: 1.2,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}