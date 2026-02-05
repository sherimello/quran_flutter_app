# Running the Embedding Generator

## Prerequisites
1. Install Python 3.8 or higher
2. Navigate to the project directory in terminal

## Installation
```bash
pip install -r requirements_embeddings.txt
```

**Note**: On first run, the `sentence-transformers` library will download the embedding model (~90MB). This is a one-time download.

## Generate Embeddings
```bash
python generate_tafseer_embeddings.py
```

This will:
1. Load all 6,210+ Tafseer entries from `assets/db/quran_tafsir.db`
2. Clean HTML tags from the text
3. Generate semantic embeddings using the `all-MiniLM-L6-v2` model
4. Save to `assets/embeddings/tafseer_embeddings.json` (~25-50 MB)

**Expected time**: 5-10 minutes on a modern CPU (faster with GPU)

## Output
- File: `assets/embeddings/tafseer_embeddings.json`
- Size: Approximately 25-50 MB
- Format: JSON array of objects with embeddings

## Using in Flutter
Once generated, the Flutter app will automatically load these embeddings when the Contextual Search screen is opened.

## Troubleshooting
- **Error loading database**: Ensure `assets/db/quran_tafsir.db` exists
- **Out of memory**: The script processes in batches; if issues persist, reduce batch size in the script
- **Model download fails**: Check internet connection on first run
