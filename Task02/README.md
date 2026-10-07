# Лабораторная работа 2

## Требования к окружению
- Python v.3
- SQLite 3

## Как запустить
1. Убедитесь, что в папке `dataset` лежат файлы: `movies.csv`, `ratings.csv`, `tags.csv`, `users.csv`.
2. Запустите скрипт `db_init.bat`.
3. После выполнения создастся база данных `movies_rating.db` с заполненными таблицами.

## Структура базы данных
- `movies` — информация о фильмах (id, title, year, genres)
- `ratings` — оценки пользователей (id, user_id, movie_id, rating, timestamp)
- `tags` — теги к фильмам (id, user_id, movie_id, tag, timestamp)
- `users` — пользователи (id, name, email, gender, register_date, occupation)