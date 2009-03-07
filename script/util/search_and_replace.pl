use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";

use MojoMojo;
use MojoMojo::Schema;
use Data::Dump::Streamer;

my $schema = schema_connect();
my $preference_rs            = $schema->resultset('Preference');
print "count: ", $preference_rs->count, "\n";
my $page_rs                  = $schema->resultset('Page');
my $root_page                = $page_rs->find( { id => 1 } );
my $howto_page               = $page_rs->find( { id => 113 } );
print $howto_page->content_version, " is the content version.\n";
my @root_lower_family        = $root_page->descendants;
my $number_of_family_members = scalar @root_lower_family;
print "Number of nodes: $number_of_family_members\n";

while ( my $page = $page_rs->next ) {
    # This is for the lastest content version of a page.
    my $page_content = $schema->resultset('Content')->search({
        page => $page->id,
        version => $page->content_version,
    });
    if ( $page_content->count == 1 ) {
        my $content = $page_content->first->body;
        print "content: $content\n";   
    }
    else {
        print "ERROR: Seems there is more than one 'latest version' of 
        the page: ", $page->name, "\n";
    }
}


sub schema_connect {
    my @db_cfg = @{MojoMojo->config()->{'Model::DBIC'}->{'connect_info'}};

    return MojoMojo::Schema->connect( @db_cfg[qw/0 1 2/] );
}




__END__

=head1 Usage



=cut
