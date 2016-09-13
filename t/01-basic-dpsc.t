use strict;
use warnings;

use Test::More import => ['!pass'];
use Test::Differences;
use t::lib::TestApp;
use Dancer ':syntax';

use Dancer::Test;
use HTML::TreeBuilder;

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

# test basic routes return 200 codes
response_status_is    [ GET => '/users' ],        200,   "GET /users returns 200";
response_status_is    [ GET => '/users/add' ],    200,   "GET /users/add returns 200";
response_status_is    [ GET => '/users/edit/1' ], 200,   "GET /users/edit/1 returns 200";
response_status_is    [ GET => '/users/view/1' ], 200,   "GET /users/view/1 returns 200";
response_status_is    [ GET => '/users?searchfield=id&searchtype=e&q=1' ], 200, "GET {search on id=1} returns 200";

###############################################################################
# test suggestions from bigpresh:
# Hmm, I'd like to parse the resulting output, and test:
#    1) all columns are present as expected
#    2) supplied custom columns are present
#    3) values calculated in custom columns are as expected
#    4) add/edit/delete routes work
#    5) searching works
#    6) sorting works
###############################################################################

my $response = dancer_response GET => '/users';
is $response->{status}, 200, "response for GET /users is 200";

my $tree = HTML::TreeBuilder->new_from_content( $response->{content} );

# high-level test definition

# this test looks for the 0th thead tag, thenthe 0th tr tag, then compares the text of the tags therein
test_html_contents( $tree, [qw( thead:0 tr:0 )], ["id", "username", "password", "actions"], "correct table headers" );


sub test_html_contents {
    my ($tree, $elements_spec, $row_contents_expected, $test_name) = @_;
    my $node = $tree;
    for my $e (@$elements_spec) {
        my ($tag, $n) = split(/:/, $e);
        $node = ($node->look_down( '_tag', $tag ))[$n];
        last unless $node;
    }
    return ok(0, "can't find html matching elements_spec (@$elements_spec)") unless $node;

    my @texts = map { $_->as_text() } $node->content_list();
    eq_or_diff( \@texts, $row_contents_expected, $test_name );
}

done_testing();
