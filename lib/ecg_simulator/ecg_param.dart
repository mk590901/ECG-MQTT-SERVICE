import 'dart:math';

class EcgParam {
  double _hrMean = 60.0; // Mean heart rate (beats/min)
  double _hrStd = 1.0; // Heart rate standard deviation
  double _lfHfRatio = 0.5; // LF/HF ratio
  int _sfEcg = 256; // ECG sampling frequency (Hz)
  int _sf = 512; // Internal sampling frequency (Hz)
  double _aNoise = 0.04; // Noise amplitude (mV)
  double _fLo = 0.1; // Low frequency (Hz)
  double _fHi = 0.25; // High frequency (Hz)
  double _fLoStd = 0.01; // Low frequency std
  double _fHiStd = 0.01; // High frequency std
  int _n = 1000; // Approximate number of heart beats
  int _seed = -1; // Random seed
  int _ecgAnimateInterval = 1000; // Animation interval (ms)
  final List<double> _theta = List.filled(6, 0.0); // PQRST angles (degrees)
  final List<double> _a = List.filled(6, 0.0); // PQRST amplitudes (mV)
  final List<double> _b = List.filled(6, 0.0); // PQRST widths

  EcgParam() {
    // Default PQRST parameters (P, Q, R, S, T)
    _theta[1] = -70.0;
    _theta[2] = -15.0;
    _theta[3] = 0.0;
    _theta[4] = 15.0;
    _theta[5] = 100.0;
    _a[1] = 1.2;
    _a[2] = -5.0;
    _a[3] = 30.0;
    _a[4] = -7.5;
    _a[5] = 0.75;
    _b[1] = 0.25;
    _b[2] = 0.1;
    _b[3] = 0.1;
    _b[4] = 0.1;
    _b[5] = 0.4;
  }

  // Getters
  int getN() => _n;
  double getHrStd() => _hrStd;
  double getHrMean() => _hrMean;
  double getLfHfRatio() => _lfHfRatio;
  int getSfEcg() => _sfEcg;
  int getSf() => _sf;
  double getANoise() => _aNoise;
  double getFLo() => _fLo;
  double getFHi() => _fHi;
  double getFLoStd() => _fLoStd;
  double getFHiStd() => _fHiStd;
  int getSeed() => _seed;
  int getEcgAnimateInterval() => _ecgAnimateInterval;
  double getTheta(int index) => _theta[index + 1];
  double getA(int index) => _a[index + 1];
  double getB(int index) => _b[index + 1];

  // Setters
  void setHrMean(double value) => _hrMean = value;
  void setHrStd(double value) => _hrStd = value;
  void setLfHfRatio(double value) => _lfHfRatio = value;
  void setSfEcg(int value) => _sfEcg = value;
  void setSf(int value) => _sf = value;
  void setANoise(double value) => _aNoise = value;
  void setFLo(double value) => _fLo = value;
  void setFHi(double value) => _fHi = value;
  void setFLoStd(double value) => _fLoStd = value;
  void setFHiStd(double value) => _fHiStd = value;
  void setN(int value) => _n = value;
  void setSeed(int value) => _seed = value;
  void setEcgAnimateInterval(int value) => _ecgAnimateInterval = value;

  // Set PQRST parameters individually
  void setThetaValue(int index, double value) {
    if (index >= 0 && index < 5) _theta[index + 1] = value;
  }

  void setAValue(int index, double value) {
    if (index >= 0 && index < 5) _a[index + 1] = value;
  }

  void setBValue(int index, double value) {
    if (index >= 0 && index < 5) _b[index + 1] = value;
  }

  // Set PQRST parameters as lists
  void setThetaList(List<double> values) {
    for (int i = 0; i < min(5, values.length); i++) {
      _theta[i + 1] = values[i];
    }
  }

  void setAList(List<double> values) {
    for (int i = 0; i < min(5, values.length); i++) {
      _a[i + 1] = values[i];
    }
  }

  void setBList(List<double> values) {
    for (int i = 0; i < min(5, values.length); i++) {
      _b[i + 1] = values[i];
    }
  }
}
