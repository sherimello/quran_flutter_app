import sqlite3
import re

def normalize_arabic(text):
    # Remove tashkeel (diacritics)
    tashkeel = re.compile(r'[\u0617-\u061A\u064B-\u0652]')
    return tashkeel.sub('', text)

def check_db():
    try:
        conn = sqlite3.connect('assets/db/Quran.db')
        cursor = conn.cursor()
        
        tables = ['al_quran_indopak_quran', 'al_quran_utsmani_quran']
        
        for table in tables:
            print(f"\nScanning table: {table}")
            cursor.execute(f"SELECT sura, aya, text FROM {table}")
            rows = cursor.fetchall()
            
            for row in rows:
                surah, verse, text = row
                normalized = normalize_arabic(text)
                
                # Check for "المؤمنون" followed immediately by "كل" (n+k)
                # Normalized: Al-Muminun ends with Nun (\u0646). Kull starts with Kaf (\u0643).
                # Look for ...المؤمنونكل... in normalized text
                
                if "المؤمنونكل" in normalized:
                    print(f"FOUND MERGE in {table}!")
                    print(f"Surah {surah}, Verse {verse}")
                    print(f"Original: {text}")
                    print(f"Normalized: {normalized}")
                    
                    # Inspect the area around the merge
                    idx = normalized.index("المؤمنونكل")
                    # Original text has diacritics, so index mapping is hard. 
                    # But we can just inspect the string manually in the output.
                    
                    # Let's check if there is ANY space in the original corresponding to that location?
                    # Actually, if "المؤمنونكل" is in normalized, it means there were NO non-tashkeel chars between Nun and Kaf.
                    # Normalization only removed diacritics. It did NOT remove spaces.
                    # So if we found it, it acts as PROOF that there is NO space.
                
                elif "المؤمنون كل" in normalized:
                     # Just to verify we can find the separated version
                     # print(f"Found separated version in {surah}:{verse}")
                     pass

    except Exception as e:
        print(f"Error: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    check_db()
