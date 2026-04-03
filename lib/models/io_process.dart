class IOProcess {
  final String id;
  final int arrivalTime;
  final int cpuBurst1;
  final int ioBurst;
  final int cpuBurst2;
  
  int completionTime = 0;
  int turnaroundTime = 0;
  int waitingTime = 0;

  IOProcess({
    required this.id,
    required this.arrivalTime,
    required this.cpuBurst1,
    required this.ioBurst,
    required this.cpuBurst2,
  });
}