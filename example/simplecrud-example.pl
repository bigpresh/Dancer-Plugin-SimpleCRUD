#!/usr/bin/perl

use lib '../lib';
use Dancer;
use Dancer::Plugin::SimpleCRUD;

simple_crud(
    record_title => 'Person',
    db_table => 'people',
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
