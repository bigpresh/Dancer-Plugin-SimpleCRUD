use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Dancer::Plugin::SimpleCRUD',
    AUTHOR              => q{David Precious <davidp@preshweb.co.uk>},
    VERSION_FROM        => 'lib/Dancer/Plugin/SimpleCRUD.pm',
    ABSTRACT_FROM       => 'lib/Dancer/Plugin/SimpleCRUD.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Dancer'     => 1.3,
        'Dancer::Plugin::Database' => 1.00,
        'Dancer::Plugin::Database::Core' => 0.15,
        'HTML::Table::FromDatabase' => 1.10,
        'CGI::FormBuilder' => 3.10,
        'DBD::SQLite'   => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Dancer-Plugin-SimpleCRUD-*' },

    META_MERGE => {
        resources => {
            repository => 'https://github.com/bigpresh/Dancer-Plugin-SimpleCRUD',
            bugtracker => 'https://github.com/bigpresh/Dancer-Plugin-SimpleCRUD/issues',
            homepage   => 'https://github.com/bigpresh/Dancer-Plugin-SimpleCRUD/wiki/Quick-intro',
        },
    },
);
