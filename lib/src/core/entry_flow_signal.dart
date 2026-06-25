import 'package:flutter/foundation.dart';

class EntryFlowSignal {
  EntryFlowSignal._();

  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void notifyChanged() {
    tick.value++;
  }
}
