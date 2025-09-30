import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<String> _labels = [];
  List<String?> _scientificNames = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure TensorFlow Lite options for memory efficiency
      final options = InterpreterOptions()
        ..threads = 1  // Use single thread to reduce memory overhead
        ..useNnApiForAndroid = false;  // Disable NNAPI to avoid additional memory
      
      // Load the TFLite model with optimized options
      _interpreter = await Interpreter.fromAsset('weights/model_float16.tflite', options: options);

      // Important: allocate tensors first (like Python example)
      _interpreter!.allocateTensors();

      // Create the isolate interpreter for background inference
      _isolateInterpreter = await IsolateInterpreter.create(address: _interpreter!.address);

      // Load species labels
      await _loadLabels();

      _isInitialized = true;
      print('Model initialized successfully');
      print('IsolateInterpreter created for background inference');
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output tensors: ${_interpreter!.getOutputTensors().length}');
      for (int i = 0; i < _interpreter!.getOutputTensors().length; i++) {
        print('Output $i shape: ${_interpreter!.getOutputTensor(i).shape}');
        print('Output $i name: ${_interpreter!.getOutputTensor(i).name}');
      }
    } catch (e) {
      print('Error initializing model: $e');
      rethrow;
    }
  }

  List<String> _parseCsvRow(String row) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < row.length; i++) {
      final char = row[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }

    result.add(current.toString().trim());
    return result;
  }

  Future<void> _loadLabels() async {
    try {
      // Load enhanced labels with common names
      final labelsData = await rootBundle.loadString('weights/assets/enhanced_labels.csv');
      final lines = labelsData.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      // Skip header row and extract both scientific and display names
      final labelData = lines.skip(1).map((line) {
        final parts = _parseCsvRow(line);
        if (parts.length >= 3) {
          final scientificName = parts[0].trim();
          final displayName = parts[2].trim();
          return {
            'scientific': scientificName.isEmpty ? null : scientificName,
            'display': displayName,
          };
        } else if (parts.isNotEmpty) {
          // Fallback to original label
          return {
            'scientific': null,
            'display': parts[0].trim(),
          };
        } else {
          return {
            'scientific': null,
            'display': '',
          };
        }
      }).where((data) => data['display']!.isNotEmpty).toList();

      // Extract labels and scientific names separately
      _labels = labelData.map((data) => data['display']!).toList();
      _scientificNames = labelData.map((data) => data['scientific']).toList();

      print('Loaded ${_labels.length} enhanced species labels with common names');
    } catch (e) {
      print('Error loading enhanced labels: $e');
      // Fallback to original labels if enhanced labels fail
      try {
        final labelsData = await rootBundle.loadString('weights/assets/labels.csv');
        _labels = labelsData.split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        print('Loaded ${_labels.length} fallback species labels');
      } catch (fallbackError) {
        print('Error loading fallback labels: $fallbackError');
        rethrow;
      }
    }
  }

  Future<ModelInferenceResult> runInference(Float32List audioWaveform) async {
    if (!_isInitialized) {
      throw Exception('Model not initialized');
    }

    if (_isolateInterpreter == null) {
      throw Exception('IsolateInterpreter is null');
    }

    if (audioWaveform.length != 160000) { // 5 seconds * 32000 Hz
      throw Exception('Audio waveform must be exactly 160000 samples (5 seconds at 32kHz)');
    }

    try {
      print('Running inference in isolate using IsolateInterpreter');
      print('Input waveform length: ${audioWaveform.length}');

      // Prepare input  - must wrap audio in list for TFLite
      final input = [audioWaveform];

      // Allocate fresh output buffers for each inference
      final outputs = <int, Object>{};
      final numOutputs = _interpreter!.getOutputTensors().length;

      for (int i = 0; i < numOutputs; i++) {
        final tensorShape = _interpreter!.getOutputTensor(i).shape;

        if (tensorShape.length == 1) {
          outputs[i] = List.filled(tensorShape[0], 0.0);
        } else if (tensorShape.length == 2) {
          outputs[i] = List.generate(tensorShape[0],
            (_) => List.filled(tensorShape[1], 0.0));
        } else if (tensorShape.length == 3) {
          outputs[i] = List.generate(tensorShape[0],
            (_) => List.generate(tensorShape[1],
              (_) => List.filled(tensorShape[2], 0.0)));
        } else if (tensorShape.length == 4) {
          outputs[i] = List.generate(tensorShape[0],
            (_) => List.generate(tensorShape[1],
              (_) => List.generate(tensorShape[2],
                (_) => List.filled(tensorShape[3], 0.0))));
        }
      }

      // Run inference in isolate using IsolateInterpreter
      await _isolateInterpreter!.runForMultipleInputs([input], outputs);

      print('Isolate inference completed successfully!');

      // Find the classification output tensor (should be the largest 2D tensor)
      int classificationTensorIndex = -1;
      int maxOutputSize = 0;

      for (int i = 0; i < numOutputs; i++) {
        final output = outputs[i];
        if (output is List<List<double>>) {
          final outputSize = output[0].length;
          if (outputSize > maxOutputSize) {
            maxOutputSize = outputSize;
            classificationTensorIndex = i;
          }
        }
      }

      if (classificationTensorIndex == -1) {
        throw Exception('Could not find classification output tensor');
      }

      final classificationOutput = outputs[classificationTensorIndex] as List<List<double>>;
      final rawLogits = Float32List.fromList(classificationOutput[0]);

      // Apply softmax to convert logits to probabilities
      final classificationScores = _applySoftmax(rawLogits);

      final predictions = _getTopPredictionsOptimized(classificationScores);

      print('Generated ${predictions.length} predictions');
      if (predictions.isNotEmpty) {
        print('Top prediction: ${predictions[0]}');
      }

      return ModelInferenceResult(
        topPredictions: predictions,
        allScores: [],
      );
    } catch (e) {
      print('Error during inference: $e');
      rethrow;
    }
  }


  Float32List _applySoftmax(Float32List logits) {
    // Find the maximum value for numerical stability
    double maxLogit = logits[0];
    for (int i = 1; i < logits.length; i++) {
      if (logits[i] > maxLogit) {
        maxLogit = logits[i];
      }
    }

    // Compute exp(logit - max) and sum
    final expValues = Float32List(logits.length);
    double sum = 0.0;
    for (int i = 0; i < logits.length; i++) {
      expValues[i] = math.exp(logits[i] - maxLogit);
      sum += expValues[i];
    }

    // Normalize to get probabilities
    final probabilities = Float32List(logits.length);
    for (int i = 0; i < logits.length; i++) {
      probabilities[i] = expValues[i] / sum;
    }

    return probabilities;
  }

  List<SpeciesPrediction> _getTopPredictionsOptimized(Float32List classificationOutput) {
    // Use the scores directly (already Float32List)
    final scores = classificationOutput;

    // Find top 3 without creating full intermediate lists
    double top1Score = -1.0, top2Score = -1.0, top3Score = -1.0;
    int top1Index = -1, top2Index = -1, top3Index = -1;

    final maxIndex = scores.length < _labels.length ? scores.length : _labels.length;
    for (int i = 0; i < maxIndex; i++) {
      final score = scores[i].toDouble();

      if (score > top1Score) {
        // Shift previous values down
        top3Score = top2Score;
        top3Index = top2Index;
        top2Score = top1Score;
        top2Index = top1Index;
        // Set new top
        top1Score = score;
        top1Index = i;
      } else if (score > top2Score) {
        // Shift previous values down
        top3Score = top2Score;
        top3Index = top2Index;
        // Set new second
        top2Score = score;
        top2Index = i;
      } else if (score > top3Score) {
        // Set new third
        top3Score = score;
        top3Index = i;
      }
    }

    // Return top predictions
    final result = <SpeciesPrediction>[];
    if (top1Index >= 0) {
      result.add(SpeciesPrediction(
        speciesName: _labels[top1Index],
        scientificName: top1Index < _scientificNames.length ? _scientificNames[top1Index] : null,
        confidence: top1Score,
        index: top1Index,
      ));
    }
    if (top2Index >= 0) {
      result.add(SpeciesPrediction(
        speciesName: _labels[top2Index],
        scientificName: top2Index < _scientificNames.length ? _scientificNames[top2Index] : null,
        confidence: top2Score,
        index: top2Index,
      ));
    }
    if (top3Index >= 0) {
      result.add(SpeciesPrediction(
        speciesName: _labels[top3Index],
        scientificName: top3Index < _scientificNames.length ? _scientificNames[top3Index] : null,
        confidence: top3Score,
        index: top3Index,
      ));
    }

    return result;
  }

  void dispose() {
    _isolateInterpreter?.close();
    _interpreter?.close();
    _labels.clear();
    _scientificNames.clear();
    _isInitialized = false;
  }
}


class ModelInferenceResult {
  final List<SpeciesPrediction> topPredictions;
  final List<double> allScores;

  ModelInferenceResult({
    required this.topPredictions,
    required this.allScores,
  });
}

class SpeciesPrediction {
  final String speciesName;
  final String? scientificName;
  final double confidence;
  final int index;

  SpeciesPrediction({
    required this.speciesName,
    this.scientificName,
    required this.confidence,
    required this.index,
  });

  @override
  String toString() {
    return '$speciesName (${(confidence * 100).toStringAsFixed(1)}%)';
  }
}