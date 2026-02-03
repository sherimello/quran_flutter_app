import sqlite3

conn = sqlite3.connect('assets/db/Quran.db')
cursor = conn.cursor()

# Sample from each table
tables = ['al_quran_indopak_quran', 'al_quran_utsmani_quran', 
          'terjemahan_quran', 'jalalayn_quran', 'latin_quran',
          'latin_english_quran', 'kata_quran', 'sura_search_sura_search']

for table in tables:
    print(f"\n{'='*50}")
    print(f"{table}:")
    print('='*50)
    cursor.execute(f"SELECT * FROM {table} LIMIT 3")
    rows = cursor.fetchall()
    for row in rows:
        print(row)

# Check word-by-word structure for surah 1, ayah 1
print(f"\n{'='*50}")
print("Word-by-word for Surah 1, Ayah 1:")
print('='*50)
cursor.execute("SELECT word, ar, tr FROM kata_quran WHERE sura=1 AND aya=1 ORDER BY word")
for row in cursor.fetchall():
    print(f"Word {row[0]}: {row[1]} = {row[2]}")

conn.close()
