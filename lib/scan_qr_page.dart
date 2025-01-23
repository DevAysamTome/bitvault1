import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cameraController.start();
    });
  }

  @override
  void dispose() {
    cameraController.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    const boxSize = 250.0;
    final centerX = width / 2;
    final centerY = height / 2;
    final scanWindowRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: boxSize,
      height: boxSize,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            fit: BoxFit.cover,
            onDetect: (capture) {
              if (!_isProcessing &&
                  capture.barcodes.isNotEmpty &&
                  capture.barcodes.first.rawValue != null) {
                setState(() {
                  _isProcessing = true;
                });
                final code = capture.barcodes.first.rawValue!;
                HapticFeedback.lightImpact();
                //   نرجع العنوان للصفحة السابقة
                Navigator.pop(context, code);
              }
            },
          ),
          // تظليل المناطق خارج مربع المسح
          CustomPaint(
            size: Size(width, height),
            painter: _OverlayPainter(scanWindowRect: scanWindowRect),
          ),
          // رسم إطار أبيض حول مربع المسح
          CustomPaint(
            size: Size(width, height),
            painter: _CameraFramePainter(scanWindowRect: scanWindowRect),
          ),
          // زر الرجوع
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
          ),
          // نص علوي
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: const Text(
              "Send Bitcoin!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect scanWindowRect;
  _OverlayPainter({required this.scanWindowRect});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanWindowRect);

    final paint = Paint()..color = Colors.black54;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraFramePainter extends CustomPainter {
  final Rect scanWindowRect;
  _CameraFramePainter({required this.scanWindowRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    const lineLength = 35.0;

    // العلوية اليسرى
    canvas.drawLine(
      Offset(scanWindowRect.left, scanWindowRect.top),
      Offset(scanWindowRect.left, scanWindowRect.top + lineLength),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindowRect.left, scanWindowRect.top),
      Offset(scanWindowRect.left + lineLength, scanWindowRect.top),
      paint,
    );

    // العلوية اليمنى
    canvas.drawLine(
      Offset(scanWindowRect.right, scanWindowRect.top),
      Offset(scanWindowRect.right, scanWindowRect.top + lineLength),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindowRect.right, scanWindowRect.top),
      Offset(scanWindowRect.right - lineLength, scanWindowRect.top),
      paint,
    );

    // السفلية اليسرى
    canvas.drawLine(
      Offset(scanWindowRect.left, scanWindowRect.bottom),
      Offset(scanWindowRect.left, scanWindowRect.bottom - lineLength),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindowRect.left, scanWindowRect.bottom),
      Offset(scanWindowRect.left + lineLength, scanWindowRect.bottom),
      paint,
    );

    // السفلية اليمنى
    canvas.drawLine(
      Offset(scanWindowRect.right, scanWindowRect.bottom),
      Offset(scanWindowRect.right, scanWindowRect.bottom - lineLength),
      paint,
    );
    canvas.drawLine(
      Offset(scanWindowRect.right, scanWindowRect.bottom),
      Offset(scanWindowRect.right - lineLength, scanWindowRect.bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
