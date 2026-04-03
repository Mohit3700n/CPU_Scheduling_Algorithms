import '../models/process.dart';

class SJFScheduler {
  static List<Process> run(List<Process> processes) {
    List<Process> readyQueue = List.from(processes);
    List<Process> result = [];
    int currentTime = 0;

    readyQueue.sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

    while (readyQueue.isNotEmpty) {
      List<Process> availableProcesses = readyQueue.where((p) => p.arrivalTime <= currentTime).toList();

      if (availableProcesses.isEmpty) {
        currentTime = readyQueue.first.arrivalTime;
        continue;
      }

      availableProcesses.sort((a, b) {
        int btCompare = a.burstTime.compareTo(b.burstTime);
        if (btCompare == 0) {
          return a.arrivalTime.compareTo(b.arrivalTime);
        }
        return btCompare;
      });

      Process shortestJob = availableProcesses.first;
      readyQueue.remove(shortestJob);
      currentTime += shortestJob.burstTime;

      shortestJob.completionTime = currentTime;
      shortestJob.turnaroundTime = shortestJob.completionTime - shortestJob.arrivalTime;
      shortestJob.waitingTime = shortestJob.turnaroundTime - shortestJob.burstTime;

      result.add(shortestJob);
    }

    return result;
  }
}