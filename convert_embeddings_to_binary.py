"""
Convert JSON embeddings to optimized binary format for Flutter.
Reduces file size from ~92MB to ~10MB.

Binary Format:
- Magic: "TAF1" (4 bytes)
- Count: Uint32 (4 bytes)
- Dim: Uint32 (4 bytes)
- Entries:
  - ID: Uint16 (2 bytes)
  - Surah: Uint8 (1 byte)
  - Ayah: Uint16 (2 bytes) (Ayah > 255 exists)
  - Embedding: 384 * Float32 (1536 bytes)
"""

import json
import struct
import os

def convert_to_binary(json_path='assets/embeddings/tafseer_embeddings.json', output_path='assets/embeddings/tafseer_embeddings.bin'):
    print(f"=== Converting {json_path} to Binary ===\n")
    
    if not os.path.exists(json_path):
        print(f"Error: {json_path} not found!")
        return

    # Load JSON
    print("Loading JSON (this might take a moment)...")
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    count = len(data)
    print(f"Loaded {count} entries.")
    
    if count == 0:
        print("No data to convert.")
        return

    # Helper to check embedding dim
    dim = len(data[0]['embedding'])
    print(f"Embedding dimension: {dim}")

    # Open binary file
    with open(output_path, 'wb') as f:
        # Header
        f.write(b'TAF1')            # Magic
        f.write(struct.pack('<I', count)) # Count (Little Endian Uint32)
        f.write(struct.pack('<I', dim))   # Dim (Little Endian Uint32)
        
        print("Writing binary data...")
        for i, entry in enumerate(data):
            # Fields
            id_val = int(entry['id'])
            surah = int(entry['surah'])
            ayah = int(entry['ayah'])
            embedding = entry['embedding']
            
            # Write metadata
            f.write(struct.pack('<H', id_val))  # ID (Uint16)
            f.write(struct.pack('<B', surah))   # Surah (Uint8)
            f.write(struct.pack('<H', ayah))    # Ayah (Uint16)
            
            # Write embedding (384 floats)
            # 'f' is standard float (32-bit)
            f.write(struct.pack(f'<{dim}f', *embedding))
            
            if (i + 1) % 1000 == 0:
                print(f"  Processed {i + 1}/{count}")

    print(f"\nconversion complete!")
    
    json_size = os.path.getsize(json_path) / (1024 * 1024)
    bin_size = os.path.getsize(output_path) / (1024 * 1024)
    
    print(f"Original JSON: {json_size:.2f} MB")
    print(f"Binary Output: {bin_size:.2f} MB")
    print(f"Reduction: {(1 - bin_size/json_size)*100:.1f}%")

if __name__ == '__main__':
    convert_to_binary()
