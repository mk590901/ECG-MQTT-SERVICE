import 'dart:convert';
import 'dart:typed_data';

class DataPacket {
  late String        sensorId = '';
  late String        sensorName = '';
  late int           seriesLength = 0;
  late List<double>  rawData = [];

  DataPacket(this.sensorId, this.sensorName, this.seriesLength, this.rawData);
  DataPacket.empty();

  String encode() {
    String rawDataBase64 = base64encode(rawData);
    Map<String, dynamic> packetMetadata = {
      'sensor_id'     : sensorId,
      'sensor_name'   : sensorName,
      'series_length' : seriesLength,
      'raw_data'      : rawDataBase64,
    };
    String result = jsonEncode(packetMetadata);
    return result;
  }

  DataPacket decode(String jsonString) {
    Map<String, dynamic> metadata = jsonDecode(jsonString);
    String sensorId   = metadata['sensor_id'];
    String sensorName = metadata['sensor_name'];
    int seriesLength  = metadata['series_length'];
    List<double> rawData = base64decode(metadata['raw_data'] as String);
    return DataPacket(sensorId, sensorName, seriesLength, rawData);
  }

  String base64encode(List<double> rawData) {
    // Convert List<double> to Float64List
    final Float64List floatList = Float64List.fromList(rawData);
    // Get bytes from Float64List
    final Uint8List bytes = floatList.buffer.asUint8List();
    // Encode bytes to base64 string
    return base64Encode(bytes);
  }

  List<double> base64decode(String base64string) {
    // Decode base64 string to bytes
    final Uint8List bytes = base64Decode(base64string);
    // Convert bytes to Float64List
    final Float64List floatList = Float64List.fromList(
        Uint8List.fromList(bytes).buffer.asFloat64List().toList()
    );
    // Return as List<double>
    return floatList.toList();
  }

}