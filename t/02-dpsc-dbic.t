use strict;
use warnings;

use Test::More import => ['!pass'];
use Test::Differences;
use t::lib::TestAppDBIC;
use Dancer ':syntax';

use Dancer::Test;
use HTML::TreeBuilder;

eval { require DBD::SQLite };
if ($@) {
    plan skip_all => 'DBD::SQLite required to run these tests';
}
eval { require Dancer::Plugin::DBIC };
if ($@) {
    plan skip_all => 'Dancer::Plugin::DBIC required to run these tests';
}
eval { require DBIx::Class::Schema::Loader };
if ($@) {
    plan skip_all => 'DBIx::Class::Schema::Loader required to run these tests';
}

my $dsn = t::lib::TestAppDBIC::_dsn();

my $conf = {
    DBIC => {
        default => {
            dsn                        => $dsn,
            connection_check_threshold => 0.1,
            dbi_params                 => {
                RaiseError => 0,
                PrintError => 0,
                PrintWarn  => 0,
            },
            #handle_class => 'TestHandleClass',
        }
    }
};

set plugins => $conf;
set logger  => 'capture';
set log     => 'debug';
my $trap = Dancer::Logger::Capture->trap;

main();

sub main {

    # test basic route returns 200 codes and /users/add returns 404
    response_status_is [GET => '/users'],     200, "GET /users returns 200";
    response_status_is [GET => '/users/add'], 404, "GET /users/add returns 404";

    done_testing();
}

