import sqlite3

def inspect_db():
    conn = sqlite3.connect('assets/db/Quran.db')
    cursor = conn.cursor()
    
    # List all tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row[0] for row in cursor.fetchall()]
    print(f"Tables: {tables}")
    
    for table in ['chapter_information', 'juz_information']:
        if table in tables:
            print(f"\nInfo for {table}:")
            cursor.execute(f"PRAGMA table_info({table})")
            for col in cursor.fetchall():
                print(col)
            
            # Show a sample row to verify data
            try:
                cursor.execute(f"SELECT * FROM {table} LIMIT 1")
                row = cursor.fetchone()
                print(f"Sample row: {row}")
            except Exception as e:
                print(f"Error fetching sample: {e}")
        else:
            print(f"\nTable {table} NOT found!")
            
    conn.close()

if __name__ == "__main__":
    inspect_db()
