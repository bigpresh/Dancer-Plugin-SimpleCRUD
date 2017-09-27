CREATE DATABASE base1;
USE base1;

CREATE TABLE people (
    id integer NOT NULL AUTO_INCREMENT primary key,
    first_name  varchar(50),
    last_name   varchar(80),
    email       varchar(80),
    gender      varchar(30),
    age         int,
    notes       text,
    employer_id int,
    is_admin    boolean default 0
);
INSERT INTO people
VALUES(1,'David','Precious','davidp@preshweb.co.uk','Male',29,'The author of Dancer::Plugin::SimpleCRUD.  He would greatly appreciate any feedback!',1,1);
INSERT INTO people VALUES(2,'John','Smith','john@example.com','Male',39,'A fictional person.',3, 0);
INSERT INTO people VALUES(3,'Jane','Doe','jane@example.com','Female',21,'Another fictional person.',1,1);
INSERT INTO people VALUES(4,'Test','User','test.user@example.com','Male',18,'A test user.',2,0);
INSERT INTO people VALUES(5,'John','Doe','john.doe@example.com','Male',36,NULL,1,0);
INSERT INTO people VALUES(6,'Jack','Doe','jack.doe@example.com','Male',52,NULL,1,0);
INSERT INTO people VALUES(7,'Emma','Doe','emma.doe@example.com','Female',22,'Test!',1,0);
INSERT INTO people VALUES(8,'Sophie','Doe','sophie.doe@example.com','Female',21,'',1,0);
INSERT INTO people VALUES(9,'Hayley','Doe','hayley.doe@example.com','Female',19,NULL,1,0);
INSERT INTO people VALUES(10,'Michelle','Doe','michelle.doe@example.com','Female',29,NULL,1,0);
INSERT INTO people VALUES(11,'Bob','Doe','bob.doe@example.com','Male',36,'Surprise - another test!',1,0);
INSERT INTO people VALUES(12,'Burt','Bacharach','burt@example.com','Male',84,'',2,0);
CREATE TABLE employer ( id integer NOT NULL AUTO_INCREMENT primary key, name varchar(150) );
INSERT INTO employer VALUES(1,'ACME Ltd');
INSERT INTO employer VALUES(2,'Bob''s Widgets Ltd');
INSERT INTO employer VALUES(3,'Bertie''s Badgers PLC');
