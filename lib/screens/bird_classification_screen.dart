import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../services/classification_service.dart';
import '../services/model_service.dart';
import '../widgets/spectrogram_widget.dart';
import 'species_detail_screen.dart';
import 'licenses_screen.dart';
import 'about_screen.dart';

class BirdClassificationScreen extends StatefulWidget {
  const BirdClassificationScreen({super.key});

  @override
  State<BirdClassificationScreen> createState() => _BirdClassificationScreenState();
}

class _BirdClassificationScreenState extends State<BirdClassificationScreen> with WidgetsBindingObserver {
  final ClassificationService _classificationService = ClassificationService();
  final AudioRecorder _recorder = AudioRecorder();
  List<SpeciesPrediction> _currentPredictions = [];
  bool _isRecording = false;
  bool _isInitializing = false;
  String? _errorMessage;
  bool _hasPermission = false; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeService();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      setState(() {
        _hasPermission = hasPermission;
      });
      
      // Log the permission status for debugging
      print('Has microphone permission: $hasPermission');
      
      // Auto-start recording if we have permissions and initialization is complete
      _tryAutoStartRecording();
    } catch (e) {
      print('Error checking permissions: $e');
      setState(() {
        _hasPermission = false;
      });
    }
  }

  Future<void> _initializeService() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      await _classificationService.initialize();
      setState(() {
        _isInitializing = false;
      });
      
      // Auto-start recording if we have permissions and initialization is now complete
      _tryAutoStartRecording();
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  void _tryAutoStartRecording() {
    // Only auto-start if:
    // 1. We have permissions
    // 2. Initialization is complete
    // 3. We're not already recording
    // 4. There's no error message
    if (_hasPermission && !_isInitializing && !_isRecording && _errorMessage == null) {
      print('Auto-starting recording...');
      _startRecording();
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      // Double-check permissions before starting
      await _checkPermissions();
      if (!_hasPermission) {
        setState(() {
          _errorMessage = 'Microphone permission is required to start recording';
        });
        return;
      }

      await _classificationService.startClassification();
      
      // Listen to predictions
      _classificationService.predictionsStream.listen(
        (predictions) {
          print('UI received ${predictions.length} predictions');
          setState(() {
            _currentPredictions = predictions;
          });
        },
        onError: (error) {
          setState(() {
            _errorMessage = 'Recording error: $error';
            _isRecording = false;
          });
        },
      );

      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      final errorStr = e.toString();
      setState(() {
        if (errorStr.contains('Microphone permission denied')) {
          _errorMessage = 'Microphone permission denied. Please grant access and try again.';
          _hasPermission = false; // Update permission status
        } else {
          _errorMessage = 'Failed to start recording: $e';
        }
      });
    }
  }

  Future<void> _openAppSettings() async {
    // This will need to be handled by the user manually
    // since we removed permission_handler package
    setState(() {
      _errorMessage = 'Please go to iOS Settings > Privacy & Security > Microphone and enable access for Twig';
    });
  }

  Future<void> _requestPermission() async {
    try {
      print('Requesting microphone permission...');
      
      // The record package will automatically show the permission dialog
      // when we try to start recording. Let's check current status first.
      final hasPermission = await _recorder.hasPermission();
      print('Current permission status: $hasPermission');
      
      if (!hasPermission) {
        // Try to start a temporary recording to trigger permission dialog
        try {
          await _recorder.start(const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            numChannels: 1,
          ), path: '');
          await _recorder.stop();
          
          // Check permission again after the attempt
          final newPermission = await _recorder.hasPermission();
          setState(() {
            _hasPermission = newPermission;
            if (newPermission) {
              _errorMessage = null;
            } else {
              _errorMessage = 'Microphone permission denied. Please enable it in Settings.';
            }
          });
          
          // Try to auto-start recording if permission was granted
          if (newPermission) {
            _tryAutoStartRecording();
          }
        } catch (e) {
          print('Error during permission request: $e');
          setState(() {
            _hasPermission = false;
            _errorMessage = 'Microphone permission denied. Please enable it in Settings.';
          });
        }
      } else {
        setState(() {
          _hasPermission = true;
          _errorMessage = null;
        });
        
        // Try to auto-start recording if we already have permission
        _tryAutoStartRecording();
      }
      
      // Refresh the permission status
      await _checkPermissions();
    } catch (e) {
      print('Error requesting permission: $e');
      setState(() {
        _errorMessage = 'Error requesting permission: $e';
        _hasPermission = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _classificationService.stopClassification();
      setState(() {
        _isRecording = false;
        _currentPredictions = [];
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to stop recording: $e';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check permissions when returning from settings
      print('App resumed, checking permissions...');
      _checkPermissions(); // This will call _tryAutoStartRecording if conditions are met
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _classificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twig'),
        backgroundColor: const Color(0xFF549342),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'about':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutScreen(),
                    ),
                  );
                  break;
                case 'licenses':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LicensesScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info),
                    SizedBox(width: 8),
                    Text('About'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'licenses',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('Licenses'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRecording ? Icons.mic : Icons.mic_off,
                          color: _isRecording ? Colors.red : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRecording ? 'Recording...' : 'Not Recording',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Permission status
                    if (!_hasPermission)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _hasPermission ? Icons.check_circle : Icons.error,
                            color: _hasPermission ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _hasPermission ? 'Microphone access granted' : 'Microphone access needed',
                            style: TextStyle(
                              color: _hasPermission ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 12),
                    
                    // Request permission button if not granted
                    if (!_hasPermission)
                      ElevatedButton.icon(
                        onPressed: _requestPermission,
                        icon: const Icon(Icons.mic),
                        label: const Text('Grant Microphone Access'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    
                    if (_hasPermission) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isInitializing ? null : _toggleRecording,
                        icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                        label: Text(_isRecording ? 'Stop' : 'Start Recording'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // Spectrogram - show when recording
            if (_isRecording)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: SpectrogramWidget(
                          audioStream: _classificationService.audioService.rawAudioStream,
                          width: MediaQuery.of(context).size.width - 64,
                          height: 75,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isRecording)
              const SizedBox(height: 20),

            // Error Message
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      if (_errorMessage!.contains('Microphone permission denied')) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Please enable microphone access in Settings to use bird classification.',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _openAppSettings,
                          icon: const Icon(Icons.settings),
                          label: const Text('Open Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Initialization Loading
            if (_isInitializing)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Initializing model...'),
                    ],
                  ),
                ),
              ),

            // Predictions
            if (_isRecording && _currentPredictions.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top 3 Species Detected:',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _currentPredictions.length,
                            itemBuilder: (context, index) {
                              final prediction = _currentPredictions[index];
                              final confidence = (prediction.confidence * 100).toStringAsFixed(1);
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SpeciesDetailScreen(
                                          prediction: prediction,
                                        ),
                                      ),
                                    );
                                  },
                                  leading: CircleAvatar(
                                    backgroundColor: _getConfidenceColor(prediction.confidence),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    prediction.speciesName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text('Confidence: $confidence%'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: LinearProgressIndicator(
                                          value: prediction.confidence,
                                          backgroundColor: Colors.grey.shade300,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _getConfidenceColor(prediction.confidence),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Instructions when not recording
            if (!_isRecording && !_isInitializing && _errorMessage == null)
              const Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pets,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Tap "Start Recording" to begin bird classification',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'The app will analyze 5-second audio segments and show the top 3 most likely species.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green;
    if (confidence > 0.4) return Colors.orange;
    return Colors.red;
  }
}