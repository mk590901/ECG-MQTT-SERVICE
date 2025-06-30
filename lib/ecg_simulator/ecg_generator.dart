import 'dart:math';
import 'ecg_log.dart';
import 'ecg_param.dart';
import 'ieee_remainder.dart';

class ECGGenerator {
  // Configuration parameters from EcgParam
  final double hrmean; // Mean heart rate (beats/min)
  final double hrstd; // Heart rate standard deviation
  final double lfhfratio; // LF/HF ratio
  final double sfecg; // ECG sampling frequency (Hz)
  final double sf; // Internal sampling frequency (Hz)
  final double anoise; // Noise amplitude (mV)
  final double flo; // Low frequency (Hz)
  final double fhi; // High frequency (Hz)
  final double flostd; // Low frequency standard deviation
  final double fhistd; // High frequency standard deviation
  final List<double> theta; // PQRST angles (degrees)
  final List<double> a; // PQRST amplitudes (mV)
  final List<double> b; // PQRST widths
  final int seed; // Random seed
  final EcgLogWindow log; // Logger
  late EcgParam paramOb; // Store EcgParam instance

  // Adjusted parameters (radians, scaled for heart rate)
  late List<double> ti; // PQRST angles (radians)
  late List<double> ai; // Adjusted amplitudes
  late List<double> bi; // Adjusted widths

  // Runtime state
  double _t = 0.0; // Current time (seconds)
  final List<double> _x = [0.0, 1.0, 0.0, 0.04]; // State vector [x, y, z]
  final double _h; // Internal time step (1/sf)
  final double _tstep; // ECG time step (1/sfecg)
  final int _q; // Downsampling factor (sf/sfecg)
  List<double> _rrBuffer = List.filled(10, 0.0); // Small RR-interval buffer
  int _rrIndex = 0; // Current RR-interval index
  int _rrCount = 0; // Number of valid RR-intervals
  double _nextRRTime = 0.0; // Time of next beat
  double _zmin = double.infinity; // Min voltage for scaling
  double _zmax = double.negativeInfinity; // Max voltage for scaling

  // Random number generator state (for ran1)
  int _rseed;
  int _iy = 0;
  final List<int> _iv = List.filled(32, 0);

  // Constants
  static const double PI = 3.141592653589793;
  static const int NTAB = 32;
  static const int IA = 16807;
  static const int IM = 2147483647;
  static const double AM = 1.0 / IM;
  static const int IQ = 127773;
  static const int IR = 2836;
  static const double NDIV = (1 + (IM - 1) / NTAB);
  static const double EPS = 1.2e-7;
  static const double RNMX = 1.0 - EPS;
  static const int mstate = 3; // State space dimension

  ECGGenerator({required EcgParam param, required this.log})
    : hrmean = param.getHrMean(),
      hrstd = param.getHrStd(),
      lfhfratio = param.getLfHfRatio(),
      sfecg = param.getSfEcg().toDouble(),
      sf = param.getSf().toDouble(),
      anoise = param.getANoise(),
      flo = param.getFLo(),
      fhi = param.getFHi(),
      flostd = param.getFLoStd(),
      fhistd = param.getFHiStd(),
      seed = param.getSeed(),
      _rseed = -param.getSeed(),
      theta = List.generate(5, (i) => param.getTheta(i)),
      a = List.generate(5, (i) => param.getA(i)),
      b = List.generate(5, (i) => param.getB(i)),
      paramOb = param,
      _h = 1.0 / param.getSf().toDouble(),
      _tstep = 1.0 / param.getSfEcg().toDouble(),
      _q = (param.getSf() / param.getSfEcg()).round() {
    // Initialize adjusted parameters
    _initializeParameters();
    // Initialize RR buffer
    _generateRRBuffer();
    // Log parameters
    _logParameters();
  }

  void _initializeParameters() {
    // Convert angles to radians and adjust for heart rate
    ti = List.filled(6, 0.0);
    ai = List.filled(6, 0.0);
    bi = List.filled(6, 0.0);
    double hrfact = sqrt(hrmean / 60.0);
    double hrfact2 = sqrt(hrfact);
    for (int i = 0; i < 5; i++) {
      ti[i + 1] = theta[i] * PI / 180.0;
      ai[i + 1] = a[i];
      bi[i + 1] = b[i] * hrfact;
    }
    ti[1] *= hrfact2;
    ti[2] *= hrfact;
    ti[3] *= 1.0;
    ti[4] *= hrfact;
    ti[5] *= 1.0;
  }

  void _logParameters() {
    log.println("ECG Generator Parameters:");
    log.println("Approximate number of heart beats: ${paramOb.getN()}");
    log.println("ECG sampling frequency: $sfecg Hertz");
    log.println("Internal sampling frequency: $sf Hertz");
    log.println("Amplitude of additive noise: $anoise mV");
    log.println("Heart rate mean: $hrmean beats per minute");
    log.println("Heart rate std: $hrstd beats per minute");
    log.println("Low frequency: $flo Hertz");
    log.println("High frequency: $fhi Hertz");
    log.println("Low frequency std: $flostd Hertz");
    log.println("High frequency std: $fhistd Hertz");
    log.println("LF/HF ratio: $lfhfratio");
    log.println("Order of Extrema (P, Q, R, S, T):");
    log.println("theta(radians): ${ti.sublist(1)}");
    log.println("a(mV): ${ai.sublist(1)}");
    log.println("b(radians): ${bi.sublist(1)}");
  }

  double ran1() {
    int j;
    int k;
    double temp;
    bool flg = _iy != 0;

    if (_rseed <= 0 || !flg) {
      if (-_rseed < 1) {
        _rseed = 1;
      } else {
        _rseed = -_rseed;
      }
      for (j = NTAB + 7; j >= 0; j--) {
        k = (_rseed ~/ IQ);
        _rseed = IA * (_rseed - k * IQ) - IR * k;
        if (_rseed < 0) _rseed += IM;
        if (j < NTAB) _iv[j] = _rseed;
      }
      _iy = _iv[0];
    }

    k = (_rseed ~/ IQ);
    _rseed = IA * (_rseed - k * IQ) - IR * k;
    if (_rseed < 0) _rseed += IM;
    j = (_iy ~/ NDIV).toInt();
    _iy = _iv[j];
    _iv[j] = _rseed;

    temp = AM * _iy;
    return temp > RNMX ? RNMX : temp;
  }

  void ifft(List<double> data, int nn, int isign) {
    int n = nn << 1;
    int j = 1;
    for (int i = 1; i < n; i += 2) {
      if (j > i) {
        double swap = data[j];
        data[j] = data[i];
        data[i] = swap;
        swap = data[j + 1];
        data[j + 1] = data[i + 1];
        data[i + 1] = swap;
      }
      int m = n >> 1;
      while (m >= 2 && j > m) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }
    int mmax = 2;
    while (n > mmax) {
      int istep = mmax << 1;
      double theta = isign * (6.28318530717959 / mmax);
      double wtemp = sin(0.5 * theta);
      double wpr = -2.0 * wtemp * wtemp;
      double wpi = sin(theta);
      double wr = 1.0;
      double wi = 0.0;
      for (int m = 1; m < mmax; m += 2) {
        for (int i = m; i <= n; i += istep) {
          int j2 = i + mmax;
          double tempr = wr * data[j2] - wi * data[j2 + 1];
          double tempi = wr * data[j2 + 1] + wi * data[j2];
          data[j2] = data[i] - tempr;
          data[j2 + 1] = data[i + 1] - tempi;
          data[i] += tempr;
          data[i + 1] += tempi;
        }
        wr = (wtemp = wr) * wpr - wi * wpi + wr;
        wi = wi * wpr + wtemp * wpi + wi;
      }
      mmax = istep;
    }
  }

  double stdev(List<double> x, int n) {
    double add = 0.0;
    for (int j = 1; j <= n; j++) {
      add += x[j];
    }
    double mean = add / n;
    double total = 0.0;
    for (int j = 1; j <= n; j++) {
      double diff = x[j] - mean;
      total += diff * diff;
    }
    return sqrt(total / (n - 1));
  }

  void rrprocess(
    List<double> rr,
    double flo,
    double fhi,
    double flostd,
    double fhistd,
    double lfhfratio,
    double hrmean,
    double hrstd,
    double sf,
    int n,
  ) {
    List<double> w = List.filled(n + 1, 0.0);
    List<double> hw = List.filled(n + 1, 0.0);
    List<double> sw = List.filled(n + 1, 0.0);
    List<double> ph0 = List.filled(n ~/ 2, 0.0);
    List<double> ph = List.filled(n + 1, 0.0);
    List<double> swC = List.filled(2 * n + 1, 0.0);

    double w1 = 2.0 * PI * flo;
    double w2 = 2.0 * PI * fhi;
    double c1 = 2.0 * PI * flostd;
    double c2 = 2.0 * PI * fhistd;
    double sig2 = 1.0;
    double sig1 = lfhfratio;
    double rrmean = 60.0 / hrmean;
    double rrstd = 60.0 * hrstd / (hrmean * hrmean);
    double df = sf / n;

    for (int i = 1; i <= n; i++) {
      w[i] = (i - 1) * 2.0 * PI * df;
    }
    for (int i = 1; i <= n; i++) {
      hw[i] =
          (sig1 *
              exp(-0.5 * pow(w[i] - w1, 2) / pow(c1, 2)) /
              sqrt(2 * PI * c1 * c1)) +
          (sig2 *
              exp(-0.5 * pow(w[i] - w2, 2) / pow(c2, 2)) /
              sqrt(2 * PI * c2 * c2));
    }
    for (int i = 1; i <= n ~/ 2; i++) {
      sw[i] = (sf / 2.0) * sqrt(hw[i]);
    }
    for (int i = n ~/ 2 + 1; i <= n; i++) {
      sw[i] = (sf / 2.0) * sqrt(hw[n - i + 1]);
    }
    for (int i = 1; i < n ~/ 2; i++) {
      ph0[i] = 2.0 * PI * ran1();
    }
    ph[1] = 0.0;
    for (int i = 1; i < n ~/ 2; i++) {
      ph[i + 1] = ph0[i];
    }
    ph[n ~/ 2 + 1] = 0.0;
    for (int i = 1; i < n ~/ 2; i++) {
      ph[n - i + 1] = -ph0[i];
    }
    for (int i = 1; i <= n; i++) {
      swC[2 * i - 1] = sw[i] * cos(ph[i]);
      swC[2 * i] = sw[i] * sin(ph[i]);
    }
    ifft(swC, n, -1);
    for (int i = 1; i <= n; i++) {
      rr[i] = (1.0 / n) * swC[2 * i - 1];
    }
    double xstd = stdev(rr, n);
    double ratio = rrstd / xstd;
    for (int i = 1; i <= n; i++) {
      rr[i] = rr[i] * ratio + rrmean;
    }
  }

  void derivspqrst(double t0, List<double> x, List<double> dxdt) {
    double w0 = 2.0 * PI / _rrBuffer[_rrIndex];
    double r0 = 1.0;
    double x0 = 0.0;
    double y0 = 0.0;
    //double z0 = 0.0;
    double a0 =
        1.0 - sqrt((x[1] - x0) * (x[1] - x0) + (x[2] - y0) * (x[2] - y0)) / r0;
    double zbase = 0.005 * sin(2.0 * PI * fhi * t0);
    double t = atan2(x[2], x[1]);

    dxdt[1] = a0 * (x[1] - x0) - w0 * (x[2] - y0);
    dxdt[2] = a0 * (x[2] - y0) + w0 * (x[1] - x0);
    dxdt[3] = 0.0;
    for (int i = 1; i <= 5; i++) {
      double dt = ieeeRemainder(t - ti[i], 2.0 * PI);
      double dt2 = dt * dt;
      dxdt[3] += -ai[i] * dt * exp(-0.5 * dt2 / (bi[i] * bi[i]));
    }
    dxdt[3] += -1.0 * (x[3] - zbase);
  }

  void rk4(List<double> y, int n, double x, double h, List<double> yout) {
    List<double> dydx = List.filled(n + 1, 0.0);
    List<double> dym = List.filled(n + 1, 0.0);
    List<double> dyt = List.filled(n + 1, 0.0);
    List<double> yt = List.filled(n + 1, 0.0);

    double hh = h * 0.5;
    double h6 = h / 6.0;
    double xh = x + hh;

    derivspqrst(x, y, dydx);
    for (int i = 1; i <= n; i++) {
      yt[i] = y[i] + hh * dydx[i];
    }
    derivspqrst(xh, yt, dyt);
    for (int i = 1; i <= n; i++) {
      yt[i] = y[i] + hh * dyt[i];
    }
    derivspqrst(xh, yt, dym);
    for (int i = 1; i <= n; i++) {
      yt[i] = y[i] + h * dym[i];
      dym[i] += dyt[i];
    }
    derivspqrst(x + h, yt, dyt);
    for (int i = 1; i <= n; i++) {
      yout[i] = y[i] + h6 * (dydx[i] + dyt[i] + 2.0 * dym[i]);
    }
  }

  void detectpeaks(
    List<double> ipeak,
    List<double> x,
    List<double> y,
    List<double> z,
    int n,
  ) {
    double thetap1 = ti[1],
        thetap2 = ti[2],
        thetap3 = ti[3],
        thetap4 = ti[4],
        thetap5 = ti[5];
    for (int i = 1; i <= n; i++) {
      ipeak[i] = 0.0;
    }
    double theta1 = atan2(y[1], x[1]);
    for (int i = 1; i < n; i++) {
      double theta2 = atan2(y[i + 1], x[i + 1]);
      if (theta1 <= thetap1 && thetap1 <= theta2) {
        double d1 = thetap1 - theta1;
        double d2 = theta2 - thetap1;
        ipeak[d1 < d2 ? i : i + 1] = 1.0;
      } else if (theta1 <= thetap2 && thetap2 <= theta2) {
        double d1 = thetap2 - theta1;
        double d2 = theta2 - thetap2;
        ipeak[d1 < d2 ? i : i + 1] = 2.0;
      } else if (theta1 <= thetap3 && thetap3 <= theta2) {
        double d1 = thetap3 - theta1;
        double d2 = theta2 - thetap3;
        ipeak[d1 < d2 ? i : i + 1] = 3.0;
      } else if (theta1 <= thetap4 && thetap4 <= theta2) {
        double d1 = thetap4 - theta1;
        double d2 = theta2 - thetap4;
        ipeak[d1 < d2 ? i : i + 1] = 4.0;
      } else if (theta1 <= thetap5 && thetap5 <= theta2) {
        double d1 = thetap5 - theta1;
        double d2 = theta2 - thetap5;
        ipeak[d1 < d2 ? i : i + 1] = 5.0;
      }
      theta1 = theta2;
    }
    int d = (sfecg / 64).ceil();
    for (int i = 1; i <= n; i++) {
      if (ipeak[i] == 1 || ipeak[i] == 3 || ipeak[i] == 5) {
        int j1 = max(1, i - d);
        int j2 = min(n, i + d);
        int jmax = j1;
        double zmax = z[j1];
        for (int j = j1 + 1; j <= j2; j++) {
          if (z[j] > zmax) {
            jmax = j;
            zmax = z[j];
          }
        }
        if (jmax != i) {
          ipeak[jmax] = ipeak[i];
          ipeak[i] = 0;
        }
      } else if (ipeak[i] == 2 || ipeak[i] == 4) {
        int j1 = max(1, i - d);
        int j2 = min(n, i + d);
        int jmin = j1;
        double zmin = z[j1];
        for (int j = j1 + 1; j <= j2; j++) {
          if (z[j] < zmin) {
            jmin = j;
            zmin = z[j];
          }
        }
        if (jmin != i) {
          ipeak[jmin] = ipeak[i];
          ipeak[i] = 0;
        }
      }
    }
  }

  void _generateRRBuffer() {
    int nrr = 512; // Small batch size for RR-intervals
    List<double> rr = List.filled(nrr + 1, 0.0);
    rrprocess(rr, flo, fhi, flostd, fhistd, lfhfratio, hrmean, hrstd, sf, nrr);
    _rrBuffer = rr.sublist(1, min(11, nrr + 1));
    _rrCount = _rrBuffer.length;
    _rrIndex = 0;
    _nextRRTime = _t + _rrBuffer[0];
  }

  List<dynamic> generateBuffer(int bufSize) {
    List<double> time = List.filled(bufSize, 0.0);
    List<double> voltage = List.filled(bufSize, 0.0);
    List<int> peak = List.filled(bufSize, 0);
    List<double> xt = List.filled(bufSize * _q + 1, 0.0);
    List<double> yt = List.filled(bufSize * _q + 1, 0.0);
    List<double> zt = List.filled(bufSize * _q + 1, 0.0);
    List<double> xts = List.filled(bufSize + 1, 0.0);
    List<double> yts = List.filled(bufSize + 1, 0.0);
    List<double> zts = List.filled(bufSize + 1, 0.0);
    List<double> ipeak = List.filled(bufSize + 1, 0.0);

    double timev = _t;
    int nt = bufSize * _q;
    for (int i = 1; i <= nt; i++) {
      if (timev >= _nextRRTime) {
        _rrIndex++;
        if (_rrIndex >= _rrCount) {
          _generateRRBuffer();
        }
        _nextRRTime = timev + _rrBuffer[_rrIndex];
      }
      xt[i] = _x[1];
      yt[i] = _x[2];
      zt[i] = _x[3];
      rk4(_x, mstate, timev, _h, _x);
      timev += _h;
    }

    int j = 0;
    for (int i = 1; i <= nt; i += _q) {
      j++;
      xts[j] = xt[i];
      yts[j] = yt[i];
      zts[j] = zt[i];
    }
    int nts = j;

    detectpeaks(ipeak, xts, yts, zts, nts);

    for (int i = 1; i <= nts; i++) {
      _zmin = min(_zmin, zts[i]);
      _zmax = max(_zmax, zts[i]);
    }
    double zrange = _zmax - _zmin;
    for (int i = 1; i <= nts; i++) {
      zts[i] = (zts[i] - _zmin) * 1.6 / (zrange == 0 ? 1.0 : zrange) - 0.4;
      zts[i] += anoise * (2.0 * ran1() - 1.0);
    }

    for (int i = 0; i < nts; i++) {
      time[i] = _t + i * _tstep;
      voltage[i] = zts[i + 1];
      peak[i] = ipeak[i + 1].toInt();
    }
    _t += nts * _tstep;

    return [time, voltage, peak];
  }

}

