import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../services/tflite_assistant.dart';
import '../models/prediction_result.dart';

class BenchmarkExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Performance Benchmark',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BenchmarkScreen(),
    );
  }
}

class BenchmarkScreen extends StatefulWidget {
  @override
  _BenchmarkScreenState createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  final TFLiteAssistant _assistant = TFLiteAssistant();
  bool _isBenchmarking = false;
  bool _isInitialized = false;
  
  List<BenchmarkResult> _results = [];
  BenchmarkStats? _stats;
  
  final List<String> _testQueries = [
    "What's the weather like?",
    "Set a timer for 10 minutes",
    "Play some music",
    "Call mom",
    "What time is it?",
    "Turn on the lights",
    "Send a message",
    "Navigate to home",
    "Show me recipes",
    "Check my calendar",
    "Take a photo",
    "Search for restaurants",
    "Set an alarm",
    "Play the news",
    "Turn off wifi",
  ];

  @override
  void initState() {
    super.initState();
    _initializeAssistant();
  }

  Future<void> _initializeAssistant() async {
    try {
      await _assistant.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Failed to initialize assistant: $e');
    }
  }

  Future<void> _runBenchmark() async {
    if (!_isInitialized) return;
    
    setState(() {
      _isBenchmarking = true;
      _results.clear();
      _stats = null;
    });

    final random = Random();
    final iterations = 100;
    
    for (int i = 0; i < iterations; i++) {
      final query = _testQueries[random.nextInt(_testQueries.length)];
      
      try {
        final stopwatch = Stopwatch()..start();
        final result = await _assistant.classify(query);
        stopwatch.stop();
        
        _results.add(BenchmarkResult(
          query: query,
          result: result,
          latency: stopwatch.elapsedMilliseconds,
          iteration: i + 1,
        ));
        
        setState(() {});
        
        // Small delay to prevent overwhelming the system
        await Future.delayed(Duration(milliseconds: 10));
        
      } catch (e) {
        print('Error during benchmark iteration $i: $e');
      }
    }
    
    _calculateStats();
    setState(() {
      _isBenchmarking = false;
    });
  }

  void _calculateStats() {
    if (_results.isEmpty) return;
    
    final latencies = _results.map((r) => r.latency).toList();
    latencies.sort();
    
    final sum = latencies.reduce((a, b) => a + b);
    final mean = sum / latencies.length;
    final median = latencies[latencies.length ~/ 2];
    final min = latencies.first;
    final max = latencies.last;
    
    // Calculate 95th percentile
    final p95Index = ((latencies.length - 1) * 0.95).round();
    final p95 = latencies[p95Index];
    
    _stats = BenchmarkStats(
      totalIterations: _results.length,
      meanLatency: mean,
      medianLatency: median.toDouble(),
      minLatency: min.toDouble(),
      maxLatency: max.toDouble(),
      p95Latency: p95.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Performance Benchmark'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            SizedBox(height: 16),
            _buildBenchmarkButton(),
            SizedBox(height: 16),
            if (_stats != null) _buildStatsCard(),
            SizedBox(height: 16),
            if (_results.isNotEmpty) _buildResultsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _isInitialized ? Icons.check_circle : Icons.error,
                  color: _isInitialized ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  _isInitialized ? 'TFLite Assistant Ready' : 'Initializing...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            if (_isBenchmarking) ...[
              SizedBox(height: 8),
              LinearProgressIndicator(),
              SizedBox(height: 8),
              Text('Running benchmark: ${_results.length}/100 iterations'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isInitialized && !_isBenchmarking ? _runBenchmark : null,
        child: Text(_isBenchmarking ? 'Running Benchmark...' : 'Start Benchmark'),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildStatRow('Total Iterations', '${_stats!.totalIterations}'),
            _buildStatRow('Mean Latency', '${_stats!.meanLatency.toStringAsFixed(1)} ms'),
            _buildStatRow('Median Latency', '${_stats!.medianLatency.toStringAsFixed(1)} ms'),
            _buildStatRow('Min Latency', '${_stats!.minLatency.toStringAsFixed(1)} ms'),
            _buildStatRow('Max Latency', '${_stats!.maxLatency.toStringAsFixed(1)} ms'),
            _buildStatRow('95th Percentile', '${_stats!.p95Latency.toStringAsFixed(1)} ms'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Container(
              height: 300,
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[_results.length - 1 - index];
                  return ListTile(
                    title: Text(result.query),
                    subtitle: Text('Result: ${result.result.label}'),
                    trailing: Text('${result.latency}ms'),
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BenchmarkResult {
  final String query;
  final PredictionResult result;
  final int latency;
  final int iteration;

  BenchmarkResult({
    required this.query,
    required this.result,
    required this.latency,
    required this.iteration,
  });
}

class BenchmarkStats {
  final int totalIterations;
  final double meanLatency;
  final double medianLatency;
  final double minLatency;
  final double maxLatency;
  final double p95Latency;

  BenchmarkStats({
    required this.totalIterations,
    required this.meanLatency,
    required this.medianLatency,
    required this.minLatency,
    required this.maxLatency,
    required this.p95Latency,
  });
}

void main() {
  runApp(BenchmarkExample());
}