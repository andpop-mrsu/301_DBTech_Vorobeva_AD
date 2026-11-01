#!/bin/bash

# Проверяем, существует ли база данных. Если нет - создаем.
if [ ! -f movies_rating.db ]; then
    echo "Создание базы данных..."
    sqlite3 movies_rating.db < db_init.sql
    echo "База создана!"
fi

echo "1. Найти все пары пользователей, оценивших один и тот же фильм. Устранить дубликаты, проверить отсутствие пар с самим собой. Для каждой пары должны быть указаны имена пользователей и название фильма, который они ценили. В списке оставить первые 100 записей."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT DISTINCT u1.name AS user1, u2.name AS user2, m.title FROM ratings r1 JOIN ratings r2 ON r1.movie_id = r2.movie_id AND r1.user_id < r2.user_id JOIN users u1 ON r1.user_id = u1.id JOIN users u2 ON r2.user_id = u2.id JOIN movies m ON r1.movie_id = m.id LIMIT 100;"
echo " "

echo "2. Найти 10 самых свежих оценок от разных пользователей, вывести названия фильмов, имена пользователей, оценку, дату отзыва в формате ГГГГ-ММ-ДД."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT m.title, u.name, r.rating, date(r.timestamp, 'unixepoch') AS rating_date FROM ratings r JOIN users u ON r.user_id = u.id JOIN movies m ON r.movie_id = m.id GROUP BY r.user_id ORDER BY r.timestamp DESC LIMIT 10;"
echo " "

echo "3. Вывести в одном списке все фильмы с максимальным средним рейтингом и все фильмы с минимальным средним рейтингом. Общий список отсортировать по году выпуска и названию фильма. В зависимости от рейтинга в колонке 'Рекомендуем' для фильмов должно быть написано 'Да' или 'Нет'."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH AvgRatings AS (SELECT m.id, m.title, m.year, AVG(r.rating) AS avg_rating FROM movies m JOIN ratings r ON m.id = r.movie_id WHERE m.year IS NOT NULL GROUP BY m.id), MinMax AS (SELECT MAX(avg_rating) AS max_r, MIN(avg_rating) AS min_r FROM AvgRatings) SELECT title, year, avg_rating, CASE WHEN avg_rating = (SELECT max_r FROM MinMax) THEN 'Да' ELSE 'Нет' END AS 'Рекомендуем' FROM AvgRatings WHERE avg_rating = (SELECT max_r FROM MinMax) OR avg_rating = (SELECT min_r FROM MinMax) ORDER BY year ASC, title ASC;"
echo " "

echo "4. Вычислить количество оценок и среднюю оценку, которую дали фильмам пользователи-женщины в период с 2010 по 2012 год."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT COUNT(r.id) AS count_ratings, AVG(r.rating) AS avg_rating FROM ratings r JOIN users u ON r.user_id = u.id WHERE u.gender = 'female' AND strftime('%Y', datetime(r.timestamp, 'unixepoch')) BETWEEN '2010' AND '2012';"
echo " "

echo "5. Составить список фильмов с указанием их средней оценки и места в рейтинге по средней оценке. Полученный список отсортировать по году выпуска и названиям фильмов. В списке оставить первые 20 записей."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH AvgRatings AS (SELECT m.id, m.title, m.year, AVG(r.rating) AS avg_rating FROM movies m JOIN ratings r ON m.id = r.movie_id WHERE m.year IS NOT NULL GROUP BY m.id) SELECT title, year, avg_rating, RANK() OVER (ORDER BY avg_rating DESC) AS rating_place FROM AvgRatings ORDER BY year ASC, title ASC LIMIT 20;"
echo " "

echo "6. Вывести список из 10 последних зарегистрированных пользователей в формате 'Фамилия Имя|Дата регистрации' (сначала фамилия, потом имя)."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "SELECT substr(name, instr(name, ' ') + 1) || ' ' || substr(name, 1, instr(name, ' ') - 1) || '|' || register_date AS user_info FROM users ORDER BY register_date DESC LIMIT 10;"
echo " "

echo "7. С помощью рекурсивного CTE составить таблицу умножения для чисел от 1 до 10. Должен получиться один столбец следующего вида:"
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH RECURSIVE multiplication(i, j) AS (SELECT 1, 1 UNION ALL SELECT CASE WHEN j = 10 THEN i + 1 ELSE i END, CASE WHEN j = 10 THEN 1 ELSE j + 1 END FROM multiplication WHERE i <= 10 AND NOT (i = 10 AND j = 10)) SELECT i || 'x' || j || '=' || (i * j) AS result FROM multiplication;"
echo " "

echo "8. С помощью рекурсивного CTE выделить все жанры фильмов, имеющиеся в таблице movies (каждый жанр в отдельной строке)."
echo "--------------------------------------------------------------------------------"
sqlite3 movies_rating.db -box -echo "WITH RECURSIVE split(genre, rest) AS (SELECT '', genres || '|' FROM movies UNION ALL SELECT substr(rest, 0, instr(rest, '|')), substr(rest, instr(rest, '|') + 1) FROM split WHERE rest <> '') SELECT DISTINCT genre FROM split WHERE genre <> '' ORDER BY genre;"