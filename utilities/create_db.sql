CREATE DATABASE chat;
CREATE USER chat_user WITH PASSWORD 'test123';
GRANT CONNECT ON DATABASE chat TO chat_user;
\connect chat;
CREATE TABLE history (id serial PRIMARY KEY, username VARCHAR (255) DEFAULT NULL, message VARCHAR(255), date_created DATE NOT NULL DEFAULT CURRENT_DATE, time_created TIME DEFAULT CURRENT_TIME );
GRANT USAGE ON SCHEMA public TO chat_user;
GRANT ALL PRIVILEGES ON table history to chat_user;
GRANT USAGE ON SEQUENCE history_id_seq TO chat_user;
