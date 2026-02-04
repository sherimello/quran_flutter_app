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
            
            count = 0
            for row in rows:
                surah, verse, text = row
                normalized = normalize_arabic(text)
                
                # Debug first row
                if count == 0:
                    print(f"Debug First Verse Normalized: {normalized}")
                    count += 1
                
                # Regex for Al-Mumin(un/in) followed by ANY whitespace (or none) and then Kaf
                # \u0643 = Kaf
                # \u0644 = Lam
                # \u0645 = Meem
                # \u0624 = Waw with Hamza
                # \u0646 = Noon
                
                # Check for Al-Mu'minun/in followed by "Kull" (Kaf Lam)
                # "المؤمنون" or "المؤمنين"
                
                matches = re.findall(r'(المؤمن[وي]ن)(\s*)(كل)', normalized)
                if matches:
                    print(f"MATCH FOUND in {surah}:{verse}")
                    print(f"Original: {text}")
                    print(f"Normalized: {normalized}")
                    for m in matches:
                        word1, space, word2 = m
                        print(f"  Word1: '{word1}'")
                        print(f"  Space: '{space}' (Len: {len(space)})")
                        print(f"  Word2: '{word2}'")
                        print(f"  Hex of Space: {[hex(ord(c)) for c in space]}")
                        
                        if len(space) == 0:
                            print("  ALERT: NO SPACE DETECTED!")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    check_db()
