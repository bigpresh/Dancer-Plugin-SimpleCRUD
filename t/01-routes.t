#!perl 

use Test::More;

use Dancer qw(:syntax :tests);
use Dancer::Test;
use File::Temp;

use FindBin qw($Bin);
use lib "$Bin/lib";	#
my $filename = File::Temp->new(UNLINK=>1);    # will be automatically unlinked. Set to 0 to keep.

config->{plugins}{Database}{driver} = "CSV";
config->{plugins}{Database}{database} = $filename;
use_ok( 'TestCRUD' ) || die "Can't load test module TestCRUD";

route_exists [ GET => '/test_table' ];

done_testing();


