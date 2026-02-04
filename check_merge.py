import sqlite3
import os

def check_db():
    db_path = 'assets/db/Quran.db'
    
    if not os.path.exists(db_path):
        print(f"Error: Database file not found at {db_path}")
        # Try finding it
        for root, dirs, files in os.walk('.'):
            for file in files:
                if file.lower() == 'quran.db':
                    print(f"Found at: {os.path.join(root, file)}")
        return

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check tables first
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = [row[0] for row in cursor.fetchall()]
        print("Tables found:", tables)
        
        target_tables = ['al_quran_indopak_quran', 'al_quran_utsmani_quran']
        
        for table in target_tables:
            if table in tables:
                print(f"\nChecking table: {table}")
                # Search for the joined text "المؤمنونكل"
                # Also searching for close proximity just in case
                query = f"SELECT sura, aya, text FROM {table} WHERE text LIKE '%المؤمنونكل%'"
                cursor.execute(query)
                results = cursor.fetchall()
                
                if results:
                    print(f"FOUND MERGED TEXT in {table}!")
                    for row in results:
                        print(f"Surah {row[0]}, Ayah {row[1]}: {row[2]}")
                else:
                    print(f"No exact merge found in {table}. Searching for separate words...")
                    # Verify they exist separately
                    cursor.execute(f"SELECT sura, aya, text FROM {table} WHERE text LIKE '%المؤمنون%' AND text LIKE '%كل%'")
                    results = cursor.fetchall()
                    if len(results) > 0:
                        print(f"Found {len(results)} verses with both words separated.")
                        # Print sample
                        print(f"Sample: {results[0]}")
            else:
                print(f"Table {table} not found.")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    check_db()
