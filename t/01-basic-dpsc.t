use strict;
use warnings;

use Test::More import => ['!pass'];
use t::lib::TestAppDatabase;
use Dancer ':syntax';

eval { require DBD::SQLite };
if ($@) {
    plan skip_all => 'DBD::SQLite required to run these tests';
}

my $dsn = "dbi:SQLite:dbname=:memory:";

my $conf = {
    Database => {
        dsn                        => $dsn,
        connection_check_threshold => 0.1,
        dbi_params                 => {
            RaiseError => 0,
            PrintError => 0,
            PrintWarn  => 0,
        },
        handle_class => 'TestHandleClass',
    }
};

set plugins => $conf;
set logger  => 'capture';
set log     => 'debug';

my $app = t::lib::TestAppDatabase->new();
$app->setup_database_and_crud();
$app->test();

done_testing();

