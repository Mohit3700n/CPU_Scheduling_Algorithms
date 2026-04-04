import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../algorithms/fcfs.dart';
import '../algorithms/sjf.dart';
import '../algorithms/round_robin.dart';
import '../algorithms/srtf.dart';
import '../models/algo_stats.dart';
import '../models/gantt_block.dart';
import '../models/process.dart';
import '../widgets/gantt_chart.dart';

Map<String, dynamic> _isolateAlgorithmRunner(Map<String, dynamic> args) {
  String algo = args['algo'];
  List<Process> copyToRun = args['processes'];
  int tq = args['tq'];

  List<Process> resultProcesses = [];
  List<GanttBlock> ganttTimeline = [];

  if (algo == 'FCFS') {
    resultProcesses = FCFSScheduler.run(copyToRun);
    ganttTimeline = _generateTimelineForNonPreemptive(resultProcesses);
  } else if (algo == 'SJF') {
    resultProcesses = SJFScheduler.run(copyToRun);
    ganttTimeline = _generateTimelineForNonPreemptive(resultProcesses);
  } else if (algo == 'SRTF') {
    var result = SRTFScheduler.run(copyToRun);
    resultProcesses = result.processes;
    ganttTimeline = result.ganttTimeline;
  } else if (algo == 'RR') {
    var result = RRScheduler.run(copyToRun, tq);
    resultProcesses = result.processes;
    ganttTimeline = result.ganttTimeline;
  }

  return {
    'processes': resultProcesses,
    'timeline': ganttTimeline,
  };
}

List<GanttBlock> _generateTimelineForNonPreemptive(List<Process> processes) {
  List<GanttBlock> timeline = processes.map((p) {
    return GanttBlock(processId: p.id, startTime: p.completionTime - p.burstTime, endTime: p.completionTime);
  }).toList();
  timeline.sort((a, b) => a.startTime.compareTo(b.startTime));
  return timeline;
}

class SingleAlgoScreen extends StatefulWidget {
  const SingleAlgoScreen({super.key});

  @override
  State<SingleAlgoScreen> createState() => _SingleAlgoScreenState();
}

class _SingleAlgoScreenState extends State<SingleAlgoScreen> with SingleTickerProviderStateMixin {
  List<Process> inputProcesses = [];
  List<Process> resultProcesses = [];
  int processCounter = 1;
  final TextEditingController _atController = TextEditingController();
  final TextEditingController _btController = TextEditingController();
  final TextEditingController _tqController = TextEditingController(text: "2");

  String selectedAlgorithm = 'FCFS';
  int timeQuantum = 2;
  List<GanttBlock> ganttTimeline = [];

  final ValueNotifier<int> currentTick = ValueNotifier<int>(0);

  int maxTick = 0;
  Timer? playbackTimer;
  bool isPlaying = false;
  bool simulationDone = false;
  bool isCalculating = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(_pulseController);
  }

  @override
  void dispose() {
    playbackTimer?.cancel();
    currentTick.dispose();
    _pulseController.dispose();
    _atController.dispose();
    _btController.dispose();
    _tqController.dispose();
    super.dispose();
  }

  void _addProcess() {
    if (_atController.text.isEmpty || _btController.text.isEmpty) return;
    int at = int.parse(_atController.text);
    int bt = int.parse(_btController.text);
    setState(() {
      inputProcesses.add(Process(id: 'P$processCounter', arrivalTime: at, burstTime: bt));
      processCounter++;
      _atController.clear();
      _btController.clear();
      _resetSimulation();
    });
  }

  void _addRandomProcess() {
    final random = Random();
    int randomAT = random.nextInt(11);
    int randomBT = random.nextInt(12) + 1;
    setState(() {
      inputProcesses.add(Process(id: 'P$processCounter', arrivalTime: randomAT, burstTime: randomBT));
      processCounter++;
      _resetSimulation();
    });
  }

  void _resetSimulation() {
    playbackTimer?.cancel();
    setState(() {
      resultProcesses.clear();
      ganttTimeline.clear();
      currentTick.value = 0;
      maxTick = 0;
      isPlaying = false;
      simulationDone = false;
    });
  }

  Future<void> _runSimulation() async {
    if (inputProcesses.isEmpty) return;

    setState(() {
      isCalculating = true;
    });

    _resetSimulation();
    List<Process> copyToRun = inputProcesses.map((p) => Process(id: p.id, arrivalTime: p.arrivalTime, burstTime: p.burstTime)).toList();
    int parsedTq = int.tryParse(_tqController.text) ?? 2;

    final result = await compute(_isolateAlgorithmRunner, {
      'algo': selectedAlgorithm,
      'processes': copyToRun,
      'tq': parsedTq,
    });

    if (!mounted) return;

    setState(() {
      resultProcesses = result['processes'];
      ganttTimeline = result['timeline'];

      if (resultProcesses.isNotEmpty) {
        maxTick = ganttTimeline.isNotEmpty ? ganttTimeline.last.endTime : 0;
        simulationDone = true;
      }
      isCalculating = false;
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

      playbackTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
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
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Live Execution Visualizer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2A2D3E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildControlPanel(isMobile: false)),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: isCalculating
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
              : simulationDone
              ? ValueListenableBuilder<int>(
            valueListenable: currentTick,
            builder: (context, tick, child) {
              return _buildRightPanelDesktop(tick);
            },
          )
              : const Center(child: Text("Add processes and hit CALCULATE", style: TextStyle(color: Colors.white54, fontSize: 18))),
        ),
      ],
    );
  }

  Widget _buildRightPanelDesktop(int tick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 180, child: _buildLiveVisualization(tick)),
        const SizedBox(height: 16),

        const Text("Live Gantt Chart", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(height: 170, child: _buildAnimatedGanttChart(tick)),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildAnimatedMetricsTable(tick, isMobile: false)),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _buildDynamicStats(tick, isMobile: false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildControlPanel(isMobile: true),
          const SizedBox(height: 16),
          isCalculating
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))))
              : simulationDone
              ? ValueListenableBuilder<int>(
            valueListenable: currentTick,
            builder: (context, tick, child) {
              return _buildRightPanelMobile(tick);
            },
          )
              : const SizedBox(height: 200, child: Center(child: Text("Add processes and hit CALCULATE", style: TextStyle(color: Colors.white54, fontSize: 18)))),
        ],
      ),
    );
  }

  Widget _buildRightPanelMobile(int tick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 200, child: _buildLiveVisualization(tick)),
        const SizedBox(height: 16),

        const Text("Live Gantt Chart", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(height: 170, child: _buildAnimatedGanttChart(tick)),
        const SizedBox(height: 16),

        _buildAnimatedMetricsTable(tick, isMobile: true),
        const SizedBox(height: 16),
        _buildDynamicStats(tick, isMobile: true),
      ],
    );
  }

  Widget _buildControlPanel({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<String>(
            value: selectedAlgorithm,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E1E2C),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: const [
              DropdownMenuItem(value: 'FCFS', child: Text('FCFS')),
              DropdownMenuItem(value: 'SJF', child: Text('SJF (Non-Preemptive)')),
              DropdownMenuItem(value: 'SRTF', child: Text('SRTF (Preemptive)')),
              DropdownMenuItem(value: 'RR', child: Text('Round Robin')),
            ],
            onChanged: (v) { setState(() { selectedAlgorithm = v!; _resetSimulation(); }); },
          ),
          const SizedBox(height: 12),
          if (selectedAlgorithm == 'RR') _buildTextField('Time Quantum (TQ)', _tqController),
          Row(
            children: [
              Expanded(child: _buildTextField('AT', _atController)),
              const SizedBox(width: 8),
              Expanded(child: _buildTextField('BT', _btController)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: isCalculating ? null : _addProcess, child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Add Process')))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: isCalculating ? null : _addRandomProcess, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Random')))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: isCalculating ? null : _runSimulation,
              child: isCalculating
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('RUN $selectedAlgorithm', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const Divider(height: 24, color: Colors.white24),
          Text('Queue (${inputProcesses.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

          isMobile
              ? SizedBox(height: 200, child: _buildQueueList())
              : Expanded(child: _buildQueueList()),
        ],
      ),
    );
  }

  Widget _buildQueueList() {
    return ListView.builder(
      itemCount: inputProcesses.length,
      itemBuilder: (ctx, i) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(inputProcesses[i].id, style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text('AT: ${inputProcesses[i].arrivalTime} | BT: ${inputProcesses[i].burstTime}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () {
          setState(() { inputProcesses.removeAt(i); _resetSimulation(); });
        }),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54, fontSize: 12), filled: true, fillColor: const Color(0xFF1E1E2C), isDense: true),
    );
  }

  Widget _buildLiveVisualization(int tick) {
    String? activeProcessId;
    for (var block in ganttTimeline) {
      if (tick >= block.startTime && tick < block.endTime) {
        activeProcessId = block.processId;
        break;
      }
    }

    List<Process> readyQueue = [];
    List<Process> completedQueue = [];
    Process? activeProcess;

    for (var p in resultProcesses) {
      if (p.completionTime <= tick) {
        completedQueue.add(p);
      } else if (p.id == activeProcessId) {
        activeProcess = p;
      } else if (p.arrivalTime <= tick) {
        readyQueue.add(p);
      }
    }

    double progress = 0.0;
    if (activeProcess != null) {
      int executedTime = 0;
      for (var block in ganttTimeline) {
        if (block.processId == activeProcess.id && block.startTime <= tick) {
          int blockEndTime = (block.endTime > tick) ? tick : block.endTime;
          executedTime += (blockEndTime - block.startTime);
        }
      }
      progress = (executedTime / activeProcess.burstTime).clamp(0.0, 1.0);
    }

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.greenAccent, size: 36),
                  onPressed: _togglePlayback,
                ),
                IconButton(
                  icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 36),
                  onPressed: () {
                    playbackTimer?.cancel();
                    setState(() { isPlaying = false; });
                    currentTick.value = 0;
                  },
                ),
                const SizedBox(width: 12),
                Text("Tick: $tick / $maxTick ms", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 100,
              width: 140,
              decoration: BoxDecoration(
                color: activeProcess != null ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                border: Border.all(color: activeProcess != null ? Colors.greenAccent : Colors.grey, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: activeProcess != null
                    ? ScaleTransition(
                    key: ValueKey(activeProcess.id),
                    scale: _pulseAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60, height: 60,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: progress),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.linear,
                            builder: (context, value, _) {
                              return CircularProgressIndicator(
                                value: value,
                                color: Colors.greenAccent,
                                strokeWidth: 4,
                                backgroundColor: Colors.green.withValues(alpha: 0.1),
                              );
                            },
                          ),
                        ),
                        _buildAnimatedBox(activeProcess, Colors.greenAccent, size: 45),
                      ],
                    )
                )
                    : const Text("CPU IDLE", key: ValueKey("idle"), style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("READY QUEUE", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: readyQueue.length,
                    itemBuilder: (ctx, i) => _buildAnimatedBox(readyQueue[i], Colors.orange, size: 45),
                  ),
                ),
              ),
              const Text("COMPLETED", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: completedQueue.length,
                    itemBuilder: (ctx, i) => _buildAnimatedBox(completedQueue[i], Colors.grey, size: 45),
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildAnimatedGanttChart(int tick) {
    List<GanttBlock> visibleBlocks = [];
    for (var b in ganttTimeline) {
      if (b.startTime <= tick) {
        int displayEndTime = b.endTime > tick ? tick : b.endTime;
        if (displayEndTime > b.startTime) {
          visibleBlocks.add(GanttBlock(processId: b.processId, startTime: b.startTime, endTime: displayEndTime));
        }
      }
    }

    if (visibleBlocks.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: const Text("Waiting for execution...", style: TextStyle(color: Colors.white54)),
      );
    }

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(12),
      child: GanttChartWidget(timeline: visibleBlocks),
    );
  }

  Widget _buildAnimatedMetricsTable(int tick, {required bool isMobile}) {
    var table = DataTable(
      headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
      dataTextStyle: const TextStyle(color: Colors.white),
      columnSpacing: 24,
      horizontalMargin: 24,
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('AT')),
        DataColumn(label: Text('BT')),
        DataColumn(label: Text('CT')),
        DataColumn(label: Text('TAT')),
        DataColumn(label: Text('WT')),
      ],
      rows: resultProcesses.map((p) {
        bool isCompleted = p.completionTime <= tick;
        bool isRunning = p.arrivalTime <= tick && !isCompleted;

        return DataRow(
            color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
              if (isCompleted) return Colors.green.withValues(alpha: 0.05);
              if (isRunning) return Colors.orange.withValues(alpha: 0.05);
              return null;
            }),
            cells: [
              DataCell(Text(p.id, style: TextStyle(color: isCompleted ? Colors.greenAccent : (isRunning ? Colors.orangeAccent : Colors.white)))),
              DataCell(Text(p.arrivalTime.toString())),
              DataCell(Text(p.burstTime.toString())),
              DataCell(Text(isCompleted ? p.completionTime.toString() : (isRunning ? "..." : "-"))),
              DataCell(Text(isCompleted ? p.turnaroundTime.toString() : "-")),
              DataCell(Text(isCompleted ? p.waitingTime.toString() : "-")),
            ]
        );
      }).toList(),
    );

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24))),
            child: const Text("Process Execution Metrics", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          if (isMobile)
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: table,
                  ),
                );
              },
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: table,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDynamicStats(int tick, {required bool isMobile}) {
    List<Process> finishedProcs = resultProcesses.where((p) => p.completionTime <= tick).toList();

    double currentAvgWT = 0.0;
    double currentAvgTAT = 0.0;

    if (finishedProcs.isNotEmpty) {
      currentAvgWT = finishedProcs.fold(0.0, (sum, p) => sum + p.waitingTime) / finishedProcs.length;
      currentAvgTAT = finishedProcs.fold(0.0, (sum, p) => sum + p.turnaroundTime) / finishedProcs.length;
    }

    var topCard = _buildMetricCard("Avg Wait Time", currentAvgWT, Colors.orangeAccent);
    var bottomCard = _buildMetricCard("Avg Turnaround", currentAvgTAT, const Color(0xFF00C9A7));
    var analysis = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF2A2D3E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Analysis of algorithm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Divider(color: Colors.white24, height: 16),
          Text(AlgoStats.getInfo(selectedAlgorithm), style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          Row(children: [Expanded(child: topCard), const SizedBox(width: 8), Expanded(child: bottomCard)]),
          const SizedBox(height: 16),
          analysis
        ],
      );
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [
            topCard,
            const SizedBox(height: 16),
            bottomCard,
            const SizedBox(height: 16),
            analysis
          ],
        ),
      );
    }
  }

  Widget _buildAnimatedBox(Process p, Color color, {double size = 60, Key? key}) {
    return Container(
      key: key,
      width: size,
      height: size,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)]),
      alignment: Alignment.center,
      child: Text(p.id, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildMetricCard(String title, double value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("${value.toStringAsFixed(2)} ms", style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}