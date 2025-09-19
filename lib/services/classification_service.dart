import 'dart:async';
import 'dart:typed_data';
import 'audio_service.dart';
import 'model_service.dart';

class ClassificationService {
  final AudioService _audioService = AudioService();
  final ModelService _modelService = ModelService();
  
  StreamController<List<SpeciesPrediction>>? _predictionsController;
  StreamSubscription<Float32List>? _audioSubscription;
  bool _isRunning = false;
  
  // Track recent predictions to avoid memory leaks
  final List<List<SpeciesPrediction>> _recentPredictions = [];
  static const int maxRecentPredictions = 5; // Reduced from 10
  
  // Throttling to reduce inference frequency
  DateTime _lastInferenceTime = DateTime(0);
  static const Duration inferenceThrottle = Duration(milliseconds: 2000); // Process every 2 seconds max
  
  // Model unloading for memory management
  Timer? _modelUnloadTimer;
  static const Duration modelUnloadDelay = Duration(seconds: 30);

  Stream<List<SpeciesPrediction>> get predictionsStream =>
      _predictionsController!.stream;

  AudioService get audioService => _audioService;

  Future<void> initialize() async {
    await _modelService.initialize();
  }

  Future<void> startClassification() async {
    if (_isRunning) return;

    if (!_modelService.isInitialized) {
      await initialize();
    }

    _predictionsController = StreamController<List<SpeciesPrediction>>.broadcast();
    _isRunning = true;


    // Start audio recording
    await _audioService.startRecording();

    // Subscribe to audio segments and run inference
    _audioSubscription = _audioService.audioSegmentStream.listen(
      (audioSegment) async {
        // Throttle inference to reduce memory pressure
        final now = DateTime.now();
        if (now.difference(_lastInferenceTime) < inferenceThrottle) {
          print('Skipping inference - throttled');
          return; // Skip this segment
        }
        _lastInferenceTime = now;
        print('Processing audio segment for inference');
        
        try {
          final result = await _modelService.runInference(audioSegment);
          if (_isRunning) {
            // Limit stored predictions to prevent memory growth
            _recentPredictions.add(result.topPredictions);
            if (_recentPredictions.length > maxRecentPredictions) {
              _recentPredictions.removeAt(0);
            }
            
            _predictionsController?.add(result.topPredictions);
            print('Sent ${result.topPredictions.length} predictions to UI');
          }
        } catch (e) {
          // Log error but continue processing
          print('Classification error: $e');
        }
      },
      onError: (error) {
        print('Audio stream error: $error');
      },
    );
  }

  Future<void> stopClassification() async {
    if (!_isRunning) return;

    _isRunning = false;
    await _audioSubscription?.cancel();
    await _audioService.stopRecording();
    await _predictionsController?.close();
    
    // Clear recent predictions to free memory
    _recentPredictions.clear();
    
    
    // Schedule model unloading to free memory after inactivity
    _modelUnloadTimer?.cancel();
    _modelUnloadTimer = Timer(modelUnloadDelay, () {
      if (!_isRunning) {
        _modelService.dispose();
        print('Model unloaded to free memory');
      }
    });
  }

  void dispose() {
    _modelUnloadTimer?.cancel();
    stopClassification();
    _audioService.dispose();
    _modelService.dispose();
  }
}