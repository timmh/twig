import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fftea/fftea.dart';

class SpectrogramWidget extends StatefulWidget {
  final Stream<Float32List> audioStream;
  final double width;
  final double height;

  const SpectrogramWidget({
    super.key,
    required this.audioStream,
    this.width = 300,
    this.height = 75,
  });

  @override
  State<SpectrogramWidget> createState() => _SpectrogramWidgetState();
}

class _SpectrogramWidgetState extends State<SpectrogramWidget> with TickerProviderStateMixin {
  final List<List<double>> _spectrogramData = [];
  final int _fftSize = 512;
  final int _sampleRate = 32000;
  late FFT _fft;
  StreamSubscription<Float32List>? _audioSubscription;
  late AnimationController _animationController;
  int _lastUpdateFrame = 0;

  // Calculate max time slices for exactly 5 seconds of data
  // Audio chunks: 3200 samples = 0.1 seconds at 32kHz
  // Hop size: 256 samples (50% overlap)
  // Windows per chunk: (3200 - 512) / 256 + 1 ≈ 11 windows
  // 5 seconds = 50 chunks = 550 time slices
  final int _maxTimeSlices = 550;

  @override
  void initState() {
    super.initState();
    print('SpectrogramWidget: initState called');
    _fft = FFT(_fftSize);
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    _subscribeToAudioStream();
  }

  void _subscribeToAudioStream() {
    print('Spectrogram: Subscribing to audio stream...');
    _audioSubscription?.cancel();
    _audioSubscription = widget.audioStream.listen(
      (audioData) {
        if (mounted) {
          print('Spectrogram: Received ${audioData.length} samples');
          _processAudioChunk(audioData);
        }
      },
      onError: (error) {
        print('Spectrogram: Stream error: $error');
      },
      onDone: () {
        print('Spectrogram: Stream done');
      },
    );
    print('Spectrogram: Subscription created');
  }

  @override
  void didUpdateWidget(SpectrogramWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioStream != widget.audioStream) {
      _subscribeToAudioStream();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioSubscription?.cancel();
    super.dispose();
  }

  void _processAudioChunk(Float32List audioData) {
    // Process all windows first, then update UI only once per chunk
    bool dataAdded = false;

    // For chunks smaller than FFT size, pad with zeros
    if (audioData.length < _fftSize) {
      final paddedData = Float32List(_fftSize);
      for (int i = 0; i < audioData.length; i++) {
        paddedData[i] = audioData[i];
      }
      final spectrum = _computeSpectrum(paddedData);

      _spectrogramData.add(spectrum);
      if (_spectrogramData.length > _maxTimeSlices) {
        _spectrogramData.removeAt(0);
      }
      dataAdded = true;
    } else {
      // Process the audio data in overlapping windows
      const int hopSize = 256; // 50% overlap
      final int numWindows = (audioData.length - _fftSize) ~/ hopSize + 1;

      for (int i = 0; i < numWindows; i++) {
        final int start = i * hopSize;
        final int end = start + _fftSize;

        if (end <= audioData.length) {
          final window = audioData.sublist(start, end);
          final spectrum = _computeSpectrum(window);

          _spectrogramData.add(spectrum);

          // Keep only the most recent time slices (remove from beginning for right-to-left scroll)
          if (_spectrogramData.length > _maxTimeSlices) {
            _spectrogramData.removeAt(0);
          }
          dataAdded = true;
        }
      }
    }

    // Update UI only once per audio chunk
    if (dataAdded && mounted) {
      setState(() {});
    }
  }

  List<double> _computeSpectrum(Float32List window) {
    // Apply Hann window to reduce spectral leakage
    final windowed = Float64List(_fftSize);
    for (int i = 0; i < _fftSize; i++) {
      final hannValue = 0.5 * (1 - cos(2 * pi * i / (_fftSize - 1)));
      windowed[i] = window[i] * hannValue;
    }

    // Compute FFT
    final fftResult = _fft.realFft(windowed);

    // Compute magnitude spectrum (only positive frequencies)
    final spectrum = <double>[];
    final nyquistBin = _fftSize ~/ 2;

    for (int i = 0; i < nyquistBin; i++) {
      // Extract real and imaginary parts from Float64x2
      final real = fftResult[i].x;
      final imag = fftResult[i].y;
      final magnitude = sqrt(real * real + imag * imag);

      // Convert to dB scale with a floor to avoid log(0)
      final magnitudeDb = 20 * log(max(magnitude, 1e-10)) / ln10;
      spectrum.add(magnitudeDb);
    }

    return spectrum;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _spectrogramData.isEmpty
          ? const Center(
              child: Text(
                'Waiting for audio data...',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RepaintBoundary(
              child: CustomPaint(
                painter: SpectrogramPainter(_spectrogramData, DateTime.now().millisecondsSinceEpoch),
                size: Size(widget.width, widget.height),
                child: Container(), // Force repaint
              ),
            ),
    );
  }
}

class SpectrogramPainter extends CustomPainter {
  final List<List<double>> spectrogramData;
  final int timestamp;

  SpectrogramPainter(this.spectrogramData, this.timestamp);

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrogramData.isEmpty) return;

    final paint = Paint();
    final timeSlices = spectrogramData.length;
    final freqBins = spectrogramData[0].length;

    // Calculate cell dimensions
    final cellWidth = size.width / timeSlices;
    final cellHeight = size.height / freqBins;

    // Find global min/max for normalization
    double minDb = double.infinity;
    double maxDb = double.negativeInfinity;

    for (final slice in spectrogramData) {
      for (final value in slice) {
        minDb = min(minDb, value);
        maxDb = max(maxDb, value);
      }
    }

    final dbRange = maxDb - minDb;
    if (dbRange == 0) return;

    // Draw spectrogram (newest data on right, oldest on left)
    for (int t = 0; t < timeSlices; t++) {
      for (int f = 0; f < freqBins; f++) {
        final dbValue = spectrogramData[t][f];
        final normalizedValue = (dbValue - minDb) / dbRange;

        // Create color based on magnitude (blue to red colormap)
        final color = _getSpectrogramColor(normalizedValue);
        paint.color = color;

        // Calculate x position: newest data (last in array) appears on the right
        // Map array index t to screen position from left to right
        final xPosition = t * cellWidth;

        // Draw from bottom (low frequency) to top (high frequency)
        final rect = Rect.fromLTWH(
          xPosition,
          size.height - (f + 1) * cellHeight, // Flip Y axis
          cellWidth,
          cellHeight,
        );

        canvas.drawRect(rect, paint);
      }
    }

    // Draw frequency axis labels
    _drawFrequencyLabels(canvas, size, freqBins);
  }

  Color _getSpectrogramColor(double normalizedValue) {
    // Clamp the value between 0 and 1
    normalizedValue = normalizedValue.clamp(0.0, 1.0);

    // Blue to cyan to yellow to red colormap
    if (normalizedValue < 0.25) {
      // Blue to cyan
      final t = normalizedValue * 4;
      return Color.lerp(Colors.blue[900]!, Colors.cyan, t)!;
    } else if (normalizedValue < 0.5) {
      // Cyan to green
      final t = (normalizedValue - 0.25) * 4;
      return Color.lerp(Colors.cyan, Colors.green, t)!;
    } else if (normalizedValue < 0.75) {
      // Green to yellow
      final t = (normalizedValue - 0.5) * 4;
      return Color.lerp(Colors.green, Colors.yellow, t)!;
    } else {
      // Yellow to red
      final t = (normalizedValue - 0.75) * 4;
      return Color.lerp(Colors.yellow, Colors.red, t)!;
    }
  }

  void _drawFrequencyLabels(Canvas canvas, Size size, int freqBins, {bool drawLabels = false}) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    const sampleRate = 32000;
    final nyquistFreq = sampleRate / 2;

    if (drawLabels) {
      // Draw a few frequency labels
      for (int i = 0; i < 4; i++) {
        final freqBin = (i * freqBins / 4).round();
        final frequency = (freqBin * nyquistFreq / freqBins).round();

        textPainter.text = TextSpan(
          text: '${frequency}Hz',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );

        textPainter.layout();

        final y = size.height - (freqBin * size.height / freqBins) - textPainter.height / 2;
        textPainter.paint(canvas, Offset(2, y));
      }
    }
  }

  @override
  bool shouldRepaint(SpectrogramPainter oldDelegate) {
    return oldDelegate.spectrogramData != spectrogramData || oldDelegate.timestamp != timestamp;
  }
}