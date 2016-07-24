#!perl 

use Test::More;

use Dancer qw(:syntax :tests);
use Dancer::Test;

use FindBin qw($Bin);
use lib "$Bin/lib";	#

BEGIN {
	config->{plugins}{Database}{driver} = "CSV";
	config->{plugins}{Database}{database} = "/tmp/foo-$$.csv";
	use_ok( 'TestCRUD' ) || die "Can't load test module TestCRUD";
};

route_exists [ GET => '/test_table' ];

done_testing();

END {
	$ENV{PATH} = "/usr/bin:/bin";
	system( "rm -f /tmp/foo-$$.csv" );
}

