from matplotlib import pyplot as plt
import numpy as np
import tensorflow as tf

# Load the TFLite model and allocate tensors.
interpreter = tf.lite.Interpreter(
    model_path="weights/model.tflite",
)
interpreter.allocate_tensors()

# Get input and output tensors.
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Input: 5 seconds of silence as mono 32 kHz waveform samples.
waveform = np.random.uniform(-1, 1, 5 * 32000).astype(np.float32)

# Set the input tensor.
interpreter.set_tensor(input_details[0]['index'], waveform[np.newaxis, :])

# Run the model.
interpreter.invoke()

# The TFLite model returns a list of outputs. To access them by name like
# the original model, we can build a dictionary.
model_outputs = {
    output['name'].split(';')[-1]: interpreter.get_tensor(output['index'])
    for output in output_details
}


print(model_outputs[-1])

# Examine the spectrogram.
# plt.imshow(model_outputs['spectrogram'][0].T)

# Examine the embeddings.
print(model_outputs['embedding'].shape)
print(model_outputs['spatial_embedding'].shape)

# Examine the logits.
print(model_outputs['label'].shape)