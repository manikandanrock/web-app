from flask import Flask, request, jsonify
import tensorflow as tf
from tensorflow.keras.applications import EfficientNetB7
from tensorflow.keras.applications.efficientnet import preprocess_input, decode_predictions
import numpy as np
from PIL import Image
from io import BytesIO

app = Flask(__name__)

# Load the model once during server startup
try:
    model = EfficientNetB7(weights='imagenet')
except Exception as e:
    app.logger.error(f"Error loading model: {str(e)}")
    model = None

def classify_image(image):
    try:
        # Convert image to RGB and resize to 600x600
        image_rgb = np.array(image.convert('RGB'))
        image_resized = tf.image.resize(image_rgb, [600, 600])
        image_array = np.expand_dims(image_resized, axis=0)
        image_preprocessed = preprocess_input(image_array)

        # Make predictions
        predictions = model.predict(image_preprocessed)
        decoded_predictions = decode_predictions(predictions, top=1)[0][0]

        class_name = decoded_predictions[1]
        confidence = decoded_predictions[2]

        return class_name, confidence
    except Exception as e:
        app.logger.error(f"Error during classification: {str(e)}")
        raise

@app.route('/classify', methods=['POST'])
def classify():
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 500

    try:
        file = request.files['image'].read()
        image = Image.open(BytesIO(file))

        if image is None:
            return jsonify({'error': 'Failed to decode image'}), 400

        class_name, confidence = classify_image(image)

        return jsonify({'class_name': class_name, 'confidence': float(confidence)})
    except Exception as e:
        app.logger.error(f'Error processing image: {str(e)}')
        return jsonify({'error': str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=5000)
