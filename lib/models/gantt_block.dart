class GanttBlock {
  final String processId;
  final int startTime;
  final int endTime;

  GanttBlock({
    required this.processId,
    required this.startTime,
    required this.endTime,
  });
  
  int get duration => endTime - startTime;
}