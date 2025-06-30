import 'package:flutter_bloc/flutter_bloc.dart';
import '../gui_adapter/service_adapter.dart';

// События
enum MqttEvent { connect, subscribe, unsubscribe, disconnect }

class InProgressEvent {
  final bool inProgress;
  InProgressEvent(this.inProgress);
}

// Состояния
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
            // Завершение connect (здесь предполагается, что ServiceAdapter уведомит о завершении)
          }
          break;
        case MqttEvent.subscribe:
          if (state.isConnected && !state.isSubscribed) {
            emit(state.copyWith(isSubscribed: true, inProgress: true));
            // Завершение subscribe (управляется через ServiceAdapter или InProgressEvent)
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


/*
import 'package:flutter_bloc/flutter_bloc.dart';

import '../gui_adapter/service_adapter.dart';

// MqttBloc
enum MqttEvent { connect, subscribe, unsubscribe, disconnect }

class MqttState {
  final bool isConnected;
  final bool isSubscribed;

  MqttState({required this.isConnected, required this.isSubscribed});

  MqttState copyWith({bool? isConnected, bool? isSubscribed}) {
    return MqttState(
      isConnected: isConnected ?? this.isConnected,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }
}

class MqttBloc extends Bloc<MqttEvent, MqttState> {
  MqttBloc() : super(MqttState(isConnected: false, isSubscribed: false)) {

    ServiceAdapter.instance()?.setMQTTBloc(this);

    on<MqttEvent>((event, emit) {
      switch (event) {
        case MqttEvent.connect:
          if (!state.isConnected) {
            emit(state.copyWith(isConnected: true));
          }
          break;
        case MqttEvent.subscribe:
          if (state.isConnected && !state.isSubscribed) {
            emit(state.copyWith(isSubscribed: true));
          }
          break;
        case MqttEvent.unsubscribe:
          if (state.isSubscribed) {
            emit(state.copyWith(isSubscribed: false));
          }
          break;
        case MqttEvent.disconnect:
          emit(state.copyWith(isConnected: false, isSubscribed: false));
          break;
      }
    });
  }
}

 */
