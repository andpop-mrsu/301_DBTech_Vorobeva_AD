import csv
import os
import re

# --- НАСТРОЙКИ ---
DATASET_DIR = '../dataset'  # Путь к папке dataset (относительно Task02)
OUTPUT_SQL = 'db_init.sql'

# --- SQL ДЛЯ СОЗДАНИЯ ТАБЛИЦ ---
CREATE_TABLES_SQL = """
DROP TABLE IF EXISTS movies;
CREATE TABLE movies (
    id INTEGER PRIMARY KEY,
    title TEXT,
    year INTEGER,
    genres TEXT
);

DROP TABLE IF EXISTS ratings;
CREATE TABLE ratings (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    movie_id INTEGER,
    rating REAL,
    timestamp INTEGER
);

DROP TABLE IF EXISTS tags;
CREATE TABLE tags (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    movie_id INTEGER,
    tag TEXT,
    timestamp INTEGER
);

DROP TABLE IF EXISTS users;
CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT,
    email TEXT,
    gender TEXT,
    register_date TEXT,
    occupation TEXT
);
"""

def escape_sql(value):
    """Экранирует одинарные кавычки для SQL."""
    if value is None or value == '':
        return "NULL"
    # Если число — без кавычек
    if re.match(r'^-?\d+(\.\d+)?$', str(value).strip()):
        return str(value).strip()
    # Иначе — в кавычках, с экранированием
    return "'" + str(value).replace("'", "''") + "'"

def parse_year(title):
    """Извлекает год из 'Toy Story (1995)'."""
    match = re.search(r'\((\d{4})\)', title)
    return int(match.group(1)) if match else None

def clean_title(title):
    """Убирает год из названия."""
    return re.sub(r'\s*\(\d{4}\)\s*$', '', title).strip()

# --- ГЕНЕРАТОРЫ INSERT'ОВ ---

def gen_movies(filepath):
    """movies.csv: movieId,title,genres"""
    sql = []
    with open(filepath, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            movie_id = row['movieId'].strip()
            title_raw = row['title'].strip()
            genres = row['genres'].strip()
            year = parse_year(title_raw)
            title = clean_title(title_raw)
            year_val = year if year else 'NULL'
            sql.append(
                f"INSERT INTO movies (id, title, year, genres) VALUES "
                f"({movie_id}, {escape_sql(title)}, {year_val}, {escape_sql(genres)});"
            )
    return sql

def gen_ratings(filepath):
    """ratings.csv: userId,movieId,rating,timestamp"""
    sql = []
    with open(filepath, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for idx, row in enumerate(reader, start=1):
            sql.append(
                f"INSERT INTO ratings (id, user_id, movie_id, rating, timestamp) VALUES "
                f"({idx}, {row['userId'].strip()}, {row['movieId'].strip()}, "
                f"{row['rating'].strip()}, {row['timestamp'].strip()});"
            )
    return sql

def gen_tags(filepath):
    """tags.csv: userId,movieId,tag,timestamp"""
    sql = []
    with open(filepath, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for idx, row in enumerate(reader, start=1):
            sql.append(
                f"INSERT INTO tags (id, user_id, movie_id, tag, timestamp) VALUES "
                f"({idx}, {row['userId'].strip()}, {row['movieId'].strip()}, "
                f"{escape_sql(row['tag'].strip())}, {row['timestamp'].strip()});"
            )
    return sql

def gen_users(filepath):
    """
    users.csv: БЕЗ заголовков, разделитель '|'.
    Формат строки: id|name|email|gender|register_date|occupation
    """
    sql = []
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split('|')
            if len(parts) < 6:
                # Если вдруг меньше 6 полей — пропускаем или дополняем
                continue
            user_id, name, email, gender, register_date, occupation = parts[:6]
            sql.append(
                f"INSERT INTO users (id, name, email, gender, register_date, occupation) VALUES "
                f"({user_id.strip()}, {escape_sql(name.strip())}, {escape_sql(email.strip())}, "
                f"{escape_sql(gender.strip())}, {escape_sql(register_date.strip())}, {escape_sql(occupation.strip())});"
            )
    return sql

# --- ОСНОВНАЯ ФУНКЦИЯ ---

def main():
    print("Начинаю генерацию SQL-скрипта...")

    tasks = [
        ('movies', 'movies.csv', gen_movies),
        ('ratings', 'ratings.csv', gen_ratings),
        ('tags', 'tags.csv', gen_tags),
        ('users', 'users.csv', gen_users),
    ]

    with open(OUTPUT_SQL, 'w', encoding='utf-8') as f:
        f.write(CREATE_TABLES_SQL)
        f.write("\n")

        for table_name, filename, gen_func in tasks:
            filepath = os.path.join(DATASET_DIR, filename)
            if not os.path.exists(filepath):
                print(f"[!] Файл {filepath} не найден. Пропускаю.")
                continue

            print(f"Обрабатываю {filename}...")
            f.write(f"\n-- Данные для таблицы {table_name}\n")
            try:
                inserts = gen_func(filepath)
                f.write("\n".join(inserts))
                f.write("\n")
                print(f"  -> {len(inserts)} записей.")
            except Exception as e:
                print(f"  [!] Ошибка: {e}")

    print(f"Готово! SQL-скрипт сохранен в {OUTPUT_SQL}")

if __name__ == '__main__':
    main()