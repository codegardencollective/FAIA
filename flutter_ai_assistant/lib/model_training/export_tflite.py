"""
Export trained model to TensorFlow Lite format with quantization
Based on the paper "Building Cross-Platform AI Assistants with Flutter and TensorFlow"
"""

import os
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing.text import tokenizer_from_json
from tensorflow.keras.preprocessing.sequence import pad_sequences

# Configuration
CONFIG = {
    'model_path': 'models/intent_classifier.h5',
    'tokenizer_path': 'models/tokenizer.json',
    'label_encoder_path': 'models/label_encoder.json',
    'tflite_model_path': 'assets/model.tflite',
    'tflite_quantized_path': 'assets/model_quantized.tflite',
    'model_metadata_path': 'assets/model_metadata.json',
    'max_sequence_length': 32,
    'representative_dataset_size': 100
}

def load_tokenizer_and_labels():
    """Load tokenizer and label encoder"""
    # Load tokenizer
    with open(CONFIG['tokenizer_path'], 'r') as f:
        tokenizer_json = f.read()
    tokenizer = tokenizer_from_json(tokenizer_json)
    
    # Load label encoder
    with open(CONFIG['label_encoder_path'], 'r') as f:
        label_encoder_data = json.load(f)
    
    return tokenizer, label_encoder_data['classes']

def create_representative_dataset(tokenizer):
    """Create representative dataset for quantization"""
    # Sample texts for representative dataset
    sample_texts = [
        "What's the weather like?",
        "What time is it?",
        "Hello there",
        "Play some music",
        "Show me my calendar",
        "What's in the news?",
        "Help me with this",
        "Good morning",
        "Is it going to rain?",
        "Play my favorite song",
        "What's on my schedule?",
        "Tell me a joke",
        "How's the weather today?",
        "What's the current time?",
        "Hi there",
        "Turn on the radio",
        "Check my appointments",
        "What's happening in the world?",
        "What can you do?",
        "Good evening",
    ]
    
    # Convert to sequences
    sequences = tokenizer.texts_to_sequences(sample_texts)
    
    # Pad sequences
    padded_sequences = pad_sequences(
        sequences,
        maxlen=CONFIG['max_sequence_length'],
        padding='post',
        truncating='post'
    )
    
    # Create representative dataset generator
    def representative_dataset():
        for i in range(min(len(padded_sequences), CONFIG['representative_dataset_size'])):
            yield [padded_sequences[i:i+1].astype(np.float32)]
    
    return representative_dataset

def export_tflite_model():
    """Export model to TensorFlow Lite format"""
    # Create assets directory
    os.makedirs('assets', exist_ok=True)
    
    # Load model
    print("Loading trained model...")
    model = load_model(CONFIG['model_path'])
    
    # Load tokenizer and labels
    tokenizer, class_names = load_tokenizer_and_labels()
    
    # Create TensorFlow Lite converter
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Convert to TFLite (float32)
    print("Converting to TensorFlow Lite (float32)...")
    tflite_model = converter.convert()
    
    # Save float32 model
    with open(CONFIG['tflite_model_path'], 'wb') as f:
        f.write(tflite_model)
    
    print(f"Float32 model saved to: {CONFIG['tflite_model_path']}")
    print(f"Float32 model size: {len(tflite_model) / 1024:.2f} KB")
    
    # Create quantized model
    print("Converting to TensorFlow Lite (quantized)...")
    converter_quantized = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Set optimization flags
    converter_quantized.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Set representative dataset for quantization
    representative_dataset = create_representative_dataset(tokenizer)
    converter_quantized.representative_dataset = representative_dataset
    
    # Ensure integer-only quantization
    converter_quantized.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter_quantized.inference_input_type = tf.int8
    converter_quantized.inference_output_type = tf.int8
    
    try:
        # Convert with quantization
        tflite_quantized_model = converter_quantized.convert()
        
        # Save quantized model
        with open(CONFIG['tflite_quantized_path'], 'wb') as f:
            f.write(tflite_quantized_model)
        
        print(f"Quantized model saved to: {CONFIG['tflite_quantized_path']}")
        print(f"Quantized model size: {len(tflite_quantized_model) / 1024:.2f} KB")
        print(f"Compression ratio: {len(tflite_model) / len(tflite_quantized_model):.2f}x")
        
    except Exception as e:
        print(f"Quantization failed: {e}")
        print("Using dynamic range quantization instead...")
        
        # Fallback to dynamic range quantization
        converter_dynamic = tf.lite.TFLiteConverter.from_keras_model(model)
        converter_dynamic.optimizations = [tf.lite.Optimize.DEFAULT]
        
        tflite_quantized_model = converter_dynamic.convert()
        
        with open(CONFIG['tflite_quantized_path'], 'wb') as f:
            f.write(tflite_quantized_model)
        
        print(f"Dynamic quantized model saved to: {CONFIG['tflite_quantized_path']}")
        print(f"Dynamic quantized model size: {len(tflite_quantized_model) / 1024:.2f} KB")
    
    # Create model metadata
    metadata = {
        'model_name': 'Intent Classification Model',
        'model_version': '1.0.0',
        'input_shape': [1, CONFIG['max_sequence_length']],
        'output_shape': [1, len(class_names)],
        'class_names': class_names,
        'max_sequence_length': CONFIG['max_sequence_length'],
        'vocab_size': len(tokenizer.word_index) + 1,
        'preprocessing': {
            'tokenizer_config': tokenizer.get_config(),
            'padding': 'post',
            'truncating': 'post'
        }
    }
    
    # Save metadata
    with open(CONFIG['model_metadata_path'], 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f"Model metadata saved to: {CONFIG['model_metadata_path']}")
    
    # Test the models
    print("\nTesting models...")
    test_inference(CONFIG['tflite_model_path'], tokenizer, class_names)
    test_inference(CONFIG['tflite_quantized_path'], tokenizer, class_names)
    
    print("\nExport completed successfully!")

def test_inference(model_path, tokenizer, class_names):
    """Test inference with the exported model"""
    # Load TFLite model
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    
    # Get input and output tensors
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # Test samples
    test_texts = [
        "What's the weather like?",
        "What time is it?",
        "Hello there",
        "Play some music"
    ]
    
    print(f"\nTesting {model_path}:")
    
    for text in test_texts:
        # Preprocess text
        sequence = tokenizer.texts_to_sequences([text])
        padded = pad_sequences(
            sequence,
            maxlen=CONFIG['max_sequence_length'],
            padding='post',
            truncating='post'
        )
        
        # Set input tensor
        interpreter.set_tensor(input_details[0]['index'], padded.astype(np.float32))
        
        # Run inference
        interpreter.invoke()
        
        # Get output
        output = interpreter.get_tensor(output_details[0]['index'])[0]
        predicted_class = class_names[np.argmax(output)]
        confidence = np.max(output)
        
        print(f"  '{text}' -> {predicted_class} (confidence: {confidence:.3f})")

if __name__ == "__main__":
    export_tflite_model()