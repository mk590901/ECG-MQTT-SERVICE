// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:gui_model/data_packet.dart';
import 'package:gui_model/gui_adapter/service_adapter.dart';

void main() {

  ServiceAdapter.initInstance();

  String? one = '';
  String? two = '';

  test('Service gui_adapter creation', () {
    expect(0, ServiceAdapter.instance()?.size());
  });

  test('Service gui_adapter add', () {
    one = ServiceAdapter.instance()?.add();
    expect(1, ServiceAdapter.instance()?.size());

  });

  test('Service gui_adapter add', () {
    two = ServiceAdapter.instance()?.add();
    expect(2, ServiceAdapter.instance()?.size());
  });

  test('Service gui_adapter remove', () {
    ServiceAdapter.instance()?.remove(one);
    expect(1, ServiceAdapter.instance()?.size());
    ServiceAdapter.instance()?.remove(two);
    expect(0, ServiceAdapter.instance()?.size());
  });

  test('DataPacket', () {
    DataPacket sourceDataPacket = DataPacket('Id', 'Name', 5, [1.1, 1.2, 1.3, 1.4, 1.5]);
    String jsonString = sourceDataPacket.encode();
    print ('jsonString->$jsonString');
    DataPacket targetDataPacket = DataPacket.empty().decode(jsonString);
    expect('Id', targetDataPacket.sensorId);
    expect('Name', targetDataPacket.sensorName);
    expect(5, targetDataPacket.seriesLength);
    expect( [1.1, 1.2, 1.3, 1.4, 1.5], targetDataPacket.rawData);
  });

}


