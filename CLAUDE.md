# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Twig is a Flutter mobile app that serves as a frontend to the Perch acoustic classification model. The app integrates with Google Research's Perch bioacoustics model, which can classify bird (and other) species from audio recordings.

### Architecture

- **Flutter App**: Located in the root directory (`lib/`, `android/`, `ios/`, etc.)
- **Perch Model**: Google Research bioacoustics model included as a git submodule (`perch/`)
- **ML Components**: Pre-trained TensorFlow Lite model and weights in `weights/`
- **Python Scripts**: Model conversion and testing utilities (`convert_to_tflite.py`, `example.py`)

### Key Components

1. **Flutter Application**:
   - Main entry point: `lib/main.dart`
   - Currently displays "Hello World" (basic setup)
   - Standard Flutter project structure with platform-specific directories

2. **Perch Integration**:
   - Perch submodule: Contains the full Google Research bioacoustics codebase
   - Pre-trained model: `weights/model.tflite` (TensorFlow Lite format)
   - Class labels: `weights/assets/labels.csv` (10k+ species)
   - eBird classification: `weights/assets/perch_v2_ebird_classes.csv`

3. **ML Pipeline**:
   - Model expects 5 seconds of mono audio at 32 kHz sampling rate
   - Outputs: spectrogram, embeddings, spatial embeddings, and classification logits
   - Uses PCEN melspectrogram frontend with EfficientNet backbone

## Development Commands

### Flutter Commands
```bash
# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Run on specific device
flutter run -d iphone             # iOS Simulator
flutter run -d android         # Android Emulator
flutter run -d chrome          # Web browser

# Build for release
flutter build apk              # Android
flutter build ios             # iOS
flutter build web             # Web

# Run tests
flutter test

# Check for issues
flutter doctor

# Analyze code
flutter analyze

# Clean build files
flutter clean
```

### Perch Model Commands
```bash
# Convert SavedModel to TensorFlow Lite (if needed)
/Users/timm/.micromamba/envs/perch/bin/python3 convert_to_tflite.py

# Test the TFLite model (Note: TFLite runtime unsupported on macOS)
/Users/timm/.micromamba/envs/perch/bin/python3 example.py

# Install Perch dependencies (from perch/ directory)
cd perch
poetry install --with jaxtrain --with nonwindows

# Run Perch tests
cd perch
poetry run python -m unittest discover -s chirp/tests -p "*test.py"
poetry run python -m unittest discover -s chirp/inference/tests -p "*test.py"
```

## File Structure Context

### Flutter App Structure
- `lib/main.dart`: Main application entry point
- `pubspec.yaml`: Flutter dependencies and project configuration
- `analysis_options.yaml`: Dart linting rules (uses `flutter_lints`)
- Platform directories: `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`

### ML Components
- `weights/`: Contains the pre-trained TensorFlow Lite model and associated files
  - `model.tflite`: The main inference model
  - `saved_model.pb`: Original SavedModel format
  - `assets/labels.csv`: Full species classification labels
  - `assets/perch_v2_ebird_classes.csv`: eBird-specific class mappings
- `perch/`: Git submodule containing Google Research's Perch codebase
  - Extensive bioacoustics research toolkit
  - Model training, inference, and evaluation code
  - Supports multiple model architectures (EfficientNet, Conformer, etc.)

### Perch Model Architecture
The Perch model uses:
- **Frontend**: PCEN (Per-Channel Energy Normalization) melspectrogram
- **Backbone**: EfficientNet for feature extraction
- **Output**: Multi-head classification for 10k+ species
- **Training**: Uses JAX/Flax framework with Poetry for dependency management

### Integration Points
- The Flutter app will need to integrate TensorFlow Lite for on-device inference
- Audio processing will require microphone access and real-time audio capture
- The model expects specific audio preprocessing (32 kHz mono, 5-second windows)
- Classification results should map to the provided species labels

## Implementation Overview

The Flutter app has been implemented with the following features:

### Core Services
1. **AudioService** (`lib/services/audio_service.dart`):
   - Records continuous audio from microphone at 32kHz mono
   - Processes audio in 5-second segments with 2-second overlaps
   - Converts PCM16 audio to Float32 format for model input
   - Handles permissions and streaming

2. **ModelService** (`lib/services/model_service.dart`):
   - Loads and initializes the TensorFlow Lite Perch model
   - Processes 160,000-sample audio segments (5 seconds × 32kHz)
   - Returns top predictions with confidence scores
   - Manages species labels from CSV files

3. **ClassificationService** (`lib/services/classification_service.dart`):
   - Coordinates audio recording and model inference
   - Streams real-time predictions to the UI
   - Handles errors and service lifecycle

### User Interface
- **BirdClassificationScreen** (`lib/screens/bird_classification_screen.dart`):
  - Real-time recording status and controls
  - Continuously updated list of top 3 species predictions
  - Confidence scores with visual indicators
  - Error handling and user feedback

### Model Integration
- Uses `tflite_flutter` package for on-device inference
- Model and labels are bundled as Flutter assets
- Supports the full Perch v2 model with 10k+ species classification
- Audio preprocessing matches the Python example in `example.py`

## Setup Requirements

### iOS Development
1. Install Xcode and complete setup:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

2. Update CocoaPods:
   ```bash
   sudo gem install cocoapods
   ```

3. Install iOS pods:
   ```bash
   cd ios && pod install
   ```

### Running the App
1. The app requires microphone permissions (already configured in iOS Info.plist)
2. Run with: `flutter run -d iphone` for iOS simulator
3. The app will show permission status and provide buttons to grant access
4. Tap "Grant Microphone Access" if needed, then "Start Recording" to begin classification

### Permission Handling
- App checks microphone permission status on startup
- Provides clear UI feedback about permission state
- "Grant Microphone Access" button to request permissions
- "Open Settings" button if permissions are permanently denied
- Visual indicators show current permission status

## Technical Notes

- Audio buffer management ensures smooth overlapping segments
- Model inference runs on device using TensorFlow Lite
- UI updates in real-time as new predictions arrive
- Error handling for permissions, model loading, and audio processing
- The project uses Git submodules (Perch is included as a submodule)
- When testing code changes, NEVER rely on flutter's hot reload, ALWAYS fully restart the app
- When running `flutter run`, always do this the background and check the output periodically