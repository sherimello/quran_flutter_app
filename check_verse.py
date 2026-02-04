import sqlite3

def check_db():
    try:
        conn = sqlite3.connect('assets/db/Quran.db')
        cursor = conn.cursor()
        
        tables = ['al_quran_indopak_quran', 'al_quran_utsmani_quran']
        
        for table in tables:
            print(f"\nScanning table: {table}")
            cursor.execute(f"SELECT text FROM {table} WHERE sura=2 AND aya=285")
            rows = cursor.fetchall()
            
            for row in rows:
                text = row[0]
                print(f"Text length: {len(text)}")
                print(f"Text content: {text}")
                
                # Check for Al-Mu'minun substring and what follows
                # "المؤمنون"
                if "المؤمنون" in text:
                    idx = text.index("المؤمنون")
                    # show context chars approx
                    start = idx
                    end = min(len(text), idx + 20)
                    snippet = text[start:end]
                    print(f"Snippet at 'Al-Mu'minun': {snippet}")
                    
                    # Print hex values of snippet
                    print("Hex dump of snippet:")
                    for c in snippet:
                        print(f"  {c}: {hex(ord(c))}")
                
                # Also check normalization in this specific verse
                import re
                tashkeel = re.compile(r'[\u0617-\u061A\u064B-\u0652]')
                norm = tashkeel.sub('', text)
                print(f"Normalized snippet: {norm}")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    check_db()
