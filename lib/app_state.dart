import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

enum GameState {
  idle,
  playing,
  crashed,
}

class AppState extends ChangeNotifier {
  static final instance = AppState._();
  bool _hasVibrator = true;
  AppState._() {
    Vibration.hasVibrator().then((hasVibrator) {
      _hasVibrator = hasVibrator == true;
    });
  }

  final rng = Random.secure();

  Timer? _timer;
  GameState state = GameState.idle;
  double currentFactor = 1.0;
  bool cashedOut = false;
  bool crashed = false;

  double coins = 100;
  double lastBet = 0;
  bool canBet(double bet) => bet <= coins;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void play(double bet) {
    if (state == GameState.playing) {
      return;
    }
    if (canBet(bet)) {
      lastBet = bet;
    } else {
      return;
    }
    state = GameState.playing;
    crashed = false;
    cashedOut = false;
    coins -= lastBet;
    notifyListeners();

    const step = 1;
    const slowDown = 20;
    const p = 1 / 68.5 / slowDown;
    int i = 0;
    crashed = false;
    _timer =
        Timer.periodic(const Duration(microseconds: 1000000 ~/ 120), (timer) {
      crashed = rng.nextDouble() < p;
      currentFactor = pow(e, i / 100 / slowDown) as double;
      // print('Factor $currentFactor');
      if (crashed) {
        timer.cancel();
        debugPrint('Crashed at $currentFactor');
        state = GameState.crashed;
        if (_hasVibrator) {
          Vibration.vibrate();
        }
      } else {
        i += step;
      }
      notifyListeners();
    });
  }

  void cashOut() {
    debugPrint('cash out');
    if (state != GameState.playing) {
      return;
    }
    if (crashed || cashedOut) {
      return;
    }
    cashedOut = true;
    coins += currentFactor * lastBet;
    HapticFeedback.mediumImpact()
        .then((_) => Future.delayed(const Duration(milliseconds: 200)))
        .then((_) => HapticFeedback.heavyImpact());
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    state = GameState.idle;
    notifyListeners();
  }

  // void playRepeatedly(int n) {
  //   double sum = 0;
  //   for (int i = 0; i < n; ++i) {
  //     sum += play();
  //   }
  //   final average = sum / n;
  //   print('Average after $n games: $average');
  // }
}
