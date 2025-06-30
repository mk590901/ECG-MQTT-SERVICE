import 'dart:collection';
import '../callback_fun_type.dart';
import 'circular_buffer.dart';
import 'message_handler.dart';

class DataExchanger {
  late  CircularBuffer<double> buffer_;
  final int _bufferLength;
  final Queue<List<double>>	_dataQueue	= Queue<List<double>>();
  final Queue<int>	_sizeQueue	= Queue<int>();
  final MessageHandler handler = MessageHandler<VoidCallback?>();
  final ListCallback? callback;

  DataExchanger(this._bufferLength, this.callback) {
    buffer_ = CircularBuffer<double>(_bufferLength + 1);
    handler.messages.listen((callback) {
      callback?.call();
    });
  }

  CircularBuffer<double> buffer() {
    return buffer_;
  }

  void write(List<double> rawData) {
    if (rawData.isEmpty) {
      return;
    }
    buffer_.writeRaw(rawData);
  }

  void put(List<double> rawData) {
    _dataQueue.add(rawData);
    handler.sendMessage(putData);
  }

  void get(int orderedSize) {
    _sizeQueue.add(orderedSize);
    handler.sendMessage(getData);
  }

  List<double>  read(int orderedSize) {
    if (orderedSize <= 0) {
      return [];
    }
    return buffer_.readRaw(orderedSize);
  }

  void dispose() {
    handler.dispose();
  }

  void putData() {
    if (_dataQueue.isEmpty) {
      return;
    }
    List<double> data = _dataQueue.removeFirst();
    write(data);
  }

  void getData() {
    if (_sizeQueue.isEmpty) {
      return;
    }

    int orderedSize = _sizeQueue.removeFirst();
    List<double>  out = read(orderedSize);
    callback?.call(out);

  }

}
