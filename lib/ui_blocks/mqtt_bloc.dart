import 'package:flutter_bloc/flutter_bloc.dart';
import '../gui_adapter/service_adapter.dart';

// Events
enum MqttEvent { connect, subscribe, unsubscribe, disconnect }

class InProgressEvent {
  final bool inProgress;
  InProgressEvent(this.inProgress);
}

// States
class MqttState {
  final bool isConnected;
  final bool isSubscribed;
  final bool inProgress;

  MqttState({
    required this.isConnected,
    required this.isSubscribed,
    required this.inProgress,
  });

  MqttState copyWith({
    bool? isConnected,
    bool? isSubscribed,
    bool? inProgress,
  }) {
    return MqttState(
      isConnected: isConnected ?? this.isConnected,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      inProgress: inProgress ?? this.inProgress,
    );
  }
}

class MqttBloc extends Bloc<dynamic, MqttState> {
  MqttBloc() : super(MqttState(isConnected: false, isSubscribed: false, inProgress: false)) {
    ServiceAdapter.instance()?.setMQTTBloc(this);

    on<MqttEvent>((event, emit) {
      switch (event) {
        case MqttEvent.connect:
          if (!state.isConnected) {
            emit(state.copyWith(isConnected: true, inProgress: true));
          }
          break;
        case MqttEvent.subscribe:
          if (state.isConnected && !state.isSubscribed) {
            emit(state.copyWith(isSubscribed: true, inProgress: true));
          }
          break;
        case MqttEvent.unsubscribe:
          if (state.isSubscribed) {
            emit(state.copyWith(isSubscribed: false, inProgress: false));
          }
          break;
        case MqttEvent.disconnect:
          emit(state.copyWith(isConnected: false, isSubscribed: false, inProgress: false));
          break;
      }
    });

    on<InProgressEvent>((event, emit) {
      emit(state.copyWith(inProgress: event.inProgress));
    });
  }
}
