
import re

# Sample texts with various waqf signs and spacing issues
samples = [
    # Surah Al-Baqarah Ayah 7 (Common merge issue)
    "خَتَمَ اللّٰهُ عَلٰي قُلُوْبِهِمْ وَعَلٰي سَمْعِهِمْ ؕ وَعَلٰٓي اَبْصَارِهِمْ غِشَاوَةٌ c وَّلَهُمْ عَذَابٌ عَظِيْمٌ ࣖ",
    # Surah Yasin Ayah 1 (Ligatures)
    "يٰسٓ ۚ",
    # Random Ayah with multiple signs
    "ذٰلِكَ الْكِتٰبُ لَا رَيْبَ ۛ فِيْهِ ۛ هُدًى لِّلْمُتَّقِيْنَ ۙ",
]

# Current logic
print("--- Current Logic (Space Split + Waqf Filter) ---")
waqf_regex = re.compile(r'^[\u06D6-\u06DC]+$')
for text in samples:
    tokens = [t for t in text.split(' ') if t.strip() and not waqf_regex.match(t)]
    print(f"Original: {text}")
    print(f"Tokens ({len(tokens)}): {tokens}")
    print("-" * 20)

# Proposed Logic
# We want to match WORDS, ignoring waqf signs that might be attached or standalone.
# But waqf signs act as delimiters too. 
# Problem: "word\u06da" -> should be "word"
# Problem: "word1 word2" -> "word1", "word2"

print("\n--- Proposed Regex Logic ---")
# Regex to match Arabic words/letters, EXCLUDING standalone waqf signs if possible, 
# or splitting on them.

# Method 1: Remove all waqf signs first, then split?
# If we remove them, "word1\u06d6word2" becomes "word1word2" (BAD).
# So replace them with space? "word1 word2" (GOOD).

def robust_tokenize(text):
    # 1. Replace all waqf signs and special markers with SPACE
    # Range: \u06D6-\u06DC (Waqf), \u06DE-\u06E9 (Other small marks including sajda, hizb, etc if needed)
    # Let's stick to the common waqf range first + small meem handling if needed.
    
    # Standard Waqf signs + Small Meem (stop) + others:
    # \u06D6-\u06DC, \u06E5, \u06E6 (small waw/ya - WAIT, rare these are words?), 
    # \u06DB (three dots), \u08D6 (stop?)
    
    # Common IndoPak/Uthmani signs:
    # \u06D6 (Sad Lam Alif), \u06D7 (Qaf Lam Alif), \u06D8 (Meem), \u06D9 (Laa), 
    # \u06DA (Jeem), \u06DB (Three dots), \u06DC (Seen), \u06DF (Round zero), \u06E0 (Rect zero)
    # \u06E2 (Meem), \u06ED (Meem Low)
    
    # Regex for "Non-Word Characters that should split words"
    # Actually, we can just replace specific partial-word-breaking chars with space.
    
    clean_text = text
    
    # Replace Waqf signs with SPACE to ensure they act as separators if they were attached
    clean_text = re.sub(r'[\u06D6-\u06DC\u06Df-\u06E4\u06E9]', ' ', clean_text)
    
    # Split by whitespace
    tokens = [t for t in clean_text.split() if t.strip()]
    return tokens

for text in samples:
    tokens = robust_tokenize(text)
    print(f"Original: {text}")
    print(f"Tokens ({len(tokens)}): {tokens}")
    print("-" * 20)
