"""
Tafseer Embeddings Generator
Generates semantic embeddings for all Tafseer entries using sentence-transformers.
Output: assets/embeddings/tafseer_embeddings.json
"""

import sqlite3
import json
import os
import re
from sentence_transformers import SentenceTransformer
import numpy as np

def clean_html(text):
    """Remove HTML tags from text."""
    clean = re.compile('<.*?>')
    return re.sub(clean, '', text)

def load_tafseer_data(db_path):
    """Load all Tafseer entries from database."""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("SELECT id, surah, ayah, verse_key, text FROM tafseer ORDER BY id")
    rows = cursor.fetchall()
    conn.close()
    
    data = []
    for row in rows:
        id_val, surah, ayah, verse_key, text = row
        cleaned_text = clean_html(text)
        
        # Skip very short entries (likely errors or empty)
        if len(cleaned_text.strip()) < 20:
            continue
            
        data.append({
            'id': id_val,
            'surah': surah,
            'ayah': ayah,
            'verse_key': verse_key,
            'text': cleaned_text.strip()
        })
    
    return data

def generate_embeddings(data, model_name='all-MiniLM-L6-v2'):
    """Generate embeddings for all Tafseer entries."""
    print(f"Loading model: {model_name}")
    model = SentenceTransformer(model_name)
    
    print(f"Generating embeddings for {len(data)} entries...")
    texts = [entry['text'] for entry in data]
    
    # Generate embeddings in batches for efficiency
    embeddings = model.encode(texts, batch_size=32, show_progress_bar=True)
    
    # Add embeddings to data
    for i, entry in enumerate(data):
        entry['embedding'] = embeddings[i].tolist()
    
    return data

def save_embeddings(data, output_path):
    """Save embeddings to JSON file."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    print(f"Saving embeddings to {output_path}")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False)
    
    # Print file size
    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"File saved successfully! Size: {size_mb:.2f} MB")

def main():
    # Paths
    db_path = 'assets/db/quran_tafsir.db'
    output_path = 'assets/embeddings/tafseer_embeddings.json'
    
    print("=== Tafseer Embeddings Generator ===")
    print(f"Database: {db_path}")
    print(f"Output: {output_path}\n")
    
    # Load data
    print("Step 1: Loading Tafseer data...")
    data = load_tafseer_data(db_path)
    print(f"Loaded {len(data)} valid Tafseer entries\n")
    
    # Generate embeddings
    print("Step 2: Generating embeddings...")
    print("(This may take a few minutes on first run as the model is downloaded)")
    data_with_embeddings = generate_embeddings(data)
    print("Embeddings generated successfully!\n")
    
    # Save to file
    print("Step 3: Saving to JSON file...")
    save_embeddings(data_with_embeddings, output_path)
    
    print("\n=== Complete! ===")
    print(f"Embeddings ready for use in Flutter app")
    print(f"Total entries: {len(data_with_embeddings)}")

if __name__ == '__main__':
    main()
