package t::lib::TestAppDatabase;

use Dancer;
use Dancer::Plugin::Database;
use Test::More import => ['!pass']; # import avoids 'prototype mismatch' with Dancer
use File::Temp qw(tempfile);
use t::lib::TestAppBase;

use Moo;
has 'base' => ( is=>'rw', default=>sub {  t::lib::TestAppBase->new( dbh=>database(), provider=>"Database" ); } );

sub setup_database_and_crud {
    my $self = shift;
    $self->base->setup_database_and_crud();
}
sub test {
    my $self = shift;
    $self->base->test();
}

1;
