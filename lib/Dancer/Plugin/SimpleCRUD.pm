# First, a dead simple object that can be fed a hashref of params from the
# Dancer params() keyword, and returns then when its param() method is called,
# so that we can feed it to CGI::FormBuilder:
package Dancer::Plugin::SimpleCRUD::ParamsObject;

sub new {
    my ($class, $params) = @_;
    return bless { params => $params }, $class;
}

sub param {
    my ($self, @args) = @_;

    # If called with no args, return all param names
    if (!@args) {
        return $self->{params} if !$paramname;

        # With one arg, act as an accessor
    } elsif (@args == 1) {
        return $self->{params}{ $args[0] };

        # With two args, act as a mutator
    } elsif ($args == 2) {
        return $self->{params}{ $args[0] } = $args[1];
    }
}

# Now, on to the real stuff
package Dancer::Plugin::SimpleCRUD;

use warnings;
use strict;
use Dancer::Plugin;
use Dancer qw(:syntax);
use Dancer::Plugin::Database;
use HTML::Table::FromDatabase;
use CGI::FormBuilder;
use HTML::Entities;
use URI::Escape;

our $VERSION = '1.01';

=encoding utf8

=head1 NAME

Dancer::Plugin::SimpleCRUD - very simple CRUD (create/read/update/delete)


=head1 DESCRIPTION

A plugin for Dancer web applications, to use a  few lines of code to create
appropriate routes to support creating/editing/deleting/viewing records within a
database table.  Uses L<CGI::FormBuilder> to generate, process and validate forms,
L<Dancer::Plugin::Database> for database interaction and
L<HTML::Table::FromDatabase> to display lists of records.

Setting up forms and code to display and edit database records is a very common
requirement in web apps; this plugin tries to make something basic trivially
easy to set up and use.


=head1 SYNOPSIS

The following assumes that you already have a working L<Dancer> app and have
put your database connection details in your C<config.yml> to be read by
L<Dancer::Plugin::Database>, which this plugin uses in order to obtain a database
connection.

    # In your Dancer app,
    use Dancer::Plugin::SimpleCRUD;

    # Simple example:
    simple_crud(
        record_title => 'Widget',
        prefix => '/widgets',
        db_table => 'widgets',
        editable => 1,
    );

    # The above would create a route to handle C</widgets>, listing all widgets,
    # with options to add/edit entries (linking to C</widgets/add> and
    # C</widgets/edit/:id> respectively) where a form to add a new entry or edit
    # an existing entry will be created.
    # All fields in the database table would be editable.
    #
    # There is also a view route, C</widgets/view/:id>, which shows all the values
    # for the fields of a single database entry.

    # A more in-depth synopsis, using all options (of course, usually you'd only
    # need to use a few of the options where you need to change the default
    # behaviour):

    simple_crud(
        record_title => 'Team',
        prefix => '/teams',
        db_table => 'team',
        labels => {     # More human-friendly labels for some columns
            venue_id => 'Home Venue',
            name     => 'Team Name', 
        },  
        validation => {  # validate values entered for some columns
            division => qr/\d+/,
        },
        input_types => {  # overriding form input type for some columns
            supersecret => 'password',
            lotsoftext' => 'textarea',
        },
        key_column => 'id', # id is default anyway
        editable_columns => [ qw( venue_id name division )    ],
        display_columns  => [ qw( id venue_id name division ) ],
        deleteable => 1,
        editable => 1,
        sortable => 1,
        paginate => 300,
        template => 'simple_crud.tt',
        query_auto_focus => 1,
        downloadable => 1,
        foreign_keys => {
            columnname => {
                table => 'venues',
                key_column => 'id',
                label_column => 'name',
            },
        },
	table_class => 'table table-bordered',
	paginate_table_class => 'table table-borderless',
        custom_columns => [
            {
                name => "division_news",
                raw_column => "division",
                transform  => sub {
                    my $division_name = shift;
                    my $label = "News about $division_name";
                    $division_name =~ s/([^-_.~A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
                    my $search = qq{http://news.google.com/news?q="$division_name"};
                    return "<a href='$search'>$label</a>";
                },
            },
        ],
        auth => {
            view => {
                require_login => 1,
            },
            edit => {
                require_role => 'Admin',
            },
        },
    );



=head1 USAGE

This plugin provides a C<simple_crud> keyword, which takes a hash of options as
described below, and sets up the appropriate routes to present add/edit/delete
options.

=head1 OPTIONS

The options you can pass to simple_crud are:

=over 4

=item C<record_title> (required)

What we're editing, for instance, if you're editing widgets, use 'Widget'.  Will
be used in form titles (for instance "Add a ...", "Edit ..."), and button
labels.

=item C<prefix> (required)

The prefix for the routes which will be created.  Given a prefix of C</widgets>,
then you can go to C</widgets/new> to create a new Widget, and C</widgets/42> to
edit the widget with the ID (see keu_column) 42.

Don't confuse this with Dancer's C<prefix> setting, which would be prepended
before the prefix you pass to this plugin.  For example, if you used:

    prefix '/foo';
    simple_crud(
        prefix => 'bar',
        ...
    );

... then you'd end up with e.g. C</foo/bar> as the record listing page.

=item C<db_table> (required)

The name of the database table.

=item C<key_column> (optional, default: 'id')

Specify which column in the table is the primary key.  If not given, defaults to
id.

=item C<where_filter> (optional)

Specify one or more 'where' clauses to use to filter the table. For example:

    simple_crud(
        prefix => 'bar',
        where_filter => {user_id => 1000},
        ...
    );

This would cause only rows with an user_id of 1000 to be displayed in listings
and search results, viewed, edited etc.

The C<where_filter> parameter takes a hashref describing the WHERE clause, as 
used by L<Dancer::Plugin::Database>'s C<quick_select> convenience method for
example - see the 
L<where clause documentation in Dancer::Plugin::Database::Core::Handle|Dancer::Plugin::Database::Core::Handle/WHERE-clauses-as-hashrefs>.

Alternatively, if the filter condition needs to be calculated at runtime (for
example, based on the logged in user calling it), then you can provide a coderef
which returns the WHERE clause hashref - for instance:

  where_filter => sub { { customer_id => logged_in_user()->{customer_id} } },

=item C<db_connection_name> (optional)

We use L<Dancer::Plugin::Database> to obtain database connections.  This option
allows you to specify the name of a connection defined in the config file to
use.  See the documentation for L<Dancer::Plugin::Database> for how multiple
database configurations work.  If this is not supplied or is empty, the default
database connection details in your config file will be used - this is often
what you want, so unless your app is dealing with multiple DBs, you probably
won't need to worry about this option.

=item C<labels> (optional)

A hashref of field_name => 'Label', if you want to provide more user-friendly
labels for some or all fields.  As we're using CGI::FormBuilder, it will do a
reasonable job of figuring these out for itself usually anyway - for instance, a
field named C<first_name> will be shown as C<First Name>.

=item C<input_types> (optional)

A hashref of field_name => input type, if you want to override the default type
of input which would be selected by L<CGI::FormBuilder> or by our DWIMmery (by
default, password fields will be used for field names like 'password', 'passwd'
etc, and text area inputs will be used for columns with type 'TEXT').

Valid values include anything allowed by HTML, e.g. C<text>, C<select>,
C<textarea>, C<radio>, C<checkbox>, C<password>, C<hidden>.

Example:

    input_types => {
        first_name => 'text',
        secret     => 'password',
        gender     => 'radio',
    }

=item C<validation> (optional)

A hashref of field_name => validation criteria which should be passed to 
L<CGI::FormBuilder>.

Example:

    validation => {
        email_address => 'EMAIL',
        age => '/^\d+$/',
    }


=item C<message> (optional)

A hashref of field_name => messages to show if validation failed.

Default is "Invalid entry".

Example:

    message => {
        age   => 'Please enter your age in years',
        email => 'That is not a valid email address',
    },

=item C<jsmessage> (optional)

A hashref of field_name => message to show when Javascript validation fails.

Default message is "- Invalid entry for the "$fieldname" field".  See above for
example.

=item C<sort_options> (optional)

A hashref of field_name => optionspec indicating how select options should be sorted

This is currently a passthrough to L<CGI::FormBuilder>'s L<sortopts|CGI::FormBuilder/sortopts>.  There are several
built-in values:

    NAME            Sort option values by name
    NUM             Sort option values numerically
    LABELNAME       Sort option labels by name
    LABELNUM        Sort option labels numerically

See the documentation for L<CGI::FormBuilder/sortopts> for more.

=item C<acceptable_values> (optional)

A hashref of arrayrefs to declare that certain fields can take only a set of
acceptable values.

Example:

    acceptable_values => {
        gender => ['Male', 'Female'],
        status => [qw(Alive Dead Zombie Unknown)],
    }

You can automatically create option groups (on a field of type C<select>) by specifying 
the acceptable values in CGI::FormBuilder's C<[value, label, category]> format, like this:

    acceptable_values => {
        gender => ['Male', 'Female'],
        status => [qw(Alive Dead Zombie Unknown)],
        threat_level => [
            [ 'child_puke',   'Regurgitation',       'Child'],
            [ 'child_knee',   'Knee Biter',          'Child'],
            [ 'teen_eye',     'Eye Roll',            'Adolescent'],
            [ 'teen_lip',     'Withering Sarcasm',   'Adolescent'],
            [ 'adult_silent', 'Pointedly Ignore',    'Adult'],
            [ 'adult_freak',  'Become Very Put Out', 'Adult'],
        ],
    }

If you are letting FormBuilder choose the field type, you won't see these categories
unless you have enough options that it makes the field into a select.  If you want to
see the categories all the time, you can use the L</input_types> option to force your 
field to be rendered as a select.

=item C<default_value> (optional)

A hashref of default values to have pre-selected on the add form.

Example:

    default_value => {
        gender => 'Female',
        status => 'Unknown',
    }


=item C<editable_columns> (optional)

Specify an arrayref of fields which the user can edit.  By default, this is all
columns in the database table, with the exception of the key column.

=item C<not_editable_columns> (optional)

Specify an arrayref of fields which should not be editable.

=item C<required> (optional)

Specify an arrayref of fields which must be completed.  If this is not provided,
DWIMmery based on whether the field is set to allow null values in the database
will be used - i.e. if that column can contain null, then it doesn't have to be
completed, otherwise, it does.

=item C<deletable>

Specify whether to support deleting records.  If set to a true value, a route
will be created for C</prefix/delete/:id> to delete the record with the ID
given, and the edit form will have a "Delete $record_title" button.

=item C<editable>

Specify whether to support editing records.  Defaults to true.  If set to a
false value, it will not be possible to add or edit rows in the table.

=item C<sortable>

Specify whether to support sorting the table. Defaults to false. If set to a
true value, column headers will become clickable, allowing the user to sort
the output by each column, and with ascending/descending order.

=item C<paginate>

Specify whether to show results in pages (with next/previous buttons).  Defaults
to undef, meaning all records are shown on one page (not useful for large
tables).  When defined as a number, only this number of results will be shown.

=item C<display_columns>

Specify an arrayref of columns that should show up in the list.  Defaults to all.

=item C<template>

Specify a template that will be applied to all output.  This template must have
a "simple_crud" placeholder defined or you won't get any output.  This template
must be located in your "views" directory.

Any global layout will be applied automatically because this option causes the
module to use the C<template> keyword.  If you don't use this option, the
C<template> keyword is not used, which implies that any
C<before_template_render> and C<after_template_render> hooks won't be called.

=item C<query_auto_focus>

Specify whether to automatically set input focus to the query input field.
Defaults to true. If set to a false value, focus will not be set.
The focus is set using a simple inlined javascript.

=item C<downloadable>

Specify whether to support downloading the results.  Defaults to false. If set
to a true value, The results show on the HTML page can be downloaded as
CSV/TSV/JSON/XML.  The download links will appear at the top of the page.

=item C<foreign_keys>

A hashref to specify columns in the table which are foreign keys; for each one,
the value should be a hashref containing the keys C<table>, C<key_column> and
C<label_column>.

=item C<custom_columns>

An arrayref of hashrefs to specify custom columns to appear in the list view 
of an entity.  (Previously, this was just a hashref of column names and specs,
and this style is still supported for backwards compatibility, but is deprecated
because it leaves the order of the columns unpredictable.)

The keys of each hash are C<name>, the name to use for this custom column,
C<raw_column> indicating a column from the table that should be selected to
build the custom column from, and C<transform>, a subref to be used as a
HTML::Table::FromDatabase callback on the resulting column.  If no
C<transform> is provided, sub { return shift; } will be used.

For a somewhat spurious example:

    ...
    custom_columns => [
        {
            name => 'email_provider',
            raw_column => 'email',
            transform => sub {
                my $value = shift;
                return (split /@/, 1)[1];
            },
        },
    ],
    ...


The C<transform> code ref is passed to L<HTML::Table::FromDatabase> as a
callback for that column, so it can do anything a
L<HTML::Table::FromDatabase callback|HTML::Table::FromDatabase/CALLBACKS>
can do.  In particular, the coderef will receive the value of the
column as the first parameter, but also a reference to the whole row hashref
as the second parameter, so you can do a variety of cunning things.

An example of a custom column whose C<transform> coderef uses the row
hashref to get other values for the same row could be:

    ...
    custom_columns => [
        {
            name => 'salutation',
            raw_column => 'name',
            transform => sub {
                my ($name_value, $row) = @_;
                return "Hi, $row->{title} $name_value!";
            },
        }
    ],
    ...

=item C<auth>

You can require that users be authenticated to view/edit records using the C<auth>
option to enable authentication powered by L<Dancer::Plugin::Auth::Extensible>.

You can set different requirements for viewing and editing, for example:

    auth => {
        view => {
            require_login => 1,
        },
        edit => {
            require_role => 'Admin',
        },
    },

The example above means that any logged in user can view records, but only users
with the 'Admin' role are able to create/edit/delete records.

Or, to just require login for anything (same requirements for both viewing and
editing), you can use the shorthand:

    auth => {
        require_login => 1,
    },


=item C<table_class>

This provides a CSS class for the tables.

=item C<paginate_table_class>

This provides a CSS class for the tables paginate buttons.

=cut

sub simple_crud {
    my (%args) = @_;

    # Get a database connection to verify that the table name is OK, etc.
    my $dbh = database($args{db_connection_name});

    if (!$dbh) {
        warn "No database handle";
        return;
    }

    if (!$args{prefix}) { die "Need prefix to create routes!"; }
    if ($args{prefix} !~ m{^/}) {
        $args{prefix} = '/' . $args{prefix};
    }

    # If there's a Dancer prefix in use, as well as a prefix we're told about,
    # then _construct_url() will need to be told about that later so it can
    # construct URLs.  It can't just call Dancer::App->current->prefix itself,
    # though, as the prefix may have changed by the time the code is actually
    # running.  (See RT #73620.)   So, we need to grab it here and add it to
    # %args, so it can see it later.
    $args{dancer_prefix} = Dancer::App->current->prefix || '';

    if (!$args{db_table}) { die "Need table name!"; }

    # Accept deleteable as a synonym for deletable
    $args{deletable} = delete $args{deleteable}
        if !exists $args{deletable} && exists $args{deleteable};

    # Sane default values:
    $args{key_column}   ||= 'id';
    $args{record_title} ||= 'record';
    $args{editable}         = 1 unless exists $args{editable};
    $args{query_auto_focus} = 1 unless exists $args{query_auto_focus};

    # Sanitise things we'll have to interpolate into queries (yes, that makes me
    # feel bad, but you can't use params for field/table names):
    my $table_name = $args{db_table};
    my $key_column = $args{key_column};
    for ($table_name, $key_column) {
        die "Invalid table name/key column - SQL injection attempt?"
            if /--/;
        s/[^a-zA-Z0-9_-]//g;
    }

    # OK, create a route handler to deal with adding/editing:
    my $handler
        = sub { _create_add_edit_route(\%args, $table_name, $key_column); };

    if ($args{editable}) {
        _ensure_auth('edit', $handler, \%args);
        for ('/add', '/edit/:id') {
            my $url = _construct_url($args{dancer_prefix}, $args{prefix}, $_);
            Dancer::Logger::debug("Setting up route for $url");
            any ['get', 'post'] => $url => $handler;
        }
    }

    # And a route to list records already in the table:
    my $list_handler
        = _ensure_auth(
            'view',
            sub { _create_list_handler(\%args, $table_name, $key_column); },
            \%args,
        );
    get _construct_url(
        $args{dancer_prefix},
        $args{prefix},
    ) => $list_handler;

    # If we should allow deletion of records, set up routes to handle that,
    # too.
    if ($args{editable} && $args{deletable}) {

        # A route for GET requests, to present a "Do you want to delete this"
        # message with a form to submit (this is only for browsers which didn't
        # support Javascript, otherwise the list page will have POSTed the ID
        # to us) (or they just came here directly for some reason)
        get _construct_url(
            $args{dancer_prefix}, $args{prefix}, "/delete/:id"
            ) => sub {
            return _apply_template(<<CONFIRMDELETE, $args{'template'}, $args{'record_title'});
<p>
Do you really wish to delete this record?
</p>

<form method="post">
<input type="button" value="Cancel" onclick="history.back();">
<input type="submit" value="Delete record">
</form>
CONFIRMDELETE

        };

        # A route for POST requests, to actually delete the record
        my $del_url_stub = _construct_url(
            $args{dancer_prefix}, $args{prefix}, '/delete'
        );
        my $delete_handler = sub {
            my ($id) = params->{record_id} || splat;
            my $dbh = database($args{db_connection_name});
            my $where = _get_where_filter_from_args(\%args);
            $where->{$key_column} = $id;
            $dbh->quick_delete($table_name, $where)
                or return _apply_template("<p>Failed to delete!</p>",
                $args{'template'});

            redirect _external_url($args{dancer_prefix}, $args{prefix});
        };
        _ensure_auth('edit', $delete_handler, \%args);
        post qr[$del_url_stub/?(.+)?$] => $delete_handler;
    }
    my $view_url_stub = _construct_url(
        $args{dancer_prefix}, $args{prefix}, '/view'
    );
    my $view_handler = _ensure_auth(
        'view',
        sub { _create_view_handler(\%args, $table_name, $key_column); },
        \%args,
    );

    get $view_url_stub.'/:id' => $view_handler;
}

sub _create_view_handler {
    my ($args, $table_name, $key_column) = @_;
    my $params = params;
    my $id     = $params->{id} or return _apply_template("<p>Need id to view!</p>", $args->{'template'});

    my $dbh = database($args->{db_connection_name});

    # a hash containing the current values in the database.  Take where_filter
    # into account, so we can't fetch a row if it doesn't match the filter
    # (otherwise people could load any record they wished just by changing the
    # ID in the URL, which would be considered a Bad Thing)
    my $where = _get_where_filter_from_args($args);
    $where->{$key_column} = $id;
    my $values_from_database = $dbh->quick_select($table_name, $where);

    # Find out about table columns:
    my $all_table_columns = _find_columns($dbh, $args->{db_table});
    my @rows = (['Column Name', 'Value']);
    my $table = HTML::Table->new( -border=>1 );
    $table->addSectionRow('thead', 0, 'Column Name', 'Value');
    $table->setSectionCellHead('thead', 0, 1, 1, 1);
    $table->setSectionCellHead('thead', 0, 1, 2, 1);
    foreach my $col (@$all_table_columns) {
        $table->addSectionRow('tbody', 0, $col->{COLUMN_NAME}, $values_from_database->{$col->{COLUMN_NAME}});
    }
    my $html = $table->getTable || '';
    return _apply_template($html, $args->{'template'});
}

register simple_crud => \&simple_crud;
register_hook(qw(
    add_edit_row
    add_edit_row_pre_save
    add_edit_row_post_save
));
register_plugin;

sub _create_add_edit_route {
    my ($args, $table_name, $key_column) = @_;
    my $params = params;
    my $id     = $params->{id};

    my $dbh = database($args->{db_connection_name});

    # a hash containing the current values in the database
    my $values_from_database;
    if ($id) {
        my $where = _get_where_filter_from_args($args);
        $where->{$key_column} = $id;
        $values_from_database
            = $dbh->quick_select($table_name, $where);
    }

    # Find out about table columns:
    my $all_table_columns = _find_columns($dbh, $args->{db_table});
    my @editable_columns;

    # Now, find out which ones we can edit.
    if ($args->{editable_columns}) {

        # We were given an explicit list of fields we can edit, so this is
        # easy:
        @editable_columns = @{ $args->{editable_columns} };
    } else {

        # OK, take all the columns from the table, except the key field:
        @editable_columns = grep { $_ ne $key_column }
            map { $_->{COLUMN_NAME} } @$all_table_columns;
    }

    if ($args->{not_editable_columns}) {
        for my $col (@{ $args->{not_editable_columns} }) {
            @editable_columns = grep { $_ ne $col } @editable_columns;
        }
    }

    # Some DWIMery: if we don't have a validation rule specified for a
    # field, and it's pretty clear what it is supposed to be, just do it:
    my $validation = $args->{validation} || {};
    for my $field (grep { $_ ne $key_column } @editable_columns) {
        next if $validation->{$field};
        if ($field =~ /email/) {
            $validation->{$field} = 'EMAIL';
        }
    }

    # More DWIMmery: if the user hasn't supplied a list of required fields,
    # work out what fields are required by whether they're nullable in the
    # DB:
    my %required_fields;
    if (exists $args->{required}) {
        $required_fields{$_}++ for @{ $args->{required} };
    } else {
        $_->{NULLABLE} || $required_fields{ $_->{COLUMN_NAME} }++
            for @$all_table_columns;
    }

    # If the user didn't supply a list of acceptable values for a field, but
    # it's an ENUM column, use the possible values declared in the ENUM.
    # Also remember field types for easy reference later
    my %constrain_values;
    my %field_type;
    for my $field (@$all_table_columns) {
        my $name = $field->{COLUMN_NAME};
        $field_type{$name} = $field->{TYPE_NAME};
        if (my $values_specified = $args->{acceptable_values}->{$name}) {

            # It may have been given to us as a coderef; if so, execute it to
            # get the results
            if (ref $values_specified eq 'CODE') {
                $values_specified = $values_specified->();
            }
            $constrain_values{$name} = $values_specified;

        } elsif (my $foreign_key = $args->{foreign_keys}{$name}) {

            # Find out the possible values for this column from the other table:
            my %possible_values;
            debug "Looking for rows for foreign relation: " => $foreign_key;
            for my $row ($dbh->quick_select($foreign_key->{table}, {})) {
                debug "Row from foreign relation: " => $row;
                $possible_values{ $row->{ $foreign_key->{key_column} } }
                    = $row->{ $foreign_key->{label_column} };
            }
            $constrain_values{$name} = \%possible_values;

        } elsif (my $values_from_db = $field->{mysql_values}) {
            $constrain_values{$name} = $values_from_db;
        }
    }

    # Only give CGI::FormBuilder our fake CGI object if the form has been
    # POSTed to us already; otherwise, it will ignore default values from
    # the DB, it seems.
    my $paramsobj
        = request->{method} eq 'POST'
        ? Dancer::Plugin::SimpleCRUD::ParamsObject->new({ params() })
        : undef;

    my $form = CGI::FormBuilder->new(
        fields   => \@editable_columns,
        params   => $paramsobj,
        values   => $values_from_database,
        validate => $validation,
        method   => 'post',
        action   => _external_url(
            $args->{dancer_prefix},
            $args->{prefix},
            (
                params->{id}
                ? '/edit/' . params->{id}
                : '/add'
            )
        ),
    );
    for my $field (@editable_columns) {
        # first check if there's data from the database for this field,
        # then if there's a value in params() for this field,
        # then if args->{default_value} was set for this field via the
        # 'default_value' hash when the route was created.
        my $default = 
                exists $values_from_database->{$field}  
              ? $values_from_database->{$field}
              : exists params->{$field} 
              ? uri_unescape(params->{$field})
              : exists $args->{default_value}->{$field} 
              ? $args->{default_value}->{$field}
              : '';
        my %field_params = (
            name  => $field,
            value => $default,
        );

        $field_params{required} = $required_fields{$field};

        if ($constrain_values{$field}) {
            $field_params{options} = $constrain_values{$field};
        }

        # Certain options in $args simply cause that value to be added to the
        # params for this field we'll pass to $form->field:
        my %option_map = (
            labels        => 'label',
            validation    => 'validate',
            message       => 'message',
            jsmessage     => 'jsmessage',
            sort_options  => 'sortopts',
        );
        while (my ($arg_name, $field_param_name) = each(%option_map)) {
            if (my $val = $args->{$arg_name}{$field}) {
                $field_params{$field_param_name} = $val;
            }
        }

        # Normally, CGI::FormBuilder can guess the type of field perfectly,
        # but give it some extra DWIMmy help:
        if ($field =~ /pass(?:wd|word)?$/i) {
            $field_params{type} = 'password';
        }

        # use a <textarea> for large text fields.
        if ($field_type{$field} eq 'TEXT') {
            $field_params{type} = 'textarea';
        }

        # ... unless the user specified a type for this field, in which case,
        # use what they said
        if (my $override_type = $args->{input_types}{$field}) {
            $field_params{type} = $override_type;
        }

        # if the constraint on this is an array of arrays,
        # and there are three elements in the first array in that list,
        # (which will be intepreted as: value, label, category)
        # we are going to assume you want optgroups, with the 
        # third element in each being the category.
        #
        # (See the optgroups option in CGI::FormBuilder)
        if (ref($field_params{options}) eq 'ARRAY') {
            if (ref( $field_params{options}->[0] )  eq 'ARRAY') {
                if (@{ $field_params{options}->[0] } == 3) {
                    $field_params{optgroups} = 1;
                }
            }
        }


        # OK, add the field to the form:
        $form->field(%field_params);
    }

    # Now, if all is OK, go ahead and process:
    if (request->{method} eq 'POST' && $form->submitted && $form->validate) {

        # Assemble a hash of only fields from the DB (if other fields were
        # submitted with the form which don't belong in the DB, ignore them)
        my %params;
        $params{$_} = params('body')->{$_} for @editable_columns;

        my $meta_for_hook = {
            args => $args,
            params => \%params,
            table_name => $table_name,
            key_column => $key_column,
        };
        # Fire a hook so the user can manipulate the data in a whole range of
        # cunning ways, if they wish
        execute_hook('add_edit_row', \%params);
        execute_hook('add_edit_row_pre_save', $meta_for_hook);

        my $verb;
        my $success;
        if (exists params('route')->{id}) {

            # We're editing an existing record - make sure the WHERE clause
            # hashref incorporates where_filter, if in use, so that users can't
            # edit stuff they shouldn't be able to
            my $where = _get_where_filter_from_args($args);
            $where->{$key_column} = params('route')->{id};
            $success = $dbh->quick_update($table_name, $where, \%params);
            $verb = 'update';
        } else {
            $success = $dbh->quick_insert($table_name, \%params);
            # pass them *this* dbh instance so that they can call last_insert_id()
            # against it if they need to.  last_insert_id in some instances requires
            # catalog, schema, etc args, so we can't just call it and save the result.
            # important that we don't do any more database operations that would change
            # last_insert_id between here and the hook, or this won'w work.
            $meta_for_hook->{dbh} = $dbh;
            $verb = 'create new';
        }

        $meta_for_hook->{success} = $success;
        $meta_for_hook->{verb} = $verb;
        if ($success) {

            # Redirect to the list page
            # TODO: pass a param to cause it to show a message?
            execute_hook('add_edit_row_post_save', $meta_for_hook);
            redirect _external_url($args->{dancer_prefix}, $args->{prefix});
            return;
        } else {
            execute_hook('add_edit_row_post_save', $meta_for_hook);
            # TODO: better error handling - options to provide error templates
            # etc
            # (below is one approach to that TODO--this, or perhaps the hook could return a hash
            # that would specify these overrides?  Probably best to come up with a complete mechanism
            # consistent across hooks before we implement.)
            # return _apply_template(
            #    $meta_for_hook->{return}{error_message}  || "<p>Unable to $verb $args->{record_title}</p>",
            #    $meta_for_hook->{return}{error_template} || $args->{error_template} || $args->{'template'}
            #);
            return _apply_template(
                "<p>Unable to $verb $args->{record_title}</p>",
                $args->{'template'}, $args->{'record_title'});
        }

    } else {
        return _apply_template($form->render, $args->{'template'}, $args->{'record_title'});
    }
}

sub _create_list_handler {
    my ($args, $table_name, $key_column) = @_;

    my $dbh = database($args->{db_connection_name});
    my $columns = _find_columns($dbh, $table_name);

    my $display_columns = $args->{'display_columns'};

    my $table_class = $args->{'table_class'} || '';
    my $paginate_table_class = $args->{'paginate_table_class'} || '';

    # If display_columns argument was passed, filter the column list to only
    # have the ones we asked for.
    if (ref $display_columns eq 'ARRAY') {
        my @filtered_columns;

        foreach my $col (@$columns) {
            if (grep { $_ eq $col->{'COLUMN_NAME'} } @$display_columns) {
                push @filtered_columns, $col;
            }
        }

        if (@filtered_columns) {
            $columns = \@filtered_columns;
        }
    }

    my $searchfield = params->{searchfield} || $key_column;
    my $searchfield_options = join(
        "\n",
        map {
            my $friendly_name = $_->{COLUMN_NAME};
            if ($args->{labels}{$_->{COLUMN_NAME}}) {
                $friendly_name = $args->{labels}{$_->{COLUMN_NAME}};
            }
            my $sel
                = (defined $searchfield
                    && $searchfield eq $_->{COLUMN_NAME})
                ? "selected"
                : "";
            "<option $sel value='$_->{COLUMN_NAME}'>$friendly_name</option>"
            } @$columns
    );
    my @searchtypes = (
        [ e => { name=>"Equals", cmp=>"="} ],
        [ c => { name=>"Contains", cmp=>"like"} ],
        [ ne => { name=>"Does Not Equal", cmp=>"!="} ],
        [ nc => { name=>"Does Not Contain", cmp=>"not like"} ],

        [ lt => { name=>"Less Than", cmp=>"<"} ],
        [ lte => { name=>"Less Than or Equal To", cmp=>"<="} ],
        [ gt => { name=>"Greater Than", cmp=>">"} ],
        [ gte => { name=>"Greater Than or Equal To", cmp=>">="} ],
    );
    my $searchtype_options = join( "\n",
        map { 
            my ($search_code, $hashref) = @$_;
            my $name = $hashref->{name};
            my $sel = _defined_or_empty(params->{searchtype} || "e") eq $search_code;
            sprintf("<option value='%s'%s>%s</option>", $search_code, $sel ? " selected" : "", $name);
        } @searchtypes 
    );

    my $order_by_param     = params->{'o'} || "";
    my $order_by_direction = params->{'d'} || "";
    my $q                   = _defined_or_empty(params->{'q'});
    my $display_q           = encode_entities( $q );
    my $html               = <<"SEARCHFORM";
 <p><form name="searchform" method="get">
     Field:  <select name="searchfield">$searchfield_options</select> &nbsp;&nbsp;
     <select name="searchtype">$searchtype_options</select>&nbsp;&nbsp;
     <input name="q" id="searchquery" type="text" size="30" value="$display_q" /> &nbsp;&nbsp;
     <input name="o" type="hidden" value="$order_by_param"/>
     <input name="d" type="hidden" value="$order_by_direction"/>
     <input name="searchsubmit" type="submit" value="Search"/>
 </form></p>
SEARCHFORM

    if ($args->{query_auto_focus}) {
        $html
            .= "<script>document.getElementById(\"searchquery\").focus();</script>";
    }

    # Explicitly select the columns we are displaying.  (May have been filtered
    # by display_columns above.)

    my @select_cols = map { $_->{COLUMN_NAME} } @$columns;

    # If we have some columns declared as foreign keys, though, we don't want to
    # see the raw values in the result; we'll add JOIN clauses to fetch the info
    # from the related table, so for now just select the defined label column
    # from the related table instead of the raw ID value.

    # This _as_simplecrud_fk_ mechanism is clearly a bit of a hack.  At some point we
    # might want to pull in an existing solution for this--this is simple and
    # may have pitfalls that have already been solved in Catalyst/DBIC code.
    # For now, we're going with simple. git show 14cec4ea647 to see the
    # basic change (that's previous to the add of LEFT to the JOIN, though), if you want
    # to know exactly what to pull out when replacing this

    my @foreign_cols;
    my %fk_alias; # foreign key aliases for cases where we might have collisions
    if ($args->{foreign_keys}) {
        my $seen_table = {$table_name=>1};
        while (my ($col, $foreign_key) = each(%{ $args->{foreign_keys} })) {
            @select_cols = grep { $_ ne $col } @select_cols;
            my $raw_ftable = $foreign_key->{table};
            my $ftable_alias;
            if ($seen_table->{$raw_ftable}++) {
                $ftable_alias = $fk_alias{ $col } = $dbh->quote_identifier($raw_ftable. "_as_simplecrud_fk_$seen_table->{$raw_ftable}");
            }
            my $ftable = $dbh->quote_identifier($raw_ftable);
            my $fcol
                = $dbh->quote_identifier($foreign_key->{label_column});
            my $lcol
                = $dbh->quote_identifier($args->{labels}{$col} || $col);

            my $table_or_alias = $fk_alias{ $col } || $ftable;
            push @foreign_cols, "$table_or_alias.$fcol AS $lcol";
        }
    }

    my @custom_cols;

    # For backwards compatibility, understand custom_columns being a hashref,
    # and translate it
    if (ref $args->{custom_columns} eq 'HASH') {
        my @custom_cols_list;
        for my $column_alias (keys %{ $args->{custom_columns} }) {
            push @custom_cols_list, {
                name => $column_alias,
                %{ $args->{custom_columns}{$column_alias} }
            };
        }
        $args->{custom_columns} = \@custom_cols_list;
    }

    for my $custom_col_spec (@{ $args->{custom_columns} || [] }) {
        my $column_alias = $custom_col_spec->{name};
        my $raw_column = $custom_col_spec->{raw_column}
            or die "you must specify a raw_column that "
                 . "$column_alias will be built using";
        if ($raw_column =~ /^[\w_]+$/) {
            push @custom_cols, "$table_name." 
                . $dbh->quote_identifier($raw_column) 
                . " AS ". $dbh->quote_identifier($column_alias);
        } else {
            push @custom_cols, "$raw_column AS $column_alias";
        }
    }

    my $col_list = join(
        ',',
        map(
            { $table_name . "." . $dbh->quote_identifier($_) }
            @select_cols
        ),
        @foreign_cols,    # already assembled from quoted identifiers
        @custom_cols,
    );
    my $add_actions
        = $args->{editable}
        ? ", $table_name.$key_column AS actions"
        : '';
    my $query = "SELECT $col_list $add_actions FROM $table_name";
    my @binds;

    # If we have foreign key relationship info, we need to join on those tables:
    if ($args->{foreign_keys}) {
        while (my ($col, $foreign_key) = each %{ $args->{foreign_keys} }) {
            my $ftable = $dbh->quote_identifier($foreign_key->{table});
            my $lkey   = $dbh->quote_identifier($col);
            my $rkey   = $dbh->quote_identifier($foreign_key->{key_column});

            # Identifiers quoted above, and $table_name quoted further up, so
            # all safe to interpolate
            my $what_to_join = $ftable;
            my $join_reference = $ftable;
            if (my $alias = $fk_alias{$col}) {
                $what_to_join = " $ftable AS $alias ";
                $join_reference = $alias;
            }
            # If this join is not a left join, the list view only shows rows where the
            # foreign key is defined and matching a row
            $query .= " LEFT JOIN $what_to_join ON $table_name.$lkey = $join_reference.$rkey ";
        }
    }

    # If we have a query or a where_filter, we need to assemble a WHERE clause...
    my $where_filter = _get_where_filter_from_args($args);
    if (length $q || $where_filter) {
        
        # Turn the $where_filter hashref into some SQL clauses and bind params,
        # which we'll add to with the user's search params shortly
        my ($where_filter_sql, @where_filter_binds)
            = $dbh->generate_where_clauses($where_filter);

        my (@search_wheres, @search_binds);
        if (length $q) {    # this nested code is all for queries in $q
            my ($column_data)
                = grep { lc $_->{COLUMN_NAME} eq lc $searchfield }
                @{$columns};
            debug(
                "Searching on $column_data->{COLUMN_NAME} which is a "
                . "$column_data->{TYPE_NAME}"
            );
            my $st = params->{searchtype} || "e";   # searchtype defaults to 'equals'

            if ($column_data) {
                my $search_value = $q;
                if ($st eq 'c' || $st eq 'nc') {
                    $search_value = '%' . $search_value . '%';
                }

                my ($searchtype_row) = grep { $_->[0] eq $st } @searchtypes;
                my $cmp = $searchtype_row->[1]->{cmp} || '=';
                push(@search_wheres,
                    "$table_name."
                    . $dbh->quote_identifier($searchfield)
                    . " $cmp ?" );
                push(@search_binds, $search_value);

                my $matchtype = $st eq "c" ? "contains": 
                                $st eq "nc" ? "does not contain" :
                                $st eq "ne" ? "does not equal": "equals";
                $html
                    .= sprintf(
                    "<p>Showing results from searching for '%s' %s '%s'",
                    encode_entities($searchfield), $matchtype, encode_entities($q)
                );
                $html .= sprintf '&mdash;<a href="%s">Reset search</a></p>',
                    _external_url($args->{dancer_prefix}, $args->{prefix});
            }
        }
        # add the 'where' clauses to $query and the binds to @binds
        $query .= " where " . join( " AND ", grep { length $_ } ($where_filter_sql, @search_wheres));
        push(@binds, @where_filter_binds, @search_binds);
    }

    if ($args->{downloadable}) {
        my $qt   = uri_escape($q);
        my $sf   = uri_escape(params->{searchfield} || $searchfield);
        my $st   = uri_escape(params->{searchtype} || "e"); # defaults to 'equals'
        my $o    = uri_escape(params->{'o'}         || "");
        my $d    = uri_escape(params->{'d'}         || "");
        my $page = uri_escape(params->{'p'}         || 0);

        my @formats = qw/csv tabular json xml/;

        my $url = _external_url($args->{dancer_prefix}, $args->{prefix})
            . "?o=$o&d=$d&q=$qt&searchfield=$sf&searchtype=$st&p=$page";

        $html
            .= "<p>Download as: "
            . join(", ", map { "<a href=\"$url&format=$_\">$_</a>" } @formats)
            . "<p>";
    }

    my %columns_sort_options;
    if ($args->{sortable}) {
        my $qt              = uri_escape($q);
        my $sf              = uri_escape($searchfield);
        my $st              = uri_escape(params->{searchtype} || "e");
        my $order_by_column = uri_escape(params->{'o'})        || $key_column;

        # Invalid column name ? discard it
        my $valid = grep { $_->{COLUMN_NAME} eq $order_by_column } @$columns;
        $order_by_column = $key_column unless $valid;
        my $order_by_table = $table_name;

        my $order_by_direction
            = (exists params->{'d'} && params->{'d'} eq "desc")
            ? "desc"
            : "asc";
        my $opposite_order_by_direction
            = ($order_by_direction eq "asc") ? "desc" : "asc";

        # Get a list of all columns (normal, and custom_columns), then assemble
        # the names and labels to pass to HTML::Table::FromDatabase
        my @all_cols = map { $_->{COLUMN_NAME} } @$columns;
        %columns_sort_options = map {
            my $col_name       = $_;
            my $direction      = $order_by_direction;
            my $direction_char = "";
            my $friendly_name  = $col_name;
            if ($args->{labels}{$col_name}) {
                $friendly_name = $args->{labels}{$col_name};
            } else {
                $friendly_name = _prettify_column_name($friendly_name);
            }
            if ($col_name eq $order_by_column) {
                $direction = $opposite_order_by_direction;
                $direction_char = ($direction eq "asc") ? "&uarr;" : "&darr;";
            }
            my $url = _external_url($args->{dancer_prefix}, $args->{prefix})
                . "?o=$col_name&d=$direction&q=$q&searchfield=$sf&searchtype=$st";
            $col_name =>
                "<a href=\"$url\">$friendly_name&nbsp;$direction_char</a>";
        } @all_cols;

        # And for custom columns, do the prettification, but don't include a
        # link for sorting - as we can't sort by them currently (the sorting is
        # done by SQL, and the custom column values are calculated after we get
        # the results from the SQL query, so to support sorting by them we'd
        # have to stop getting the database to sort the data and sort it
        # ourselves afterwards).
        if (exists $args->{custom_columns}) {
            for my $custom_column_name (
                map { $_->{name} } @{ $args->{custom_columns} }
            ) {
                $columns_sort_options{$custom_column_name}
                    = _prettify_column_name($custom_column_name);
            }
        }

        if (exists $args->{foreign_keys} and exists $args->{foreign_keys}{$order_by_column}) {
                my $fk = $args->{foreign_keys}{$order_by_column};
                $order_by_column = $fk->{label_column};
                $order_by_table = $fk->{table};
        }

        $query .= " ORDER BY "
            . $dbh->quote_identifier($order_by_table) . "."
            . $dbh->quote_identifier($order_by_column)
            . " $order_by_direction ";
    }

    if ($args->{paginate} && $args->{paginate} =~ /^\d+$/) {
        my $page_size = $args->{paginate};

        my $qt   = uri_escape($q);
        my $sf   = uri_escape(params->{searchfield} || $searchfield);
        my $st   = uri_escape(params->{searchtype} || "e");
        my $o    = uri_escape(params->{'o'}         || "");
        my $d    = uri_escape(params->{'d'}         || "");
        my $page = uri_escape(params->{'p'}         || 0);
        $page = 0 unless $page =~ /^\d+$/;

        my $offset = $page_size * $page;
        my $limit  = $page_size;

        my $url = _external_url($args->{dancer_prefix}, $args->{prefix})
            . "?o=$o&d=$d&q=$qt&searchfield=$sf&searchtype=$st";
        $html .= "<p>";
	$html .= "<table class=\"$paginate_table_class\"><tr>";

        if ($page > 0) {
            $html
                .= sprintf(
                "<td><a href=\"%s&p=%d\">&larr;&nbsp;prev.&nbsp;page</a></td>",
                $url, $page - 1)
        } else {
            $html .= "<td>&larr;&nbsp;prev.&nbsp;page&nbsp</td>";
        }
        $html .= sprintf(
            "<td>Showing page %d (records %d to %d)",
            $page + 1,
            $offset + 1,
            $offset + 1 + $limit
        );
        $html .= "</td>";
        $html .= sprintf("<td><a href=\"%s&p=%d\">next&nbsp;page&nbsp;&rarr;</a>",
            $url, $page + 1);
        $html .= "</td></tr></table>";

        $query .= " LIMIT $limit OFFSET $offset ";
    }

    debug("Running query: $query");
    my $sth = $dbh->prepare($query);
    $sth->execute(@binds)
        or die "Failed to query for records in $table_name - "
        . $dbh->errstr;

    if ($args->{downloadable} && params->{format}) {

        ##Return results as a downloaded file, instead of generating the HTML table.
        return _return_downloadable_query($args, $sth, params->{format});
    }

    my @custom_callbacks = ();
    for my $custom_col_spec (@{ $args->{custom_columns} || [] } ) {
        push @custom_callbacks, {
            column=>$custom_col_spec->{name}, 
            transform=> ($custom_col_spec->{transform} or sub { return shift;}),
        };
    }


    my $table = HTML::Table::FromDatabase->new(
        -sth       => $sth,
        -border    => 1,
        -callbacks => [
            {
                column    => 'actions',
                transform => sub {
                    my $id = shift;
                    my $action_links;
                    if ($args->{editable} && _has_permission('edit', $args)) {
                        my $edit_url
                            = _external_url(
                                $args->{dancer_prefix}, $args->{prefix}, 
                                "/edit/$id"
                            );
                        $action_links
                            .= qq[<a href="$edit_url" class="edit_link">Edit</a>];
                        if ($args->{deletable} && _has_permission('edit', $args)) {
                            my $del_url =_external_url(
                                $args->{dancer_prefix}, $args->{prefix},
                                "/delete/$id"
                            );
                            $action_links
                                .= qq[ / <a href="$del_url" class="delete_link"]
                                . qq[ onclick="delrec('$id'); return false;">]
                                . qq[Delete</a>];
                        }
                    }
                    return $action_links;
                },
            },
            @custom_callbacks,
        ],
        -rename_headers      => \%columns_sort_options,
        -html                => 'escape',
        -class               => "$table_class",
    );

    $html .= $table->getTable || '';

    if ($args->{editable} && _has_permission('edit', $args)) {
        $html .= sprintf '<a href="%s">Add a new %s</a></p>',
            _external_url($args->{dancer_prefix}, $args->{prefix}, '/add'),
            $args->{record_title};

        # Append a little Javascript which asks for confirmation that they'd
        # like to delete the record, then makes a POST request via a hidden
        # form.  This could be made AJAXy in future.
        my $del_action = _external_url(
            $args->{dancer_prefix}, $args->{prefix}, '/delete'
        );
        $html .= <<DELETEJS;
<form name="deleteform" method="post" action="$del_action">
<input name="record_id" type="hidden">
</form>
<script language="Javascript">
function delrec(record_id) {
    if (confirm('Confirm you wish to delete this record?')) {
        document.deleteform.rowid.value = record_id;
        document.deleteform.submit();
    }
}
</script>

DELETEJS
    }

    return _apply_template($html, $args->{'template'}, $args->{'record_title'});
}

sub _apply_template {
    my ($html, $template, $title) = @_;

    if ($template) {
        return template $template, { simple_crud => $html, record_title => $title };
    } else {
        return engine('template')->apply_layout($html);
    }
}

sub _return_downloadable_query {
    my ($args, $sth, $format) = @_;

    my $output;

    ## Generate an informative filename
    my $filename = $args->{db_table};
    if (params->{'o'}) {
        my $order = params->{'o'};
        $order =~ s/[^\w\.\-]+/_/g;
        $filename .= "__sorted_by_" . $order;
    }
    my $q = _defined_or_empty(params->{'q'});
    if (length($q)) {
        my $query = $q;
        $query =~ s/[^\w\.\-]+/_/g;
        $filename .= "__query_" . $query;
    }
    if (params->{'p'}) {
        my $page = params->{'p'};
        $page =~ s/[^0-9]+/_/g;
        $filename .= "__page_" . $page;
    }

    ## Generate data in the requested format
    if ($format eq "tabular") {
        header('Content-Type' => 'text/tab-separated-values');
        header('Content-Disposition' =>
                "attachment; filename=\"$filename.txt\"");
        my $aref = $sth->{NAME};
        $output = join("\t", @$aref) . "\r\n";
        while ($aref = $sth->fetchrow_arrayref) {
            $output .= join("\t", @{$aref}) . "\r\n";
        }
    } elsif ($format eq "csv") {
        eval { require Text::CSV };
        return
            "Error: required module Text::CSV not installed. Can't generate CSV file."
            if $@;

        header('Content-Type' => 'text/comma-separated-values');
        header('Content-Disposition' =>
                "attachment; filename=\"$filename.csv\"");

        my $csv  = Text::CSV->new();
        my $aref = $sth->{NAME};
        $csv->combine(@{$aref});
        $output = $csv->string() . "\r\n";
        while ($aref = $sth->fetchrow_arrayref) {
            $csv->combine(@{$aref});
            $output .= $csv->string() . "\r\n";
        }
    } elsif ($format eq "json") {
        header('Content-Type' => 'text/json');
        header('Content-Disposition' =>
                "attachment; filename=\"$filename.json\"");
        $output = to_json($sth->fetchall_arrayref({}));
    } elsif ($format eq "xml") {
        header('Content-Type' => 'text/xml');
        header('Content-Disposition' =>
                "attachment; filename=\"$filename.xml\"");
        $output = to_xml($sth->fetchall_arrayref({}));
    } else {
        $output = "Error: unknown format $format";
    }

    return $output;
}

# Given a table name, return an arrayref of hashrefs describing each column in
# the table.
# Expect to see the following keys:
# COLUMN_NAME
# COLUMN_SIZE
# NULLABLE
# DATETIME ?
# TYPE_NAME (e.g. INT, VARCHAR, ENUM)
# MySQL-specific stuff includes:
# mysql_type_name (e.g. "enum('One', 'Two', 'Three')"
# mysql_is_pri_key
# mysql_values (for an enum, ["One", "Two", "Three"]
sub _find_columns {
    my ($dbh, $table_name) = @_;
    my $sth = $dbh->column_info(undef, undef, $table_name, undef)
        or die "Failed to get column info for $table_name - " . $dbh->errstr;
    my @columns;
    while (my $col = $sth->fetchrow_hashref) {

        # Push a copy of the hashref, as I think DBI re-uses them
        push @columns, {%$col};
    }

    die "no columns for table [$table_name]--are you sure this table exists in the database [$dbh->{Driver}->{Name}:$dbh->{Name}]?" unless @columns;

    # Return the columns, sorted by their position in the table:
    return [sort { $a->{ORDINAL_POSITION} <=> $b->{ORDINAL_POSITION} }
            @columns];
}

# Given parts of an URL, assemble them together, prepending the current prefix
# setting if needed, and taking care to get slashes right.
# e.g. for the following example:
#     prefix '/foo';
#     simple_crud( prefix => '/bar', ....);
# calling: _construct_url($args{prefix}, '/baz')
# would return: /foo/bar/baz
sub _construct_url {
    my @url_parts = @_;

    # Just concatenate all parts together, then deal with multiple slashes.
    # This could be problematic if any URL was ever supposed to contain multiple
    # slashes, but that shouldn't be an issue here.
    my $url = '/' . join '/', @url_parts;
    $url =~ s{/{2,}}{/}g;
    return $url;
}

sub _external_url {
    if ( plugin_setting()->{use_old_url_scheme} ) {
        return _construct_url(@_);
    }
    else {
        return uri_for(_construct_url(@_));
    }
}

# Given a mode ("view" or "edit", a handler coderef, and an args coderef, works
# out if we need to wrap the handler coderef via
# Dancer::Plugin::Auth::Extensible to ensure authorisation, and if so, does so.
sub _ensure_auth {
    my ($mode, $handler, $args) = @_;
    
    my $auth_settings = $args->{auth}{$mode} || $args->{auth} || {};

    if (keys %$auth_settings) {
        Dancer::ModuleLoader->load('Dancer::Plugin::Auth::Extensible')
            or die "Can't use auth settings without"
                . " Dancer::Plugin::Auth::Extensible!";
    } else {
        # I think this can just be 'return;' given the way it is
        # used currently, but the other branch returns a $handler,
        # so this is more consistent
        return $handler;
    }

    if ($auth_settings->{require_login}) {
        return $handler = 
            Dancer::Plugin::Auth::Extensible::require_login($handler);
    } else {
        for my $keyword (qw(require_role require_any_role require_all_roles)) {
            if (my $val = $auth_settings->{$keyword}) {
                return $handler = Dancer::Plugin::Auth::Extensible->can($keyword)->(
                    $val, $handler
                );
            }
        }
    }
}

# Given an action (view/edit) and an args coderef, returns whether the user has
# permission to perform that action (e.g. if require_login is set, checks the
# user is logged in; if require_role is set, checks they have that role, etc)
sub _has_permission {
    my ($mode, $args) = @_;
    
    my $auth_settings = $args->{auth}{$mode} || $args->{auth} || {};
    if (keys %$auth_settings) {
        Dancer::ModuleLoader->load('Dancer::Plugin::Auth::Extensible')
            or die "Can't use auth settings without"
                . " Dancer::Plugin::Auth::Extensible!";
    } else {
        # If no auth settings provided, they can do what they like
        return 1;
    }

    if ($auth_settings->{require_login}) {
        return Dancer::Plugin::Auth::Extensible::logged_in_user() ? 1 : 0;
    }

    if (my $need_role = $auth_settings->{require_role}) {
        return Dancer::Plugin::Auth::Extensible::user_has_role($need_role);
    }

    # TODO: handle require_any_role / require_all_roles here
    warn "TODO: handle require_any_role / requires_all_roles";
    return 0;
}

sub _defined_or_empty {
    my $v = shift;
    return defined($v) ? $v : "";
}

# where_filter  "if it's a coderef, call it and check it gave us a hashref to
# use, otherwise expect it to be a hashref" logic as we need this in several
# places.  Returns a hashref, ready for us to add other stuff to in most cases
# (e.g. usually we'd call this, then add $key_column => ... to it)
sub _get_where_filter_from_args {
    my $args = shift;
    return unless $args->{where_filter};

    if (ref $args->{where_filter} eq 'HASH') {
        return $args->{where_filter};
    } elsif (ref $args->{where_filter} eq 'CODE') {
        my $result = $args->{where_filter}->();
        if (ref $result eq 'HASH') {
            return $result;
        } else {
            # TODO: better error reporting, so we know which one caused
            # the problem
            die "where_filter coderef didn't return a hashref!";
        }
    } else {
        die "Invalid where_filter";
    }
}

sub _prettify_column_name {
    my $name = shift;
    for ($name) {
        $_ = lc;
        s{_}{ }g;
        s{\b(\w)}{\u$1}g;
    }
    return $name;
}

=back

=head1 DWIMmery

This module tries to do what you'd expect it to do, so you can rock up your web
app with as little code and effort as possible, whilst still giving you control
to override its decisions wherever you need to.

=head2 Field types

CGI::FormBuilder is excellent at working out what kind of field to use by
itself, but we give it a little help where needed.  For instance, if a field
looks like it's supposed to contain a password, we'll have it rendered as a
password entry box, rather than a standard text box.

If the column in the database is an ENUM, we'll limit the choices available for
this field to the choices defined by the ENUM list.  (Unless you've provided a
set of acceptable values for this field using the C<acceptable_values> option to
C<simple_crud>, in which case what you say goes.)

=head1 Hooks

Hooks are provided, which can be used in the normal Dancer way, using the 
C<hook> keyword.

=head2 add_edit_row (deprecated, use add_edit_row_pre_save)

You can use the same code from your add_edit_row hook in an add_edit_row_pre_save
hook.  The only modification is that the new hook passes the editable params
as a key of the first argument (called C<params>), rather than as the first
argument itself.  So, if your hook had C<my $args = shift;>, it could just
use C<< my $args = shift->{params}; >> and it should work the same way.

=head2 add_edit_row_pre_save, add_edit_row_post_save

These fire right before and after a row is added/edited; a hashref is
passed with metadata such as the name of the table (in C<table_name>), the
args from the original route setup (C<args>), the table's key column
(C<key_column>), and the values of the editable params (C<params>).

In the post-save hook, you are also sent C<success> (the return value of
quick_insert or quick_update) telling you if the save was successful,
C<dbh> giving you the instance of the handle used to save the entity
(so you can access last_insert_id()), and C<verb> (currently either
'create new' or 'update').

For instance, if you were dealing with a users table, you could use the
pre_save hook to hash the password before storing it - assuming for the sake
of example that you have a C<hash_pw()> function to return a hashed password:

  hook add_edit_row_pre_save => sub {
      my $args = shift;
      if ($args->{table_name} eq 'user') {
          $args->{params}{password} = hash_pw($args->{params}{password});
      }
  };

=head1 AUTHOR

David Precious, C<< <davidp@preshweb.co.uk> >>

=head1 ACKNOWLEDGEMENTS

Alberto Simões (ambs)

WK

Johnathan Barber

saberworks

jasonjayr

Paul Johnson (pjcj)

Rahul Kotamaraju

Michael J South (msouth)

Martijn Lievaart

Josh Rabinowitz

=head1 BUGS

Please report any bugs or feature requests to C<bug-dancer-plugin-simplecrud at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dancer-Plugin-SimpleCRUD>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 CONTRIBUTING

This module is developed on Github:

http://github.com/bigpresh/Dancer-Plugin-SimpleCRUD

Bug reports, ideas, suggestions, patches/pull requests all welcome.

Even just a quick "Hey, this is great, thanks" or "This is no good to me
because..." is greatly appreciated.  It's always good to know if people are
using your code, and what they think.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dancer::Plugin::SimpleCRUD

You may find help with this module on the main Dancer IRC channel or mailing
list - see http://www.perldancer.org/


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dancer-Plugin-SimpleCRUD>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dancer-Plugin-SimpleCRUD>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dancer-Plugin-SimpleCRUD>

=item * Search CPAN

L<http://search.cpan.org/dist/Dancer-Plugin-SimpleCRUD/>

=back


=head1 LICENSE AND COPYRIGHT

Copyright 2010-16 David Precious.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Dancer::Plugin::SimpleCRUD
