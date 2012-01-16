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

our $VERSION = '0.40';

=head1 NAME

Dancer::Plugin::SimpleCRUD - very simple CRUD (create/read/update/delete)


=head1 DESCRIPTION

A plugin for Dancer web applications, to use a  few lines of code to create
appropriate routes to support creating/editing/deleting/viewing records within a
database table.  Uses L<CGI::FormBuilder> to generate, process and validate forms,
L<Dancer::Plugin::Database> for database interaction and
L<HTML::Table::FromDatabase> to display lists of records.


=head1 SYNOPSIS

    # In your Dancer app,
    use Dancer::Plugin::SimpleCRUD;

    # Simple example:
    simple_crud(
        record_title => 'Widget',
        prefix => '/widgets',
        db_table => 'widgets',
    );

    # The above would create a route to handle C</widget/add> and
    # C</widget/:id>, presenting a form to add/edit a Widget respectively.
    # All fields in the database table would be editable.

    # A more in-depth synopsis, using all options:
    simple_crud(
        record_title => 'Widget',
        prefix => '/widgets',
        db_table => 'widgets',
        labels => {
            country => 'Country of Origin',
            type    => 'Widget Type', 
        },  
        validation => {
            weight => qr/\d+/,
        },
        input_types => {
            supersecret => 'password',
            lotsoftext' => 'textarea',
        },
        key_column => 'sku',
        editable_columns => [ qw( f_name l_name adr_1 ),
        display_columns => [ qw( f_name l_name adr_1 ),
        deleteable => 1,
        editable => 1,
        sortable => 1,
        paginate => 300,
        template => 'simple_crud.tt',
        query_auto_focus => 1,
        downloadable => 1,
    );



=head1 USAGE

This plugin provides a C<simple_crud> keyword, which takes a hash of options as
described below, and sets up the appropriate route to present add/edit/delete
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

=item C<db_table> (required)

The name of the database table.

=item C<key_column> (optional, default: 'id')

Specify which column in the table is the primary key.  If not given, defaults to
id.

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

=item C<validation> (optional)

A hashref of validation criteria which should be passed to L<CGI::FormBuilder>.

=item C<acceptable_values> (optional)

A hashref of arrayrefs to declare that certain fields can take only a set of
acceptable values, for instance:

  { foo => [ qw(Foo Bar Baz) ] }


=item C<editable_columns> (optional)

Specify an arrayref of fields which the user can edit.  By default, this is all
columns in the database table, with the exception of the key column.

=item <not_editable_columns> (optional)

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

Specify whether to show results in pages (with next/previous buttons).
Defaults to undef, meaning all records are shown on one page (not useful for large tables).
When defined as a number, only this number of results will be shown.

=item C<display_columns>

Specify an arrayref of columns that should show up in the list.  Defaults to all.

=item C<template>

Specify a template that will be applied to all output.  This template must have
a "simple_crud" placeholder defined or you won't get any output.  This template
must be located in your "views" directory.  Any global layout will be applied
automatically because this option causes the module to use the "template"
keyword.

=item C<query_auto_focus>

Specify whether to automatically set input focus to the query input field.
Defaults to true. If set to a false value, focus will not be set.
The focus is set using a simple inlined javascript.

=item C<downloadable>

Specify whether to support downloading the results.  Defaults to false. If set to a
true value, The results show on the HTML page can be downloaded as CSV/TSV/JSON/XML.
The download links will appear at the top of the page.

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

    if (!$args{db_table}) { die "Need table name!"; }

    # Find out what kind of engine we're talking to:
    my $db_type = $dbh->get_info(17);
    if ($db_type ne 'MySQL') {
	    warning "This module has so far only been tested with MySQL databases.";
    }

    # Accept deleteable as a synonym for deletable
    $args{deletable} = delete $args{deleteable}
	if !exists $args{deletable} && exists $args{deleteable};

    # Sane default values:
    $args{key_column}   ||= 'id';
    $args{record_title} ||= 'record';
    $args{editable} = 1 unless exists $args{editable};
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
        Dancer::Logger::debug("Setting up routes for $args{prefix}/add etc");
        any ['get', 'post'] => "$args{prefix}/add"      => $handler;
        any ['get', 'post'] => "$args{prefix}/edit/:id" => $handler;
    }

    # And a route to list records already in the table:
    my $list_handler
	= sub { _create_list_handler(\%args, $table_name, $key_column); };
    get "$args{prefix}" => $list_handler;

    # If we should allow deletion of records, set up routes to handle that,
    # too.
    if ($args{editable} && $args{deletable}) {

	# A route for GET requests, to present a "Do you want to delete this"
	# message with a form to submit (this is only for browsers which didn't
	# support Javascript, otherwise the list page will have POSTed the ID
	# to us) (or they just came here directly for some reason)
	get "$args{prefix}/delete/:id" => sub {
	    return _apply_template(<<CONFIRMDELETE, $args{'template'});
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
	post qr[$args{prefix}/delete/?(.+)?$] => sub {
	    my ($id) = params->{record_id} || splat;
	    database->quick_delete($table_name, { $key_column => $id })
		or return _apply_template("<p>Failed to delete!</p>", $args{'template'});

	    redirect _construct_url($args{prefix});
	};
    }

}

register simple_crud => \&simple_crud;
register_plugin;

sub _create_add_edit_route {
    my ($args, $table_name, $key_column) = @_;
    my $params = params;
    my $id     = $params->{id};

    my $dbh = database($args->{db_connection_name});

    my $default_field_values;
    if ($id) {
	$default_field_values
	    = database->quick_select($table_name, { $key_column => $id });
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
        for my $col (@{$args->{not_editable_columns}}) {
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
	values   => $default_field_values,
	validate => $validation,
	method   => 'post',
	action   => _construct_url(
	    $args->{prefix},
	    (
		params->{id}
		? '/edit/' . params->{id}
		: '/add'
	    )
	),
    );
    for my $field (@editable_columns) {
	my %field_params = (
	    name  => $field,
	    value => $default_field_values->{$field} || '',
	);
	if (my $label = $args->{labels}->{$field}) {
	    $field_params{label} = $label;
	}
	if (my $validation = $args->{validation}->{$field}) {
	    $field_params{validate} = $validation;
	}

	$field_params{required} = $required_fields{$field};

	if ($constrain_values{$field}) {
	    $field_params{options} = $constrain_values{$field};
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

	# OK, add the field to the form:
	$form->field(%field_params);
    }

    # Now, if all is OK, go ahead and process:
    if (request->{method} eq 'POST' && $form->submitted && $form->validate) {

	# Assemble a hash of only fields from the DB (if other fields were
	# submitted with the form which don't belong in the DB, ignore them)
	my %params;
	$params{$_} = params->{$_} for @editable_columns;
	my $verb;
	my $success;
	if (exists params->{$key_column}) {

	    # We're editing an existing record
	    $success = database->quick_update($table_name,
		{ $key_column => params->{$key_column} }, \%params);
	    $verb = 'update';
	} else {
	    $success = database->quick_insert($table_name, \%params);
	    $verb = 'create new';
	}

	if ($success) {

	    # Redirect to the list page
	    # TODO: pass a param to cause it to show a message?
	    redirect _construct_url($args->{prefix});
	    return;
	} else {

	    # TODO: better error handling - options to provide error templates
	    # etc
	    return _apply_template("<p>Unable to $verb $args->{record_title}</p>", $args->{'template'});
	}

    } else {
	    return _apply_template($form->render, $args->{'template'});
    }
}

sub _create_list_handler {
    my ($args, $table_name, $key_column) = @_;

    my $dbh     = database($args->{db_connection_name});
    my $columns = _find_columns($dbh, $table_name);

    my $display_columns = $args->{'display_columns'};

    # If display_columns argument was passed, filter the column list to only
    # have the ones we asked for.
    if(ref $display_columns eq 'ARRAY') {
        my @filtered_columns;

        foreach my $col (@$columns) {
            if(grep { $_ eq $col->{'COLUMN_NAME'} } @$display_columns) {
                push @filtered_columns, $col;
            }
        }

        if(@filtered_columns) {
            $columns = \@filtered_columns;
        }
    }

    my $options = join(
	"\n",
	map {	my $selected = (defined params->{searchfield}
				&& params->{searchfield} eq $_->{COLUMN_NAME})
				?"selected":"";
		"<option $selected value='$_->{COLUMN_NAME}'>$_->{COLUMN_NAME}</option>" }
	    @$columns
    );

    my $order_by_param=params->{'o'} || "";
    my $order_by_direction=params->{'d'} || "";
    my $html = <<"SEARCHFORM";
 <p><form name="searchform" method="get">
     Field:  <select name="searchfield">$options</select> &nbsp;&nbsp;
     Query: <input name="q" id="searchquery" type="text" size="30"/> &nbsp;&nbsp;
     <input name="o" type="hidden" value="$order_by_param"/>
     <input name="d" type="hidden" value="$order_by_direction"/>
     <input name="searchsubmit" type="submit" value="Search"/>
 </form></p>
SEARCHFORM

    if ($args->{query_auto_focus}) {
	$html .= "<script>document.getElementById(\"searchquery\").focus();</script>";
    }

    # TODO: handle pagination
    # TODO: Fix me with more data types. Make this global?
    my %known_type = (
	INT     => q{%s = %s},
	VARCHAR => q{%s LIKE %s},
    );

    # Explicitly select the columns we are displaying.  (May have been filtered
    # by display_columns above.)
    my $select_cols = join(',', 
        map { database->quote_identifier($_->{'COLUMN_NAME'}) } @$columns);
    my $add_actions = $args->{editable} ? ", $key_column AS actions" : '';
    my $query = "SELECT $select_cols $add_actions FROM $table_name";

    if (params->{'q'}) {
	my ($column_data)
	    = grep { lc $_->{COLUMN_NAME} eq lc params->{searchfield} }
	    @{$columns};
	debug(    "Searching on $column_data->{COLUMN_NAME} which is a "
		. "$column_data->{TYPE_NAME}");

	if ($column_data
	    and my $add_clause = $known_type{ uc $column_data->{TYPE_NAME} })
	{
	    $query .= ' WHERE ' . sprintf $add_clause,
		$dbh->quote_identifier(params->{searchfield}),
		$dbh->quote('%' . params->{'q'} . '%');

	    $html
		.= sprintf(
		"<p>Showing results from searching for '%s' in '%s'",
		params->{'q'}, params->{searchfield});
	    $html .= sprintf '&mdash;<a href="%s">Reset search</a></p>',
		_construct_url($args->{prefix});
	}
    }

	if ($args->{downloadable}) {
		my $q = params->{'q'} || "";
		my $sf = params->{searchfield} || "";
		my $o = params->{'o'} || "";
		my $d = params->{'d'} || "";
		my $page = params->{'p'} || 0 ;

		my @formats = qw/csv tabular json xml/;

		my $url = _construct_url($args->{prefix}) .
			"?o=$o&d=$d&q=$q&searchfield=$sf&p=$page";

		$html .="<p>Download as: " . join(", ",
			map { "<a href=\"$url&format=$_\">$_</a>" } @formats ) . "<p>";
	}

	## Build a hash to add sorting CGI parameters + URL to each column header.
	## (will be used with HTML::Table::FromDatabase's "-rename_columns" parameter.
	my %columns_sort_options;
	if ($args->{sortable}) {
		my $q = params->{'q'} || "";
		my $sf = params->{searchfield} || "";
		my $order_by_column = params->{'o'} || $key_column;
		# Invalid column name ? discard it
		my $valid = grep { $_->{COLUMN_NAME} eq $order_by_column } @$columns;
		$order_by_column = $key_column unless $valid;

		my $order_by_direction = (exists params->{'d'} && params->{'d'} eq "desc")?"desc":"asc";
		my $opposite_order_by_direction = ($order_by_direction eq "asc")?"desc":"asc";

		%columns_sort_options = map {
			my $col_name = $_->{COLUMN_NAME};
			my $direction = $order_by_direction;
			my $direction_char = "";
			if ($col_name eq $order_by_column) {
				$direction = $opposite_order_by_direction;
				$direction_char = ($direction eq "asc")?"&uarr;":"&darr;";
			}
			my $url = _construct_url($args->{prefix}) .
				"?o=$col_name&d=$direction&q=$q&searchfield=$sf";
			$col_name => "<a href=\"$url\">$col_name&nbsp;$direction_char</a>";
			} @$columns;

	    $query .= " ORDER BY " . database->quote_identifier($order_by_column) .
			" " .$order_by_direction . " " ;
	}

	if ($args->{paginate} && $args->{paginate} =~ /^\d+$/ ) {
		my $page_size = $args->{paginate};

		my $q = params->{'q'} || "";
		my $sf = params->{searchfield} || "";
		my $o = params->{'o'} || "";
		my $d = params->{'d'} || "";
		my $page = params->{'p'} || 0 ;
		$page = 0 unless $page =~ /^\d+$/;

		my $offset = $page_size * $page ;
		my $limit = $page_size ;

		my $url = _construct_url($args->{prefix}) .
			"?o=$o&d=$d&q=$q&searchfield=$sf";
		$html .= "<p>";
		if ($page > 0) {
			$html .= sprintf("<a href=\"$url&p=%d\">&larr;&nbsp;prev.&nbsp;page</a>", $page-1)
		} else {
			$html .= "&larr;&nbsp;prev.&nbsp;page&nbsp";
		}
		$html .= "&nbsp;" x 5;
		$html .= sprintf("Showing page %d (records %d to %d)",
				$page+1, $offset+1, $offset+1 + $limit );
		$html .= "&nbsp;" x 5;
		$html .= sprintf("<a href=\"$url&p=%d\">next&nbsp;page&nbsp;&rarr;</a>", $page+1);
		$html .= "<p>";


		$query .= " LIMIT $limit OFFSET $offset " ;
	}



    debug("Running query: $query");
    my $sth = $dbh->prepare($query);
    $sth->execute()
	or die "Failed to query for records in $table_name - "
	. database->errstr;

    if ($args->{downloadable} && params->{format} ) {
	    ##Return results as a downloaded file, instead of generating the HTML table.
	    return _return_downloadable_query($args, $sth, params->{format});
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
                    if ($args->{editable}) {
                        my $edit_url
                            = _construct_url($args->{prefix}, "/edit/$id");
                        $action_links
                            .= qq[<a href="$edit_url" class="edit_link">Edit</a>];
                        if ($args->{deletable}) {
                            my $del_url
                                = _construct_url($args->{prefix}, "/delete/$id");
                            $action_links
                                .= qq[ / <a href="$del_url" class="delete_link"]
                                . qq[ onclick="delrec('$id'); return false;">]
                                . qq[Delete</a>];
                        }
                    }
		    return $action_links;
		},
	    },
	],
	-rename_headers => \%columns_sort_options,
        -html => 'escape',
    );

    $html .= $table->getTable || '';

    if ($args->{editable}) {
        $html .= sprintf '<a href="%s">Add a new %s</a></p>',
            _construct_url($args->{prefix}, '/add'), $args->{record_title};

        # Append a little Javascript which asks for confirmation that they'd
        # like to delete the record, then makes a POST request via a hidden
        # form.  This could be made AJAXy in future.
        my $del_action = _construct_url($args->{prefix}, '/delete');
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

    return _apply_template($html, $args->{'template'});
}

sub _apply_template {
    my ($html, $template) = @_;

    if($template) {
        return template $template, { simple_crud => $html };
    }
    else {
        return engine('template')->apply_layout($html);
    }
};

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
	if (params->{'q'}) {
		my $query = params->{'q'};
		$query =~ s/[^\w\.\-]+/_/g;
		$filename .= "__query_" . $query ;
	}
	if (params->{'p'}) {
		my $page = params->{'p'};
		$page =~ s/[^0-9]+/_/g;
		$filename .= "__page_" . $page ;
	}

	## Generate data in the requested format
	if ($format eq "tabular") {
		header('Content-Type' => 'text/tab-separated-values');
		header('Content-Disposition' => "attachment; filename=\"$filename.txt\"");
		my $aref = $sth->{NAME};
		$output = join("\t", @$aref) . "\r\n";
		while( $aref = $sth->fetchrow_arrayref ) {
			$output .= join("\t", @{ $aref } ) . "\r\n";
		}
	}
	elsif ($format eq "csv") {
		eval { require Text::CSV };
		return "Error: required module Text::CSV not installed. Can't generate CSV file." if $@;

		header('Content-Type' => 'text/comma-separated-values');
		header('Content-Disposition' => "attachment; filename=\"$filename.csv\"");

		my $csv = Text::CSV->new();
		my $aref = $sth->{NAME};
		$csv->combine( @{ $aref } );
		$output = $csv->string() . "\r\n";
		while( $aref = $sth->fetchrow_arrayref ) {
			$csv->combine( @{ $aref } );
			$output .= $csv->string() . "\r\n";
		}
	}
	elsif ($format eq "json") {
		header('Content-Type' => 'text/json');
		header('Content-Disposition' => "attachment; filename=\"$filename.json\"");
		$output = to_json ( $sth->fetchall_arrayref ( {} ) );
	}
	elsif ($format eq "xml") {
		header('Content-Type' => 'text/xml');
		header('Content-Disposition' => "attachment; filename=\"$filename.xml\"");
		$output = to_xml ( $sth->fetchall_arrayref ( {} ) );
	}
	else  {
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
    my $prefix_setting = Dancer::App->current->prefix || '';
    unshift @url_parts, $prefix_setting;

    # Just concatenate all parts together, then deal with multiple slashes.
    # This could be problematic if any URL was ever supposed to contain multiple
    # slashes, but that shouldn't be an issue here.
    my $url = '/' . join '/', @url_parts;
    $url =~ s{/{2,}}{/}g;
    return uri_for($url);
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



=head1 AUTHOR

David Precious, C<< <davidp@preshweb.co.uk> >>

=head1 ACKNOWLEDGEMENTS

Alberto Simões (ambs)

WK

Johnathan Barber

saberworks


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


=head1 ACKNOWLEDGEMENTS

Alberto Simões (ambs)

Jonathan Barber

saberworks

jasonjayr


=head1 LICENSE AND COPYRIGHT

Copyright 2010-11 David Precious.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Dancer::Plugin::SimpleCRUD
