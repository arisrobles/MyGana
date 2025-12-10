#!/usr/bin/env python3
"""
Data Collection Script for Japanese Character Recognition
Generates synthetic training data and collects real user data
"""

import os
import json
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont
import base64
import io
import random
from datetime import datetime

class DataCollector:
    def __init__(self):
        self.input_size = 64
        self.characters = [
    'あ', 'い', 'う', 'え', 'お',
    'か', 'き', 'く', 'け', 'こ',
    'さ', 'し', 'す', 'せ', 'そ',
    'た', 'ち', 'つ', 'て', 'と',
    'な', 'に', 'ぬ', 'ね', 'の',
    'は', 'ひ', 'ふ', 'へ', 'ほ',
    'ま', 'み', 'む', 'め', 'も',
    'や', 'ゆ', 'よ',
    'ら', 'り', 'る', 'れ', 'ろ',
            'わ', 'を', 'ん'
        ]
    
    def generate_synthetic_data(self, num_samples_per_char=50):
        """Generate synthetic training data"""
        print("Generating synthetic training data...")
        
        training_data = []
        
        for char in self.characters:
            print(f"Generating data for character: {char}")
            
            for i in range(num_samples_per_char):
                # Create image with character
                img = self.create_character_image(char, variation=i)
                
                # Convert to base64
                img_bytes = io.BytesIO()
                img.save(img_bytes, format='PNG')
                img_base64 = base64.b64encode(img_bytes.getvalue()).decode('utf-8')
                
                # Create training entry
                entry = {
                    'character': char,
                    'type': 'hiragana',
                    'isCorrect': True,
                    'accuracyScore': random.uniform(80, 100),
                    'timestamp': datetime.now().isoformat(),
                    'strokeCount': self.get_stroke_count(char),
                    'imageData': img_base64
                }
                
                training_data.append(entry)
        
        return training_data
    
    def create_character_image(self, character, variation=0):
        """Create an image of a Japanese character with variations"""
        # Create image
        img = Image.new('L', (self.input_size, self.input_size), 255)
        draw = ImageDraw.Draw(img)
        
        # Try to use a Japanese font, fallback to default
        try:
            # Try different font paths
            font_paths = [
                '/System/Library/Fonts/Hiragino Sans GB.ttc',  # macOS
                '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',  # Linux
                'C:/Windows/Fonts/msgothic.ttc',  # Windows
            ]
            
            font_size = 40
            font = None
            
            for font_path in font_paths:
                if os.path.exists(font_path):
                    try:
                        font = ImageFont.truetype(font_path, font_size)
                        break
                    except:
                        continue
            
            if font is None:
                font = ImageFont.load_default()
                
        except:
            font = ImageFont.load_default()
        
        # Add variations
        x_offset = random.randint(-5, 5) + variation % 3
        y_offset = random.randint(-5, 5) + variation % 3
        
        # Draw character
        bbox = draw.textbbox((0, 0), character, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        
        x = (self.input_size - text_width) // 2 + x_offset
        y = (self.input_size - text_height) // 2 + y_offset
        
        draw.text((x, y), character, font=font, fill=0)
        
        # Add some noise/variations
        img_array = np.array(img)
        
        # Add slight rotation
        if variation % 3 == 0:
            angle = random.uniform(-5, 5)
            img_array = self.rotate_image(img_array, angle)
        
        # Add slight scaling
        if variation % 4 == 0:
            scale = random.uniform(0.9, 1.1)
            img_array = self.scale_image(img_array, scale)
        
        # Add slight blur
        if variation % 5 == 0:
            img_array = cv2.GaussianBlur(img_array, (3, 3), 0)
        
        return Image.fromarray(img_array)
    
    def rotate_image(self, image, angle):
        """Rotate image by angle degrees"""
        h, w = image.shape
        center = (w // 2, h // 2)
        
        M = cv2.getRotationMatrix2D(center, angle, 1.0)
        rotated = cv2.warpAffine(image, M, (w, h), borderValue=255)
        
        return rotated
    
    def scale_image(self, image, scale):
        """Scale image by scale factor"""
        h, w = image.shape
        new_h, new_w = int(h * scale), int(w * scale)
        
        scaled = cv2.resize(image, (new_w, new_h))
        
        # Pad or crop to original size
        if scale > 1:
            # Crop
            start_h = (new_h - h) // 2
            start_w = (new_w - w) // 2
            scaled = scaled[start_h:start_h+h, start_w:start_w+w]
        else:
            # Pad
            pad_h = (h - new_h) // 2
            pad_w = (w - new_w) // 2
            padded = np.full((h, w), 255, dtype=np.uint8)
            padded[pad_h:pad_h+new_h, pad_w:pad_w+new_w] = scaled
            scaled = padded
        
        return scaled
    
    def get_stroke_count(self, character):
        """Get stroke count for character (simplified)"""
        stroke_counts = {
            'あ': 3, 'い': 2, 'う': 2, 'え': 2, 'お': 3,
            'か': 3, 'き': 3, 'く': 2, 'け': 3, 'こ': 2,
            'さ': 3, 'し': 1, 'す': 2, 'せ': 3, 'そ': 2,
            'た': 4, 'ち': 2, 'つ': 1, 'て': 1, 'と': 2,
            'な': 4, 'に': 3, 'ぬ': 2, 'ね': 2, 'の': 1,
            'は': 3, 'ひ': 1, 'ふ': 4, 'へ': 1, 'ほ': 4,
            'ま': 3, 'み': 2, 'む': 3, 'め': 2, 'も': 3,
            'や': 3, 'ゆ': 2, 'よ': 2,
            'ら': 2, 'り': 2, 'る': 1, 'れ': 2, 'ろ': 1,
            'わ': 2, 'を': 3, 'ん': 1,
        }
        return stroke_counts.get(character, 2)
    
    def load_existing_data(self, file_path):
        """Load existing training data"""
        if os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        return {'data': []}
    
    def save_training_data(self, data, file_path):
        """Save training data to JSON file"""
        # Create metadata
        metadata = {
            'totalSamples': len(data),
            'exportDate': datetime.now().isoformat(),
            'characters': list(set(entry['character'] for entry in data)),
            'dataSource': 'synthetic_generation'
        }
        
        # Save data
        output_data = {
            'metadata': metadata,
            'data': data
        }
        
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)
        
        print(f"Training data saved to {file_path}")
        print(f"Total samples: {len(data)}")
        print(f"Characters: {len(metadata['characters'])}")

def main():
    """Main data collection function"""
        print("Japanese Character Data Collection")
        print("=" * 40)
    
    collector = DataCollector()
    
    # Load existing data
    existing_data = collector.load_existing_data('training_data_export.json')
    existing_samples = len(existing_data['data'])
    
    print(f"Existing samples: {existing_samples}")
    
    # Generate synthetic data
    if existing_samples < 1000:  # Generate more data if we don't have enough
        num_samples_per_char = max(20, (1000 - existing_samples) // len(collector.characters))
        synthetic_data = collector.generate_synthetic_data(num_samples_per_char)
        
        # Combine with existing data
        all_data = existing_data['data'] + synthetic_data
        
        # Save combined data
        collector.save_training_data(all_data, 'training_data_export.json')
    else:
        print("Sufficient training data already available!")

if __name__ == "__main__":
    main()