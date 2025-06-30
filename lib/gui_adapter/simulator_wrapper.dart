//import 'dart:math';
import 'package:uuid/uuid.dart';

import '../ecg_simulator/ecg_simulator.dart';
import '../utils.dart';

class SimulatorWrapper {
  late String _id;
  late String _name;
  late int _seriesLength;

  late List<double> rawData = [];

  late EcgSimulator _ecgSimulator;
  late bool _itemPresence = true;
  late DateTime _updateTime = DateTime.now();

  SimulatorWrapper() {  //  For service
    _id = const Uuid().v4().toString();
    _seriesLength = getSeriesLength();
    _ecgSimulator = EcgSimulator(_seriesLength);
  }

  SimulatorWrapper.part(this._id, this._name, this._seriesLength);  //  For app

  String id() {
    return _id;
  }

  bool presence() {
    return _itemPresence;
  }

  int length() {
    return _seriesLength;
  }

  String name() {
    return _name;
  }

  List<double> generateRawData() {
    return _ecgSimulator.generateECGData();
  }

  void setItemPresence(bool presence) {
    _itemPresence = presence;
  }

  List<double> getData() {
    return rawData;
  }

  void putData(List<double> data) {
    _updateTime = DateTime.now();
    rawData = data;
  }

  DateTime updatedTime() {
    return _updateTime;
  }

  void updateTime() {
    _updateTime = DateTime.now();
    print('[$hashCode] updateTime->[$_updateTime]');
  }

}
