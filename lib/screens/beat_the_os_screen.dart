import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Isolate ke liye
import 'package:flutter/material.dart';

import '../models/algo_stats.dart';
import '../models/process.dart';
import '../models/gantt_block.dart';
import '../algorithms/fcfs.dart';
import '../algorithms/sjf.dart';
import '../algorithms/srtf.dart';
import '../algorithms/round_robin.dart';
import '../widgets/gantt_chart.dart';

Map<String, dynamic> _computeBattleExecution(Map<String, dynamic> args) {
  List<Process> userQueue = args['userQueue'];
  List<Process> osQueue = args['osQueue'];
  String osAlgo = args['osAlgo'];

  List<Process> userResults = [];
  List<GanttBlock> userTimeline = [];
  int currentTime = 0;
  for (var p in userQueue) {
    if (currentTime < p.arrivalTime) {
      currentTime = p.arrivalTime;
    }
    int start = currentTime;
    currentTime += p.burstTime;

    userTimeline.add(GanttBlock(processId: p.id, startTime: start, endTime: currentTime));
    p.completionTime = currentTime;
    p.turnaroundTime = p.completionTime - p.arrivalTime;
    p.waitingTime = p.turnaroundTime - p.burstTime;
    userResults.add(Process(id: p.id, arrivalTime: p.arrivalTime, burstTime: p.burstTime)
      ..completionTime = p.completionTime
      ..turnaroundTime = p.turnaroundTime
      ..waitingTime = p.waitingTime);
  }

  List<Process> osResults = [];
  List<GanttBlock> osTimeline = [];

  if (osAlgo == 'FCFS') {
    osResults = FCFSScheduler.run(osQueue);
    osTimeline = _convertToBlocks(osResults);
  } else if (osAlgo == 'SJF') {
    osResults = SJFScheduler.run(osQueue);
    osTimeline = _convertToBlocks(osResults);
  } else if (osAlgo == 'SRTF') {
    var srtfOutput = SRTFScheduler.run(osQueue);
    osResults = srtfOutput.processes;
    osTimeline = srtfOutput.ganttTimeline;
  } else if (osAlgo == 'RR') {
    var rrOutput = RRScheduler.run(osQueue, 2);
    osResults = rrOutput.processes;
    osTimeline = rrOutput.ganttTimeline;
  }

  double userAvgWT = userResults.fold(0.0, (sum, p) => sum + p.waitingTime) / userResults.length;
  double osAvgWT = osResults.fold(0.0, (sum, p) => sum + p.waitingTime) / osResults.length;

  return {
    'userResults': userResults,
    'userTimeline': userTimeline,
    'userAvgWT': userAvgWT,
    'osResults': osResults,
    'osTimeline': osTimeline,
    'osAvgWT': osAvgWT,
  };
}

List<GanttBlock> _convertToBlocks(List<Process> processes) {
  List<GanttBlock> blocks = processes.map((p) {
    return GanttBlock(processId: p.id, startTime: p.completionTime - p.burstTime, endTime: p.completionTime);
  }).toList();
  blocks.sort((a, b) => a.startTime.compareTo(b.startTime));
  return blocks;
}

class BeatTheOsScreen extends StatefulWidget {
  const BeatTheOsScreen({super.key});

  @override
  State<BeatTheOsScreen> createState() => _BeatTheOsScreenState();
}

class _BeatTheOsScreenState extends State<BeatTheOsScreen> with SingleTickerProviderStateMixin {
  List<Process> initialProcesses = [];
  List<Process> availablePool = [];
  List<Process> userSequence = [];

  String osAlgo = 'SJF';
  double serverTemperature = 40.0;
  bool isCalculating = false;

  bool isBattleMode = false;
  List<Process> userResultProcs = [];
  List<Process> osResultProcs = [];
  List<GanttBlock> userTimeline = [];
  List<GanttBlock> osTimeline = [];
  double userAvgWT = 0;
  double osAvgWT = 0;

  final ValueNotifier<int> currentTick = ValueNotifier<int>(0);
  int maxTick = 0;
  Timer? playbackTimer;
  bool isPlaying = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(_pulseController);
    _startNewGame();
  }

  @override
  void dispose() {
    playbackTimer?.cancel();
    currentTick.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startNewGame() {
    playbackTimer?.cancel();
    final random = Random();
    int processCount = random.nextInt(3) + 4;

    List<Process> newProcs = [];
    Set<String> uniqueSignatures = {};

    int firstBt = random.nextInt(8) + 2;
    newProcs.add(Process(id: 'P1', arrivalTime: 0, burstTime: firstBt));
    uniqueSignatures.add("0_$firstBt");

    for (int i = 2; i <= processCount; i++) {
      int at, bt;
      String signature;
      do {
        at = random.nextInt(6);
        bt = random.nextInt(8) + 1;
        signature = "${at}_$bt";
      } while (uniqueSignatures.contains(signature));
      uniqueSignatures.add(signature);
      newProcs.add(Process(id: 'P$i', arrivalTime: at, burstTime: bt));
    }

    newProcs.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

    for (int i = 0; i < newProcs.length; i++) {
      newProcs[i] = Process(id: 'P${i + 1}', arrivalTime: newProcs[i].arrivalTime, burstTime: newProcs[i].burstTime);
    }

    setState(() {
      initialProcesses = newProcs;
      availablePool = List.from(newProcs);
      userSequence = [];
      isBattleMode = false;
      serverTemperature = 40.0;
      currentTick.value = 0;
      isPlaying = false;
    });
  }

  void _updateTemperature() {
    if (userSequence.isEmpty) {
      serverTemperature = 40.0;
      return;
    }

    double penalty = 0;
    int cTime = 0;
    for (var p in userSequence) {
      if (cTime < p.arrivalTime) {
        penalty += (p.arrivalTime - cTime) * 15;
        cTime = p.arrivalTime;
      }
      cTime += p.burstTime;
    }
    serverTemperature = 40.0 + penalty;
    if (serverTemperature > 120.0) serverTemperature = 120.0;
  }

  void _selectProcess(Process p) {
    setState(() {
      availablePool.remove(p);
      userSequence.add(p);
      _updateTemperature();
    });
  }

  void _deselectProcess(Process p) {
    setState(() {
      userSequence.remove(p);
      availablePool.add(p);
      _updateTemperature();
    });
  }

  Future<void> _runBattle() async {
    if (availablePool.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arrange ALL processes first!'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() {
      isCalculating = true;
    });

    List<Process> userCopy = userSequence.map((p) => Process(id: p.id, arrivalTime: p.arrivalTime, burstTime: p.burstTime)).toList();
    List<Process> osCopy = initialProcesses.map((p) => Process(id: p.id, arrivalTime: p.arrivalTime, burstTime: p.burstTime)).toList();

    final result = await compute(_computeBattleExecution, {
      'userQueue': userCopy,
      'osQueue': osCopy,
      'osAlgo': osAlgo,
    });

    if (!mounted) return;

    setState(() {
      userResultProcs = result['userResults'];
      userTimeline = result['userTimeline'];
      userAvgWT = result['userAvgWT'];

      osResultProcs = result['osResults'];
      osTimeline = result['osTimeline'];
      osAvgWT = result['osAvgWT'];

      int userMax = userTimeline.isNotEmpty ? userTimeline.last.endTime : 0;
      int osMax = osTimeline.isNotEmpty ? osTimeline.last.endTime : 0;
      maxTick = max(userMax, osMax);

      isCalculating = false;
      isBattleMode = true;
    });

    _togglePlayback();
  }

  void _togglePlayback() {
    if (isPlaying) {
      playbackTimer?.cancel();
      setState(() => isPlaying = false);
    } else {
      if (currentTick.value >= maxTick) currentTick.value = 0;
      setState(() => isPlaying = true);

      playbackTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
        if (currentTick.value >= maxTick) {
          timer.cancel();
          setState(() => isPlaying = false);
        } else {
          currentTick.value++;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Breakpoint defined here
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Beat The OS: Live Battle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2A2D3E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _startNewGame),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: isCalculating
              ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
              : isBattleMode
              ? _buildBattleArena(isMobile)
              : _buildSelectionScreen(isMobile),
        ),
      ),
    );
  }

  // --- SELECTION SCREEN ---
  Widget _buildSelectionScreen(bool isMobile) {
    Color heatColor = Colors.greenAccent;
    if (serverTemperature > 60) heatColor = Colors.orangeAccent;
    if (serverTemperature > 90) heatColor = Colors.redAccent;

    // Extracted column widgets to reuse in Row or Column
    Widget availableProcessesColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("1. Available Processes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(12)),
            child: availablePool.isEmpty
                ? const Center(child: Text("Ready!", style: TextStyle(color: Colors.greenAccent)))
                : SingleChildScrollView(child: Wrap(spacing: 8, runSpacing: 8, children: availablePool.map((p) => _buildProcessCard(p, true)).toList())),
          ),
        ),
      ],
    );

    Widget customQueueColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("2. Your Custom Queue", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: heatColor, width: 2), borderRadius: BorderRadius.circular(12)),
            child: userSequence.isEmpty
                ? const Center(child: Text("Empty", style: TextStyle(color: Colors.white54)))
                : SingleChildScrollView(
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(userSequence.length, (index) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Rank ${index + 1}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      _buildProcessCard(userSequence[index], false),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(12), border: Border.all(color: heatColor, width: 2)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Live Server Temperature 🌡️", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("${serverTemperature.toStringAsFixed(1)}°C", style: TextStyle(color: heatColor, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: (serverTemperature - 40) / (120 - 40), backgroundColor: Colors.white12, color: heatColor, minHeight: 10),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),

        // FIX: Switch layout based on device width
        Expanded(
          child: isMobile
              ? Column(
            children: [
              Expanded(child: availableProcessesColumn),
              const SizedBox(height: 16),
              Expanded(child: customQueueColumn),
            ],
          )
              : Row(
            children: [
              Expanded(child: availableProcessesColumn),
              const SizedBox(width: 16),
              Expanded(child: customQueueColumn),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: availablePool.isEmpty ? const Color(0xFFFF5C8D) : Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
            onPressed: availablePool.isEmpty ? _runBattle : null,
            icon: const Icon(Icons.flash_on, color: Colors.white),
            label: const Text('ENGAGE BATTLE!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        )
      ],
    );
  }

  Widget _buildProcessCard(Process p, bool isAvailable) {
    return InkWell(
      onTap: () => isAvailable ? _selectProcess(p) : _deselectProcess(p),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
          border: Border.all(color: const Color(0xFF6C63FF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(p.id, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(color: Colors.white24, height: 8),
            Text("AT: ${p.arrivalTime}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text("BT: ${p.burstTime}", style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- LIVE BATTLE ARENA ---
  Widget _buildBattleArena(bool isMobile) {
    return ValueListenableBuilder<int>(
      valueListenable: currentTick,
      builder: (context, tick, child) {
        bool battleOver = tick >= maxTick;

        // Top Panel controls
        Widget statusBanner = battleOver ? _buildResultBanner() : Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(12)),
          child: const Text("BATTLE IN PROGRESS...", textAlign: TextAlign.center, style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
        );

        Widget timeControls = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.greenAccent, size: 36), onPressed: _togglePlayback),
              IconButton(icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 36), onPressed: () { playbackTimer?.cancel(); setState(() => isPlaying = false); currentTick.value = 0; }),
              const SizedBox(width: 12),
              Text("Time: $tick ms", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOP PANEL: Responsive switch
            isMobile
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [statusBanner, const SizedBox(height: 8), timeControls],
            )
                : Row(
              children: [
                Expanded(child: statusBanner),
                const SizedBox(width: 16),
                timeControls
              ],
            ),

            const SizedBox(height: 16),

            // DUAL ARENA: Responsive switch
            Expanded(
              child: isMobile
              // FIX: Use ListView on mobile to prevent squishing and bounded height for Gantt Chart stability
                  ? ListView(
                children: [
                  SizedBox(
                      height: 450,
                      child: _buildSystemArena("YOUR STRATEGY (Human)", userResultProcs, userTimeline, tick, Colors.lightBlueAccent, userAvgWT, battleOver)
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                      height: 450,
                      child: _buildSystemArena("OS STRATEGY ($osAlgo)", osResultProcs, osTimeline, tick, Colors.redAccent, osAvgWT, battleOver)
                  ),
                ],
              )
                  : Row(
                children: [
                  Expanded(child: _buildSystemArena("YOUR STRATEGY (Human)", userResultProcs, userTimeline, tick, Colors.lightBlueAccent, userAvgWT, battleOver)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSystemArena("OS STRATEGY ($osAlgo)", osResultProcs, osTimeline, tick, Colors.redAccent, osAvgWT, battleOver)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultBanner() {
    bool isTie = userAvgWT == osAvgWT;
    bool userWon = userAvgWT < osAvgWT;
    Color rColor = isTie ? Colors.amber : (userWon ? Colors.lightBlueAccent : Colors.redAccent);
    String rText = isTie ? "IT's A TIE!" : (userWon ? "YOU OUTSMARTED THE OS!" : "THE OS DESTROYED YOU!");

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: rColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: rColor, width: 2)),
      child: Text(rText, textAlign: TextAlign.center, style: TextStyle(color: rColor, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSystemArena(String title, List<Process> results, List<GanttBlock> timeline, int tick, Color themeColor, double finalAwt, bool showStats) {
    String? activeProcessId;
    for (var block in timeline) {
      if (tick >= block.startTime && tick < block.endTime) {
        activeProcessId = block.processId;
        break;
      }
    }

    List<Process> readyQ = [];
    List<Process> completedQ = [];
    Process? activeProc;

    for (var p in results) {
      if (p.completionTime <= tick) {
        completedQ.add(p);
      } else if (p.id == activeProcessId) {
        activeProc = p;
      } else if (p.arrivalTime <= tick) {
        readyQ.add(p);
      }
    }

    // Filter Gantt
    List<GanttBlock> visibleBlocks = [];
    for (var b in timeline) {
      if (b.startTime <= tick) {
        int dEnd = b.endTime > tick ? tick : b.endTime;
        if (dEnd > b.startTime) visibleBlocks.add(GanttBlock(processId: b.processId, startTime: b.startTime, endTime: dEnd));
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(16), border: Border.all(color: themeColor.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: themeColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24),

          // CPU & Queues Row
          Row(
            children: [
              // CPU
              Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                    color: activeProc != null ? themeColor.withValues(alpha: 0.1) : Colors.black12,
                    border: Border.all(color: activeProc != null ? themeColor : Colors.white24, width: 2),
                    borderRadius: BorderRadius.circular(12)
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: activeProc != null
                      ? ScaleTransition(
                    key: ValueKey(activeProc.id),
                    scale: _pulseAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(width: 70, height: 70, child: CircularProgressIndicator(color: themeColor, strokeWidth: 3)),
                        _buildMiniBox(activeProc.id, themeColor),
                      ],
                    ),
                  )
                      : const Text("IDLE", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              // Queues
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Ready Queue", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Container(
                      height: 35,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: readyQ.length,
                        itemBuilder: (ctx, i) => _buildMiniBox(readyQ[i].id, Colors.orange),
                      ),
                    ),
                    const Text("Completed", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    SizedBox(
                      height: 35,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: completedQ.length,
                        itemBuilder: (ctx, i) => _buildMiniBox(completedQ[i].id, Colors.grey),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),

          const SizedBox(height: 16),
          const Text("Live Execution Chart", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),

          Expanded(
            child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(8)),
                child: visibleBlocks.isEmpty
                    ? const Center(child: Text("Waiting...", style: TextStyle(color: Colors.white24)))
                    : GanttChartWidget(timeline: visibleBlocks)
            ),
          ),

          if (showStats) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Text("Avg Waiting Time: ${finalAwt.toStringAsFixed(2)} ms", textAlign: TextAlign.center, style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 5),
            Text(
                title.contains('Human') ? AlgoStats.getInfo('UserStrategy') : AlgoStats.getInfo(osAlgo),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMiniBox(String text, Color color) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}