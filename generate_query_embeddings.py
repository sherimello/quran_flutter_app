"""
Generate embeddings for common search queries/concepts.
Uses sentence-transformers (NO TensorFlow required!)
Output: assets/embeddings/query_embeddings.json
"""

import json
import os
from sentence_transformers import SentenceTransformer

# Common Islamic/Quranic search terms and concepts
COMMON_QUERIES = [
    # Core concepts
    "patience", "sabr", "endurance", "steadfastness", "perseverance",
    "prayer", "salah", "worship", "prostration", "bowing",
    "charity", "zakat", "sadaqah", "giving", "generosity", "alms",
    "forgiveness", "mercy", "compassion", "pardon", "clemency",
    "faith", "belief", "iman", "trust in Allah", "piety",
    "gratitude", "thankfulness", "shukr", "gratefulness",
    "repentance", "tawbah", "seeking forgiveness", "turning back to Allah",
    "justice", "fairness", "equity", "righteousness",
    "kindness", "ihsan", "excellence", "goodness", "benevolence",
    "honesty", "truthfulness", "sincerity", "integrity",
    
    # Life topics
    "marriage", "family", "parents", "children", "spouse", "husband", "wife",
    "death", "afterlife", "paradise", "heaven", "jannah", "hell", "jahannam",
    "wealth", "money", "rizq", "sustenance", "provision",
    "health", "sickness", "healing", "disease", "cure",
    "knowledge", "learning", "wisdom", "understanding", "education",
    "work", "livelihood", "business", "trade", "halal income",
    "food", "eating", "halal", "haram", "dietary laws",
    "fasting", "sawm", "ramadan", "hunger", "abstinence",
    
    # Spiritual concepts
    "dua", "supplication", "asking Allah", "calling upon God",
    "trust in God", "tawakkul", "reliance on Allah",
    "fear of Allah", "taqwa", "God-consciousness", "piety",
    "love of Allah", "devotion", "spiritual connection",
    "angels", "jinn", "unseen", "ghayb", "revelation",
    "prophets", "messengers", "Muhammad", "Jesus", "Moses", "Abraham",
    "Quran", "scripture", "revelation", "guidance", "book",
    "day of judgment", "resurrection", "accountability", "hereafter",
    
    # Social topics
    "neighbors", "community", "ummah", "brotherhood", "sisterhood",
    "orphans", "poor", "needy", "helping others", "social welfare",
    "oppression", "injustice", "tyranny", "persecution",
    "peace", "salam", "harmony", "reconciliation",
    "war", "fighting", "jihad", "struggle", "defense",
    "treaties", "agreements", "promises", "covenants",
    
    # Emotions and states
    "fear", "anxiety", "worry", "stress", "hardship",
    "hope", "optimism", "trust", "reliance",
    "anger", "controlling anger", "forgiveness", "calm",
    "happiness", "joy", "contentment", "satisfaction",
    "grief", "sadness", "loss", "mourning", "comfort",
    "pride", "arrogance", "humility", "modesty",
    "jealousy", "envy", "hasad", "contentment",
    
    # Actions and behaviors
    "lying", "deception", "fraud", "cheating",
    "backbiting", "gossip", "slander", "false accusations",
    "alcohol", "intoxicants", "drugs", "gambling",
    "adultery", "fornication", "modesty", "chastity",
    "theft", "stealing", "taking what is not yours",
    "murder", "killing", "taking life", "sanctity of life",
    
    # Nature and signs
    "creation", "universe", "heavens", "earth", "nature",
    "sun", "moon", "stars", "night", "day",
    "water", "rain", "rivers", "seas", "oceans",
    "mountains", "trees", "plants", "animals", "birds",
    
    # Question formats
    "what does Islam say about patience",
    "how to be patient",
    "why pray",
    "importance of charity",
    "dealing with hardship",
    "how to forgive",
    "how to repent",
    "what is taqwa",
    "meaning of life",
    "purpose of creation",
]

def generate_query_embeddings(output_path='assets/embeddings/query_embeddings.json'):
    """Generate embeddings for all common queries."""
    print("=== Query Embeddings Generator ===\n")
    
    # Load the same model used for tafseer embeddings
    print("Loading model: all-MiniLM-L6-v2")
    model = SentenceTransformer('all-MiniLM-L6-v2')
    print("Model loaded!\n")
    
    print(f"Generating embeddings for {len(COMMON_QUERIES)} queries...")
    embeddings = model.encode(COMMON_QUERIES, show_progress_bar=True)
    
    # Create output data
    data = []
    for i, query in enumerate(COMMON_QUERIES):
        data.append({
            'query': query,
            'embedding': embeddings[i].tolist()
        })
    
    # Save to file
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False)
    
    size_kb = os.path.getsize(output_path) / 1024
    print(f"\nSaved to {output_path}")
    print(f"File size: {size_kb:.2f} KB")
    print(f"Total queries: {len(data)}")
    print("\n=== Complete! ===")

if __name__ == '__main__':
    generate_query_embeddings()
