import sqlite3
import os

db_path = r'C:\Users\SAMSUNG\AppData\Roaming\quran_data\Quran.db'
# Try default path first, if not found, try the one from the code (assets copied)
# Actually the code says: join(await getDatabasesPath(), 'Quran.db');
# On Windows, getDatabasesPath() usually maps to a specific folder. 
# Let's try to find where the DB is.
# The user said they added a new table in Quran.db. They probably modified the one in assets/db/Quran.db 
# OR they modified the one in the app's data directory. 
# Given they are a developer, they likely modified the source asset or the one on the device.
# Since I am on the dev machine, I should check the asset file first as that's what gets copied.

possible_paths = [
    r'C:\dev\quran_flutter_app\assets\db\Quran.db',
    r'C:\Users\SAMSUNG\AppData\Local\Google\AndroidStudio2024.1\device-explorer\...\data\data\com.example.quran_flutter_app\databases\Quran.db', # distinct path
]

db_file = None
if os.path.exists(r'C:\dev\quran_flutter_app\assets\db\Quran.db'):
    db_file = r'C:\dev\quran_flutter_app\assets\db\Quran.db'
    print(f"Found DB at: {db_file}")

if not db_file:
    print("Could not find Quran.db in assets/db/. Please check path.")
    exit()

try:
    conn = sqlite3.connect(db_file)
    cursor = conn.cursor()

    # List tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = cursor.fetchall()
    print("Tables:", [t[0] for t in tables])

    if ('allwords',) in tables:
        print("\n--- allwords Table Info ---")
        cursor.execute("PRAGMA table_info(allwords)")
        columns = cursor.fetchall()
        for col in columns:
            print(col)
        
        print("\n--- Sample Data (First 5 rows) ---")
        cursor.execute("SELECT * FROM allwords LIMIT 5")
        rows = cursor.fetchall()
        for row in rows:
            print(row)
            
        print("\n--- Word Count Analysis ---")
        # Let's pick Surah 1 (Al-Fatiha) to check word counts
        # Column name is 'ayah' according to schema info: (1, 'ayah', 'INT', 0, None, 0)
        cursor.execute("SELECT COUNT(*) FROM allwords WHERE sura=1 AND ayah=1")
        wbw_count = cursor.fetchone()[0]
        print(f"Surah 1, Ayah 1 Word Count in allwords: {wbw_count}")

        # Compare with existing Arabic text table (assuming 'al_quran_indopak_quran' exists)
        if ('al_quran_indopak_quran',) in tables:
             cursor.execute("SELECT text FROM al_quran_indopak_quran WHERE sura=1 AND aya=1")
             arabic_text = cursor.fetchone()
             if arabic_text:
                 text = arabic_text[0]
                 # Simple space split for estimation
                 splitted = text.split(' ')
                 print(f"Surah 1, Ayah 1 Text in indopak: {text}")
                 print(f"Surah 1, Ayah 1 Approx Word Count (split by space): {len(splitted)}")
                 
        # Let's check another one: Surah 114, Ayah 1
        cursor.execute("SELECT COUNT(*) FROM allwords WHERE sura=114 AND ayah=1")
        wbw_count_114 = cursor.fetchone()[0]
        print(f"Surah 114, Ayah 1 Word Count in allwords: {wbw_count_114}")
        
        if ('al_quran_indopak_quran',) in tables:
             cursor.execute("SELECT text FROM al_quran_indopak_quran WHERE sura=114 AND aya=1")
             arabic_text = cursor.fetchone()
             if arabic_text:
                 text = arabic_text[0]
                 splitted = text.split(' ')
                 print(f"Surah 114, Ayah 1 Text in indopak: {text}")
                 print(f"Surah 114, Ayah 1 Approx Word Count: {len(splitted)}")
        
    else:
        print("Table 'allwords' not found!")

    conn.close()

except Exception as e:
    print(f"Error: {e}")
