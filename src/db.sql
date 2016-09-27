CREATE TABLE IF NOT EXISTS stats (
  id integer primary key autoincrement,
  datetime DATETIME DEFAULT CURRENT_TIMESTAMP,
  temp tinyint(3) not NULL,
  humidity tinyint(3) not NULL
);

CREATE TABLE IF NOT EXISTS aux (
    id VARCHAR(4),
    pin TINYINT(2),
    state TINYINT(1),
    override TINYINT(1),
    on_time INTEGER
);

DROP TABLE IF EXISTS control;

CREATE TABLE control (
    id INTEGER primary key autoincrement,
    temp_limit TINYINT(3),
    humidity_limit TINYINT(3),
    temp_aux_on_time INTEGER,
    humidity_aux_on_time INTEGER,
    temp_aux VARCHAR(7),
    humidity_aux VARCHAR(7)
);

INSERT INTO control VALUES (NULL, 80, 20, 900, 900, 'aux1', 'aux2');


