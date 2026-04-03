import 'dart:math';
import '../models/process.dart';
import '../models/gantt_block.dart';

class RRResult {
  final List<Process> processes;
  final List<GanttBlock> ganttTimeline;

  RRResult(this.processes, this.ganttTimeline);
}

class RRScheduler {
  static RRResult run(List<Process> processes, int timeQuantum) {
    List<Process> resultList = List.from(processes);
    List<GanttBlock> timeline = [];

    resultList.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

    Map<String, int> remainingBurst = {};
    for (var p in resultList) {
      remainingBurst[p.id] = p.burstTime;
    }

    int currentTime = 0;
    int completedProcesses = 0;
    List<Process> readyQueue = [];

    if (resultList.isNotEmpty) {
      readyQueue.add(resultList.first);
      currentTime = resultList.first.arrivalTime;
    }

    Set<String> inQueue = {resultList.first.id};

    while (completedProcesses < resultList.length) {
      if (readyQueue.isEmpty) {
        Process nextArrival = resultList.firstWhere((p) => remainingBurst[p.id]! > 0 && !inQueue.contains(p.id));
        currentTime = nextArrival.arrivalTime;
        readyQueue.add(nextArrival);
        inQueue.add(nextArrival.id);
        continue;
      }

      Process currentProcess = readyQueue.removeAt(0);
      int burstLeft = remainingBurst[currentProcess.id]!;
      int executionTime = min(timeQuantum, burstLeft);

      timeline.add(GanttBlock(
        processId: currentProcess.id,
        startTime: currentTime,
        endTime: currentTime + executionTime,
      ));

      currentTime += executionTime;
      remainingBurst[currentProcess.id] = burstLeft - executionTime;

      for (var p in resultList) {
        if (p.arrivalTime <= currentTime && !inQueue.contains(p.id) && remainingBurst[p.id]! > 0) {
          readyQueue.add(p);
          inQueue.add(p.id);
        }
      }

      if (remainingBurst[currentProcess.id]! > 0) {
        readyQueue.add(currentProcess);
      } else {
        completedProcesses++;
        currentProcess.completionTime = currentTime;
        currentProcess.turnaroundTime = currentProcess.completionTime - currentProcess.arrivalTime;
        currentProcess.waitingTime = currentProcess.turnaroundTime - currentProcess.burstTime;
      }
    }

    return RRResult(resultList, timeline);
  }
}