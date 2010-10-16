# First, a dead simple object that can be fed a hashref of params from the
# Dancer params() keyword, and returns then when its param() method is called,
# so that we can feed it to CGI::FormBuilder:
package Dancer::Plugin::SimpleCRUD::ParamsObject;
sub new { 
    my ($class, $params) = @_; 
    return bless { params => $params }, $class;
}
sub param { shift->{params} };

# Now, on to the real stuff
package Dancer::Plugin::SimpleCRUD;

use warnings;
use strict;
use Dancer::Plugin;
use Dancer qw(:syntax);
use Dancer::Plugin::Database;
use CGI::FormBuilder;

our $VERSION = '0.01';


=head1 NAME

Dancer::Plugin::SimpleCRUD - very simple CRUD (create/read/update/delete)


=head1 DESCRIPTION

A plugin for Dancer web applications, to use a  few lines of code to create
appropriate routes to support creating/editing/deleting records within a
database table.  Uses L<HTML::FormFu> to generate, process and validate forms,
and L<Dancer::Plugin::Database> for database interaction.


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
        field_labels => {
            country => 'Country of Origin',
            type    => 'Widget Type', 
        },  
        validation => {
            weight => qr/\d+/,
        },
        key_column => 'sku',
        editable => [ qw( f_name l_name adr_1 ),
        deleteable => 1,
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

=item <field_labels> (optional)

A hashref of field_name => 'Label', if you want to provide more user-friendly
labels for some or all fields.  As we're using CGI::FormBuilder, it will do a
reasonable job of figuring these out for itself usually anyway - for instance, a
field named C<first_name> will be shown as C<First Name>.

=item C<validation> (optional)

A hashref of validation criteria which should be passed to HTML::FormFu.

=item C<editable> (optional)

Specify an arrayref of fields which the user can edit.  By default, this is all
columns in the database table, with the exception of the key column.

=item <not_editable> (optional)

Specify an arrayref of fields which should not be editable.


=item C<deletable>

Specify whether to support deleting records.  If set to a true value, a route
will be created for C</prefix/delete/:id> to delete the record with the ID
given, and the edit form will have a "Delete $record_title" button.


=cut

sub simple_crud {
    my (%args) = @_;


    # Either use a database handle passed to us, or get one via the
    # Dancer::Plugin::Database plugin:
    my $dbh;
    if ($args{dbh}) {
        $dbh = $args{dbh};
    } else {
        $dbh = database();
    }

    if (!$dbh) {
        warn "No database handle";
        return;
    }

    if (!$args{prefix}) { die  "Need prefix to create routes!"; }
    if ($args{prefix} !~ m{^/}) {
        $args{prefix} = '/' . $args{prefix};
    }

    if (!$args{db_table}) { die "Need table name!"; }

    # Find out what kind of engine we're talking to:
    my $db_type = $dbh->get_info(17);
    if ($db_type ne 'MySQL') {
        die "This module has so far only been tested with MySQL databases.";
    }

    # Sanitise things we'll have to interpolate into queries (yes, that makes me
    # feel bad, but you can't use params for field/table names):
    my $table_name = $args{db_table};
    my $key_column = $args{key_column} || 'id';
    for ($table_name, $key_column) {
        die "Invalid table name/key column - SQL injection attempt?"
            if /--/;
        s/[^a-zA-Z0-9_-]//g;
    }

    # OK, create a route handler to deal with adding/editing:
    my $handler = sub {
        my $params = params;
        my $id = $params->{id};
        
        my $default_field_values;
        if ($id) {
            my $record = database->selectrow_hashref(
                "select * from $table_name where $key_column = ?",
                {}, $id
            );
            $default_field_values = $record;
        }

        # Find out about table columns:
        Dancer::Logger::debug("Looking for columns in $table_name (via $dbh)");
        my $all_table_columns = _find_columns($dbh, $args{db_table});
        use Data::Dump;
        Dancer::Logger::debug("All columns in $table_name:\n"
            . Data::Dump::dump($all_table_columns));

        my @editable_columns;
        # Now, find out which ones we can edit.
        if ($args{editable_columns}) {
            # We were given an explicit list of fields we can edit, so this is
            # easy:
            @editable_columns = @{ $args{editable_columns} };
        } else {
            # OK, take all the columns from the table:
            @editable_columns = map { $_->{COLUMN_NAME} } @$all_table_columns;
        }

        # Some DWIMery: if we don't have a validation rule specified for a
        # field, and it's pretty clear what it is supposed to be, just do it:
        my $validation = $args{validation} || {};
        for my $field (grep { $_ ne $key_column } @editable_columns) 
        {
            next if $validation->{$field};
            if ($field =~ /email/) {
                $validation->{$field} = 'EMAIL';
            }
        }

        # More DWIMmery: if the user hasn't supplied a list of required fields,
        # work out what fields are required by whether they're nullable in the
        # DB:
        my %required_fields;
        if (exists $args{required}) {
            $required_fields{$_}++ for @{ $args{required} };
        } else {
            $_->{NULLABLE} || $required_fields{ $_->{COLUMN_NAME} }++
                for @$all_table_columns;
        }

        use Data::Dump;
        Dancer::Logger::debug("Required fields: "
            . Data::Dump::dump(\%required_fields));


        my $paramsobj = Dancer::Plugin::SimpleCRUD::ParamsObject->new({params()});

        use Data::Dump;
        Dancer::Logger::debug("Params from Dancer are:" .
            Data::Dump::dump(params()));
        Dancer::Logger::debug("Params from paramsobj are: "
            . Data::Dump::dump($paramsobj->param));
        Dancer::Logger::debug("Default values from DB are: "
            . Data::Dump::dump($default_field_values));

        my $form = CGI::FormBuilder->new(
            fields => \@editable_columns,
            params => $paramsobj,
            values => $default_field_values,
            validate => $validation,
            method => 'post',
            action => $args{prefix} . 
                (params->{id} ? '/edit/' . params->{id} : '/add'),
        );
        for my $field (@editable_columns) {
            my %field_params = (
                name => $field
            );
            if (my $label = $args{labels}->{$field}) {
                $field_params{label} = $label;
            }
            if (my $validation = $args{validation}->{$field}) {
                $field_params{validate} = $validation;
            }

            $field_params{required} = $required_fields{$field};

            # Normally, CGI::FormBuilder can guess the type of field perfectly,
            # but give it some extra DWIMmy help:
            if ($field =~ /pass(?:wd|word)?$/i) {
                $field_params{type} = 'password';
            }

            # OK, add the field to the form:
            $form->field(%field_params);
        }

        # Now, if all is OK, go ahead and process:
        if ($form->submitted && $form->validate) {
            debug("I would add/update here");
            use Data::Dump;
            debug("Params: " . Data::Dump::dump(params()) );
        } else {
            return $form->render;
        }
    };
    Dancer::Logger::debug("Setting up routes for $args{prefix}/add etc");
    any ['get','post'] => "$args{prefix}/add"      => $handler;
    any ['get','post'] => "$args{prefix}/edit/:id" => $handler;


    if ($args{deletable}) {
        post "$args{prefix}/delete:id" => sub {
            database()->do('delete ....');
        };
    }

}

register simple_crud => \&simple_crud;
register_plugin;


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
        push @columns, { %$col };
    }

    # Return the columns, sorted by their position in the table:
    return [ 
        sort { 
            $a->{ORDINAL_POSITION} <=> $b->{ORDINAL_POSITION} 
        } @columns
    ];
}


=head1 AUTHORS

David Precious, C<< <davidp@preshweb.co.uk> >>

James Ronan, C<< <james.ronan@ronanweb.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dancer-plugin-simplecrud at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Dancer-Plugin-SimpleCRUD>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 CONTRIBUTING

This module is developed on Github:

http://github.com/bigpresh/Dancer-Plugin-SimpleCRUD


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


=head1 LICENSE AND COPYRIGHT

Copyright 2010 David Precious.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Dancer::Plugin::SimpleCRUD
