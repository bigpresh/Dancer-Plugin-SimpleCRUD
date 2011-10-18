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
);

get '/' => sub {
    redirect '/people';
};


dance;
