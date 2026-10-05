@echo off
py make_db_init.py
sqlite3 movies_rating.db < db_init.sql