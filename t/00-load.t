#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Dancer::Plugin::SimpleCRUD' ) || print "Bail out!
";
}

diag( "Testing Dancer::Plugin::SimpleCRUD $Dancer::Plugin::SimpleCRUD::VERSION, Perl $], $^X" );
