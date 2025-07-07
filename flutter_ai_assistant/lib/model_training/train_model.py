"""
Training script for intent classification model
Based on the paper "Building Cross-Platform AI Assistants with Flutter and TensorFlow"
"""

import os
import json
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from tensorflow.keras.models import Model
from tensorflow.keras.layers import Input, Dense, Embedding, GlobalAveragePooling1D, Dropout
from tensorflow.keras.preprocessing.text import Tokenizer
from tensorflow.keras.preprocessing.sequence import pad_sequences
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau

# Configuration
CONFIG = {
    'max_vocab_size': 10000,
    'max_sequence_length': 32,
    'embedding_dim': 128,
    'hidden_units': 64,
    'dropout_rate': 0.3,
    'batch_size': 32,
    'epochs': 100,
    'learning_rate': 0.001,
    'validation_split': 0.2,
    'model_save_path': 'models/intent_classifier.h5',
    'tokenizer_save_path': 'models/tokenizer.json',
    'label_encoder_save_path': 'models/label_encoder.json'
}

def load_data():
    """Load and prepare training data"""
    # Sample intent data - replace with your actual dataset
    data = {
        'text': [
            # Weather queries
            "What's the weather like?",
            "How's the weather today?",
            "Is it going to rain?",
            "What's the temperature?",
            "Will it be sunny tomorrow?",
            "Check the weather forecast",
            "Is it cold outside?",
            "What's the weather forecast for this week?",
            
            # Time queries
            "What time is it?",
            "Tell me the current time",
            "What's the time now?",
            "Show me the clock",
            "What time is it in New York?",
            "Current time please",
            
            # Greetings
            "Hello",
            "Hi there",
            "Good morning",
            "Good evening",
            "Hey",
            "How are you?",
            "Nice to meet you",
            "Greetings",
            
            # Music queries
            "Play some music",
            "Play my favorite song",
            "Turn on the radio",
            "Play rock music",
            "Start the music player",
            "I want to listen to music",
            "Play something upbeat",
            
            # Calendar queries
            "What's on my calendar?",
            "Show me my schedule",
            "Do I have any meetings today?",
            "What's my next appointment?",
            "Check my calendar",
            "Schedule a meeting",
            
            # News queries
            "What's in the news?",
            "Show me the latest news",
            "Tell me about current events",
            "What's happening in the world?",
            "Read me the news",
            "Any breaking news?",
            
            # General queries
            "Help me",
            "What can you do?",
            "Tell me a joke",
            "How do I use this app?",
            "What are your features?",
            "Show me the menu",
        ],
        'intent': [
            # Weather
            'weather', 'weather', 'weather', 'weather', 'weather', 'weather', 'weather', 'weather',
            # Time
            'time', 'time', 'time', 'time', 'time', 'time',
            # Greetings
            'greeting', 'greeting', 'greeting', 'greeting', 'greeting', 'greeting', 'greeting', 'greeting',
            # Music
            'music', 'music', 'music', 'music', 'music', 'music', 'music',
            # Calendar
            'calendar', 'calendar', 'calendar', 'calendar', 'calendar', 'calendar',
            # News
            'news', 'news', 'news', 'news', 'news', 'news',
            # General
            'help', 'help', 'help', 'help', 'help', 'help',
        ]
    }
    
    return pd.DataFrame(data)

def preprocess_data(df):
    """Preprocess text data and encode labels"""
    # Initialize tokenizer
    tokenizer = Tokenizer(
        num_words=CONFIG['max_vocab_size'],
        oov_token='<OOV>'
    )
    
    # Fit tokenizer on texts
    tokenizer.fit_on_texts(df['text'])
    
    # Convert texts to sequences
    sequences = tokenizer.texts_to_sequences(df['text'])
    
    # Pad sequences
    X = pad_sequences(
        sequences,
        maxlen=CONFIG['max_sequence_length'],
        padding='post',
        truncating='post'
    )
    
    # Encode labels
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(df['intent'])
    
    # Convert to categorical
    y = tf.keras.utils.to_categorical(y, num_classes=len(label_encoder.classes_))
    
    return X, y, tokenizer, label_encoder

def create_model(vocab_size, num_classes):
    """Create the intent classification model"""
    # Input layer
    input_layer = Input(shape=(CONFIG['max_sequence_length'],))
    
    # Embedding layer
    embedding = Embedding(
        vocab_size,
        CONFIG['embedding_dim'],
        input_length=CONFIG['max_sequence_length']
    )(input_layer)
    
    # Global average pooling
    pooling = GlobalAveragePooling1D()(embedding)
    
    # Dense layers
    dense1 = Dense(
        CONFIG['hidden_units'],
        activation='relu'
    )(pooling)
    
    dropout1 = Dropout(CONFIG['dropout_rate'])(dense1)
    
    dense2 = Dense(
        CONFIG['hidden_units'] // 2,
        activation='relu'
    )(dropout1)
    
    dropout2 = Dropout(CONFIG['dropout_rate'])(dense2)
    
    # Output layer
    output = Dense(
        num_classes,
        activation='softmax'
    )(dropout2)
    
    # Create model
    model = Model(inputs=input_layer, outputs=output)
    
    # Compile model
    model.compile(
        optimizer=Adam(learning_rate=CONFIG['learning_rate']),
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    return model

def train_model():
    """Main training function"""
    # Create directories
    os.makedirs('models', exist_ok=True)
    
    # Load data
    print("Loading data...")
    df = load_data()
    print(f"Loaded {len(df)} samples with {df['intent'].nunique()} unique intents")
    
    # Preprocess data
    print("Preprocessing data...")
    X, y, tokenizer, label_encoder = preprocess_data(df)
    
    # Split data
    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=CONFIG['validation_split'], random_state=42
    )
    
    print(f"Training samples: {len(X_train)}")
    print(f"Validation samples: {len(X_val)}")
    
    # Create model
    print("Creating model...")
    vocab_size = min(len(tokenizer.word_index) + 1, CONFIG['max_vocab_size'])
    num_classes = len(label_encoder.classes_)
    
    model = create_model(vocab_size, num_classes)
    model.summary()
    
    # Callbacks
    callbacks = [
        EarlyStopping(
            monitor='val_loss',
            patience=10,
            restore_best_weights=True
        ),
        ModelCheckpoint(
            CONFIG['model_save_path'],
            monitor='val_accuracy',
            save_best_only=True,
            save_weights_only=False
        ),
        ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-6
        )
    ]
    
    # Train model
    print("Training model...")
    history = model.fit(
        X_train, y_train,
        batch_size=CONFIG['batch_size'],
        epochs=CONFIG['epochs'],
        validation_data=(X_val, y_val),
        callbacks=callbacks,
        verbose=1
    )
    
    # Save tokenizer
    print("Saving tokenizer...")
    tokenizer_json = tokenizer.to_json()
    with open(CONFIG['tokenizer_save_path'], 'w') as f:
        f.write(tokenizer_json)
    
    # Save label encoder
    print("Saving label encoder...")
    label_encoder_data = {
        'classes': label_encoder.classes_.tolist()
    }
    with open(CONFIG['label_encoder_save_path'], 'w') as f:
        json.dump(label_encoder_data, f)
    
    # Evaluate model
    print("Evaluating model...")
    val_loss, val_accuracy = model.evaluate(X_val, y_val, verbose=0)
    print(f"Validation Loss: {val_loss:.4f}")
    print(f"Validation Accuracy: {val_accuracy:.4f}")
    
    # Save training history
    history_data = {
        'loss': history.history['loss'],
        'accuracy': history.history['accuracy'],
        'val_loss': history.history['val_loss'],
        'val_accuracy': history.history['val_accuracy']
    }
    with open('models/training_history.json', 'w') as f:
        json.dump(history_data, f)
    
    print("Training completed successfully!")
    print(f"Model saved to: {CONFIG['model_save_path']}")
    print(f"Tokenizer saved to: {CONFIG['tokenizer_save_path']}")
    print(f"Label encoder saved to: {CONFIG['label_encoder_save_path']}")

if __name__ == "__main__":
    train_model()