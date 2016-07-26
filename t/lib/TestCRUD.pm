package TestCRUD;
use Dancer ':syntax';

our $VERSION = '0.01';

use Dancer::Plugin::SimpleCRUD;

simple_crud(
	prefix => "/test_table",
	db_table => "test_table",
);

