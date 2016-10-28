package t::lib::TestApp;

use Dancer;
use Dancer::Plugin::Database;
use Test::More import => ['!pass']; # import avoids 'prototype mismatch' with Dancer
use File::Temp qw(tempfile);

my $db_fh = File::Temp->new( EXLOCK => 0 );

config->{plugins}{Database}{driver} = "SQLite";
config->{plugins}{Database}{database} = $db_fh->filename;

BEGIN {
    use_ok( 'Dancer::Plugin::SimpleCRUD' ) || die "Can't load Dancer::Plugin::SimpleCrud. Bail out!\n";
}
my $password = "{SSHA}LfvBweDp3ieVPRjAUeWikwpaF6NoiTSK";     # password is 'tester'
my @sql = (
    qq/create table users (id INTEGER, username VARCHAR, password VARCHAR, type_id INTEGER)/,
    qq/insert into users values (1, 'sukria', '$password', 10)/,
    qq/insert into users values (2, 'bigpresh', '$password', 11)/,
    qq/insert into users values (3, 'badger', '$password', 11)/,
    qq/insert into users values (4, 'bodger', '$password', 11)/,
    qq/insert into users values (5, 'mousey', '$password', 11)/,
    qq/insert into users values (6, 'mystery2', '$password', 11)/,
    qq/insert into users values (7, 'mystery1', '$password', 11)/,

    qq/create table user_extras (id INTEGER, user_id INTEGER, extra VARCHAR)/,
    qq/insert into user_extras values (1, 1, "sukria's extra data")/,

    qq/create table user_extras2 (id INTEGER, user_id INTEGER, extra2 VARCHAR)/,
    qq/insert into user_extras2 values (1, 1, "extra2 data")/,

    qq/create table user_types (id INTEGER, name VARCHAR)/,
    qq/insert into user_types values (10, "carbon-based")/,
    qq/insert into user_types values (11, "mercurial")/,
);

database->do($_) for @sql;

my $custom_column = { name => 'extra', raw_column => 'id', transform => sub { "Hello, id: $_[0]" } };
# now set up our simple_crud interfaci
simple_crud( prefix => '/users'  ,              record_title=>'A', db_table => 'users', editable => 0, );
simple_crud( prefix => '/users_editable',       record_title=>'A', db_table => 'users', editable => 1, );
simple_crud( prefix => '/users_editable_not_addable',       
                                                record_title=>'A', db_table => 'users', editable => 1, addable => 0);
simple_crud( prefix => '/users_custom_columns', record_title=>'A', db_table => 'users', editable => 0, custom_columns => [ $custom_column ] );

# override display of 'username' column
simple_crud( prefix => '/users_customized_column', record_title=>'A', db_table => 'users', editable => 0, sortable=>1,
                custom_columns => [ { name => "username", raw_column=>"username", transform => sub { "Username: $_[0]" } } ] );

# one join
simple_crud( prefix => '/users_with_join'  ,    record_title=>'A', db_table => 'users', editable => 0, 
    joins => [ 
        { table=>"user_extras", join_style=>"join", select_columns=>["extra"], key_column=>"id", join_column=>"user_id" },
    ] 
);
simple_crud( prefix => '/users_with_joins',   record_title=>'A', db_table => 'users', editable => 0, 
    joins => [ 
        { table=>"user_extras",  join_style=>"join",      select_columns=>["extra"],  key_column=>"id", join_column=>"user_id" },
        { table=>"user_extras2", join_style=>"left join", select_columns=>["extra2"], key_column=>"id", join_column=>"user_id" },
    ],
);

# one foreign key
simple_crud( prefix => '/users_with_foreign_key',   record_title=>'A', db_table => 'users', editable => 0, 
    foreign_keys => { type_id => { table=>"user_types", key_column=>"id", label_column=>"name" }, }
);

## two joins (turntables) and a foreign key (microphone) with apologies to readers and Beck
#simple_crud( prefix => '/users_with_joins_and_foreign_key',   record_title=>'A', db_table => 'users', editable => 0, 
#    joins => [ 
#        { table=>"user_extras",  join_style=>"join",      select_columns=>["extra"],  key_column=>"id", join_column=>"user_id" },
#        { table=>"user_extras2", join_style=>"left join", select_columns=>["extra2"], key_column=>"id", join_column=>"user_id" },
#    ],
#    foreign_keys => {
#        extra3 => { table=>"user_extras3", key_column=>"id", label_column=>"extra3" },
#    }
#);


1;
