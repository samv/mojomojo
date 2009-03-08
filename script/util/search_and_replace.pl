use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";

use MojoMojo;
use MojoMojo::Schema;
use Data::Dump::Streamer;

my $schema  = schema_connect();
my $page_rs = $schema->resultset('Page');

my $search_string      = 'Catalyst';
my $replacement_string = 'Dogalyst';

while ( my $page = $page_rs->next ) {

    # This is for the lastest content version of a page.
    my $page_content = $schema->resultset('Content')->search(
        {
            page    => $page->id,
            version => $page->content_version,
        }
    );
    if ( $page_content->count == 1 ) {
        my $content = $page_content->first->body;

        # Search on something
        if ( $content =~ m{$search_string} ) {
            my $number_of_replaments =
              $content =~ s{$search_string}{$replacement_string}mxg;
            print "Made $number_of_replaments replacments in page: ",
              $page->name_orig, " .\n";

            #print "content: $content\n";
            # Give the adulterated content back to db.
            $page_content->first->update( { body => $content } );

            # Reverse the replacment for sanity check.
            $content =~ s{$replacement_string}{$search_string}mxg;
            print "Made $number_of_replaments replacments in page: ",
              $page->name_orig, " .\n";
            $page_content->first->update( { body => $content } );
        }
    }
    elsif ( $page_content->count > 1 ) {
        print
          "ERROR: Seems there is more than one 'latest content version' of 
        the page: ", $page->name, "\n";
    }
    else {

        # This case happens when a page is only in prototype form.  In other
        # words, it is a node with children that has never received content
        # of it's own.
        print "NOTICE: Page ", $page->name,
          " is only a prototype and therefore has no content.\n";
    }
}

sub schema_connect {
    my @db_cfg = @{ MojoMojo->config()->{'Model::DBIC'}->{'connect_info'} };

    return MojoMojo::Schema->connect( @db_cfg[qw/0 1 2/] );
}

__END__

=head1 Usage



=cut
