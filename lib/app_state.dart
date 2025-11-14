import 'dart:async';
import 'dart:ffi';
import 'dart:math';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' hide Size;
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

enum GameState {
  idle,
  playing,
  crashed,
}

class FastDoubleBuffer {
  final Float64List _data;
  final Pointer<Double> _ptr;
  static late final void Function(Pointer<Void>, Pointer<Void>, int) _memmove;

  // One-time init for memmove (platform-safe, generic Void pointers)
  static void _initMemmove() {
    _memmove = DynamicLibrary.process().lookupFunction<Void Function(Pointer<Void>, Pointer<Void>, Size),
        void Function(Pointer<Void>, Pointer<Void>, int)>('memmove');
  }

  FastDoubleBuffer(int capacity)
      : _ptr = calloc<Double>(capacity),
        _data = calloc<Double>(capacity).asTypedList(capacity) {
    // FIXED: Single alloc, shared view
    _initMemmove(); // Safe to call multiple times
  }

  // Factory for init from List<double> (copies into shared buffer)
  factory FastDoubleBuffer.fromList(List<double> src) {
    final buffer = FastDoubleBuffer(src.length);
    buffer._data.setRange(0, src.length, src); // Fast bulk copy
    return buffer;
  }

  // Fast in-place left-shift by 1 (memmove + clear tail)
  void shiftLeft() {
    final count = _data.length - 1;
    if (count > 0) {
      _memmove(_ptr.cast<Void>(), (_ptr + 1).cast<Void>(), count * sizeOf<Double>()); // FIXED: Cast to Void for call
    }
    _data[_data.length - 1] = 0.0; // Clear tail
  }

  // Accessors (backed by shared _data)
  double operator [](int i) => _data[i];
  void operator []=(int i, double v) => _data[i] = v;
}

class AppState extends ChangeNotifier {
  static final instance = AppState._();
  bool _hasVibrator = true;
  bool _hasAskedForFeedback = false;
  AppState._() {
    Vibration.hasVibrator().then((hasVibrator) {
      _hasVibrator = hasVibrator == true;
    });
    SharedPreferences.getInstance().then((prefs) {
      _hasAskedForFeedback = prefs.getBool('hasAskedForFeedback_v1') ?? false;
    });
  }

  final rng = Random.secure();

  Timer? _timer;
  GameState state = GameState.idle;
  double currentFactor = 13.37;
  bool cashedOut = false;
  int cashOutCount = 0;
  bool crashed = false;

  static const double initialCapital = 100;
  double coins = initialCapital;
  bool isCoinsTextExpanded = false;
  double lastBet = 10;
  bool canBet(double bet) => bet <= coins;

  // Chart data for visualization
  static const int maxChartPoints = 10000; // Keep last 600 points for longer history
  final chartData = FastDoubleBuffer(maxChartPoints);
  int chartDataIndex = 0;

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
    chartData[0] = 1.0; // Start chart with initial factor of 1.0
    chartDataIndex = 1;
    notifyListeners();

    const step = 1;
    const slowDown = 20;
    const betterOdds = 2; // 1 = equal/default
    const p = 1 / 68.5 / slowDown / betterOdds;
    int i = 0;
    crashed = false;
    _timer = Timer.periodic(const Duration(microseconds: 1000000 ~/ 120), (timer) {
      crashed = rng.nextDouble() < p;
      currentFactor = pow(e, i / 100 / slowDown) as double;

      // Update chart data - add every point, remove old ones when exceeding max
      if (chartDataIndex >= maxChartPoints - 1) {
        chartData.shiftLeft();
        chartDataIndex = maxChartPoints - 1;
        chartData[chartDataIndex] = currentFactor;
      } else {
        chartData[chartDataIndex] = currentFactor;
        chartDataIndex++;
      }

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
    cashOutCount++;
    coins += currentFactor * lastBet;
    isCoinsTextExpanded = true;
    notifyListeners();
    HapticFeedback.mediumImpact().then((_) => Future.delayed(const Duration(milliseconds: 200))).then((_) {
      isCoinsTextExpanded = false;
      notifyListeners();
      return HapticFeedback.heavyImpact();
    }).then((_) {
      if (!_hasAskedForFeedback && cashOutCount >= 2) {
        _hasAskedForFeedback = true;
        InAppReview.instance.isAvailable().then((available) {
          if (available) {
            InAppReview.instance.requestReview();
            SharedPreferences.getInstance().then((prefs) {
              prefs.setBool('hasAskedForFeedback_v1', true);
            });
          }
        });
      }
    });
  }

  void stop() {
    _timer?.cancel();
    state = GameState.idle;
    notifyListeners();
  }

  void refill() {
    coins = initialCapital;
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
