import '../models/process.dart';
import '../models/gantt_block.dart';

class SRTFResult {
  final List<Process> processes;
  final List<GanttBlock> ganttTimeline;
  SRTFResult(this.processes, this.ganttTimeline);
}

class SRTFScheduler {
  static SRTFResult run(List<Process> processes) {
    List<Process> procs = processes.map((p) => Process(id: p.id, arrivalTime: p.arrivalTime, burstTime: p.burstTime)).toList();
    procs.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

    int currentTime = 0;
    int completed = 0;

    Map<String, int> remainingTime = {for (var p in procs) p.id: p.burstTime};

    List<GanttBlock> timeline = [];
    Process? currentProcess;
    int blockStartTime = 0;

    while (completed != procs.length) {
      Process? shortestProc;
      int minRemaining = 999999;

      // Sabse chota remaining time wala process dhoondho jo aa chuka hai
      for (var p in procs) {
        if (p.arrivalTime <= currentTime && remainingTime[p.id]! > 0 && remainingTime[p.id]! < minRemaining) {
          shortestProc = p;
          minRemaining = remainingTime[p.id]!;
        }
      }

      // Agar koi process ready nahi hai toh CPU idle rahega
      if (shortestProc == null) {
        if (currentProcess != null) {
          timeline.add(GanttBlock(processId: currentProcess.id, startTime: blockStartTime, endTime: currentTime));
          currentProcess = null;
        }
        currentTime++;
        continue;
      }

      // Context Switch: Agar naya process current wale se alag hai
      if (currentProcess != shortestProc) {
        if (currentProcess != null) {
          // Purane process ka block Gantt chart me save karo
          timeline.add(GanttBlock(processId: currentProcess.id, startTime: blockStartTime, endTime: currentTime));
        }
        currentProcess = shortestProc;
        blockStartTime = currentTime;
      }

      // Process ko 1 millisecond ke liye chalao
      remainingTime[shortestProc.id] = remainingTime[shortestProc.id]! - 1;
      currentTime++;

      // Agar process pura ho gaya
      if (remainingTime[shortestProc.id] == 0) {
        completed++;
        shortestProc.completionTime = currentTime;
        shortestProc.turnaroundTime = shortestProc.completionTime - shortestProc.arrivalTime;
        shortestProc.waitingTime = shortestProc.turnaroundTime - shortestProc.burstTime;

        timeline.add(GanttBlock(processId: shortestProc.id, startTime: blockStartTime, endTime: currentTime));
        currentProcess = null; // Next loop me naya process pick hoga
      }
    }

    return SRTFResult(procs, timeline);
  }
}