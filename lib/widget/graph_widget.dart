import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data_collection/obtained.dart';
import '../states/drawing_state.dart';
import '../data_collection/ecg_wrapper.dart';
import 'drawing_bloc.dart';
import 'graph_mode.dart';
import 'path_painter.dart';

class GraphWidget extends StatelessWidget {
  static const int FREQ = 24; // frames-per-seconds
  final int PERIOD = 1000; // 1s = 1000ms

  final int samplesNumber;
  final double width;
  final double height;
  final GraphMode mode;
  final String uuid;

  late ECGWrapper ecgWrapper;

  final Obtained obtain = Obtained.part(const Duration(milliseconds: FREQ));

  GraphWidget(
      {super.key,
      required this.uuid,
      required this.samplesNumber,
      required this.width,
      required this.height,
      required this.mode,
      }) {
    int pointsToDraw =
        (samplesNumber.toDouble() / (PERIOD.toDouble() / FREQ.toDouble())).toInt() + 1;
    ecgWrapper = ECGWrapper(uuid, samplesNumber, 5, pointsToDraw, mode);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      postBuildAction();
    });

  }

  void postBuildAction() {
    print('GraphWidget has been built!');
    if (!isStarted()) {
      start();
    }
  }

  bool isStarted() {
    return obtain.isActive();
  }

  void start() {
    ecgWrapper.start();
    obtain.start(uuid);
  }

  void stop() {
    obtain.stop(uuid);
    ecgWrapper.stop();
  }

  void onChangeMode() {
    ecgWrapper.setMode(isFlowing() ? GraphMode.overlay : GraphMode.flowing);
  }

  bool isFlowing() {
    return ecgWrapper.mode() == GraphMode.flowing;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DrawingBloc>(
      create: (_) => DrawingBloc(DrawingState(DrawingStates.drawing)),
      child: GestureDetector(
        onTap: () {
          onChangeMode();
        },
        child:
            BlocBuilder<DrawingBloc, DrawingState>(builder: (context, state) {
          obtain.set(ecgWrapper.drawingFrequency(), context);
          ecgWrapper.updateBuffer(state.counter());
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: width,
                height: height,
                child: CustomPaint(
                  painter: PathPainter.graph(state.counter(), ecgWrapper),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  void dispose() {
    obtain.stop(uuid);
    ecgWrapper.stop();
  }
}
