"""
Download pre-exported ONNX model from HuggingFace.
No Python version restrictions - just downloads files!
"""

import urllib.request
import os
import json

MODEL_FILES = {
    # From Xenova/all-MiniLM-L6-v2 - Quantized
    'model.onnx': 'https://huggingface.co/Xenova/all-MiniLM-L6-v2/resolve/main/onnx/model_quantized.onnx',
    'tokenizer.json': 'https://huggingface.co/Xenova/all-MiniLM-L6-v2/resolve/main/tokenizer.json',
    'config.json': 'https://huggingface.co/Xenova/all-MiniLM-L6-v2/resolve/main/config.json',
    'special_tokens_map.json': 'https://huggingface.co/Xenova/all-MiniLM-L6-v2/resolve/main/special_tokens_map.json',
    'tokenizer_config.json': 'https://huggingface.co/Xenova/all-MiniLM-L6-v2/resolve/main/tokenizer_config.json',
    'vocab.txt': 'https://huggingface.co/Xenova/all-MiniLM-L6-v2/resolve/main/vocab.txt',
}

def download_model(output_dir='assets/models'):
    """Download all model files from HuggingFace."""
    print("=== Downloading ONNX Model from HuggingFace ===\n")
    
    os.makedirs(output_dir, exist_ok=True)
    
    for filename, url in MODEL_FILES.items():
        filepath = os.path.join(output_dir, filename)
        print(f"Downloading {filename}...")
        
        try:
            urllib.request.urlretrieve(url, filepath)
            size = os.path.getsize(filepath)
            if size > 1024 * 1024:
                print(f"  ✓ {size / (1024*1024):.2f} MB")
            else:
                print(f"  ✓ {size / 1024:.2f} KB")
        except Exception as e:
            print(f"  ✗ Failed: {e}")
            return False
    
    print("\n=== Download Complete! ===")
    print(f"\nFiles saved to {output_dir}:")
    for f in os.listdir(output_dir):
        size = os.path.getsize(os.path.join(output_dir, f))
        if size > 1024 * 1024:
            print(f"  - {f} ({size / (1024*1024):.2f} MB)")
        else:
            print(f"  - {f} ({size / 1024:.2f} KB)")
    
    return True

if __name__ == '__main__':
    download_model()
