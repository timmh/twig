import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

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
    final startIndex = (_writeIndex - _size + startOffset + capacity) % capacity;
    
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
  static const int maxBufferSize = sampleRate * 7; // Reduced to 7 seconds of audio
  static const int sampleRate = 32000;
  static const int segmentDurationSeconds = 5;
  static const int overlapSeconds = 1;
  static const int segmentSamples = sampleRate * segmentDurationSeconds;
  static const int stepSamples = sampleRate * (segmentDurationSeconds - overlapSeconds);
  
  // Pre-allocate conversion buffer to avoid repeated allocations
  static final List<double> _conversionBuffer = <double>[];

  Stream<Float32List> get audioSegmentStream => _audioStreamController!.stream;
  Stream<Float32List> get rawAudioStream => _rawAudioStreamController!.stream;

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

      // Emit raw audio data for spectrogram - send all samples for real-time display
      if (samples.isNotEmpty) {
        _rawAudioStreamController?.add(Float32List.fromList(samples));
        print('Emitted ${samples.length} samples to raw audio stream');
      }

      print('Buffer size: ${_audioBuffer?.length ?? 0} / $segmentSamples needed for segment');
      
      // Process segments when we have enough data
      _processAudioBuffer();
    });

    // Start timer for periodic segment extraction
    _segmentTimer = Timer.periodic(
      Duration(milliseconds: (stepSamples * 1000 / sampleRate).round()),
      (_) => _processAudioBuffer(),
    );
  }

  List<double> _convertPcm16ToFloat32(Uint8List pcmData) {
    final samples = <double>[];
    for (int i = 0; i < pcmData.length; i += 2) {
      if (i + 1 < pcmData.length) {
        // Convert 16-bit PCM to float32 normalized to [-1, 1]
        final sample = (pcmData[i] | (pcmData[i + 1] << 8));
        final normalizedSample = sample < 32768 ? sample / 32768.0 : (sample - 65536) / 32768.0;
        samples.add(normalizedSample);
      }
    }
    print('Converted ${samples.length} samples from ${pcmData.length} bytes');
    return samples;
  }

  void _processAudioBuffer() {
    final buffer = _audioBuffer;
    if (buffer == null) return;

    while (buffer.length >= segmentSamples) {
      // Extract 5-second segment from the start of the buffer
      final segment = buffer.getSegment(segmentSamples, 0);

      print('Generated audio segment: ${segment.length} samples');

      // Emit the segment
      _audioStreamController?.add(segment);

      // Remove processed samples (step by overlap amount)
      buffer.removeFromStart(stepSamples);
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
  }

  void dispose() {
    stopRecording();
    _recorder.dispose();
  }
}