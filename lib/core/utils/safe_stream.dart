import 'dart:async';
import 'package:flutter/foundation.dart';

/// Safely creates a Stream that immediately yields REST data, listens to Supabase Realtime,
/// and seamlessly degrades to periodic REST polling if WebSockets time out, fail, or throw exceptions.
Stream<T> safeSupabaseStream<T>({
  required Future<T> Function() fetchRest,
  required Stream<T> Function() streamRealtime,
  Duration pollingInterval = const Duration(seconds: 10),
}) async* {
  // 1. Immediately yield initial data from REST API over HTTPS
  try {
    final initialData = await fetchRest().timeout(const Duration(seconds: 2));
    yield initialData;
  } catch (e) {
    debugPrint('SafeStream: Initial REST fetch failed: $e');
    try {
      final fallbackData = await fetchRest();
      yield fallbackData;
    } catch (_) {
      try {
        yield <Never>[] as T;
      } catch (_) {}
    }
  }

  // 2. Listen to Realtime stream with fallback to periodic REST polling
  final controller = StreamController<T>();
  StreamSubscription<T>? realtimeSub;
  Timer? pollingTimer;
  bool realtimeReceivedData = false;

  void startPolling() {
    if (pollingTimer?.isActive == true) return;
    debugPrint('SafeStream: Realtime stream fallback activated. Polling REST API every ${pollingInterval.inSeconds}s.');
    pollingTimer = Timer.periodic(pollingInterval, (_) async {
      try {
        final data = await fetchRest();
        if (!controller.isClosed) {
          controller.add(data);
        }
      } catch (e) {
        debugPrint('SafeStream: Polling REST fetch error: $e');
      }
    });
  }

  try {
    final realtimeStream = streamRealtime();
    realtimeSub = realtimeStream.listen(
      (data) {
        realtimeReceivedData = true;
        if (!controller.isClosed) {
          controller.add(data);
        }
      },
      onError: (err, stack) {
        debugPrint('SafeStream: Realtime error ($err). Falling back to REST polling.');
        realtimeSub?.cancel();
        startPolling();
      },
      onDone: () {
        if (!realtimeReceivedData) {
          startPolling();
        }
      },
      cancelOnError: true,
    );

    // Timeout safety check: If Realtime stream does not yield any event within 5 seconds, start polling
    Timer(const Duration(seconds: 5), () {
      if (!realtimeReceivedData && pollingTimer?.isActive != true) {
        startPolling();
      }
    });
  } catch (e) {
    debugPrint('SafeStream: Failed to initiate Realtime stream subscription ($e). Starting REST polling.');
    startPolling();
  }

  // Yield all events from controller
  yield* controller.stream;

  // Cleanup upon listener cancellation
  controller.onCancel = () {
    realtimeSub?.cancel();
    pollingTimer?.cancel();
    controller.close();
  };
}
