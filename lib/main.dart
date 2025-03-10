import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assisted Emotion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AnimatedHomePage(),
    );
  }
}

class AnimatedHomePage extends StatefulWidget {
  const AnimatedHomePage({super.key});

  @override
  State<AnimatedHomePage> createState() => _AnimatedHomePageState();
}

class _AnimatedHomePageState extends State<AnimatedHomePage> {
  String animatedText = "";
  bool showConnectButton = false;
  final String fullText = "Assisted Emotion";
  int charIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTypewriterAnimation();
  }

  void _startTypewriterAnimation() {
    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (charIndex < fullText.length) {
        setState(() {
          animatedText += fullText[charIndex];
        });
        charIndex++;
      } else {
        timer.cancel();
        _fadeOutTextAndShowButton();
      }
    });
  }

  void _fadeOutTextAndShowButton() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      showConnectButton = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: showConnectButton
          ? AppBar(
              title: const Text('Assisted Emotion'),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            )
          : null,
      body: Center(
        child: showConnectButton
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GraphScreen(deviceName: "Biosensor"),
                    ),
                  );
                },
                child: const Text('Biosensor'),
              )
            : Text(
                animatedText,
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.lightBlue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}

class GraphScreen extends StatefulWidget {
  final String deviceName;
  const GraphScreen({super.key, required this.deviceName});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  FlutterBlue flutterBlue = FlutterBlue.instance;
  late BluetoothDevice device;
  late BluetoothCharacteristic characteristic;

  List<double> sensor1Values = [];
  List<double> sensor2Values = [];
  Color orbColor = Colors.lightBlue;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _connectToDevice();
  }

  void _connectToDevice() async {
    // Scan for devices
    flutterBlue.startScan(timeout: const Duration(seconds: 4));

    // Listen to scan results
    var subscription = flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.name == widget.deviceName) {
          device = r.device;
          flutterBlue.stopScan();
          _connectToCharacteristic();
          break;
        }
      }
    });
  }

  void _connectToCharacteristic() async {
    await device.connect();
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic c in service.characteristics) {
        if (c.properties.notify) {
          characteristic = c;
          await characteristic.setNotifyValue(true);
          characteristic.value.listen((value) {
            final sensor1 = value[0].toDouble();
            final sensor2 = value[1].toDouble();

            setState(() {
              sensor1Values.add(sensor1);
              sensor2Values.add(sensor2);

              // Keep only the last 10 values for phase calculation
              if (sensor1Values.length > 10) {
                sensor1Values.removeAt(0);
                sensor2Values.removeAt(0);
              }

              // Calculate the phase difference
              final phaseDifference = calculatePhaseDifference(sensor1Values, sensor2Values);

              // Map the phase difference to a color
              orbColor = getColorFromPhaseDifference(phaseDifference);
            });

            _animationController.forward(from: 0.0);
          });
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    device.disconnect();
    _animationController.dispose();
    super.dispose();
  }

  double calculatePhaseDifference(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) return 0.0;

    final n = x.length;
    double sumX = 0.0;
    double sumY = 0.0;
    double sumXY = 0.0;
    double sumX2 = 0.0;
    double sumY2 = 0.0;

    for (int i = 0; i < n; i++) {
      sumX += x[i];
      sumY += y[i];
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
      sumY2 += y[i] * y[i];
    }

    final numerator = n * sumXY - sumX * sumY;
    final denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));

    return numerator / denominator;
  }

  Color getColorFromPhaseDifference(double phaseDifference) {
    // Map phase difference to a color between green, blue, and purple
    if (phaseDifference < -0.5) {
      return Color.lerp(Colors.green, Colors.black, -phaseDifference)!;
    } else if (phaseDifference < 0.5) {
      return Color.lerp(Colors.lightBlue, Colors.blue, phaseDifference + 0.5)!;
    } else {
      return Color.lerp(Colors.purple, Colors.black, phaseDifference - 0.5)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connected to ${widget.deviceName}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: OrbPainter(orbColor),
            );
          },
        ),
      ),
    );
  }
}

class OrbPainter extends CustomPainter {
  final Color orbColor;

  OrbPainter(this.orbColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [orbColor.withOpacity(0.5), orbColor],
        stops: [0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: 100));
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 100, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}