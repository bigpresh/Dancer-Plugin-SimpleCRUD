#!/usr/bin/perl

use lib '../lib';
use Dancer;
use Dancer::Plugin::SimpleCRUD;

simple_crud(
    record_title => 'Person',
    db_table => 'people',
    db_connection_name => 'foo',
    prefix => '/people',
    acceptable_values => {
        gender => [ qw( Male Female ) ],
    },
    deletable => 'yes',
    sortable => 'yes',
    paginate => 5,
    downloadable => 1,
    foreign_keys => {
        employer_id => {
            table        => 'employer',
            key_column   => 'id',
            label_column => 'name',
        },
    },
    custom_columns => {
        mailto_link => {
            raw_column => 'email',
            transform  => sub { my $email = shift; return "<a href='mailto:$email'>mail</a>"; },
        },
        full_name => {
            raw_column => "(first_name || ' ' || last_name)",
            transform => sub { return shift }, # (unnecessary, btw, as this is the default)
        },
    },
    labels => {
        age => 'Age (years)',
    },
    auth => {
        view => {
            require_login => 1,
        },
        edit => {
            require_role => 'editor',
        },
    },
);

get '/' => sub {
    redirect '/people';
};

# manipulate the name entered via a hook
hook add_edit_row => sub {
    my $row = shift;
    $_ = ucfirst lc $_ for (@$row{qw(first_name last_name)});
};


dance;
