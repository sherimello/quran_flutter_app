import sqlite3

db_path = r'C:\Users\SAMSUNG\Downloads\QGT.db'
conn = sqlite3.connect(db_path)
c = conn.cursor()

# List tables
c.execute("SELECT name FROM sqlite_master WHERE type='table'")
print("Tables:", [r[0] for r in c.fetchall()])

# corpus schema
print("\n--- corpus Schema ---")
c.execute("PRAGMA table_info(corpus)")
for col in c.fetchall():
    print(col)

# Sample rows
print("\n--- corpus Sample (Surah 1 Ayah 1) ---")
c.execute("SELECT * FROM corpus WHERE surah=1 AND ayah=1 ORDER BY word")
for row in c.fetchall():
    print(row)

# Check ar1+ar2 concatenation
print("\n--- ar1+ar2 Concatenation (Surah 1 Ayah 1) ---")
c.execute("""
    SELECT word, ar1, ar2, 
           CASE WHEN ar2 IS NOT NULL AND ar2 != '' 
                THEN ar1 || ar2 
                ELSE ar1 
           END as combined
    FROM corpus WHERE surah=1 AND ayah=1 ORDER BY word
""")
for row in c.fetchall():
    print(f"  word={row[0]}, ar1='{row[1]}', ar2='{row[2]}', combined='{row[3]}'")

# Check a longer ayah
print("\n--- ar1+ar2 (Surah 1 Ayah 7 - الضالين) ---")
c.execute("""
    SELECT word, ar1, ar2,
           CASE WHEN ar2 IS NOT NULL AND ar2 != ''
                THEN ar1 || ar2
                ELSE ar1
           END as combined
    FROM corpus WHERE surah=1 AND ayah=7 ORDER BY word
""")
for row in c.fetchall():
    print(f"  word={row[0]}, ar1='{row[1]}', ar2='{row[2]}', combined='{row[3]}'")

# Check ar3 - does it ever have data?
print("\n--- ar3 non-null count ---")
c.execute("SELECT COUNT(*) FROM corpus WHERE ar3 IS NOT NULL AND ar3 != ''")
print(f"  ar3 non-null rows: {c.fetchone()[0]}")

# Total word count
c.execute("SELECT COUNT(*) FROM corpus")
print(f"\nTotal corpus records: {c.fetchone()[0]}")

# Compare with allwords count from Quran.db
quran_conn = sqlite3.connect(r'C:\dev\quran_flutter_app\assets\db\Quran.db')
qc = quran_conn.cursor()
qc.execute("SELECT COUNT(*) FROM allwords")
print(f"Total allwords records: {qc.fetchone()[0]}")

# Check if word counts match for Surah 1
c.execute("SELECT ayah, COUNT(*) FROM corpus WHERE surah=1 GROUP BY ayah ORDER BY ayah")
corpus_counts = {r[0]: r[1] for r in c.fetchall()}
qc.execute("SELECT ayah, COUNT(*) FROM allwords WHERE sura=1 GROUP BY ayah ORDER BY ayah")
allwords_counts = {r[0]: r[1] for r in qc.fetchall()}

print("\n--- Word Count Comparison (Surah 1) ---")
for ayah in sorted(set(list(corpus_counts.keys()) + list(allwords_counts.keys()))):
    cc = corpus_counts.get(ayah, 0)
    ac = allwords_counts.get(ayah, 0)
    match = "✓" if cc == ac else "✗"
    print(f"  Ayah {ayah}: corpus={cc}, allwords={ac} {match}")

conn.close()
quran_conn.close()
