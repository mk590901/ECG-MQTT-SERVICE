import 'dart:async';
import 'package:synchronized/synchronized.dart';

import '../ui_blocks/app_bloc.dart';
import '../ui_blocks/item_model.dart';
import '../ui_blocks/items_bloc.dart';
import '../ui_blocks/mqtt_bloc.dart';
import 'simulator_wrapper.dart';

class ServiceAdapter {
  static ServiceAdapter? _instance;

  final Map<String,SimulatorWrapper> container = {};

  final Lock _lock = Lock();

  late AppBloc? _appBloc;
  late ItemsBloc? _itemsBloc;
  late MqttBloc? _mqttBloc;

  static int PERIOD = 1000;
  static int DELETE_DELAY = 4000;
  static int STOP_DELAY = 2000;

  final Duration _period = Duration(milliseconds: PERIOD);
  late Timer? _cleanupTimer = null;

  late String _deviceName = '';

  static void initInstance() {
    _instance ??= ServiceAdapter();
    print ('ServiceAdapter.initInstance -- Ok');
  }

  static ServiceAdapter? instance() {
    if (_instance == null) {
      throw Exception("--- ServiceAdapter was not initialized ---");
    }
    return _instance;
  }

  void setDeviceName(String deviceName) {
    _deviceName = deviceName;
    print ('PHONE->[$_deviceName]');
  }

  String getDeviceName() {
    return _deviceName;
  }

  String? add() { // Only for tests

      SimulatorWrapper wrapper = SimulatorWrapper();
      _lock.synchronized(() {
        container[wrapper.id()] = wrapper;
      });

      print ('*** ServiceAdapter.add [${wrapper.id()}]');

      if (size() == 1) {
        start();
      }
      return wrapper.id();
  }

  void create(String id, String name, int? length){

    SimulatorWrapper wrapper = SimulatorWrapper.part(id, name, length?? 128);
    _lock.synchronized(() {
      container[wrapper.id()] = wrapper;
    });

    print ('*** ServiceAdapter.create [${wrapper.id()}]');

    if (container.length == 1) {
      _startCleanupTimer();
    }


  }

  void remove(String? id) {

    _lock.synchronized(() {
      if (container.containsKey(id)) {
        container.remove(id);
      }
    });

    print ('*** ServiceAdapter.remove [$id]');

    if (container.isEmpty) {
      _stopCleanupTimer();
    }

  }

  void removeItems() {
    _lock.synchronized(() {
      container.clear();
    });
    if (container.isEmpty) {
      _stopCleanupTimer();
    }

  }

  void stopTimer() {
    _stopCleanupTimer();
  }


  void markPresence(String? id, bool presence) {
    _lock.synchronized(() {
      if (container.containsKey(id)) {
        container[id]?.setItemPresence(false);
      }
    });

    print ('*** ServiceAdapter.markPresence [$id:$presence]');
  }

  SimulatorWrapper? get(String? id) {
    SimulatorWrapper? result;
    _lock.synchronized(() {
      if (container.containsKey(id)) {
        result = container[id];
      }
    });
    return result;
  }

  List<double> getData(String id) {
    List<double> result = [];
    SimulatorWrapper? wrapper = get(id);
    if (wrapper == null) {
      return result;
    }
    result = wrapper.getData();

    return result;
  }

  int size() {
    return container.length;
  }

  void setItemsBloc(ItemsBloc? itemsBloc) {
    _itemsBloc = itemsBloc;
  }

  void setAppBloc(AppBloc? appBloc) {
    _appBloc = appBloc;
  }

  void setMQTTBloc(MqttBloc? mqttBloc) {
    _mqttBloc = mqttBloc;
  }

  void mqttConnect() {
    _mqttBloc?.add(MqttEvent.connect);
  }

  void mqttSubscribe() {
    _mqttBloc?.add(MqttEvent.subscribe);
  }

  void mqttUnsubscribe() {
    _mqttBloc?.add(MqttEvent.unsubscribe);
  }

  void mqttDisconnect() {
    _mqttBloc?.add(MqttEvent.disconnect);
  }

  void start() {

    if (container.isEmpty) {
      return;
    }
    print ('------- ServiceMock.start -------');

  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _cleanupOldItems();
    });
    print ('******* _startCleanupTimer *******');
  }

  void _stopCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    print ('******* _stopCleanupTimer *******');
  }

  void _cleanupOldItems() {

    print ('------- _cleanupOldItems -------');

    final now = DateTime.now();
    final List<String> itemsToRemove = [];

    // We divide the elements into those that will remain and those that will be deleted
    container.forEach((key, value) {
      int diff = now.difference(value.updatedTime()).inMilliseconds;
      print ('[$key] [$diff]');
      if (diff > ServiceAdapter.STOP_DELAY) {
        stopRendering(key);
      }
      if (diff > DELETE_DELAY) {
         itemsToRemove.add(key);
      }
    });

    // No changes
    if (itemsToRemove.isEmpty) {
      return;
    }

    // Call preparation for each element to be removed.
    for (final itemId in itemsToRemove) {
      print ('PREPARE [$itemId]');
      _itemsBloc?.add(RemoveItemEvent(itemId));
      _appBloc?.add(SendData('delete_object', itemId));
    }
    print ('+++++++ _cleanupOldItems +++++++');
  }

  void updateRawData(String id, List<double> rawData) {
    SimulatorWrapper? wrapper = get(id);
    if (wrapper == null) {
      print ('Failed to update [$id]');
      return;
    }
    wrapper.putData(rawData);
    print ('SimulatorWrapper [$id] was updated');

  }

  void destroyObject(String id) {
    print ('******* ServiceAdapter.DestroyObject [$id] *******');
    _itemsBloc?.add(RemoveItemEvent(id));
    _appBloc?.add(SendData('delete_object', id));
  }

  void stop() {

    print ('------- callbackFunction.stop -------');

    _stopCleanupTimer();

    _itemsBloc?.add(ClearItemsEvent());

  }

  void dispose(String key) {
    print ('- ServiceMock.dispose($key) -');
    Item? item = getItem(key);
    item?.graphWidget.stop();
    print ('+ ServiceMock.dispose($key) +');

  }

  void createGuiItemIfNeed(String key) {
    if (_itemsBloc == null) {
      return;
    }
    if (itemsListContains(key)) {
      return;
    }
    SimulatorWrapper? wrapper = get(key);
    if (wrapper == null) {
      return;
    }
    wrapper.setItemPresence(true);
    _itemsBloc?.add(AddItemEvent(key, wrapper.name(), wrapper.length()));
  }

  void createGuiItem(String key, String name, int length) {

    print ('ServiceMock.createGuiItem [$key:$name:$length]');

    if (_itemsBloc == null) {
      return;
    }
    if (itemsListContains(key)) {
      return;
    }
    _itemsBloc?.add(AddItemEvent(key, name, length));
  }

  bool itemsListContains(String key) {
    bool result = false;

    if (_itemsBloc == null) {
      return result;
    }

    List<Item>? items = _itemsBloc?.state.items;
    if (items == null) {
      return result;
    }

    int size = items.length;
    if (size ==  0) {
      return result;
    }

    for (int i = 0; i < size; i++) {
      Item item = items[i];
      if (item.id == key) {
        result = true;
        break;
      }
    }
    return result;
  }

  Item? getItem(String key) {
    Item? result;

    if (_itemsBloc == null) {
      return result;
    }

    List<Item>? items = _itemsBloc?.state.items;
    if (items == null) {
      return result;
    }

    int size = items.length;
    if (size ==  0) {
      return result;
    }

    for (int i = 0; i < size; i++) {
      Item item = items[i];
      if (item.id == key) {
        result = item;
        break;
      }
    }
    return result;
  }


  void stopRendering(String key) {
    Item? item = getItem(key);
    item?.graphWidget.stop();
  }

  void setProgress(bool progress) {
    _mqttBloc?.add(InProgressEvent(progress));
    print ('******* setProgress $progress ******* ${DateTime.now()}');
  }
}
