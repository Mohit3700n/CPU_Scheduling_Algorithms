import '../../models/process.dart';

class FCFSScheduler {

  static List<Process> run(List<Process> processes) {
    processes.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

    int currentTime = 0;

    for (var process in processes) {
      if (currentTime < process.arrivalTime) {
        currentTime = process.arrivalTime;
      }

      currentTime += process.burstTime;
      process.completionTime = currentTime;
      process.turnaroundTime = process.completionTime - process.arrivalTime;
      process.waitingTime = process.turnaroundTime - process.burstTime;
    }

    return processes;
  }
}