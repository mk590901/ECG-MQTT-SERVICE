import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'gui_adapter/service_adapter.dart';
import 'service_components/foreground_service.dart';
import 'ui_blocks/app_bloc.dart';
import 'ui_blocks/items_bloc.dart';
import 'ui_blocks/mqtt_bloc.dart';
import 'ui_components/home_page.dart';

void main() async {
  ServiceAdapter.initInstance();
  WidgetsFlutterBinding.ensureInitialized();
  await initializeForegroundService();
  await detectDeviceName();
  runApp(const FrontendApp());
}

Future<void> detectDeviceName() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    ServiceAdapter.instance()?.setDeviceName('${androidInfo.brand} ${androidInfo.model}');
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    ServiceAdapter.instance()?.setDeviceName('${iosInfo.name} (${iosInfo.model})');
  }

}

// App class
class FrontendApp extends StatelessWidget {
  const FrontendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AppBloc()),
        BlocProvider(create: (context) => ItemsBloc()),
        BlocProvider(create: (context) => MqttBloc()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
