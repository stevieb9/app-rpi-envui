CREATE TABLE IF NOT EXISTS stats (
  id integer primary key autoincrement,
  datetime DATETIME DEFAULT CURRENT_TIMESTAMP,
  temp tinyint(3) not NULL,
  humidity tinyint(3) not NULL
);

DROP TABLE IF EXISTS aux;

CREATE TABLE aux (
    id VARCHAR(4),
    pin TINYINT(2),
    state TINYINT(1),
    override TINYINT(1),
    on_time INTEGER
);

INSERT INTO aux VALUES ('aux1', 0, 0, 0, 0);
INSERT INTO aux VALUES ('aux2', 0, 0, 0, 0);
INSERT INTO aux VALUES ('aux3', -1, 0, 0, 0);
INSERT INTO aux VALUES ('aux4', -1, 0, 0, 0);
INSERT INTO aux VALUES ('aux5', -1, 0, 0, 0);

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

DROP TABLE IF EXISTS core;

CREATE TABLE core (
    id VARCHAR(20),
    value VARCHAR(50)
);

INSERT INTO core VALUES ('event_fetch_timer', 15);
INSERT INTO core VALUES ('event_action_timer', 3);
INSERT INTO core VALUES ('event_display_timer', 4);

DROP TABLE IF EXISTS light;

CREATE TABLE light (
    id VARCHAR(20),
    value VARCHAR(50)
);

INSERT INTO light VALUES ('on_at', '18:00');
INSERT INTO light VALUES ('on_hours', '12');

