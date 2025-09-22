# Twig

Twig is a mobile app that acts as an unofficial frontend to the [perch](https://github.com/google-research/perch) acoustic classification model.

## Setup
- [Install Flutter](https://docs.flutter.dev/get-started/install)
- Install the right TensorFlow version for [Perch v2](https://www.kaggle.com/models/google/bird-vocalization-classifier/tensorFlow2/perch_v2), e.g. via `pip install tensorflow==2.20`.
- Run `./scripts/setup.sh` to download and convert the weights into TensorFlow Lite format, and to enhance the model's label list.

## Development
- Use `flutter run` to compile and run the app on Android and iOS