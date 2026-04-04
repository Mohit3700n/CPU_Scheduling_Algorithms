class AlgoStats {
  static String getInfo(String algo) {
    switch (algo) {
      case 'FCFS':
        return "Strategy: FIFO Queue | Time Complexity: O(N log N)";
      case 'SJF':
        return "Strategy: Greedy Approach | Time Complexity: O(N log N)";
      case 'SRTF':
        return "Strategy: Preemptive Greedy | Time Complexity: O(N log N)";
      case 'RR':
        return "Strategy: Circular Queue (Time Sliced) | Time Complexity: O(N)";
      case 'UserStrategy':
        return "Strategy: Custom Sequential | Time Complexity: O(N)";
      default:
        return "Custom User Strategy";
    }
  }
}