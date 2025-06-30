import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

//import '../data_collection/data_holder.dart';
import '../data_collection/message_handler.dart';
import '../data_collection/pair_data_object.dart';
import '../data_packet.dart';
import '../ecg_simulator/ecg_simulator.dart';
import '../gui_adapter/simulator_wrapper.dart';

// Initialize the foreground service
Future<void> initializeForegroundService() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'foreground_service',
      channelName: 'Foreground Service Notification',
      channelDescription: 'This notification appears when the foreground service is running.',
      channelImportance: NotificationChannelImportance.DEFAULT,
      priority: NotificationPriority.DEFAULT,
      enableVibration: false,
      playSound: false,
      showWhen: false,
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 1000, // Run every 1 second
      autoRunOnBoot: false,
      allowWifiLock: true,
    ),
  );
}

// Task handler for the foreground service
class ServiceTaskHandler extends TaskHandler {

  final Map<String,SimulatorWrapper> container = {};

  int counter = 0;

//  MQTT /////////////////////////////////////////////////////////////////
  MqttServerClient? client;

  late String _deviceId = '';

/*
HiveMQ: _server = 'broker.hivemq.com'; _port = 1883;
Mosquitto: _server = 'test.mosquitto.org'; _port = 1883;
MQTTHQ: _server = 'public.mqtthq.com'; _port = 1883;
Flespi: _server = 'mqtt.flespi.io'; _port = 1883;
EMQX: _server = 'broker.emqx.io'
 */

  //static final String _server = 'test.mosquitto.org';
  static final String _server = 'broker.hivemq.com';
  //static final String _server = 'public.mqtthq.com';
  //static final String _server = 'mqtt.flespi.io';
  //static final String _server = 'broker.emqx.io';
  static final String _flutterClient = 'flutter_client_${const Uuid().v4()}';
  static final String _topic = 'hsm_v2/topic';

  final Queue<Map>	queue	= Queue<Map>();
  final List<String> deletedObjectsList = [];

  Timer? _reconnectTimer;
  bool _serviceStopped = true;

  SendPort? _sendPort;

//  MQTT /////////////////////////////////////////////////////////////////

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) async {
    print('Foreground service started');
    _serviceStopped = false;
    _sendPort = sendPort;
    await initializeMqttClient(sendPort);
  }

  Future<void> initializeMqttClient(SendPort? sendPort) async {
    // Send initial data
    sendPort?.send({
      'response': 'progress',
      'value': true,
    });

    sendPort?.send({
      'response': 'counter',
      'value': counter,
    });

    client = MqttServerClient(_server, _flutterClient);

    client?.logging(on: false); //  true
    client?.setProtocolV311();
    client?.connectTimeoutPeriod = 2000;
    client?.keepAlivePeriod = 20;
    client?.onDisconnected = onDisconnected;
    client?.onConnected = onConnected;
    client?.onSubscribed = onSubscribed;
    client?.onUnsubscribed = onUnsubscribed;
    client?.autoReconnect = false;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_flutterClient)
        .startClean();
    client?.connectionMessage = connMess;

    try {
      await client?.connect();
    } catch (e) {
      print('Connection failed: $e');
      client?.disconnect();
      sendPort?.send({
        'response': 'progress',
        'value': false,
      });
      scheduleReconnect();
    }

    // Subscribe to topic
    if (client?.connectionStatus!.state == MqttConnectionState.connected) {
      client?.subscribe(_topic, MqttQos.atLeastOnce);
      client?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMessage = c[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
            recMessage.payload.message);
        String message = payload;
        //print('Received message: $payload from topic: ${c[0].topic}');
        if (!isDataFromDeletedObject(message)) {
          queue.add({'response': 'sync', 'value': message,});
        }
      });
    }
  }

  void scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      print('******* Attempting to reconnect... *******');
      await initializeMqttClient(_sendPort);
    });
  }

  void onConnected() {
    print('******* onConnected: onConnectedConnected to MQTT broker  $_server *******');
    queue.add({'response': 'Connected', 'value': 'Connected to MQTT broker $_server',});
  }

  void onDisconnected() {
    print('******* onDisconnected: Disconnected from MQTT broker $_server *******');
    queue.add({'response': 'Disconnected', 'value': 'Disconnected from MQTT broker $_server',});
    queue.add({'response': 'progress', 'value': false });
    if (_serviceStopped) {
      return;
    }
    scheduleReconnect();
  }

  void onSubscribed(String topic) {
    print('******* onSubscribed to topic: $topic *******');
    queue.add({'response': 'Subscribed', 'value': 'Subscribed to topic: $topic'});
    //queue.add({'response': 'progress', 'value': false });
  }

  void onUnsubscribed(String? topic) {
    print('***!*** onUnsubscribed from topic: $topic ***!***');
    queue.add({'response': 'Unsubscribed', 'value': 'Unsubscribed from topic: $topic'});
    client?.disconnect();
    scheduleReconnect();
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {

    _sendPort = sendPort;

    counter++;
    // Update notification
    await FlutterForegroundTask.updateService(
      foregroundTaskOptions: const ForegroundTaskOptions(interval: 1000,),
      notificationTitle: 'Foreground Service',
      notificationText: '${DateTime.now()}\ncounter: $counter',
    );

    // Send data to app
    sendPort?.send({
      'response': 'counter',
      'value': counter,
    });

    sendPort?.send({
      'response': 'mqtt',
      'value':  {'connected': isConnected(), 'subscribed': isSubscribed() },
    });

    while (queue.isNotEmpty) {
      Map message = queue.removeFirst();
      sendPort?.send(message);
    }

    if (isConnected() && isSubscribed()) {
      queue.add({'response': 'progress', 'value': false });
    }

    if (size() == 0) {
      print ('size = 0');
      return;
    }

    container.forEach((key, value) {
      createSimulatorIfNeed(key);
    });

  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) async {
    print('Foreground service stopped');
    _serviceStopped = true;
    client?.disconnect();
    sendPort?.send({
      'response': 'progress',
      'value': false,
    });

  }

  @override
  void onNotificationButtonPressed(String id) {
    print('Notification button pressed: $id');
  }

  @override
  void onNotificationPressed() {
    print('Notification pressed');
  }

  // Handle data sent from the app
  @override
  void onReceiveData (dynamic data) {
    print('onDataReceived called with data: $data');
    if (data is Map && data.containsKey('command') &&  data.containsKey('data')) {
      final String command = data['command'] as String;
      final String receivedData = data['data'] as String;
      print('Service received: $command:($receivedData)');

      if (command == 'phone_id') {
        _deviceId = receivedData;
        print ('DEVICE->$_deviceId');
      }
      if (command == 'create_object') {
        Pair pair = add();
        String id = pair.uuid();
        int length = pair.counter();
        // Send data to app
        print ('Send data to app -> [created] [$id][$length]');
      }
      else
      if (command == 'delete_object') {
        String id = receivedData;
        print ('delete_object -> [$id]');
        remove(id);
      }
      else
      if (command == 'mark_object_unused') {
        String id = receivedData;
        print ('mark_object_unused -> [$id]');
        markUnused(id);
      }
      else
      if (command == 'mark_object_used') {
        String id = receivedData;
        print ('mark_object_used -> [$id]');
        markUsed(id);
      }
    } else {
      print('Invalid data format: $data');
    }
  }
////////////////////////////////////////////////////////////////////////////////
  int size() {
    return container.length;
  }

  Pair add() {
    SimulatorWrapper wrapper = SimulatorWrapper();
    container[wrapper.id()] = wrapper;
    return Pair(wrapper.id(),wrapper.length());
  }

  void remove(String? id) {
    if (container.containsKey(id)) {
      container.remove(id);
    }
    print ('remove, size->[${size()}]');
    deletedObjectsList.add(id?? '');

  }

  void markUnused(String? id,) {
    if (container.containsKey(id)) {
      container[id]?.setItemPresence(false);
    }
    print ('markUnused, size->[${size()}]');
  }

  void markUsed(String? id,) {
    if (container.containsKey(id)) {
      container[id]?.setItemPresence(true);
    }
    print ('markUsed, size->[${size()}]');
  }

  bool isSubscribed() {
    if (!isConnected()) {
      return false;
    }
    MqttSubscriptionStatus? status = client?.getSubscriptionsStatus(_topic);
    if (status == null) {
      return false;
    }
    bool result =  (status == MqttSubscriptionStatus.active) ? true : false;
    return result;
  }

  bool isConnected() {
    return (client?.connectionStatus?.state == MqttConnectionState.connected) ? true : false;
  }

  void createSimulatorIfNeed(String key/*, int ms*/) {
    SimulatorWrapper? wrapper = get(key);
    if (wrapper == null) {
      return;
    }

    if (wrapper.presence()) {
      wrapper.setItemPresence(true);
    }

    if (client?.connectionStatus?.state == MqttConnectionState.disconnecting
    ||  client?.connectionStatus?.state == MqttConnectionState.disconnected) {
      print("Client isn't connected");
      return;
    }

    if (!isSubscribed()) {
      print("Client isn't subscribed");
      return;
    }

    List<double> rawData = wrapper.generateRawData(); //  Generate ECG signal
    DataPacket sourceDataPacket = DataPacket(wrapper.id(), _deviceId, wrapper.length(), rawData);
    String jsonString = sourceDataPacket.encode();

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonString);
    try {
      client?.publishMessage(_topic, MqttQos.atMostOnce, builder.payload!);
    }
    catch (exception) {
      print ('Publish - error');
    }
  }

  SimulatorWrapper? get(String? id) {
    SimulatorWrapper? result;
    if (container.containsKey(id)) {
      result = container[id];
    }
    return result;
  }

  bool isDataFromDeletedObject(String dataPacket) {
    DataPacket targetDataPacket = DataPacket.empty().decode(dataPacket);
    String id = targetDataPacket.sensorId;
    bool result = false;
    if (deletedObjectsList.contains(id)) {
      result = true;
    }
    return result;
  }

}

// Entry point for the foreground task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ServiceTaskHandler());
}
