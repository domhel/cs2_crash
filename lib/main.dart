import 'package:cs_crash/app_state.dart';
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
            final mediumText = Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold) ??
                const TextStyle();
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
                              backgroundColor: AppState.instance.crashed
                                  ? Colors.red[200]
                                  : Colors.green[200],
                              textStyle: mediumText,
                            ),
                            onPressed: switch (AppState.instance.state) {
                              GameState.playing => AppState.instance.cashedOut
                                  ? null
                                  : () => AppState.instance.cashOut(),
                              _ => () => AppState.instance.play(10),
                            },
                            child: switch (AppState.instance.state) {
                              GameState.playing => AppState.instance.cashedOut
                                  ? const Text('Cashed out')
                                  : const Text('Cash out'),
                              _ => const Text('Play'),
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
                      color:
                          AppState.instance.crashed ? Colors.red : Colors.green,
                      child: FittedBox(
                        child: Text(
                          'x ${AppState.instance.currentFactor.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                            fontFeatures: [const FontFeature.tabularFigures()],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
