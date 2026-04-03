// algorithms/io_scheduler.dart
import '../models/io_process.dart';
import '../models/gantt_block.dart';

class IOResult {
  final List<IOProcess> processes;
  final List<GanttBlock> cpuTimeline;
  final List<GanttBlock> ioTimeline;
  IOResult(this.processes, this.cpuTimeline, this.ioTimeline);
}

class IOScheduler {
  static IOResult run(List<IOProcess> inputProcesses) {
    List<IOProcess> processes = List.from(inputProcesses);
    processes.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

    List<GanttBlock> cpuTimeline = [];
    List<GanttBlock> ioTimeline = [];

    // State Tracking
    Map<String, int> remCpu1 = {};
    Map<String, int> remIo = {};
    Map<String, int> remCpu2 = {};

    for (var p in processes) {
      remCpu1[p.id] = p.cpuBurst1;
      remIo[p.id] = p.ioBurst;
      remCpu2[p.id] = p.cpuBurst2;
    }

    int currentTime = 0;
    int completed = 0;

    List<IOProcess> readyQueue = []; // CPU ke liye wait kar rahe hain
    List<IOProcess> ioQueue = [];    // I/O ke liye wait kar rahe hain

    IOProcess? runningCpu;
    IOProcess? runningIo;

    int cpuStartTime = 0;
    int ioStartTime = 0;

    Set<String> arrived = {};

    // Time-stepper loop (Jab tak saari processes complete na ho jayein)
    while (completed < processes.length) {
      // 1. Nayi processes ka aana
      for (var p in processes) {
        if (p.arrivalTime == currentTime && !arrived.contains(p.id)) {
          readyQueue.add(p);
          arrived.add(p.id);
        }
      }

      // 2. I/O Execution & Completion
      if (runningIo != null) {
        remIo[runningIo.id] = remIo[runningIo.id]! - 1;
        if (remIo[runningIo.id] == 0) { // I/O khatam
          ioTimeline.add(GanttBlock(processId: runningIo.id, startTime: ioStartTime, endTime: currentTime));
          readyQueue.add(runningIo); // I/O ke baad CPU2 ke liye wapas ready queue me
          runningIo = null;
        }
      }

      // 3. CPU Execution & Completion
      if (runningCpu != null) {
        if (remCpu1[runningCpu.id]! > 0) {
          remCpu1[runningCpu.id] = remCpu1[runningCpu.id]! - 1;
          if (remCpu1[runningCpu.id] == 0) { // CPU1 khatam, I/O me jao
            cpuTimeline.add(GanttBlock(processId: runningCpu.id, startTime: cpuStartTime, endTime: currentTime));
            ioQueue.add(runningCpu);
            runningCpu = null;
          }
        } else if (remCpu2[runningCpu.id]! > 0) {
          remCpu2[runningCpu.id] = remCpu2[runningCpu.id]! - 1;
          if (remCpu2[runningCpu.id] == 0) { // CPU2 khatam, Process totally complete!
            cpuTimeline.add(GanttBlock(processId: runningCpu.id, startTime: cpuStartTime, endTime: currentTime));
            runningCpu.completionTime = currentTime;
            runningCpu.turnaroundTime = runningCpu.completionTime - runningCpu.arrivalTime;
            // Total Wait = TAT - (CPU1 + IO + CPU2)
            runningCpu.waitingTime = runningCpu.turnaroundTime - (runningCpu.cpuBurst1 + runningCpu.ioBurst + runningCpu.cpuBurst2);
            completed++;
            runningCpu = null;
          }
        }
      }

      // 4. Assign I/O Device (FCFS based)
      if (runningIo == null && ioQueue.isNotEmpty) {
        runningIo = ioQueue.removeAt(0);
        ioStartTime = currentTime;
      }

      // 5. Assign CPU (FCFS based)
      if (runningCpu == null && readyQueue.isNotEmpty) {
        runningCpu = readyQueue.removeAt(0);
        cpuStartTime = currentTime;
      }

      currentTime++; // Time aage badhao
    }

    return IOResult(processes, cpuTimeline, ioTimeline);
  }
}