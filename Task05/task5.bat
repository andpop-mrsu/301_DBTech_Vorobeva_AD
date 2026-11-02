#!/bin/bash

# Проверяем, существует ли база данных. Если нет - создаем.
if [ ! -f movies_rating.db ]; then
    echo "Создание базы данных..."
    sqlite3 movies_rating.db < db_init.sql
    echo "База создана!"
fi

# Добавляем индексы для ускорения запросов (выполняется моментально, если их нет)
sqlite3 movies_rating.db "CREATE INDEX IF NOT EXISTS idx_ratings_user ON ratings(user_id);"
sqlite3 movies_rating.db "CREATE INDEX IF NOT EXISTS idx_tags_user ON tags(user_id);"
sqlite3 movies_rating.db "CREATE INDEX IF NOT EXISTS idx_movies_id ON movies(id);"

echo "1. Для каждого фильма выведите его название, год выпуска и средний рейтинг. Дополнительно добавьте столбец rank_by_avg_rating, в котором укажите ранг фильма среди всех фильмов по убыванию среднего рейтинга (фильмы с одинаковым средним рейтингом должны получить одинаковый ранг). Используйте оконную функцию RANK() или DENSE_RANK(). В результирующем наборе данных оставить 10 фильмов с наибольшим рангом."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH AvgRatings AS (SELECT m.id, m.title, m.year, AVG(r.rating) AS avg_rating FROM movies m JOIN ratings r ON m.id = r.movie_id WHERE m.year IS NOT NULL GROUP BY m.id) SELECT title, year, ROUND(avg_rating, 2) AS avg_rating, RANK() OVER (ORDER BY avg_rating DESC) AS rank_by_avg_rating FROM AvgRatings LIMIT 10;"
echo " "

echo "2. С помощью рекурсивного CTE выделить все жанры фильмов, имеющиеся в таблице movies. Для каждого жанра рассчитать средний рейтинг avg_rating фильмов в этом жанре. Выведите genre, avg_rating и ранг жанра по убыванию среднего рейтинга, используя оконную функцию RANK()."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH RECURSIVE split(genre, rest, movie_id) AS (SELECT '', genres || '|', id FROM movies UNION ALL SELECT substr(rest, 0, instr(rest, '|')), substr(rest, instr(rest, '|') + 1), movie_id FROM split WHERE rest <> ''), MovieGenres AS (SELECT DISTINCT movie_id, genre FROM split WHERE genre <> ''), AvgGenreRatings AS (SELECT mg.genre, AVG(r.rating) AS avg_rating FROM MovieGenres mg JOIN ratings r ON mg.movie_id = r.movie_id GROUP BY mg.genre) SELECT genre, ROUND(avg_rating, 2) AS avg_rating, RANK() OVER (ORDER BY avg_rating DESC) AS genre_rank FROM AvgGenreRatings;"
echo " "

echo "3. Посчитайте количество фильмов в каждом жанре. Выведите два столбца: genre и movie_count, отсортировав результат по убыванию количества фильмов."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH RECURSIVE split(genre, rest, movie_id) AS (SELECT '', genres || '|', id FROM movies UNION ALL SELECT substr(rest, 0, instr(rest, '|')), substr(rest, instr(rest, '|') + 1), movie_id FROM split WHERE rest <> ''), MovieGenres AS (SELECT DISTINCT movie_id, genre FROM split WHERE genre <> '') SELECT genre, COUNT(movie_id) AS movie_count FROM MovieGenres GROUP BY genre ORDER BY movie_count DESC;"
echo " "

echo "4. Найдите жанры, в которых чаще всего оставляют теги (комментарии). Для этого подсчитайте общее количество записей в таблице tags для фильмов каждого жанра. Выведите genre, tag_count и долю этого жанра в общем числе тегов (tag_share), выраженную в процентах."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH RECURSIVE split(genre, rest, movie_id) AS (SELECT '', genres || '|', id FROM movies UNION ALL SELECT substr(rest, 0, instr(rest, '|')), substr(rest, instr(rest, '|') + 1), movie_id FROM split WHERE rest <> ''), MovieGenres AS (SELECT DISTINCT movie_id, genre FROM split WHERE genre <> ''), GenreTagCounts AS (SELECT mg.genre, COUNT(t.id) AS tag_count FROM MovieGenres mg JOIN tags t ON mg.movie_id = t.movie_id GROUP BY mg.genre), TotalTags AS (SELECT COUNT(*) AS total FROM tags) SELECT genre, tag_count, ROUND((tag_count * 100.0) / (SELECT total FROM TotalTags), 2) AS tag_share FROM GenreTagCounts ORDER BY tag_count DESC;"
echo " "

echo "5. Для каждого пользователя рассчитайте: общее количество выставленных оценок, средний выставленный рейтинг, дату первой и последней оценки (по полю timestamp в таблице ratings). Выведите user_id, rating_count, avg_rating, first_rating_date, last_rating_date. Отсортируйте результат по убыванию количества оценок и выведите только 10 первых строк."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT user_id, COUNT(*) AS rating_count, ROUND(AVG(rating), 2) AS avg_rating, date(MIN(timestamp), 'unixepoch') AS first_rating_date, date(MAX(timestamp), 'unixepoch') AS last_rating_date FROM ratings GROUP BY user_id ORDER BY rating_count DESC LIMIT 10;"
echo " "

echo "6. Сегментируйте пользователей по типу поведения:"
echo "«Комментаторы» — пользователи, у которых количество тегов (tags) больше количества оценок (ratings),"
echo "«Оценщики» — наоборот, оценок больше, чем тегов,"
echo "«Активные» — и оценок, и тегов >= 10,"
echo "«Пассивные» — и оценок, и тегов < 5. Выведите user_id, общее число оценок, общее число тегов и категорию поведения. Используйте CASE."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH UserRatings AS (SELECT user_id, COUNT(*) AS rating_count FROM ratings GROUP BY user_id), UserTags AS (SELECT user_id, COUNT(*) AS tag_count FROM tags GROUP BY user_id) SELECT u.id AS user_id, COALESCE(ur.rating_count, 0) AS rating_count, COALESCE(ut.tag_count, 0) AS tag_count, CASE WHEN COALESCE(ur.rating_count, 0) >= 10 AND COALESCE(ut.tag_count, 0) >= 10 THEN 'Активные' WHEN COALESCE(ur.rating_count, 0) < 5 AND COALESCE(ut.tag_count, 0) < 5 THEN 'Пассивные' WHEN COALESCE(ut.tag_count, 0) > COALESCE(ur.rating_count, 0) THEN 'Комментаторы' ELSE 'Оценщики' END AS behavior_type FROM users u LEFT JOIN UserRatings ur ON u.id = ur.user_id LEFT JOIN UserTags ut ON u.id = ut.user_id;"
echo " "

echo "7. Для каждого пользователя выведите его имя и последний фильм, который он оценил (по времени из ratings.timestamp). Если пользователь не оценивал ни одного фильма, он всё равно должен быть в результате (с NULL в полях фильма). Результат: user_id, name, last_rated_movie_title, last_rating_timestamp."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH RankedRatings AS (SELECT user_id, movie_id, timestamp, ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY timestamp DESC) as rn FROM ratings) SELECT u.id AS user_id, u.name, m.title AS last_rated_movie_title, rr.timestamp AS last_rating_timestamp FROM users u LEFT JOIN RankedRatings rr ON u.id = rr.user_id AND rr.rn = 1 LEFT JOIN movies m ON rr.movie_id = m.id;"
echo " "