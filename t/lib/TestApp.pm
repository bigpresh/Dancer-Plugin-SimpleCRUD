package t::lib::TestApp;

use Dancer;
use Dancer::Plugin::Database;
use Test::More import => ['!pass']; # import avoids 'prototype mismatch' with Dancer
use File::Temp qw(tempfile);

my ($db_fh, $db_filename) = tempfile( "dpsc-sqlite-XXXXX", TMPDIR => 1, UNLINK=>1 );

config->{plugins}{Database}{driver} = "SQLite";
config->{plugins}{Database}{database} = $db_filename;

BEGIN {
    use_ok( 'Dancer::Plugin::SimpleCRUD' ) || die "Can't load Dancer::Plugin::SimpleCrud. Bail out!\n";
}
my @sql = (
    #q/drop table if exists users/,
    q/create table users (id INTEGER, name VARCHAR, category VARCHAR)/,
    q/insert into users values (1, 'sukria', 'admin')/,
    q/insert into users values (2, 'bigpresh', 'admin')/,
    q/insert into users values (3, 'badger', 'animal')/,
    q/insert into users values (4, 'bodger', 'man')/,
    q/insert into users values (5, 'mousey', 'animal')/,
    q/insert into users values (6, 'mystery2', '')/,
    q/insert into users values (7, 'mystery1', '')/,
);

database->do($_) for @sql;

# At the very end, add  simple_crud test
simple_crud(
    record_title => 'Users',
    prefix => '/users',
    db_table => 'users',
    editable => 1,
);
1;
