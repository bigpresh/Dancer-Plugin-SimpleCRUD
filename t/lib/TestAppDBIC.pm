package t::lib::TestAppDBIC;

use Test::More import => ['!pass']; # import avoids 'prototype mismatch' with Dancer
use t::lib::TestAppBase;
use Dancer ':syntax';
#use Dancer::Plugin::DBIC;  # not a hard req

use Moo;
has 'base' => ( is=>'rw', default=>sub {  t::lib::TestAppBase->new( dbh=>dbh(), provider=>"DBIC" ); } );

eval { require Dancer::Plugin::DBIC };  # not a hard req
if ($@) {
  plan skip_all => 'Dancer::Plugin::DBIC required to run these tests';
}
eval { require DBIx::Class::Schema::Loader };
if ($@) {
    plan skip_all => 'DBIx::Class::Schema::Loader required to run these tests';
}
eval { use Dancer::Plugin::SimpleCRUD; };
if ($@) { die "Can't load Dancer::Plugin::SimpleCRUD. Bail out!\n"; }

sub dbh {
    my $self = shift;
    my $dbh = Dancer::Plugin::DBIC::schema()->storage->dbh;
    bless $dbh => 'Dancer::Plugin::Database::Core::Handle';
    return $dbh;
}

sub setup_database_and_crud {
    my $self = shift;
    $self->base->setup_database_and_crud();
} 
sub test {
    my $self = shift;
    $self->base->test();
}

1;

