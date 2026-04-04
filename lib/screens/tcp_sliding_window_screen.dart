import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class FlyingItem {
  final String id;
  final int seqNo;
  final bool isAck;
  double progress; // 0.0 to 1.0
  bool isLost;
  double opacity;

  FlyingItem({
    required this.id,
    required this.seqNo,
    required this.isAck,
    this.progress = 0.0,
    this.isLost = false,
    this.opacity = 1.0,
  });
}

class TcpSlidingWindowScreen extends StatefulWidget {
  const TcpSlidingWindowScreen({super.key});

  @override
  State<TcpSlidingWindowScreen> createState() => _TcpSlidingWindowScreenState();
}

class _TcpSlidingWindowScreenState extends State<TcpSlidingWindowScreen> {
  // Protocol State
  int totalPackets = 20;
  int windowSize = 4;
  int base = 0;
  int nextSeq = 0;
  int expectedSeq = 0; // Receiver side

  // Simulation Controls
  bool isPlaying = false;
  Timer? gameLoop;
  int ticks = 0;
  int timeoutCounter = 0;
  final int timeoutThreshold = 180; // ~3 seconds at 60fps

  // UI State
  List<FlyingItem> flyingItems = [];
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    _addLog("System Initialized. Ready to transmit.");
  }

  @override
  void dispose() {
    gameLoop?.cancel();
    super.dispose();
  }

  void _addLog(String msg) {
    if (logs.length > 8) logs.removeLast();
    logs.insert(0, "[Tick $ticks] $msg");
  }

  void _resetSimulation() {
    gameLoop?.cancel();
    setState(() {
      base = 0;
      nextSeq = 0;
      expectedSeq = 0;
      ticks = 0;
      timeoutCounter = 0;
      flyingItems.clear();
      logs.clear();
      isPlaying = false;
      _addLog("Simulation Reset.");
    });
  }

  void _togglePlayback() {
    if (isPlaying) {
      gameLoop?.cancel();
      setState(() => isPlaying = false);
      _addLog("Simulation Paused.");
    } else {
      setState(() => isPlaying = true);
      _addLog("Simulation Started.");
      gameLoop = Timer.periodic(const Duration(milliseconds: 16), _updateLoop);
    }
  }

  void _updateLoop(Timer timer) {
    setState(() {
      ticks++;

      if (ticks % 60 == 0 && nextSeq < base + windowSize && nextSeq < totalPackets) {
        flyingItems.add(FlyingItem(
          id: 'P_${nextSeq}_$ticks',
          seqNo: nextSeq,
          isAck: false,
        ));
        _addLog("Sent Packet $nextSeq");
        nextSeq++;
      }

      if (base < nextSeq) {
        timeoutCounter++;
        if (timeoutCounter > timeoutThreshold) {
          _addLog("TIMEOUT! No ACK for P$base. Retransmitting window.");
          nextSeq = base;
          timeoutCounter = 0;
        }
      } else {
        timeoutCounter = 0;
      }

      List<FlyingItem> toRemove = [];
      List<FlyingItem> toAdd = [];

      for (var item in flyingItems) {
        if (item.isLost) {
          item.opacity -= 0.02;
          if (item.opacity <= 0) toRemove.add(item);
          continue;
        }

        item.progress += 0.006;

        if (item.progress >= 1.0) {
          toRemove.add(item);

          if (!item.isAck) {
            if (item.seqNo == expectedSeq) {
              _addLog("Receiver got P${item.seqNo}. Sending ACK $expectedSeq");
              expectedSeq++;
              toAdd.add(FlyingItem(
                id: 'ACK_${expectedSeq - 1}_$ticks',
                seqNo: expectedSeq - 1,
                isAck: true,
              ));
            } else {
              _addLog("Receiver got OUT OF ORDER P${item.seqNo}. Discarding.");
              if (expectedSeq > 0) {
                toAdd.add(FlyingItem(
                  id: 'DUP_ACK_${expectedSeq - 1}_$ticks',
                  seqNo: expectedSeq - 1,
                  isAck: true,
                ));
              }
            }
          } else {
            if (item.seqNo >= base) {
              _addLog("Sender got ACK ${item.seqNo}. Window slides!");
              base = item.seqNo + 1;
              timeoutCounter = 0;
            }
          }
        }
      }

      flyingItems.removeWhere((item) => toRemove.contains(item));
      flyingItems.addAll(toAdd);

      if (base >= totalPackets) {
        _addLog("ALL PACKETS DELIVERED SUCCESSFULLY!");
        _togglePlayback();
      }
    });
  }

  void _injectPacketLoss() {
    var activeDataPackets = flyingItems.where((i) => !i.isLost).toList();
    if (activeDataPackets.isNotEmpty) {
      final random = Random();
      var itemToDrop = activeDataPackets[random.nextInt(activeDataPackets.length)];
      setState(() {
        itemToDrop.isLost = true;
        _addLog("💥 INJECTED LOSS: ${itemToDrop.isAck ? 'ACK' : 'Packet'} ${itemToDrop.seqNo} destroyed!");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Computer Networks: TCP Sliding Window', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2A2D3E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _resetSimulation),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
          child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildControlPanel(isMobile: false),
        const SizedBox(height: 24),
        Expanded(flex: 3, child: _buildNetworkArena()),
        const SizedBox(height: 24),
        Expanded(
          flex: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: _buildLogsPanel()),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _buildAoAAnalysis()),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildControlPanel(isMobile: true),
          const SizedBox(height: 16),
          SizedBox(height: 400, child: _buildNetworkArena()),
          const SizedBox(height: 16),
          SizedBox(height: 250, child: _buildLogsPanel()),
          const SizedBox(height: 16),
          _buildAoAAnalysis(),
        ],
      ),
    );
  }

  Widget _buildControlPanel({required bool isMobile}) {
    Widget playBtn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: isPlaying ? Colors.orangeAccent : const Color(0xFF00C9A7), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
      onPressed: _togglePlayback,
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
      label: Text(isPlaying ? 'Pause Simulation' : 'Start Transfer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );

    Widget slider = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Window Size: $windowSize", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        SizedBox(
          width: 200,
          child: Slider(
            value: windowSize.toDouble(),
            min: 1, max: 8, divisions: 7,
            activeColor: const Color(0xFF6C63FF),
            onChanged: isPlaying ? null : (val) => setState(() => windowSize = val.toInt()),
          ),
        ),
      ],
    );

    Widget lossBtn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5C8D), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
      onPressed: isPlaying ? _injectPacketLoss : null,
      icon: const Icon(Icons.flash_on, color: Colors.white),
      label: const Text('Simulate Packet Loss', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            playBtn,
            const SizedBox(height: 16),
            Center(child: slider),
            const SizedBox(height: 16),
            lossBtn,
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            playBtn,
            const SizedBox(width: 24),
            slider,
            const Spacer(),
            lossBtn,
          ],
        ),
      );
    }
  }

  Widget _buildNetworkArena() {
    Widget arenaContent = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 150,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.white12, width: 2))),
          child: Column(
            children: [
              const Text("SENDER", style: TextStyle(color: Color(0xFF6C63FF), fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: totalPackets,
                  itemBuilder: (ctx, i) {
                    bool isAcked = i < base;
                    bool isSent = i >= base && i < nextSeq;
                    bool inWindow = i >= base && i < base + windowSize;

                    Color boxColor = isAcked ? Colors.greenAccent.withValues(alpha: 0.2) : (isSent ? Colors.orangeAccent.withValues(alpha: 0.4) : (inWindow ? Colors.lightBlueAccent.withValues(alpha: 0.2) : Colors.white12));
                    Color textColor = isAcked ? Colors.greenAccent : (isSent ? Colors.orangeAccent : (inWindow ? Colors.lightBlueAccent : Colors.white54));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(4), border: inWindow && i == base ? Border.all(color: Colors.white) : null),
                      alignment: Alignment.center,
                      child: Text("Packet $i", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 2, color: Colors.white12),
                    const SizedBox(height: 100),
                    Container(height: 2, color: Colors.white12),
                  ],
                ),
              ),

              ...flyingItems.map((item) {
                double alignX = item.isAck ? (1.0 - (item.progress * 2)) : ((item.progress * 2) - 1.0);
                double alignY = item.isAck ? 0.3 : -0.3;

                return Align(
                  alignment: Alignment(alignX, alignY),
                  child: Opacity(
                    opacity: item.opacity,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: item.isLost ? Colors.redAccent : (item.isAck ? const Color(0xFF00C9A7) : const Color(0xFF6C63FF)),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: (item.isAck ? const Color(0xFF00C9A7) : const Color(0xFF6C63FF)).withValues(alpha: 0.5), blurRadius: 8)]
                      ),
                      child: item.isLost
                          ? const Icon(Icons.close, color: Colors.white)
                          : Text(item.isAck ? "ACK ${item.seqNo}" : "P ${item.seqNo}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        Container(
          width: 150,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.white12, width: 2))),
          child: Column(
            children: [
              const Text("RECEIVER", style: TextStyle(color: Color(0xFF00C9A7), fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    const Text("Expected", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("P $expectedSeq", style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double explicitWidth = max(constraints.maxWidth, 700.0);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: explicitWidth,
              height: constraints.maxHeight,
              child: arenaContent,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Live TCP Handshake Logs", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (ctx, i) {
                bool isError = logs[i].contains("TIMEOUT") || logs[i].contains("LOSS") || logs[i].contains("DISCARD");
                bool isSuccess = logs[i].contains("slides") || logs[i].contains("SUCCESS");

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    logs[i],
                    style: TextStyle(color: isError ? Colors.redAccent : (isSuccess ? Colors.greenAccent : Colors.white70), fontFamily: 'monospace', fontSize: 13),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAoAAnalysis() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF2A2D3E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
      child: SingleChildScrollView(
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Computer Network & AoA Metrics", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Divider(color: Colors.white24, height: 16),
            Text("Protocol: Go-Back-N (Sliding Window)", style: TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Time Complexity: O(N * W)", style: TextStyle(color: Colors.white70, fontSize: 12)),
            SizedBox(height: 4),
            Text("Worst Case: If packet drops, entire window (W) is retransmitted. Hence W multiplier.", style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
            SizedBox(height: 12),
            Text("Strategy: Pipelined Reliability", style: TextStyle(color: Colors.white70, fontSize: 12)),
            SizedBox(height: 4),
            Text("Keeps network saturated by sending multiple packets before requiring ACKs, avoiding the Stop-and-Wait bottleneck.", style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}