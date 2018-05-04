package t::lib::TestAppDBIC;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Test::More import => ['!pass']; # import avoids 'prototype mismatch' with Dancer
use File::Temp qw(tempfile);
use t::lib::TestAppBase;

use Mouse;
has 'db_fh' => (is=>'rw', isa=>"File::Temp", required=>1 );

eval { require Dancer::Plugin::DBIC };  # not a hard req
# do not initialize if we can't find Dancer::Plugin::DBIC
if ($@) {
  plan skip_all => 'DBD::SQLite required to run these tests';
}
eval { require DBIx::Class::Schema::Loader };
if ($@) {
    plan skip_all => 'DBIx::Class::Schema::Loader required to run these tests';
}
eval { use Dancer::Plugin::SimpleCRUD; };
if ($@) { die "Can't load Dancer::Plugin::SimpleCRUD. Bail out!\n"; }

sub _dsn { 
    my $tmpfile = shift;
    return "dbi:SQLite:$tmpfile";
}
sub dbh {
    my $self = shift;
    my $dbh = schema()->storage->dbh;
    bless $dbh => 'Dancer::Plugin::Database::Core::Handle';
    return $dbh;
}
sub setup_database_and_crud {
    my $self = shift;
    config->{plugins}{DBIC}{default}{dsn} = _dsn( $self->db_fh );
    my $test_app_base = t::lib::TestAppBase->new( dbh => $self->dbh(), provider=>"DBIC" );
    $test_app_base->setup_database_and_crud();
} 
sub test {
    my $self = shift;
    my $test_app_base = t::lib::TestAppBase->new( dbh => $self->dbh(), provider=>"DBIC" );
    $test_app_base->test();
}
1;
__END__

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


1;
