import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/io_process.dart';
import '../models/gantt_block.dart';
import '../algorithms/io_scheduler.dart';
import '../widgets/gantt_chart.dart';

Map<String, dynamic> _isolateIORunner(Map<String, dynamic> args) {
  List<IOProcess> copyToRun = args['processes'];
  var result = IOScheduler.run(copyToRun);
  return {
    'processes': result.processes,
    'cpuTimeline': result.cpuTimeline,
    'ioTimeline': result.ioTimeline,
  };
}

class IoSimulationScreen extends StatefulWidget {
  const IoSimulationScreen({super.key});

  @override
  State<IoSimulationScreen> createState() => _IoSimulationScreenState();
}

class _IoSimulationScreenState extends State<IoSimulationScreen> with SingleTickerProviderStateMixin {
  List<IOProcess> inputProcesses = [];
  List<IOProcess> resultProcesses = [];
  int processCounter = 1;

  final TextEditingController _atController = TextEditingController();
  final TextEditingController _cpu1Controller = TextEditingController();
  final TextEditingController _ioController = TextEditingController();
  final TextEditingController _cpu2Controller = TextEditingController();

  List<GanttBlock> cpuTimeline = [];
  List<GanttBlock> ioTimeline = [];

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
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(_pulseController);
  }

  @override
  void dispose() {
    playbackTimer?.cancel();
    currentTick.dispose();
    _pulseController.dispose();
    _atController.dispose();
    _cpu1Controller.dispose();
    _ioController.dispose();
    _cpu2Controller.dispose();
    super.dispose();
  }

  void _addProcess() {
    if (_atController.text.isEmpty || _cpu1Controller.text.isEmpty || _ioController.text.isEmpty || _cpu2Controller.text.isEmpty) return;
    setState(() {
      inputProcesses.add(IOProcess(
        id: 'P$processCounter',
        arrivalTime: int.parse(_atController.text),
        cpuBurst1: int.parse(_cpu1Controller.text),
        ioBurst: int.parse(_ioController.text),
        cpuBurst2: int.parse(_cpu2Controller.text),
      ));
      processCounter++;
      _atController.clear(); _cpu1Controller.clear(); _ioController.clear(); _cpu2Controller.clear();
      _resetSimulation();
    });
  }

  void _addRandom() {
    final random = Random();
    setState(() {
      inputProcesses.add(IOProcess(
        id: 'P$processCounter',
        arrivalTime: random.nextInt(10),
        cpuBurst1: random.nextInt(5) + 2,
        ioBurst: random.nextInt(6) + 2,
        cpuBurst2: random.nextInt(4) + 1,
      ));
      processCounter++;
      _resetSimulation();
    });
  }

  void _resetSimulation() {
    playbackTimer?.cancel();
    setState(() {
      resultProcesses.clear();
      cpuTimeline.clear();
      ioTimeline.clear();
      currentTick.value = 0;
      maxTick = 0;
      isPlaying = false;
      simulationDone = false;
    });
  }

  Future<void> _runSimulation() async {
    if (inputProcesses.isEmpty) return;
    setState(() => isCalculating = true);
    _resetSimulation();

    List<IOProcess> copy = inputProcesses.map((p) => IOProcess(id: p.id, arrivalTime: p.arrivalTime, cpuBurst1: p.cpuBurst1, ioBurst: p.ioBurst, cpuBurst2: p.cpuBurst2)).toList();

    final result = await compute(_isolateIORunner, {'processes': copy});

    if (!mounted) return;

    setState(() {
      resultProcesses = result['processes'];
      cpuTimeline = result['cpuTimeline'];
      ioTimeline = result['ioTimeline'];

      int maxCpu = cpuTimeline.isNotEmpty ? cpuTimeline.last.endTime : 0;
      int maxIo = ioTimeline.isNotEmpty ? ioTimeline.last.endTime : 0;
      maxTick = max(maxCpu, maxIo);

      simulationDone = true;
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
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Parallel I/O & CPU Live Visualizer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            builder: (context, tick, child) => _buildRightPanelDesktop(tick),
          )
              : const Center(child: Text("Add processes and hit CALCULATE", style: TextStyle(color: Colors.white54, fontSize: 18))),
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
            builder: (context, tick, child) => _buildRightPanelMobile(tick),
          )
              : const SizedBox(height: 200, child: Center(child: Text("Add processes and hit CALCULATE", style: TextStyle(color: Colors.white54, fontSize: 18)))),
        ],
      ),
    );
  }

  Widget _buildControlPanel({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Process Parameters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField('AT', _atController)), const SizedBox(width: 8),
              Expanded(child: _buildTextField('CPU 1', _cpu1Controller)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField('I/O Wait', _ioController)), const SizedBox(width: 8),
              Expanded(child: _buildTextField('CPU 2', _cpu2Controller)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: isCalculating ? null : _addProcess, child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Add')))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: isCalculating ? null : _addRandom, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Random')))),
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
                  : const Text('CALCULATE PARALLEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      itemBuilder: (ctx, i) {
        var p = inputProcesses[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(p.id, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: Text('AT:${p.arrivalTime} | C1:${p.cpuBurst1} | IO:${p.ioBurst} | C2:${p.cpuBurst2}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () {
            setState(() { inputProcesses.removeAt(i); _resetSimulation(); });
          }),
        );
      },
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

  Widget _buildRightPanelDesktop(int tick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopVisualizer(tick, isMobile: false),
        const SizedBox(height: 12),
        _buildAnimatedGanttCharts(tick, isMobile: false),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildAnimatedMetricsTable(tick, isMobile: false)),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _buildDynamicStats(tick)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanelMobile(int tick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopVisualizer(tick, isMobile: true),
        const SizedBox(height: 16),
        _buildAnimatedGanttCharts(tick, isMobile: true),
        const SizedBox(height: 16),
        _buildAnimatedMetricsTable(tick, isMobile: true),
        const SizedBox(height: 16),
        _buildDynamicStats(tick),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTopVisualizer(int tick, {required bool isMobile}) {
    String? activeCpuId;
    for (var b in cpuTimeline) { if (tick >= b.startTime && tick < b.endTime) { activeCpuId = b.processId; break; } }

    String? activeIoId;
    for (var b in ioTimeline) { if (tick >= b.startTime && tick < b.endTime) { activeIoId = b.processId; break; } }

    List<IOProcess> readyQueue = [];
    List<IOProcess> ioWaitQueue = [];
    List<IOProcess> completedQueue = [];
    IOProcess? runningCpu;
    IOProcess? runningIo;

    for (var p in resultProcesses) {
      if (p.completionTime <= tick) {
        completedQueue.add(p);
      } else if (p.id == activeCpuId) {
        runningCpu = p;
      } else if (p.id == activeIoId) {
        runningIo = p;
      } else if (p.arrivalTime <= tick) {
        var pCpuBlocks = cpuTimeline.where((b) => b.processId == p.id);
        var pIoBlocks = ioTimeline.where((b) => b.processId == p.id);

        GanttBlock? firstCpu = pCpuBlocks.isNotEmpty ? pCpuBlocks.first : null;
        GanttBlock? ioBlock = pIoBlocks.isNotEmpty ? pIoBlocks.first : null;

        if (firstCpu != null && tick >= firstCpu.endTime && ioBlock != null && tick < ioBlock.startTime) {
          ioWaitQueue.add(p);
        } else {
          readyQueue.add(p);
        }
      }
    }

    Widget cpuBox = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3))),
      child: Row(
        children: [
          _buildPulseBox("CPU", runningCpu, Colors.greenAccent),
          const SizedBox(width: 12),
          Expanded(child: _buildQueue("CPU Ready Queue", readyQueue, Colors.orange)),
        ],
      ),
    );

    Widget ioBox = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFF9066).withValues(alpha: 0.3))),
      child: Row(
        children: [
          _buildPulseBox("I/O DEVICE", runningIo, const Color(0xFFFF9066)),
          const SizedBox(width: 12),
          Expanded(child: _buildQueue("I/O Wait Queue", ioWaitQueue, Colors.blueAccent)),
        ],
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            IconButton(icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.greenAccent, size: 36), onPressed: _togglePlayback),
            IconButton(icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 36), onPressed: () { playbackTimer?.cancel(); setState(() => isPlaying = false); currentTick.value = 0; }),
            const SizedBox(width: 12),
            Text("Tick: $tick / $maxTick ms", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
          ],
        ),
        const SizedBox(height: 8),

        isMobile
            ? Column(children: [cpuBox, const SizedBox(height: 12), ioBox])
            : Row(children: [Expanded(child: cpuBox), const SizedBox(width: 12), Expanded(child: ioBox)]),

        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Completed Queue", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: completedQueue.map((p) => _buildMiniBox(p.id, Colors.grey)).toList()),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPulseBox(String title, IOProcess? p, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 60, width: 60,
          decoration: BoxDecoration(
              color: p != null ? color.withValues(alpha: 0.1) : Colors.black12,
              border: Border.all(color: p != null ? color : Colors.white24, width: 2),
              borderRadius: BorderRadius.circular(12)
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: p != null
                ? ScaleTransition(
              key: ValueKey(p.id), scale: _pulseAnimation,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(width: 45, height: 45, child: CircularProgressIndicator(key: ValueKey('${p.id}_spin'), color: color, strokeWidth: 3)),
                  _buildMiniBox(p.id, color, size: 35),
                ],
              ),
            )
                : const Text("IDLE", key: ValueKey("idle"), style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildQueue(String title, List<IOProcess> queue, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 45,
          decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(8)),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(6),
            itemCount: queue.length,
            itemBuilder: (ctx, i) => _buildMiniBox(queue[i].id, color),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedGanttCharts(int tick, {required bool isMobile}) {
    List<GanttBlock> getVisible(List<GanttBlock> fullList) {
      List<GanttBlock> visible = [];
      for (var b in fullList) {
        if (b.startTime <= tick) {
          int end = b.endTime > tick ? tick : b.endTime;
          if (end > b.startTime) visible.add(GanttBlock(processId: b.processId, startTime: b.startTime, endTime: end));
        }
      }
      return visible;
    }
    List<GanttBlock> visCpu = getVisible(cpuTimeline);
    List<GanttBlock> visIo = getVisible(ioTimeline);

    // FIX: Removed the SingleChildScrollView wrap from GanttChartWidget completely.
    // The Expanded widgets inside GanttChartWidget will naturally scale within the container without crashing.
    Widget cpuChart = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("CPU Timeline", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
        Container(
          height: 150, margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(8)),
          child: visCpu.isEmpty
              ? const Center(child: Text("...", style: TextStyle(color: Colors.white24)))
              : GanttChartWidget(timeline: visCpu),
        ),
      ],
    );

    Widget ioChart = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("I/O Device Timeline", style: TextStyle(color: Color(0xFFFF9066), fontSize: 12, fontWeight: FontWeight.bold)),
        Container(
          height: 150, margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(8)),
          child: visIo.isEmpty
              ? const Center(child: Text("...", style: TextStyle(color: Colors.white24)))
              : GanttChartWidget(timeline: visIo),
        ),
      ],
    );

    return isMobile
        ? Column(children: [cpuChart, const SizedBox(height: 16), ioChart])
        : Row(children: [Expanded(child: cpuChart), const SizedBox(width: 12), Expanded(child: ioChart)]);
  }

  Widget _buildAnimatedMetricsTable(int tick, {required bool isMobile}) {
    var table = DataTable(
      headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
      dataTextStyle: const TextStyle(color: Colors.white),
      columnSpacing: 16,
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('AT')),
        DataColumn(label: Text('CPU')),
        DataColumn(label: Text('I/O')),
        DataColumn(label: Text('CT')),
        DataColumn(label: Text('TAT')),
        DataColumn(label: Text('WT')),
      ],
      rows: resultProcesses.map((p) {
        bool isCompleted = p.completionTime <= tick;
        bool isRunning = p.arrivalTime <= tick && !isCompleted;

        return DataRow(
            color: WidgetStateProperty.resolveWith<Color?>((states) {
              if (isCompleted) return Colors.green.withValues(alpha: 0.05);
              if (isRunning) return Colors.orange.withValues(alpha: 0.05);
              return null;
            }),
            cells: [
              DataCell(Text(p.id, style: TextStyle(color: isCompleted ? Colors.greenAccent : (isRunning ? Colors.orangeAccent : Colors.white)))),
              DataCell(Text(p.arrivalTime.toString())),
              DataCell(Text('${p.cpuBurst1 + p.cpuBurst2}')),
              DataCell(Text(p.ioBurst.toString())),
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
            child: const Text("Parallel Execution Metrics", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          isMobile
              ? LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: table,
                  ),
                );
              }
          )
              : Expanded(
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
                }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicStats(int tick) {
    List<IOProcess> finishedProcs = resultProcesses.where((p) => p.completionTime <= tick).toList();
    double currentAvgWT = 0.0, currentAvgTAT = 0.0;

    if (finishedProcs.isNotEmpty) {
      currentAvgWT = finishedProcs.fold(0.0, (sum, p) => sum + p.waitingTime) / finishedProcs.length;
      currentAvgTAT = finishedProcs.fold(0.0, (sum, p) => sum + p.turnaroundTime) / finishedProcs.length;
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricCard("Avg Wait Time", currentAvgWT, Colors.orangeAccent),
          const SizedBox(height: 16),
          _buildMetricCard("Avg Turnaround", currentAvgTAT, const Color(0xFF00C9A7)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF2A2D3E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24)
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Analysis of algorithm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Divider(color: Colors.white24, height: 16),
                Text("Strategy: Multi-Queue Event Driven", style: TextStyle(color: Colors.white70, fontSize: 12)),
                SizedBox(height: 4),
                Text("Time Complexity: O(N log N)", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMiniBox(String text, Color color, {double size = 32}) {
    return Container(
      width: size, height: size, margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)]),
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildMetricCard(String title, double value, Color color) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.5), width: 2)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("${value.toStringAsFixed(2)} ms", style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}