// Home page
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../gui_adapter/service_adapter.dart';
import '../ui_blocks/app_bloc.dart';
import '../ui_blocks/items_bloc.dart';
import '../ui_blocks/mqtt_bloc.dart';
import '../utils.dart';
import 'card_view.dart';
import 'control_panel.dart';
import 'mqtt_panel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    return PopScope(
      canPop: false, // Disable the default behavior of the "back" button
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // If pop has already been executed, do nothing
        // Show the dialog box
        final result = await showAppExitDialog(context);

        // Processing user selection
        await reaction(result, context);
        // For 'ignore' we do nothing, the dialog just closes
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ECG Service App',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              CupertinoIcons.heart_solid,
              color: Colors.white,
            ), // Icon widget
            onPressed: () {
              // Add onPressed logic here if need
            },
          ),
          backgroundColor: Colors.lightBlue,
        ),

        body: Column(
          children: [
            const ControlPanel(),
            const MQTTPanel(),
            Expanded(
              child: BlocConsumer<ItemsBloc, ItemsState>(
                listener: (context, state) {
                  if (state.items.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      scrollController.animateTo(
                        scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    });
                  }
                },
                builder: (context, state) {
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.horizontal,
                        onDismissed: (direction) {
                          ServiceAdapter.instance()?.dispose(item.id);
                          context.read<ItemsBloc>().add(
                            RemoveItemEvent(
                              item.id,
                              // item.graphWidget,
                              // direction,
                            ),
                          );
                          if (direction == DismissDirection.endToStart) {
                            context.read<AppBloc>().add(
                              SendData('delete_object', item.id),
                            );
                          } else {
                            context.read<AppBloc>().add(
                              SendData('mark_object_unused', item.id),
                            );
                          }
                        },
                        //  Swipe left->right
                        background: Container(
                          color: Colors.blueGrey.shade200,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        //  Swipe right->left
                        secondaryBackground: Container(
                          color: Colors.deepPurple.shade200,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 16),
                          child: const Icon(
                            Icons.delete_forever,
                            color: Colors.white,
                          ),
                        ),
                        child: CardView(item: item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (context.read<AppBloc>().state.isRunning) {
              if (context.read<MqttBloc>().state.isConnected
              &&  context.read<MqttBloc>().state.isSubscribed) {
                context.read<AppBloc>().add(SendData('create_object', ''));
              }
              else {
                showToast(context, "MQTT problems");
              }
            }
            else {
              showToast(context, "Service isn't run");
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<String?> showAppExitDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Application exit',
          style: TextStyle(fontSize: 16, color: Colors.blueAccent),
        ),
        content: Text(
          'Choose one of app exit option:\n\t - Ignore: stay in application\n\t - Close: exit leaving service\n\t - Exit: stop service and exit',
          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
        ),
        actions: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'ignore'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(40, 36),
                      textStyle: TextStyle(fontSize: 10),
                    ),
                    child: Text('Ignore'),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'close'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(40, 36),
                      textStyle: TextStyle(fontSize: 10),
                    ),
                    child: Text('Close'),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'exit'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(20, 36),
                      textStyle: TextStyle(fontSize: 10),
                    ),
                    child: Text('Exit'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> reaction(String? result, BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    if (result == 'close') {
      await SystemNavigator.pop();
    } else if (result == 'exit') {
      if (context.mounted) {
        context.read<AppBloc>().add(StopService());
      }
      await SystemNavigator.pop();
    }
  }
}
