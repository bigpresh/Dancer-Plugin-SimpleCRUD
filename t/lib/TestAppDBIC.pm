package t::lib::TestAppDBIC;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Test::More import => ['!pass']; # import avoids 'prototype mismatch' with Dancer
use File::Temp qw(tempfile);
use t::lib::TestAppBase;

use Moo;
has 'db_fh' => (is=>'rw', required=>1 );

eval { require Dancer::Plugin::DBIC };  # not a hard req
# do not initialize if we can't find Dancer::Plugin::DBIC
if ($@) {
  plan skip_all => 'Dancer::Plugin::DBIC required to run these tests';
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
