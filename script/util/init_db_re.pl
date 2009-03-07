use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";

use MojoMojo::Schema;
use base 'Exporter';
our @EXPORT =
  qw( $schema $preference_rs $page_rs @root_lower_family $root_page
  $number_of_family_members $howtos_node);

# Make the dbi connection info MATCH YOUR ENVIRONMENT.
# This could set connection using the local .conf
our $schema =
  MojoMojo::Schema->connect( 'dbi:mysql:database=mojomojo;host=localhost',
    'mojomojo', 'pass' );

our $preference_rs            = $schema->resultset('Preference');
our $page_rs                  = $schema->resultset('Page');
our $root_page                = $page_rs->find( { id => 1 } );
our @root_lower_family        = $root_page->descendants;
our $number_of_family_members = scalar @root_lower_family;

# Get the howtos page for Catalyst wiki, id=113.
# For Testing only.
our $howtos_node = $page_rs->find( { id => 113 } );

__PACKAGE__->export_to_level(1);

__END__

=head1 Usage

This code can be run within re.pl as:
 
     do '$name_of_this_script' 
     
This will load the schema set the exported variables.

=cut
