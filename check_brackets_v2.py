import sqlite3

def check_brackets():
    try:
        conn = sqlite3.connect('assets/db/Quran.db')
        cursor = conn.cursor()
        
        # Check latin_quran (different table)
        print("Scanning latin_quran for '['...")
        cursor.execute("SELECT sura, aya, text FROM latin_quran WHERE text LIKE '%[%'")
        rows = cursor.fetchall()
        
        print(f"Found {len(rows)} rows with '[' in latin_quran.")
        
        for i, row in enumerate(rows[:20]):
            print(f"\nSurah {row[0]}, Verse {row[1]}:")
            print(f"Text: {row[2]}")
            
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    check_brackets()
