import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'universal_caster_interface.dart';

class UniversalCasterBridge implements UniversalDisplayCaster {
  static const MethodChannel _methodChannel = MethodChannel('com.retromesh.console/casting');
  static const EventChannel _eventChannel = EventChannel('com.retromesh.console/casting_events');

  Stream<List<UniversalTVTarget>>? _discoveredStream;

  @override
  Stream<List<UniversalTVTarget>> get discoveredDevicesStream {
    _discoveredStream ??= _eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event == null) return <UniversalTVTarget>[];
      final List<dynamic> list = jsonDecode(event as String) as List<dynamic>;
      return list.map((dynamic item) => UniversalTVTarget.fromJson(item as Map<String, dynamic>)).toList();
    });
    return _discoveredStream!;
  }

  @override
  Future<void> startScanning() async {
    await _methodChannel.invokeMethod('startScanning');
  }

  @override
  Future<void> stopScanning() async {
    await _methodChannel.invokeMethod('stopScanning');
  }

  @override
  Future<void> connectToDevice(UniversalTVTarget target) async {
    await _methodChannel.invokeMethod('connectToDevice', target.toJson());
  }

  @override
  Future<void> projectGameplayCanvas() async {
    await _methodChannel.invokeMethod('projectGameplayCanvas');
  }

  @override
  Future<void> disconnect() async {
    await _methodChannel.invokeMethod('disconnect');
  }
}
