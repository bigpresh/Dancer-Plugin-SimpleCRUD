use strict;
use warnings;

use Test::More import => ['!pass'];
use t::lib::TestApp;
use Dancer ':syntax';

use Dancer::Test;

eval { require DBD::SQLite };
if ($@) {
    plan skip_all => 'DBD::SQLite required to run these tests';
}

my $dsn = "dbi:SQLite:dbname=:memory:";

my $conf = {
            Database => {
                         dsn => $dsn,
                         connection_check_threshold => 0.1,
                         dbi_params => {
                                        RaiseError => 0,
                                        PrintError => 0,
                                        PrintWarn  => 0,
                                       },
                         handle_class => 'TestHandleClass',
                        }
           };


set plugins => $conf;
set logger => 'capture';
set log => 'debug';

response_status_is    [ GET => '/users' ], 200,   "GET /users is found";

done_testing();
