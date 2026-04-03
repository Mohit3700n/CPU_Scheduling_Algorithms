class Process {
  final String id;
  final int arrivalTime;
  final int burstTime;

  int completionTime;
  int turnaroundTime;
  int waitingTime;

  Process({
    required this.id,
    required this.arrivalTime,
    required this.burstTime,
    this.completionTime = 0,
    this.turnaroundTime = 0,
    this.waitingTime = 0,
  });

 
  @override
  String toString() {
    return 'Process $id | AT: $arrivalTime | BT: $burstTime | CT: $completionTime | TAT: $turnaroundTime | WT: $waitingTime';
  }
}