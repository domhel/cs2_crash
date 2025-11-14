import 'package:cs_crash/app_state.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.black,
      ),
      home: ListenableBuilder(
          listenable: AppState.instance,
          builder: (context, child) {
            final mediumText =
                Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold) ?? const TextStyle();
            return Scaffold(
              bottomSheet: BottomSheet(
                enableDrag: false,
                onClosing: () {},
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              AnimatedDefaultTextStyle(
                                style: AppState.instance.isCoinsTextExpanded
                                    ? mediumText.apply(fontSizeFactor: 2)
                                    : mediumText,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                child: Text(
                                  'Coins: \$${AppState.instance.coins.toStringAsFixed(2)}',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Bet: \$${AppState.instance.lastBet.toStringAsFixed(2)}',
                                style: mediumText,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppState.instance.crashed ? Colors.red[200] : Colors.green[200],
                              textStyle: mediumText,
                            ),
                            onPressed: switch (AppState.instance.state) {
                              GameState.playing =>
                                AppState.instance.cashedOut ? null : () => AppState.instance.cashOut(),
                              _ => AppState.instance.canBet(10)
                                  ? () => AppState.instance.play(10)
                                  : () => AppState.instance.refill(),
                            },
                            child: switch (AppState.instance.state) {
                              GameState.playing =>
                                AppState.instance.cashedOut ? const Text('Cashed out') : const Text('Cash out'),
                              _ => AppState.instance.canBet(10) ? const Text('Play') : const Text('Refill'),
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
              body: Column(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      height: double.infinity,
                      alignment: const Alignment(0, -0.35),
                      color: AppState.instance.crashed ? Colors.red : Colors.green,
                      child: Stack(
                        children: [
                          // Info text at the top
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Text(
                              'Press start and you see the factor go up. Cash out to receive your bet multiplied by the factor. Beware! You lose your bet if you haven\'t cashed out before crashing.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Background chart
                          if (AppState.instance.chartDataIndex > 0)
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 60,
                              bottom: 200, // Position above bottom sheet (lower than before)
                              child: _CrashChart(
                                data: AppState.instance.chartData,
                                dataIndex: AppState.instance.chartDataIndex,
                                crashed: AppState.instance.crashed,
                              ),
                            ),
                          // Factor display on top
                          Align(
                            alignment: const Alignment(0, -0.35),
                            child: FittedBox(
                              child: Text(
                                'x ${AppState.instance.currentFactor.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontFeatures: [const FontFeature.tabularFigures()],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
    );
  }
}

class _CrashChart extends StatelessWidget {
  final FastDoubleBuffer data;
  final int dataIndex;
  final bool crashed;

  const _CrashChart({
    required this.data,
    required this.dataIndex,
    required this.crashed,
  });

  @override
  Widget build(BuildContext context) {
    if (dataIndex < 2) {
      return const SizedBox.shrink();
    }

    // Convert data to chart spots
    final spots = <FlSpot>[];
    for (int i = 0; i < dataIndex; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
    }

    // Fixed coordinate system:
    // Formula: factor = e^(i/2000), so for factor=2.0: i = 2000*ln(2) ≈ 1386
    // At 120 FPS, this is about 11.5 seconds of data
    const fixedMaxXFrames = 1400.0; // Frames to reach ~2.0x
    const initialMaxY = 4.0; // Y axis goes from 0 to 4.0x initially

    // Get current max for dynamic scaling after 4.0x
    final currentMaxY = data[dataIndex - 1];
    final maxY = currentMaxY > initialMaxY ? currentMaxY : initialMaxY;

    // Calculate the actual X range to display
    // Before we have 1400 frames, show 0 to 1400 (chart fills left to right)
    // After 1400 frames, show the most recent 1400 frames
    final displayMaxX = dataIndex < fixedMaxXFrames ? fixedMaxXFrames : dataIndex.toDouble();

    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: crashed ? Colors.red[800]!.withOpacity(0.4) : Colors.green[800]!.withOpacity(0.4),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        minY: 0.95, // Start just below 1.0 to show the full curve
        maxY: maxY, // Fixed at 4.0 initially, then scales with data
        minX: 0,
        maxX: displayMaxX,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
      ),
      duration: Duration.zero,
    );
  }
}
