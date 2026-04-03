import 'package:flutter/material.dart';
import 'dart:math';
import '../models/process.dart';
import '../models/gantt_block.dart';
import '../algorithms/fcfs.dart';
import '../algorithms/sjf.dart';
import '../algorithms/srtf.dart';
import '../algorithms/round_robin.dart';
import '../widgets/gantt_chart.dart';

// NAYA: Is class me timeline aur processes list add kiya hai
class BattleResult {
  final String algoName;
  final double avgWT;
  final double avgTAT;
  final Color color;
  final List<GanttBlock> timeline;
  final List<Process> processes;

  BattleResult(this.algoName, this.avgWT, this.avgTAT, this.color, this.timeline, this.processes);
}

class BattleModeScreen extends StatefulWidget {
  const BattleModeScreen({super.key});

  @override
  State<BattleModeScreen> createState() => _BattleModeScreenState();
}

class _BattleModeScreenState extends State<BattleModeScreen> {
  List<Process> inputProcesses = [];
  int processCounter = 1;

  final TextEditingController _atController = TextEditingController();
  final TextEditingController _btController = TextEditingController();
  final TextEditingController _tqController = TextEditingController(text: "2");

  List<BattleResult> battleResults = [];
  String winnerText = "";

  void _addProcess() {
    if (_atController.text.isEmpty || _btController.text.isEmpty) return;
    int at = int.parse(_atController.text);
    int bt = int.parse(_btController.text);

    setState(() {
      inputProcesses.add(Process(id: 'P$processCounter', arrivalTime: at, burstTime: bt));
      processCounter++;
      _atController.clear();
      _btController.clear();
      battleResults.clear();
      winnerText = "";
    });
  }

  void _addRandomProcess() {
    final random = Random();
    int randomAT = random.nextInt(11);
    int randomBT = random.nextInt(12) + 1;

    setState(() {
      inputProcesses.add(
          Process(id: 'P$processCounter', arrivalTime: randomAT, burstTime: randomBT)
      );
      processCounter++;

      battleResults.clear();
      winnerText = "";
    });
  }

  // FCFS aur SJF (Non-Preemptive) ke liye Timeline Generate karne ka function
  List<GanttBlock> _generateTimeline(List<Process> processes) {
    List<GanttBlock> blocks = processes.map((p) {
      return GanttBlock(processId: p.id, startTime: p.completionTime - p.burstTime, endTime: p.completionTime);
    }).toList();
    blocks.sort((a, b) => a.startTime.compareTo(b.startTime));
    return blocks;
  }

  void _runBattle() {
    if (inputProcesses.isEmpty) return;

    int tq = int.tryParse(_tqController.text) ?? 2;

    List<Process> copyForFCFS = inputProcesses.map((p) => Process(id: p.id, arrivalTime: p.arrivalTime, burstTime: p.burstTime)).toList();
    List<Process> copyForSJF = inputProcesses.map((p) => Process(id: p.id, arrivalTime: p.arrivalTime, burstTime: p.burstTime)).toList();
    List<Process> copyForSRTF = inputProcesses.map((p) => Process(id: p.id, arrivalTime: p.arrivalTime, burstTime: p.burstTime)).toList();
    List<Process> copyForRR = inputProcesses.map((p) => Process(id: p.id, arrivalTime: p.arrivalTime, burstTime: p.burstTime)).toList();

    // 1. FCFS
    var fcfsResult = FCFSScheduler.run(copyForFCFS);
    var fcfsTimeline = _generateTimeline(fcfsResult);
    double fcfsWT = fcfsResult.fold(0, (sum, p) => sum + p.waitingTime) / fcfsResult.length;
    double fcfsTAT = fcfsResult.fold(0, (sum, p) => sum + p.turnaroundTime) / fcfsResult.length;

    // 2. SJF
    var sjfResult = SJFScheduler.run(copyForSJF);
    var sjfTimeline = _generateTimeline(sjfResult);
    double sjfWT = sjfResult.fold(0, (sum, p) => sum + p.waitingTime) / sjfResult.length;
    double sjfTAT = sjfResult.fold(0, (sum, p) => sum + p.turnaroundTime) / sjfResult.length;

    // 3. SRTF
    var srtfOutput = SRTFScheduler.run(copyForSRTF);
    var srtfResult = srtfOutput.processes;
    var srtfTimeline = srtfOutput.ganttTimeline;
    double srtfWT = srtfResult.fold(0, (sum, p) => sum + p.waitingTime) / srtfResult.length;
    double srtfTAT = srtfResult.fold(0, (sum, p) => sum + p.turnaroundTime) / srtfResult.length;

    // 4. RR
    var rrOutput = RRScheduler.run(copyForRR, tq);
    var rrResult = rrOutput.processes;
    var rrTimeline = rrOutput.ganttTimeline;
    double rrWT = rrResult.fold(0, (sum, p) => sum + p.waitingTime) / rrResult.length;
    double rrTAT = rrResult.fold(0, (sum, p) => sum + p.turnaroundTime) / rrResult.length;

    setState(() {
      // NAYA: Data save karte time timeline aur result list bhi save ki
      battleResults = [
        BattleResult('FCFS', fcfsWT, fcfsTAT, const Color(0xFF6C63FF), fcfsTimeline, fcfsResult),
        BattleResult('SJF', sjfWT, sjfTAT, const Color(0xFF00C9A7), sjfTimeline, sjfResult),
        BattleResult('SRTF', srtfWT, srtfTAT, const Color(0xFFFFD700), srtfTimeline, srtfResult),
        BattleResult('RR', rrWT, rrTAT, const Color(0xFFFF9066), rrTimeline, rrResult),
      ];

      // Sort original list temporary for checking winner, but keep real list ordered later
      List<BattleResult> sortedForWinner = List.from(battleResults)..sort((a, b) => a.avgWT.compareTo(b.avgWT));
      winnerText = "${sortedForWinner.first.algoName} Wins! (Lowest Waiting Time: ${sortedForWinner.first.avgWT.toStringAsFixed(2)})";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Algorithm Battle Mode', style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFF2A2D3E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT COLUMN: Input Section (No changes here)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Process Data', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('AT', _atController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('BT', _btController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Time Quantum (For RR)', _tqController),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _addProcess,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C9A7),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _addRandomProcess,
                            icon: const Icon(Icons.casino, color: Colors.white),
                            label: const Text('Random', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text('Battle Queue', style: TextStyle(fontSize: 16, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: inputProcesses.length,
                        itemBuilder: (context, index) {
                          final p = inputProcesses[index];
                          return Card(
                            color: const Color(0xFF1E1E2C),
                            child: ListTile(
                              title: Text(p.id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text('AT: ${p.arrivalTime} | BT: ${p.burstTime}', style: const TextStyle(color: Colors.white70)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () {
                                  setState(() {
                                    inputProcesses.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5C8D), padding: const EdgeInsets.symmetric(vertical: 20)),
                        onPressed: _runBattle,
                        child: const Text('START BATTLE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 32),

            // RIGHT COLUMN: Results Section
            Expanded(
              flex: 2,
              child: battleResults.isEmpty
                  ? const Center(child: Text('Add processes and START BATTLE to see comparison.', style: TextStyle(color: Colors.white54, fontSize: 16)))
              // NAYA: Scroll view lagaya hai taaki lamba list scroll ho sake
                  : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5C8D).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFF5C8D), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          "🏆 $winnerText",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // NAYA: Heights fix kar di hain taaki overflow na ho
                    SizedBox(
                      height: 380,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Average Waiting Time', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                Expanded(child: _buildComparisonChart(isWT: true)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Average Turnaround Time', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                Expanded(child: _buildComparisonChart(isWT: false)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Divider(color: Colors.white24, thickness: 2),
                    const SizedBox(height: 30),
                    const Text('Detailed Execution Timelines & Metrics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 32),
                    ..._buildDetailedResultsList(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1E1E2C),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildComparisonChart({required bool isWT}) {
    double maxVal = battleResults.map((e) => isWT ? e.avgWT : e.avgTAT).reduce(max);
    if (maxVal == 0) maxVal = 1;

    List<BattleResult> displayList = List.from(battleResults);
    displayList.sort((a, b) {
      List<String> order = ['FCFS', 'SJF', 'SRTF', 'RR'];
      return order.indexOf(a.algoName).compareTo(order.indexOf(b.algoName));
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
          builder: (context, constraints) {
            double availableHeightForBars = constraints.maxHeight - 80;
            if (availableHeightForBars < 0) availableHeightForBars = 0;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: displayList.map((result) {
                double val = isWT ? result.avgWT : result.avgTAT;
                double heightRatio = val / maxVal;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(val.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutQuart,
                      width: 50,
                      height: availableHeightForBars * heightRatio,
                      decoration: BoxDecoration(
                        color: result.color,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(result.algoName, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                );
              }).toList(),
            );
          }
      ),
    );
  }

  List<Widget> _buildDetailedResultsList() {
    List<String> order = ['FCFS', 'SJF', 'SRTF', 'RR'];
    List<Widget> sections = [];

    for (String algo in order) {
      var res = battleResults.firstWhere((e) => e.algoName == algo);
      sections.add(
          Container(
            margin: const EdgeInsets.only(bottom: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D3E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: res.color.withValues(alpha: 0.5), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    children: [
                      Icon(Icons.analytics, color: res.color, size: 32),
                      const SizedBox(width: 16),
                      Text(res.algoName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: res.color)),
                      const Spacer(),
                      Text("AWT: ${res.avgWT.toStringAsFixed(2)} ms  |  ATAT: ${res.avgTAT.toStringAsFixed(2)} ms",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ]
                ),
                const SizedBox(height: 32),
                const Text("Execution Timeline (Gantt Chart)", style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 12),
                GanttChartWidget(timeline: res.timeline),
                const SizedBox(height: 40),
                const Text("Process Metrics Table", style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 12),
                _buildMetricsTable(res.processes, res.color),
              ],
            ),
          )
      );
    }
    return sections;
  }

  Widget _buildMetricsTable(List<Process> processes, Color themeColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(12)),
      child: DataTable(
        headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: themeColor),
        dataTextStyle: const TextStyle(color: Colors.white70),
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('AT')),
          DataColumn(label: Text('BT')),
          DataColumn(label: Text('CT')),
          DataColumn(label: Text('TAT')),
          DataColumn(label: Text('WT')),
        ],
        rows: processes.map((p) {
          return DataRow(cells: [
            DataCell(Text(p.id, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            DataCell(Text(p.arrivalTime.toString())),
            DataCell(Text(p.burstTime.toString())),
            DataCell(Text(p.completionTime.toString())),
            DataCell(Text(p.turnaroundTime.toString())),
            DataCell(Text(p.waitingTime.toString(), style: const TextStyle(color: Colors.orangeAccent))),
          ]);
        }).toList(),
      ),
    );
  }
}