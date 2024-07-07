from flask import Flask, request, jsonify
import tensorflow as tf
from tensorflow.keras.applications import EfficientNetB7
from tensorflow.keras.applications.efficientnet import preprocess_input, decode_predictions
import numpy as np
from PIL import Image
from io import BytesIO

app = Flask(__name__)

# Load the pre-trained EfficientNetB7 model
def load_model():
    try:
        model = EfficientNetB7(weights='imagenet')
        return model
    except Exception as e:
        app.logger.error(f"Error loading model: {str(e)}")
        raise

# Define the class names
def get_class_names():
    # EfficientNetB7 trained on ImageNet has 1,000 classes. This is a sample list.
    # Replace it with the actual class names if different.
    return [f'Class {i}' for i in range(1000)]

# Process the image and perform classification
def classify_image(image, model):
    try:
        image_rgb = np.array(image.convert('RGB'))
        image_resized = tf.image.resize(image_rgb, [600, 600])  # Resize to 600x600
        image_array = np.expand_dims(image_resized, axis=0)
        image_preprocessed = preprocess_input(image_array)

        predictions = model.predict(image_preprocessed)
        decoded_predictions = decode_predictions(predictions, top=1)[0][0]

        class_name = decoded_predictions[1]  # Human-readable class name
        confidence = decoded_predictions[2]  # Confidence score

        return class_name, confidence
    except Exception as e:
        app.logger.error(f"Error during classification: {str(e)}")
        raise

@app.route('/classify', methods=['POST'])
def classify():
    try:
        file = request.files['image'].read()
        image = Image.open(BytesIO(file))
        
        if image is None:
            return jsonify({'error': 'Failed to decode image'}), 400
        
        model = load_model()
        class_name, confidence = classify_image(image, model)
        
        return jsonify({'class_name': class_name, 'confidence': float(confidence)})
    except Exception as e:
        app.logger.error(f'Error processing image: {str(e)}')
        return jsonify({'error': str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=5000)
