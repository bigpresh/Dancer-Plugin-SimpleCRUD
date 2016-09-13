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
my $password = "{SSHA}LfvBweDp3ieVPRjAUeWikwpaF6NoiTSK";     # password is 'tester'
my @sql = (
    #q/drop table if exists users/,
    qq/create table users (id INTEGER, username VARCHAR, password VARCHAR)/,
    qq/insert into users values (1, 'sukria', '$password')/,
    qq/insert into users values (2, 'bigpresh', '$password')/,
    qq/insert into users values (3, 'badger', '$password')/,
    qq/insert into users values (4, 'bodger', '$password')/,
    qq/insert into users values (5, 'mousey', '$password')/,
    qq/insert into users values (6, 'mystery2', '$password')/,
    qq/insert into users values (7, 'mystery1', '$password')/,
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
