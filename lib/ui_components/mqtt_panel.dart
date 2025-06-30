import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ui_blocks/mqtt_bloc.dart';

// MQTTPanel StatelessWidget
class MQTTPanel extends StatelessWidget {
  const MQTTPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MqttBloc, MqttState>(
      builder: (context, state) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2,
                color: state.inProgress ? Colors.blue : Colors.transparent,
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.circle_sharp, // Placeholder for connected icon
              color: state.isConnected ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.circle_sharp, // Placeholder for subscribed icon
              color: state.isSubscribed ? Colors.green : Colors.red,
              size: 32,
            ),
          ],
        );
      },
    );
  }
}
