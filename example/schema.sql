create table people (
    id integer primary key,
    first_name  varchar,
    last_name   varchar,
    email       varchar,
    gender      varchar,
    age         int,
    notes       text
);

insert into people (first_name, last_name, email, gender, age)
    values ( 'David', 'Precious', 'davidp@preshweb.co.uk', 'Male', 29)
;

