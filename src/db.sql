CREATE TABLE stats (
  id integer primary key autoincrement,
  datetime DATETIME DEFAULT CURRENT_TIMESTAMP,
  temp tinyint(3) not NULL,
  humidity tinyint(3) not NULL
);

CREATE TABLE aux (
    id VARCHAR(5),
    state TINYINT(1),
    override TINYINT(1),
    on_time INTEGER
);