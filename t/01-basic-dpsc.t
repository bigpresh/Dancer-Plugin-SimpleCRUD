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

response_status_is    [ GET => '/users' ],        200,   "GET /users returns 200";

response_status_is    [ GET => '/users/add' ],    200,   "GET /users/add returns 200";

response_status_is    [ GET => '/users/edit/1' ], 200,   "GET /users/edit/1 returns 200";

response_status_is    [ GET => '/users/view/1' ], 200,   "GET /users/view/1 returns 200";

response_status_is    [ GET => '/users?searchfield=id&searchtype=e&q=1' ], 200, "GET {search on id=1} returns 200";

done_testing();
