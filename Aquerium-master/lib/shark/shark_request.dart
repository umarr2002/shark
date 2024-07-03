

import 'shark_action.dart';

class SharkRequest {
  SharkRequest({
    required this.sharkId,
    required this.action,
    this.args,
  });

  final String sharkId;
  final SharkAction action;
  final dynamic args;
}
