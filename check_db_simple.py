import sqlite3

conn = sqlite3.connect('assets/db/Quran.db')
cursor = conn.cursor()

cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [t[0] for t in cursor.fetchall()]

print("Tables found:", len(tables))
for table_name in sorted(tables):
    print(f"\n{table_name}:")
    cursor.execute(f"PRAGMA table_info({table_name})")
    cols = cursor.fetchall()
    for col in cols:
        print(f"  {col[1]}: {col[2]}")
    cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
    print(f"  Rows: {cursor.fetchone()[0]}")

conn.close()
