import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:sensors_plus/sensors_plus.dart' as sensors;
import 'package:motion_sensors/motion_sensors.dart' as motion;
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:sensors_plus_platform_interface/src/sensor_interval.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() {
  runApp(const SensorDataApp());
}

class SensorDataApp extends StatelessWidget {
  const SensorDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Data Collector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SensorDataCollectorPage(),
    );
  }
}

class SensorDataCollectorPage extends StatefulWidget {
  const SensorDataCollectorPage({super.key});

  @override
  State<SensorDataCollectorPage> createState() =>
      _SensorDataCollectorPageState();
}

class _SensorDataCollectorPageState extends State<SensorDataCollectorPage> {
  // Sensor data streams
  StreamSubscription<sensors.AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<sensors.GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<sensors.MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<dynamic>? _motionSubscription;
  Timer? _motionThrottleTimer;
  bool _motionDataReady = false;

  // ARKit controller
  ARKitController? _arkitController;
  Timer? _arkitTimer;

  // Data storage
  final List<List<dynamic>> _sensorData = [];
  bool _isRecording = false;
  bool _isARKitSupported = false;

  // Sensor sampling intervals (iOS native modes)
  Duration _selectedInterval = SensorInterval.normalInterval;
  String _selectedSensorSpeed = 'Normal';
  final List<String> _sensorSpeeds = ['UI', 'Normal', 'Game', 'Fastest'];

  // Mapping sensor speed names to SensorInterval constants (iOS native modes)
  final Map<String, Duration> _sensorIntervalMap = {
    'UI': SensorInterval.uiInterval, // ~15Hz - for UI updates
    'Normal': SensorInterval.normalInterval, // ~5Hz - for normal use
    'Game': SensorInterval.gameInterval, // ~50Hz - for games
    'Fastest': SensorInterval.fastestInterval, // No limit - fastest possible
  };

  // Current sensor readings
  sensors.AccelerometerEvent? _accelerometerData;
  sensors.GyroscopeEvent? _gyroscopeData;
  sensors.MagnetometerEvent? _magnetometerData;
  Map<String, dynamic>? _motionData;
  Map<String, dynamic>? _arkitData;

  @override
  void initState() {
    super.initState();
    _arkitData = {
      'camera_x': 0.0,
      'camera_y': 0.0,
      'camera_z': 0.0,
      'rotation_x': 0.0,
      'rotation_y': 0.0,
      'rotation_z': 0.0,
      'rotation_w': 1.0,
    };
    _checkPermissions();
    _checkARKitSupport();
    _initializeMotionSensors();
  }

  Future<void> _checkPermissions() async {
    await Permission.camera.request();
    await Permission.sensors.request();
    await Permission.location.request();
  }

  Future<void> _checkARKitSupport() async {
    if (Platform.isIOS) {
      // For now, assume ARKit is supported on iOS devices
      // In production, you would do proper feature detection
      setState(() {
        _isARKitSupported = true;
      });
    }
  }

  void _initializeMotionSensors() {
    // Motion sensor will be started only when recording begins
    // This ensures consistent behavior with other sensors
  }

  void _updateSamplingRate(String rate) {
    setState(() {
      _selectedSensorSpeed = rate;
      _selectedInterval =
          _sensorIntervalMap[rate] ?? SensorInterval.normalInterval;
    });
    _restartSensorStreams();
  }

  void _restartSensorStreams() {
    // Stop existing streams and timers
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _motionSubscription?.cancel();
    _motionThrottleTimer?.cancel();
    _arkitTimer?.cancel();

    // Restart with new sampling rate if recording
    if (_isRecording) {
      _startSensorStreams();
    }
  }

  void _startSensorStreams() {
    // Start sensor streams with native iOS sampling intervals
    _accelerometerSubscription = sensors
        .accelerometerEventStream(samplingPeriod: _selectedInterval)
        .listen((event) {
      _accelerometerData = event;
      if (_isRecording) {
        _recordDataPoint();
        setState(() {}); // Update UI
      }
    });

    _gyroscopeSubscription = sensors
        .gyroscopeEventStream(samplingPeriod: _selectedInterval)
        .listen((event) {
      _gyroscopeData = event;
      if (_isRecording) {
        _recordDataPoint();
        setState(() {}); // Update UI
      }
    });

    _magnetometerSubscription = sensors
        .magnetometerEventStream(samplingPeriod: _selectedInterval)
        .listen((event) {
      _magnetometerData = event;
      if (_isRecording) {
        _recordDataPoint();
        setState(() {}); // Update UI
      }
    });

    // Start motion sensor with throttled updates to match sensor speed
    motion.motionSensors.isOrientationAvailable().then((available) {
      if (available) {
        _motionSubscription =
            motion.motionSensors.orientation.listen((orientation) {
          // Update motion data immediately but don't trigger UI updates too fast
          _motionData = {
            'yaw': orientation.yaw,
            'pitch': orientation.pitch,
            'roll': orientation.roll,
          };
          _motionDataReady = true;
        });

        // Create a timer that matches the selected sensor interval for motion data UI updates
        _motionThrottleTimer = Timer.periodic(_selectedInterval, (timer) {
          if (!_isRecording && !mounted) {
            timer.cancel();
            return;
          }
          if (_motionDataReady) {
            setState(() {}); // Update UI at the same rate as other sensors
            _motionDataReady = false;
          }
        });
      }
    });

    // Start ARKit timer if supported (ARKit has its own update rate)
    if (_isARKitSupported) {
      _startARKitTimer();
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _sensorData.clear();
    });

    // Add CSV headers
    _sensorData.add([
      'timestamp',
      'accel_x',
      'accel_y',
      'accel_z',
      'gyro_x',
      'gyro_y',
      'gyro_z',
      'mag_x',
      'mag_y',
      'mag_z',
      'orientation_yaw',
      'orientation_pitch',
      'orientation_roll',
      'ar_camera_x',
      'ar_camera_y',
      'ar_camera_z',
      'ar_rotation_x',
      'ar_rotation_y',
      'ar_rotation_z',
      'ar_rotation_w'
    ]);

    // Start sensor streams with native iOS sampling rates
    _startSensorStreams();
  }

  void _startARKitTimer() {
    _arkitTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      // 30Hz for ARKit
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      _updateARKitData();
    });
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });

    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _motionSubscription?.cancel();
    _motionThrottleTimer?.cancel();
    _arkitTimer?.cancel();

    _saveDataToFile();
  }

  void _recordDataPoint() {
    if (!_isRecording) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dataPoint = [
      timestamp,
      _accelerometerData?.x ?? 0,
      _accelerometerData?.y ?? 0,
      _accelerometerData?.z ?? 0,
      _gyroscopeData?.x ?? 0,
      _gyroscopeData?.y ?? 0,
      _gyroscopeData?.z ?? 0,
      _magnetometerData?.x ?? 0,
      _magnetometerData?.y ?? 0,
      _magnetometerData?.z ?? 0,
      _motionData?['yaw'] ?? 0,
      _motionData?['pitch'] ?? 0,
      _motionData?['roll'] ?? 0,
      _arkitData?['camera_x'] ?? 0,
      _arkitData?['camera_y'] ?? 0,
      _arkitData?['camera_z'] ?? 0,
      _arkitData?['rotation_x'] ?? 0,
      _arkitData?['rotation_y'] ?? 0,
      _arkitData?['rotation_z'] ?? 0,
      _arkitData?['rotation_w'] ?? 0,
    ];

    _sensorData.add(dataPoint);
  }

  Future<void> _saveDataToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/sensor_data_$timestamp.csv');

      final csv = const ListToCsvConverter().convert(_sensorData);
      await file.writeAsString(csv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
        );
      }
    }
  }

  Widget _buildARKitView() {
    if (!_isARKitSupported) {
      return const Center(
        child: Text('ARKit is not supported on this device'),
      );
    }

    return SizedBox(
      height: 200,
      child: ARKitSceneView(
        onARKitViewCreated: (controller) {
          _arkitController = controller;
        },
        worldAlignment: ARWorldAlignment.gravity,
        planeDetection: ARPlaneDetection.horizontal,
      ),
    );
  }

  void _updateARKitData() async {
    try {
      if (_arkitController != null) {
        // Get camera position from ARKit
        final position = await _arkitController!.cameraPosition();
        if (position != null) {
          _arkitData?['camera_x'] = position.x;
          _arkitData?['camera_y'] = position.y;
          _arkitData?['camera_z'] = position.z;
        } else {
          _arkitData?['camera_x'] = 0.0;
          _arkitData?['camera_y'] = 0.0;
          _arkitData?['camera_z'] = 0.0;
        }

        // Get camera rotation from point of view transform
        final transform = await _arkitController!.pointOfViewTransform();

        if (transform != null) {
          // Extract quaternion from transform matrix
          final rotation = vector.Quaternion(0, 0, 0, 0);
          final translation = vector.Vector3.zero();
          final scale = vector.Vector3.zero();
          transform.decompose(translation, rotation, scale);

          _arkitData?['rotation_x'] = rotation.x;
          _arkitData?['rotation_y'] = rotation.y;
          _arkitData?['rotation_z'] = rotation.z;
          _arkitData?['rotation_w'] = rotation.w;
        } else {
          _arkitData?['rotation_x'] = 0.0;
          _arkitData?['rotation_y'] = 0.0;
          _arkitData?['rotation_z'] = 0.0;
          _arkitData?['rotation_w'] = 1.0;
        }
      } else {
        // ARKit not initialized yet
        _arkitData = {
          'camera_x': 0.0,
          'camera_y': 0.0,
          'camera_z': 0.0,
          'rotation_x': 0.0,
          'rotation_y': 0.0,
          'rotation_z': 0.0,
          'rotation_w': 1.0,
        };
      }
    } catch (e) {
      print('ARKit data error: $e');
      // Fallback to zeros on error
      _arkitData = {
        'camera_x': 0.0,
        'camera_y': 0.0,
        'camera_z': 0.0,
        'rotation_x': 0.0,
        'rotation_y': 0.0,
        'rotation_z': 0.0,
        'rotation_w': 1.0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Data Collector'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recording controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isRecording ? null : _startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Start Recording'),
                ),
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Stop Recording'),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Sensor speed selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Sensor Speed: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _selectedSensorSpeed,
                  onChanged: _isRecording
                      ? null
                      : (String? newValue) {
                          if (newValue != null) {
                            _updateSamplingRate(newValue);
                          }
                        },
                  items: _sensorSpeeds
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Recording status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.red.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isRecording
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _isRecording ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isRecording ? 'Recording...' : 'Not Recording',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? Colors.red : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                      'Data points: ${_sensorData.isNotEmpty ? _sensorData.length - 1 : 0} ($_selectedSensorSpeed)'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Sensor data display
            _buildSensorDataCard(
                'Accelerometer', _formatSensorData(_accelerometerData)),
            _buildSensorDataCard(
                'Gyroscope', _formatSensorData(_gyroscopeData)),
            _buildSensorDataCard(
                'Magnetometer', _formatSensorData(_magnetometerData)),
            _buildSensorDataCard(
                'Motion/Orientation', _motionData?.toString() ?? 'No data'),
            _buildSensorDataCard(
                'ARKit VIO Data', _formatARKitData(_arkitData)),

            const SizedBox(height: 20),

            // ARKit view
            if (_isARKitSupported) ...[
              const Text(
                'ARKit Camera View:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildARKitView(),
              const SizedBox(height: 20),
            ],

            // Information card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sensor Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Accelerometer: Measures device acceleration'),
                    const Text('• Gyroscope: Measures device rotation rate'),
                    const Text('• Magnetometer: Measures magnetic field'),
                    const Text(
                        '• Motion: Device orientation (yaw, pitch, roll)'),
                    if (_isARKitSupported)
                      const Text(
                          '• ARKit VIO: Camera position and rotation in 3D space'),
                    const SizedBox(height: 8),
                    Text(
                      _isARKitSupported
                          ? 'ARKit VIO provides 6DOF tracking data. Data is saved as CSV files in the app documents directory.'
                          : 'Data is saved as CSV files in the app documents directory.',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSensorData(dynamic sensorEvent) {
    if (sensorEvent == null) return 'No data';

    if (sensorEvent is sensors.AccelerometerEvent ||
        sensorEvent is sensors.GyroscopeEvent ||
        sensorEvent is sensors.MagnetometerEvent) {
      return 'X: ${sensorEvent.x.toStringAsFixed(3)}\n'
          'Y: ${sensorEvent.y.toStringAsFixed(3)}\n'
          'Z: ${sensorEvent.z.toStringAsFixed(3)}';
    }

    return sensorEvent.toString();
  }

  String _formatARKitData(Map<String, dynamic>? arkitData) {
    if (arkitData == null) return 'No ARKit data';

    return 'Position:\n'
        'X: ${arkitData['camera_x']?.toStringAsFixed(3) ?? '0.000'}\n'
        'Y: ${arkitData['camera_y']?.toStringAsFixed(3) ?? '0.000'}\n'
        'Z: ${arkitData['camera_z']?.toStringAsFixed(3) ?? '0.000'}\n\n'
        'Rotation (Quaternion):\n'
        'X: ${arkitData['rotation_x']?.toStringAsFixed(3) ?? '0.000'}\n'
        'Y: ${arkitData['rotation_y']?.toStringAsFixed(3) ?? '0.000'}\n'
        'Z: ${arkitData['rotation_z']?.toStringAsFixed(3) ?? '0.000'}\n'
        'W: ${arkitData['rotation_w']?.toStringAsFixed(3) ?? '0.000'}';
  }

  Widget _buildSensorDataCard(String title, String data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              data,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _motionSubscription?.cancel();
    _motionThrottleTimer?.cancel();
    _arkitTimer?.cancel();
    _arkitController?.dispose();
    super.dispose();
  }
}
