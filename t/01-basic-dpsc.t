use strict;
use warnings;

use Test::More import => ['!pass'];
use t::lib::TestApp;
use Dancer ':syntax';

use Dancer::Test;
use Data::Dump qw(dump);
use Data::Dumper qw(Dumper);
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

# test suggestions from bigpresh:
# Hmm, I'd like to parse the resulting output, and test:
#    all columns are present as expected
#    supplied custom columns are present
#    values calculated in custom columns are as expected
#    add/edit/delete routes work
#    searching works
#    sorting works

my $response = dancer_response GET => '/users';
is $response->{status}, 200, "response for GET /users is 200";
#print "Content: '" .  dump($response->{content}) . "\n";
#is $response->{content}, "Widget #2 has been scheduled for creation",
#    "response content looks good for second POST /widgets";

use HTML::TableExtract;
my $te = HTML::TableExtract->new( headers => [qw(id name category)] );
$te->parse($response->{content});

# Examine all matching tables
foreach my $ts ($te->tables) {
  print "Table coords: (", join(',', $ts->coords), "):\n";
  foreach my $row ($ts->rows) {
     print join(',', @$row), "\n";
  }
}

if(0) {
    my $tree = HTML::TreeBuilder->new_from_content( $response->{content} );
    #print "tree->dump(): " . $tree->dump() . "\n";
    #print "dump(tree): " . Dumper($tree) . "\n";
    my $thead = $tree->find_by_tag_name('thead'); 
    #print "dump(thead): " . Dumper( $thead ) . "\n";

    my @contents = $thead->content_list();
    print "dump(contents): " . Dumper( \@contents ) . "\n";
    my (@headers) = (map { $_->as_text } @contents);
    print "dump(headers): " . Dumper( \@headers ) . "\n";
}
done_testing();
