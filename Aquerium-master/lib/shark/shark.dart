import 'dart:async';
import 'dart:isolate';

import 'package:aquarium/shark/shark_action.dart';
import 'package:aquarium/shark/shark_request.dart';

class Shark {
  Shark({
    required this.id,
    required this.huntInterval,
    required this.sendPort,
  });

  final String id;
  final Duration huntInterval;
  final SendPort sendPort;
  ReceivePort? _receiverPort;
  Timer? _huntTimer;

  void createReceivePort() {
    _receiverPort = ReceivePort();
    _actionListener();
    sendPort.send(
      SharkRequest(
        sharkId: id,
        action: SharkAction.sendPort,
        args: _receiverPort?.sendPort,
      ),
    );
    
  }

  void startHunting() {
    _huntTimer ??= Timer.periodic(huntInterval, (timer) {
      sendPort.send(
        SharkRequest(
          sharkId: id,
          action: SharkAction.hunt,
        ),
      );
    });
  }

  FutureOr<void> _close() {
    _huntTimer?.cancel();
    _receiverPort?.close();
    _receiverPort = null;
    sendPort.send(
      SharkRequest(
        sharkId: id,
        action: SharkAction.killIsolate,
      ),
    );
  }

  void _actionListener() {
    _receiverPort?.listen((message) {
      if (message is SharkAction) {
        switch (message) {
          case SharkAction.startHunting:
            startHunting();
            break;
          case SharkAction.close:
            _close();
            break;
          default:
            break;
        }
      }
    });
  }

  static void run(Shark shark) {
    shark.createReceivePort();
  }

 
}
