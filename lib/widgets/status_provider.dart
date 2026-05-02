import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../data/status.dart';
import '../utils/static.dart';

class StatusChangeNotifier extends ChangeNotifier implements ReassembleHandler {
  Status _currentStatus;

  Status get currentStatus => _currentStatus;

  StatusChangeNotifier(this._currentStatus);

  void setStatus(Status status) {
    if (_currentStatus == status) return;
    _currentStatus = status;
    Static.currentStatus = status; // 同步回全域靜態變數
    notifyListeners();
  }

  @override
  void reassemble() => setStatus(Static.currentStatus);
}

class StatusProvider extends StatelessWidget {
  final Widget Function(BuildContext context, Status currentStatus) builder;

  const StatusProvider({super.key, required this.builder});

  static StatusChangeNotifier of(BuildContext context) =>
      Provider.of<StatusChangeNotifier>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusChangeNotifier>(
      builder: (context, notifier, _) =>
          builder(context, notifier.currentStatus),
    );
  }
}
