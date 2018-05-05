package t::lib::TestAppDatabase;

use Dancer;
use Dancer::Plugin::Database;
use Test::More import => ['!pass']; # import avoids 'prototype mismatch' with Dancer
use File::Temp qw(tempfile);
use t::lib::TestAppBase;

use Moo;

has 'db_fh' => (is=>'rw', default=>sub{ File::Temp->new( EXLOCK => 0 ) } );

sub setup_database_and_crud {
    my $self = shift;
    config->{plugins}{Database}{driver} = "SQLite";
    config->{plugins}{Database}{database} = $self->db_fh->filename;
    my $test_app_base = t::lib::TestAppBase->new( dbh=>database(), provider=>"Database" );
    $test_app_base->setup_database_and_crud();
}
sub test {
    my $self = shift;
    my $test_app_base = t::lib::TestAppBase->new( dbh=>database(), provider=>"Database" );
    $test_app_base->test();
}

1;
