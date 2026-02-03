import sqlite3

# Connect to the database
conn = sqlite3.connect('assets/db/Quran.db')
cursor = conn.cursor()

# Get all table names
cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = cursor.fetchall()

print("=== TABLES IN DATABASE ===")
for table in tables:
    table_name = table[0]
    print(f"\n>>> Table: {table_name}")
    
    # Get schema for each table
    cursor.execute(f"PRAGMA table_info({table_name})")
    columns = cursor.fetchall()
    
    print("Columns:")
    for col in columns:
        print(f"  - {col[1]} ({col[2]})")
    
    # Get row count
    cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
    count = cursor.fetchone()[0]
    print(f"Row count: {count}")
    
    # Get sample row if available
    if count > 0:
        cursor.execute(f"SELECT * FROM {table_name} LIMIT 1")
        sample = cursor.fetchone()
        print(f"Sample row: {sample}")

conn.close()
