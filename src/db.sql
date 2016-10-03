CREATE TABLE IF NOT EXISTS stats (
  id integer primary key autoincrement,
  datetime DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
  temp tinyint(3) not NULL,
  humidity tinyint(3) not NULL
);

DROP TABLE IF EXISTS aux;

CREATE TABLE aux (
    id VARCHAR(4),
    desc VARCHAR(50),
    pin TINYINT(2),
    state TINYINT(1),
    override TINYINT(1),
    on_time INTEGER
);

INSERT INTO aux VALUES ('aux1', 'temp', 0, 0, 0, 0);
INSERT INTO aux VALUES ('aux2', 'humidity', 0, 0, 0, 0);
INSERT INTO aux VALUES ('aux3', 'water1', -1, 0, 0, 0);
INSERT INTO aux VALUES ('aux4', 'water2', -1, 0, 0, 0);
INSERT INTO aux VALUES ('aux5', 'light', -1, 0, 0, 0);
INSERT INTO aux VALUES ('aux6', '', -1, 0, 0, 0);
INSERT INTO aux VALUES ('aux7', '', -1, 0, 0, 0);
INSERT INTO aux VALUES ('aux8', '', -1, 0, 0, 0);

DROP TABLE IF EXISTS control;

CREATE TABLE control (
    id VARCHAR(50),
    value VARCHAR(50)
);

INSERT INTO control VALUES ('temp_limit', 80);
INSERT INTO control VALUES ('humidity_limit', 20);
INSERT INTO control VALUES ('temp_aux_on_time', 1800);
INSERT INTO control VALUES ('humidity_aux_on_time', 1800);

INSERT INTO control VALUES ('temp_aux', 'aux1');
INSERT INTO control VALUES ('humidity_aux', 'aux2');
INSERT INTO control VALUES ('light_aux', 'aux3');
INSERT INTO control VALUES ('water1_aux', 'aux4');
INSERT INTO control VALUES ('water2_aux', 'aux5');

DROP TABLE IF EXISTS core;

CREATE TABLE core (
    id VARCHAR(20),
    value VARCHAR(50)
);

INSERT INTO core VALUES ('event_fetch_timer', 15);
INSERT INTO core VALUES ('event_action_timer', 3);
INSERT INTO core VALUES ('event_display_timer', 4);
INSERT INTO core VALUES ('sensor_pin', 0);
INSERT INTO core VALUES ('time_zone', 'local');

DROP TABLE IF EXISTS water;

CREATE TABLE water (
    id VARCHAR(20),
    value VARCHAR(50)
);

INSERT INTO water VALUES ('enable', 0);

DROP TABLE IF EXISTS light;

CREATE TABLE light (
    id VARCHAR(20),
    value VARCHAR(50)
);

INSERT INTO light VALUES ('on_at', '18:00');
INSERT INTO light VALUES ('on_in', '00:00');
INSERT INTO light VALUES ('on_hours', '12');
INSERT INTO light VALUES ('on_since', 0);
INSERT INTO light VALUES ('toggle', 'enabled');
INSERT INTO light VALUES ('enable', 0);
