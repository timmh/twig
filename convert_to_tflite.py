import tensorflow as tf
import os

def convert_model_with_strategy(strategy_name, converter_config_func):
    """Convert model with a specific quantization strategy"""
    try:
        converter = tf.lite.TFLiteConverter.from_saved_model("weights")
        converter_config_func(converter)
        tflite_model = converter.convert()
        
        output_path = f'weights/model_{strategy_name}.tflite'
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        
        # Get file size for comparison
        size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"✅ {strategy_name}: {size_mb:.1f} MB - {output_path}")
        return True
        
    except Exception as e:
        print(f"❌ {strategy_name}: {str(e)}")
        return False

# Strategy 1: No quantization (original)
def no_quantization(converter):
    converter.optimizations = []
    converter.target_spec.supported_types = [tf.float32]

# Strategy 2: Float16 quantization (good balance)
def float16_quantization(converter):
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]

# Strategy 3: Dynamic range quantization
def dynamic_range_quantization(converter):
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

# Strategy 4: Representative dataset quantization (most aggressive)
def representative_quantization(converter):
    import numpy as np
    def representative_dataset():
        for _ in range(100):
            # Generate representative audio samples
            yield [np.random.uniform(-1, 1, 160000).astype(np.float32)]
    
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative_dataset
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.uint8
    converter.inference_output_type = tf.uint8

print("Converting model with different quantization strategies...")

# Try each strategy
strategies = [
    ("original", no_quantization),
    ("float16", float16_quantization), 
    ("dynamic", dynamic_range_quantization),
    ("int8", representative_quantization)
]

successful_conversions = []
for name, config_func in strategies:
    if convert_model_with_strategy(name, config_func):
        successful_conversions.append(name)

print(f"\nSuccessful conversions: {successful_conversions}")
print("\nRecommendation: Use 'float16' for best size/compatibility balance")
print("To use a specific model, copy it to 'weights/model.tflite'")