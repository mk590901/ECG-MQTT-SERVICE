import 'dart:async';

import '../data_collection/data_exchanger.dart';
import '../gui_adapter/service_adapter.dart';

class ECGSensor {
  static int PERIOD = 1000;

  final String id;
  final DataExchanger exchanger;
  final Duration _period = Duration(milliseconds: PERIOD);

  late Timer? _timer;

  ECGSensor (this.id, this.exchanger) {
    _timer = null;

    print ('-- Constructor ECGSensor --');
  }

  void start() {
    print ('------- ECGSensor.start -------');
    _timer = Timer.periodic(_period, (Timer t) {
      _callbackFunction();
    });
  }

  void stop() {
    if (isActive()) {
      _timer?.cancel();
    }
    _timer = null;
    print ('------- ECGSensor.stop -------');
  }

  void _callbackFunction() {
    List<double> rawData = ServiceAdapter.instance()?.getData(id)?? [];//[];
    exchanger.put(rawData);
  }

  void outFun(List<double> list) {
    print ('Put Data ->$list');
  }

  bool isActive() {
    return _timer != null && _timer!.isActive;
  }

}