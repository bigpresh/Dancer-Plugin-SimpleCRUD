package t::lib::TestAppDatabase;

use Dancer;
use Dancer::Plugin::Database;
use Test::More import => ['!pass']; # import avoids 'prototype mismatch' with Dancer
use File::Temp qw(tempfile);
use t::lib::TestAppBase;

use Moo;


sub setup_database_and_crud {
    my $self = shift;
    my $test_app_base = t::lib::TestAppBase->new( dbh=>database(), provider=>"Database" );
    $test_app_base->setup_database_and_crud();
}
sub test {
    my $self = shift;
    my $test_app_base = t::lib::TestAppBase->new( dbh=>database(), provider=>"Database" );
    $test_app_base->test();
}

1;
