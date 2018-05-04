use strict;
use warnings;

use Test::More import => ['!pass'];
#use Test::Differences;
use t::lib::TestAppDBIC;
use Dancer ':syntax';
#
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
my $tmpfile = File::Temp->new( EXLOCK => 0 );

my $dsn = t::lib::TestAppDBIC::_dsn($tmpfile);

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
my $app = t::lib::TestAppDBIC->new(db_fh=>$tmpfile);
$app->setup_database_and_crud();
$app->test();

done_testing();


