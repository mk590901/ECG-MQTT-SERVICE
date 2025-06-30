// --- Items BLoC (control elements list) ---
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../gui_adapter/service_adapter.dart';
import '../widget/graph_mode.dart';
import '../widget/graph_widget.dart';
import 'item_model.dart';

abstract class ItemsEvent {}

class AddItemEvent extends ItemsEvent {
  final String id;
  final String name;
  final int? length;
  late GraphWidget graphWidget;

  AddItemEvent(this.id, this.name, this.length,) {
    graphWidget = GraphWidget(
        uuid: id,
        samplesNumber: length?? 128,
        width: 340,
        height: 100,
        mode: GraphMode.flowing,);
  }
}

class RemoveItemEvent extends ItemsEvent {
  final String id;

  RemoveItemEvent(this.id, );
}

class ClearItemsEvent extends ItemsEvent {}

class ItemsState {
  final List<Item> items;

  ItemsState({required this.items});

  ItemsState copyWith({List<Item>? items}) {
    return ItemsState(items: items ?? this.items);
  }
}

class ItemsBloc extends Bloc<ItemsEvent, ItemsState> {
  ItemsBloc() : super(ItemsState(items: [])) {

    ServiceAdapter.instance()?.setItemsBloc(this);

    on<AddItemEvent>((event, emit) {

      final newItem = Item(id: event.id,
        title: "ECG [${event.id.substring(0, 8)}][${event.name}]",
        subtitle: "Sample rate is ${event.length} points/s",
        graphWidget: event.graphWidget,
      );

      ServiceAdapter.instance()?.create(event.id, event.name, event.length);  //  Create in app

      emit(state.copyWith(items: [...state.items, newItem]));
    });


    on<RemoveItemEvent>((event, emit) {

      print('RemoveItemEvent.id=${event.id}');

      ServiceAdapter.instance()?.remove(event.id); //  From app

      emit(state.copyWith(
        items: state.items.where((item) => item.id != event.id).toList(),
      ));
    });

    on<ClearItemsEvent>((event, emit) {
      emit(state.copyWith(items: []));
    });
  }

}
