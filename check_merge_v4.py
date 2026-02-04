import sqlite3
import re

def normalize_arabic(text):
    # Remove tashkeel (diacritics)
    tashkeel = re.compile(r'[\u0617-\u061A\u064B-\u0652]')
    res = tashkeel.sub('', text)
    return res

def check_db():
    try:
        conn = sqlite3.connect('assets/db/Quran.db')
        cursor = conn.cursor()
        
        tables = ['al_quran_indopak_quran', 'al_quran_utsmani_quran']
        
        for table in tables:
            print(f"\nScanning table: {table}")
            cursor.execute(f"SELECT sura, aya, text FROM {table}")
            rows = cursor.fetchall()
            
            NK_matches = 0
            
            for row in rows:
                surah, verse, text = row
                normalized = normalize_arabic(text)
                
                # Check for "Nun" followed immediately by "Kaf"
                # \u0646 = Nun
                # \u0643 = Kaf
                
                # We need to be careful not to match within a word like "Ahlan wa Sahlan" (no NK there).
                # Common NK words: "Munkar", "Nakir".
                
                # Let's search for "المؤمنون" followed by "K" specifically as user requested
                # or simplified: "MuminunK"
                
                if "مونكل" in normalized or "مينكل" in normalized or "نونكل" in normalized:
                    print(f"POSSIBLE MERGE in {surah}:{verse}")
                    print(f"Original: {text}")
                    print(f"Normalized: {normalized}")
                    nk_idx = normalized.find("مونكل")
                    if nk_idx == -1: nk_idx = normalized.find("مينكل")
                    if nk_idx == -1: nk_idx = normalized.find("نونكل")
                    
                    print(f"Matched substring: {normalized[nk_idx:nk_idx+10]}")
                    NK_matches += 1

            print(f"Total NK potential merges in {table}: {NK_matches}")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    check_db()
