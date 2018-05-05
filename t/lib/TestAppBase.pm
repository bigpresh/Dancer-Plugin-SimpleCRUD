package t::lib::TestAppBase;

use Dancer ':syntax';
use Dancer::Logger;
use Dancer::Test;

use Test::More import => ['!pass'];
use Test::Differences;
use HTML::TreeBuilder;

use Moo;
has 'dbh'  => (is=>'rw', required=>1);
has 'trap' => (is=>'rw', default=>sub { Dancer::Logger::Capture->trap } );
has 'provider' => (is=>'rw', required=>1); # "Database" or "DBIC"

BEGIN {
    eval { use Dancer::Plugin::SimpleCRUD; };
    if ($@) { die "Can't load Dancer::Plugin::SimpleCRUD. Bail out!\n"; }
}


sub setup_database_and_crud {
    my $self = shift;

    my $password = "{SSHA}LfvBweDp3ieVPRjAUeWikwpaF6NoiTSK";     # password is 'tester'
    my @sql = (
        #q/drop table if exists users/,
        qq/create table users (id INTEGER, username VARCHAR, password VARCHAR)/,
        qq/insert into users values (0, 'nobody', 'nobodyhasaplaintextpassword!')/,
        qq/insert into users values (1, 'sukria', '$password')/,
        qq/insert into users values (2, 'bigpresh', '$password')/,
        qq/insert into users values (3, 'badger', '$password')/,
        qq/insert into users values (4, 'bodger', '$password')/,
        qq/insert into users values (5, 'mousey', '$password')/,
        qq/insert into users values (6, 'mystery2', '$password')/,
        qq/insert into users values (7, 'mystery1', '$password')/,

        qq/create table roles (id INTEGER, role VARCHAR)/,
        qq/insert into roles values (1, 'superadmin')/,

        qq/create table user_roles (user_id INTEGER, role_id INTEGER)/,
        qq/insert into user_roles values (1, 1)/,
    );

    $self->dbh->do($_) for @sql;

    my %p = ( 
        db_connection_provider => $self->provider,
        record_title => "A",
        db_table => 'users' 
    );
    my $extra_custom_column = { name => 'extra', raw_column => 'id', transform => sub { "Extra: $_[0]" }, column_class=>"classhere" };
    my $id_custom_column    = { name => 'id', raw_column => 'id', transform => sub { "Hello, id: $_[0]" }, column_class=>"classhere" };
    my $username_custom_column = { name => "username", raw_column=>"username", transform => sub { "Username: $_[0]" }, column_class=>"classhere" };


    # now set up our simple_crud interfaces
    simple_crud( %p, prefix => '/users_editable', );
    simple_crud( %p, prefix => '/users', editable => 0, );
    simple_crud( %p, prefix => '/users_editable_not_addable', editable => 1, addable => 0);

    simple_crud( %p, prefix => '/users_custom_columns', editable => 0, 
                    custom_columns => [ $extra_custom_column, $id_custom_column ] 
                );

    # override display of 'username' column
    simple_crud( %p, prefix => '/users_customized_column', editable => 0, sortable=>1,
                    custom_columns => [ $username_custom_column, ], 
                );
    simple_crud( %p, prefix => '/users_customized_column2', editable => 0, sortable=>1,
                    custom_columns => [ $username_custom_column, $extra_custom_column, ],
                );
    simple_crud( %p, prefix => '/users_customized_column3', editable => 0, sortable=>1,
                    custom_columns => [ $username_custom_column, $extra_custom_column, $id_custom_column ],
                );

    # auth
    simple_crud( %p, prefix => '/users_auth', 
               auth => {
                   view => { require_login => 1, },
                   edit => { require_role => 'superadmin', },
               },
    );
}

sub test {
    my $self = shift;

    # test basic routes return 200 codes
    response_status_is [GET => '/users'], 200, "GET /users returns 200";
    response_status_is [GET => '/users/add'], 404,
        "GET /users/add returns 404";
    response_status_is [GET => '/users_editable/add'], 200,
        "GET /users_editable/add returns 200";
    response_status_is [GET => '/users_editable/edit/1'], 200,
        "GET /users_editable/edit/1 returns 200";
    response_status_is [GET => '/users/view/1'], 200,
        "GET /users/view/1 returns 200";
    response_status_is [GET => '/users_editable/view/1'], 200,
        "GET /users_editable/view/1 returns 200";
    response_status_is [GET => '/users?searchfield=id&searchtype=e&q=1'],
        200, "GET {search on id=1} returns 200";
    response_status_is [
        GET => '/users?searchfield=username&searchtype=like&q=1'
    ], 200, "GET {search on username like '1'} returns 200";

    # /users_auth returns 302
    response_status_is [
        GET => '/users_auth',
    ], 302, "GET on /users_auth redirects";

    # test html returned from GET $prefix on cruds
    my $users_tree = crud_fetch_to_htmltree(GET => '/users', 200);
    my $users_editable_tree
        = crud_fetch_to_htmltree(GET => '/users_editable', 200);
    my $users_editable_not_addable_tree
        = crud_fetch_to_htmltree(GET => '/users_editable_not_addable', 200);
    my $users_custom_columns_tree
        = crud_fetch_to_htmltree(GET => '/users_custom_columns', 200);
    my $users_customized_column_tree
        = crud_fetch_to_htmltree(GET => '/users_customized_column', 200);
    my $users_customized_column2_tree
        = crud_fetch_to_htmltree(GET => '/users_customized_column2', 200);
    my $users_customized_column3_tree
        = crud_fetch_to_htmltree(GET => '/users_customized_column3', 200);
    my $users_search_tree = crud_fetch_to_htmltree(GET => '/users?q=2', 200);
    my $users_like_search_tree = crud_fetch_to_htmltree(
        GET => '/users?searchtype=like&searchfield=username&q=bigpresh',
        200
    );

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

    ###############################################################################
    # high-level test definitions
    ###############################################################################

    # 1) all columns are present as expected
    # this test looks for the 0th thead tag, thenthe 0th tr tag, then compares the text of the tags therein
    test_htmltree_contents(
        $users_tree, [qw( thead:0 tr:0 )],
        ["id", "username", "password",],
        "table headers, not editable"
    );

    # 1a) check editable table gives 'actions' header
    test_htmltree_contents(
        $users_editable_tree, [qw( thead:0 tr:0 )],
        ["id", "username", "password", "actions"],
        "table headers, editable"
    );

    # 1b) check editable but not addable table also gives 'actions' header
    test_htmltree_contents(
        $users_editable_not_addable_tree,
        [qw( thead:0 tr:0 )],
        ["id", "username", "password", "actions"],
        "table headers, editable"
    );

    # 2) supplied custom columns are present. the spec tests the header row.
    test_htmltree_contents(
        $users_custom_columns_tree, [qw( thead:0 tr:0 )],
        ["id", "username", "password", "extra"],
        "table headers, custom column"
    );

    # 3) values calculated in custom columns are as expected. (Test first two rows)
    test_htmltree_contents(
        $users_custom_columns_tree,
        [qw( tbody:0 tr:0 )],
        [
            "Hello, id: 0", "nobody", "nobodyhasaplaintextpassword!",
            "Extra: 0"
        ],
        "table content, custom column"
    );
    test_htmltree_contents(
        $users_custom_columns_tree,
        [qw( tbody:0 tr:1 )],
        [
            "Hello, id: 1",                           "sukria",
            "{SSHA}LfvBweDp3ieVPRjAUeWikwpaF6NoiTSK", "Extra: 1"
        ],
        "table content, custom column"
    );

    # 3A) overridden customized columns as expected
    test_htmltree_contents(
        $users_customized_column_tree,
        [qw( tbody:0 tr:1 )],
        ["1", "Username: sukria", "{SSHA}LfvBweDp3ieVPRjAUeWikwpaF6NoiTSK",],
        "table content, customized column"
    );
    test_htmltree_contents(
        $users_customized_column2_tree,
        [qw( tbody:0 tr:1 )],
        [
            "1",                                      "Username: sukria",
            "{SSHA}LfvBweDp3ieVPRjAUeWikwpaF6NoiTSK", "Extra: 1"
        ],
        "table content, customized column"
    );
    test_htmltree_contents(
        $users_customized_column3_tree,
        [qw( tbody:0 tr:1 )],
        [
            "Hello, id: 1",
            "Username: sukria",
            "{SSHA}LfvBweDp3ieVPRjAUeWikwpaF6NoiTSK",
            "Extra: 1"
        ],
        "table content, customized column"
    );

    # 3B) custom_column's column_class gets applied both with added columns and overridden columns
    my $response = dancer_response(GET => "/users_custom_columns");
    like(
        $response->{content},
        qr{<td class="classhere">Hello, id: \d+</td>},
        "column_class in added custom_column",
    );

    $response = dancer_response(GET => "/users_customized_column");
    like(
        $response->{content},
        qr{<td class="classhere">Username: sukria</td>},
        "column_class from in /users_customized_column html",
    );

    # 4) add/edit/delete routes work (To Be Written)
    # We can edit user 0, and expect the existing data to be populated
    $response = dancer_response(GET => "/users_editable/edit/0");
    like(
        $response->content,
        qr/value="nobodyhasaplaintextpassword!"/,
        "Fetching user 0 populates data (GH-100)",
    );

    # Can't try to edit a record that doesn't exist
    for my $fake_id (qw(100 -50 badger)) {
        $response = dancer_response(GET => "/users_editable/edit/$fake_id");
        is($response->status, 404, "No edit page for fake ID $fake_id");
    }

    # TODO: test actual editing (submit changes, etc)

    # 5) searching works
    test_htmltree_contents(
        $users_search_tree, [qw( tbody:0 tr:0 )],
        ["2", "bigpresh", "{SSHA}LfvBweDp3ieVPRjAUeWikwpaF6NoiTSK"],
        "table content, search q=2"
    );

    test_htmltree_contents(
        $users_like_search_tree,
        [qw( tbody:0 tr:0 )],
        ["2", "bigpresh", "{SSHA}LfvBweDp3ieVPRjAUeWikwpaF6NoiTSK"],
        "table content, search username like 'bigpresh'"
    );

    # 6) sorting works
    # TODO

    # show captured errors
    my $traps = $self->trap->read();
    my @errors = grep { $_->{level} eq "error" } @$traps;
    ok(@errors == 0, "no errors");
    for my $error (@errors) {
        diag("trapped error: $error->{message}");
    }

}

# my $tree_base = crud_fetch_to_htmltree( $method, $path, $status );
# runs one test internally
sub crud_fetch_to_htmltree {
    my ($method, $path, $status) = @_;
    my $response = dancer_response($method => $path);
    is $response->{status}, $status, "response for $method $path is $status";
    return HTML::TreeBuilder->new_from_content($response->{content});
}

# test_htmltree_contents( $tree, $elements_spec, $row_contents_expected, $test_name)
# look for nested element using elements_spec, and test if found row is as expected. Runs one test.
sub test_htmltree_contents {
    my ($tree, $elements_spec, $row_contents_expected, $test_name) = @_;
    my $node = $tree;
    for my $e (@$elements_spec) {
        my ($tag, $n) = split(/:/, $e);
        $node = ($node->look_down('_tag', $tag))[$n];
        last unless $node;
    }
    return ok(0,
        "$test_name: can't find html matching elements_spec (@$elements_spec)"
    ) unless $node;

    my @texts = map { $_->as_text() } $node->content_list();
    eq_or_diff(\@texts, $row_contents_expected, $test_name);
}


1;
