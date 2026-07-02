import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import 'package:nsd/nsd.dart' as nsd;
import '../emulation/libretro.dart';

class HostServer {
  static final HostServer instance = HostServer._internal();
  HostServer._internal();

  HttpServer? _server;
  WebSocket? _p2Socket;
  nsd.Registration? _registration;

  bool get isRunning => _server != null;

  /// Starts the mesh server, mDNS broadcast, and telemetry update loop
  Future<void> start() async {
    if (isRunning) return;

    _log('Starting Console Server on Port 3000...');
    try {
      // Bind to any IPv4 address on port 3000
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 3000, shared: true);
      _log('Server bound successfully to port 3000');

      // Listen for WebSocket upgrade requests
      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleClientConnection(socket);
        } else {
          request.response.statusCode = HttpStatus.forbidden;
          await request.response.close();
        }
      }, onError: (e) {
        _log('HttpServer Error: $e');
      });

      // Advertise server via mDNS nsd package asynchronously to prevent blocking the engine boot
      _log('Publishing mDNS broadcast signature: _retroconsole._tcp...');
      nsd.register(
        const nsd.Service(
          name: 'RetroMeshConsoleHost',
          type: '_retroconsole._tcp',
          port: 3000,
        ),
      ).then((reg) {
        _registration = reg;
        _log('mDNS service registered successfully');
      }).catchError((e) {
        _log('mDNS registration failed: $e');
      });


    } catch (e) {
      _log('Failed to start server: $e');
      await stop();
      rethrow;
    }
  }

  /// Stops server, unregisters mDNS, and closes sockets
  Future<void> stop() async {
    _log('Shutting down Console Server...');

    if (_p2Socket != null) {
      await _p2Socket!.close(WebSocketStatus.normalClosure, 'Console Host shutting down');
      _p2Socket = null;
    }

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }

    _log('Console Server Stopped');
  }

  void _handleClientConnection(WebSocket socket) {
    if (_p2Socket != null) {
      _log('Rejecting extra controller client connection');
      socket.close(WebSocketStatus.normalClosure, 'Port 2 already occupied');
      return;
    }

    _p2Socket = socket;
    _log('Player 2 Controller Squad connected');

    socket.listen(
      (message) {
        if (message is List<int> || message is Uint8List) {
          // High-speed 2-byte gamepad packets (unbuffered)
          final bytes = message as List<int>;
          if (bytes.length == 2) {
            final int phase = bytes[0]; // 1 = Press (KeyDown), 2 = Release (KeyUp)
            final int buttonId = bytes[1];
            final bool pressed = (phase == 1);

            // Feed directly into Active Libretro Core on Port 2 (index 1)
            LibretroEngine.activeInstance?.updateButtonState(1, buttonId, pressed);
          }
        }
      },
      onDone: () {
        _log('Player 2 Controller disconnected');
        _p2Socket = null;
      },
      onError: (e) {
        _log('Player 2 connection error: $e');
        _p2Socket = null;
      },
      cancelOnError: true,
    );
  }


  void _log(String message) {
    ConsoleLogger.log('HostServer', message);
  }
}
