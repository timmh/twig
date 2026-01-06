import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:system_info2/system_info2.dart';

class RingBuffer {
  late final Float32List _buffer;
  int _writeIndex = 0;
  int _size = 0;
  final int capacity;

  RingBuffer(this.capacity) {
    _buffer = Float32List(capacity);
  }

  void addAll(List<double> samples) {
    for (final sample in samples) {
      add(sample);
    }
  }

  void add(double sample) {
    _buffer[_writeIndex] = sample;
    _writeIndex = (_writeIndex + 1) % capacity;
    if (_size < capacity) {
      _size++;
    }
  }

  int get length => _size;

  bool get isFull => _size == capacity;

  Float32List getSegment(int segmentLength, int startOffset) {
    if (startOffset + segmentLength > _size) {
      throw ArgumentError('Segment extends beyond available data');
    }

    final segment = Float32List(segmentLength);
    final startIndex =
        (_writeIndex - _size + startOffset + capacity) % capacity;

    for (int i = 0; i < segmentLength; i++) {
      final bufferIndex = (startIndex + i) % capacity;
      segment[i] = _buffer[bufferIndex];
    }

    return segment;
  }

  void removeFromStart(int count) {
    if (count > _size) {
      count = _size;
    }
    _size -= count;
  }

  void clear() {
    _writeIndex = 0;
    _size = 0;
  }
}

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamController<Float32List>? _audioStreamController;
  StreamController<Float32List>? _rawAudioStreamController;
  Timer? _segmentTimer;
  bool _isRecording = false;

  RingBuffer? _audioBuffer;
  static const int maxBufferSize =
      sampleRate * 7; // Reduced to 7 seconds of audio
  static const int sampleRate = 32000;
  static const double _defaultSegmentDurationSeconds = 5;
  static const double _lowMemorySegmentDurationSeconds = 2.5;
  static const double _overlapSeconds = 1;
  static const int _lowMemoryThresholdBytes = 4 * 1024 * 1024 * 1024;

  late final double _segmentDurationSeconds;
  late final int _segmentSamples;
  late final int _stepSamples;
  late final bool _isLowMemoryDevice;

  // Pre-allocate buffers to avoid repeated allocations
  List<double>? _conversionBuffer;
  Float32List? _rawAudioBuffer;

  Stream<Float32List> get audioSegmentStream => _audioStreamController!.stream;
  Stream<Float32List> get rawAudioStream => _rawAudioStreamController!.stream;

  double get segmentDurationSeconds => _segmentDurationSeconds;
  int get segmentSamples => _segmentSamples;
  bool get isLowMemoryDevice => _isLowMemoryDevice;

  AudioService() {
    _configureSegmentSettings();
  }

  Future<bool> requestPermissions() async {
    // Use the record package's built-in permission handling
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    _audioStreamController = StreamController<Float32List>.broadcast();
    _rawAudioStreamController = StreamController<Float32List>.broadcast();
    _audioBuffer = RingBuffer(maxBufferSize);

    // Pre-allocate conversion buffers (typical chunk is ~4096 samples)
    _conversionBuffer = List<double>.filled(8192, 0.0);
    _rawAudioBuffer = Float32List(8192);

    _isRecording = true;

    // Configure recording for 32kHz mono
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      bitRate: 512000,
    );

    // Start streaming audio data
    final stream = await _recorder.startStream(config);

    stream.listen((data) {
      if (!_isRecording) return;

      print('Received audio data: ${data.length} bytes');

      // Convert PCM16 bytes to Float32 samples
      final samples = _convertPcm16ToFloat32(data);
      _audioBuffer?.addAll(samples);

      // Emit raw audio data for spectrogram - reuse buffer to avoid allocation
      if (samples.isNotEmpty) {
        // Reuse pre-allocated Float32List buffer
        if (_rawAudioBuffer!.length < samples.length) {
          _rawAudioBuffer = Float32List(samples.length);
        }
        for (int i = 0; i < samples.length; i++) {
          _rawAudioBuffer![i] = samples[i];
        }
        _rawAudioStreamController?.add(
          _rawAudioBuffer!.sublist(0, samples.length),
        );
        print('Emitted ${samples.length} samples to raw audio stream');
      }

      print(
        'Buffer size: ${_audioBuffer?.length ?? 0} / $_segmentSamples needed for segment',
      );

      // Process segments when we have enough data
      _processAudioBuffer();
    });

    // Start timer for periodic segment extraction
    _segmentTimer = Timer.periodic(
      Duration(milliseconds: (_stepSamples * 1000 / sampleRate).round()),
      (_) => _processAudioBuffer(),
    );
  }

  List<double> _convertPcm16ToFloat32(Uint8List pcmData) {
    final numSamples = pcmData.length ~/ 2;

    // Ensure conversion buffer is large enough
    if (_conversionBuffer!.length < numSamples) {
      _conversionBuffer = List<double>.filled(numSamples, 0.0);
      print('Resized conversion buffer to $numSamples');
    }

    // Convert in place using pre-allocated buffer
    for (int i = 0; i < numSamples; i++) {
      final byteIndex = i * 2;
      final sample = (pcmData[byteIndex] | (pcmData[byteIndex + 1] << 8));
      _conversionBuffer![i] = sample < 32768
          ? sample / 32768.0
          : (sample - 65536) / 32768.0;
    }

    print('Converted $numSamples samples from ${pcmData.length} bytes');

    // Return a view of the buffer (no copy)
    return _conversionBuffer!.sublist(0, numSamples);
  }

  void _processAudioBuffer() {
    final buffer = _audioBuffer;
    if (buffer == null) return;

    while (buffer.length >= _segmentSamples) {
      // Extract configured-duration segment from the start of the buffer
      final segment = buffer.getSegment(_segmentSamples, 0);

      print('Generated audio segment: ${segment.length} samples');

      // Emit the segment
      _audioStreamController?.add(segment);

      // Remove processed samples (step by overlap amount)
      buffer.removeFromStart(_stepSamples);
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    _isRecording = false;
    _segmentTimer?.cancel();

    await _recorder.stop();
    await _audioStreamController?.close();
    await _rawAudioStreamController?.close();

    _audioBuffer?.clear();

    // Clear buffers to free memory
    _conversionBuffer = null;
    _rawAudioBuffer = null;
  }

  void _configureSegmentSettings() {
    int totalMemoryBytes = _lowMemoryThresholdBytes;
    try {
      totalMemoryBytes = SysInfo.getTotalPhysicalMemory();
    } catch (e) {
      print('Unable to determine total device RAM: $e');
    }

    _isLowMemoryDevice = totalMemoryBytes < _lowMemoryThresholdBytes;
    _segmentDurationSeconds = _isLowMemoryDevice
        ? _lowMemorySegmentDurationSeconds
        : _defaultSegmentDurationSeconds;

    _segmentSamples = (_segmentDurationSeconds * sampleRate).round();
    if (_segmentSamples <= 0) {
      _segmentSamples = sampleRate; // Fallback to 1 second of audio
    }

    final stepSeconds = _segmentDurationSeconds - _overlapSeconds;
    final effectiveStepSeconds = stepSeconds > 0
        ? stepSeconds
        : _segmentDurationSeconds;
    _stepSamples = (effectiveStepSeconds * sampleRate).round();
    if (_stepSamples <= 0) {
      _stepSamples = _segmentSamples;
    }

    final totalMemoryMb = totalMemoryBytes ~/ (1024 * 1024);
    print(
      'AudioService configured ${_segmentDurationSeconds.toStringAsFixed(1)}s segments '
      '(${_segmentSamples} samples) for device with ~${totalMemoryMb} MB RAM',
    );
  }

  void dispose() {
    stopRecording();
    _recorder.dispose();
  }
}
