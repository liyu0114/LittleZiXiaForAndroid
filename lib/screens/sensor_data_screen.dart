// 传感器数据展示页面
//
// 实时显示各种传感器数据

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class SensorDataScreen extends StatefulWidget {
  const SensorDataScreen({super.key});

  @override
  State<SensorDataScreen> createState() => _SensorDataScreenState();
}

class _SensorDataScreenState extends State<SensorDataScreen> {
  bool _accelerometerEnabled = false;
  bool _gyroscopeEnabled = false;
  bool _magnetometerEnabled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('📊 传感器数据'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {});
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 加速度计
              _buildSensorCard(
                '加速度计',
                '测量设备加速度（包含重力）',
                Icons.speed,
                _accelerometerEnabled,
                (value) {
                  setState(() {
                    _accelerometerEnabled = value;
                    if (value) {
                      appState.sensorService.startAccelerometer();
                    } else {
                      appState.sensorService.stopAccelerometer();
                    }
                  });
                },
                appState.sensorService.accelerometerData,
                'm/s²',
              ),

              const SizedBox(height: 16),

              // 陀螺仪
              _buildSensorCard(
                '陀螺仪',
                '测量设备旋转速度',
                Icons.rotate_right,
                _gyroscopeEnabled,
                (value) {
                  setState(() {
                    _gyroscopeEnabled = value;
                    if (value) {
                      appState.sensorService.startGyroscope();
                    } else {
                      appState.sensorService.stopGyroscope();
                    }
                  });
                },
                appState.sensorService.gyroscopeData,
                'rad/s',
              ),

              const SizedBox(height: 16),

              // 磁力计
              _buildSensorCard(
                '磁力计',
                '测量周围磁场强度',
                Icons.explore,
                _magnetometerEnabled,
                (value) {
                  setState(() {
                    _magnetometerEnabled = value;
                    if (value) {
                      appState.sensorService.startMagnetometer();
                    } else {
                      appState.sensorService.stopMagnetometer();
                    }
                  });
                },
                appState.sensorService.magnetometerData,
                'μT',
              ),

              const SizedBox(height: 24),

              // 设备倾斜角度
              if (_accelerometerEnabled && appState.sensorService.accelerometerData != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📐 设备倾斜',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '倾斜角度: ${appState.sensorService.getDeviceTilt()?.toStringAsFixed(1) ?? "未知"}°',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSensorCard(
    String title,
    String description,
    IconData icon,
    bool enabled,
    Function(bool) onToggle,
    dynamic data,
    String unit,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (enabled && data != null) ...[
              const Divider(),
              const SizedBox(height: 8),
              _buildDataDisplay(data, unit),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataDisplay(dynamic data, String unit) {
    if (data == null) {
      return const Text('等待数据...');
    }

    // 假设 data 有 x, y, z 属性
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('X: ${data.x.toStringAsFixed(3)} $unit'),
        Text('Y: ${data.y.toStringAsFixed(3)} $unit'),
        Text('Z: ${data.z.toStringAsFixed(3)} $unit'),
        const SizedBox(height: 8),
        Text(
          '合力: ${data.magnitude?.toStringAsFixed(3) ?? "计算中"} $unit',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.sensorService.stopAccelerometer();
    appState.sensorService.stopGyroscope();
    appState.sensorService.stopMagnetometer();
    super.dispose();
  }
}
