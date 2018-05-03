package t::lib::TestAppDBIC;

use Dancer;
#use Dancer::Plugin::DBIC;
use Test::More import => ['!pass']; # import avoids 'prototype mismatch' with Dancer
use File::Temp qw(tempfile);

eval { require Dancer::Plugin::DBIC };  # not a hard req
# do not initialize if we can't find Dancer::Plugin::DBIC

unless ($@) {
    my $db_fh = File::Temp->new( EXLOCK => 0 );

    sub _dsn { "dbi:SQLite:$db_fh" }
    config->{plugins}{DBIC}{default}{dsn} = _dsn();

    BEGIN {
        eval { use Dancer::Plugin::SimpleCRUD; };
        if ($@) { die "Can't load Dancer::Plugin::SimpleCRUD. Bail out!\n"; }
    }
    my $password = "{SSHA}LfvBweDp3ieVPRjAUeWikwpaF6NoiTSK";     # password is 'tester'
    my @sql = (
        #q/drop table if exists users/,
        qq/create table users (id INTEGER, username VARCHAR, password VARCHAR)/,
        qq/insert into users values (0, 'nobody', 'nobodyhasaplaintextpassword!')/,
        qq/insert into users values (1, 'sukria', '$password')/,
        qq/insert into users values (2, 'bigpresh', '$password')/,
        qq/insert into users values (3, 'badger', '$password')/,
        qq/insert into users values (4, 'bodger', '$password')/,
        qq/insert into users values (5, 'mousey', '$password')/,
        qq/insert into users values (6, 'mystery2', '$password')/,
        qq/insert into users values (7, 'mystery1', '$password')/,
    );

    Dancer::Plugin::DBIC::schema()->storage->dbh->do($_) for @sql;

    # now set up our simple_crud interface, and use DBIC
    simple_crud( prefix => '/users',  record_title=>'A', db_table => 'users', editable => 0, db_connection_provider => "DBIC" );
}


1;
