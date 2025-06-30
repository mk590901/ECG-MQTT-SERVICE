import 'ecg_generator.dart';
import 'ecg_log.dart';
import 'ecg_param.dart';

// Source: A separate Java version of ECGSYN is available from the MIT website at Java ECG Generator,
// where the source code can be downloaded.

class EcgSimulator {
  final EcgLogWindow log = EcgLogWindow();
  final EcgParam  param = EcgParam();
  final int samplingFrequency;
  late ECGGenerator generator;

  EcgSimulator(this.samplingFrequency) {
    setSamplingFrequency(samplingFrequency);
    generator = ECGGenerator(param: param, log: log);
  }

  List<int> generateBuffer() {
    List<int> buffer = [];
    var [time, voltage, peak] = generator.generateBuffer(samplingFrequency);
    for (int j = 0; j < time.length; j++) {
      double doubleValue = voltage[j] as double;
      int intValue = (doubleValue * 1000).toInt();
      buffer.add(intValue);
    }
    return buffer;
  }

  List<double> generateECGData() {
    List<double> buffer = [];
    var [time, voltage, peak] = generator.generateBuffer(samplingFrequency);
    for (int j = 0; j < time.length; j++) {
      buffer.add(voltage[j] as double);
    }
    return buffer;
  }

  void setSamplingFrequency(int value) {
    param.setSfEcg(value);
    param.setSf(value*2);
  }
}
