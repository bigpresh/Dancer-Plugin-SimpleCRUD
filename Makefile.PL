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
        'Dancer'     => 1.2,
        'Dancer::Plugin::Database' => 0.08,
        'HTML::Table::FromDatabase' => 0.07,
        'CGI::FormBuilder' => 0,
        'SQL::Abstract' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Dancer-Plugin-SimpleCRUD-*' },
);
