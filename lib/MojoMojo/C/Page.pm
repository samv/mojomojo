package MojoMojo::C::Page;

use strict;
use base 'Catalyst::Base';
use IO::Scalar;
use URI;
use Time::Piece;
use Text::Context;
use HTML::Strip;
use Data::Page;
my $m_base          = 'MojoMojo::M::Core::';
my $m_page_class    = $m_base . 'Page';
my $m_content_class = $m_base . 'Content';
my $m_verison_class = $m_base . 'PageVersion';

#For uploads
$CGI::Simple::POST_MAX = 1048576000;

=head1 NAME

MojoMojo::C::Page - Page controller

=head1 SYNOPSIS

=head1 DESCRIPTION

This controller is the main juice of MojoMojo. it handles all the
actions related to wiki pages. actions are redispatched to this
controller based on a Regex controller in the main MojoMojo class.

Every private action here expects to have a page path in args. They
can be called with urls like "/page1/page2.action".

=head1 ACTIONS

=over 4

=item  view

This is probably the most common action in MojoMojo. A lot of the 
other actions redispatches to this one. It will prepare the stash 
for page view, and set the template to view.tt, unless another is
already set.

It also takes an optional 'rev' parameter, in which case it will
load the provided revision instead.

=cut

sub view : Global {
    my ( $self, $c, $path ) = @_;

    my $stash = $c->stash;
    $stash->{template} ||= 'page/view.tt';

    my ( $path_pages, $proto_pages, $id ) = @$stash{qw/ path_pages proto_pages id /};

    # we should always have at least "/" in path pages. if we don't,
    # we must not have had these structures in the stash

    return $c->forward('edit') if $proto_pages && @$proto_pages;

    my $page= $stash->{page};

    my $content;

    my $rev = $c->req->params->{rev};
    if ( $rev && defined $page->content_version ) {
        $content = MojoMojo::M::Core::Content->retrieve(
            page    => $page->id,
            version => $rev
        );
        $stash->{rev} = ( defined $content ? $content->version : undef );
        unless( $stash->{rev} ) {
              $stash->{message} = 'No such revision for '.$page->name;
              $stash->{template} = 'message.tt';
        }
    }
    else {
        $content = $page->content;
    }
    $stash->{content} = $content;

}

=item edit

This action will display the edit form, then save the previous
revision, and create a new based on the posted content.
after saving, it will forward to the highlight action.

=cut

sub edit : Global {
    my ( $self, $c, $path ) = @_;

    # Set up the basics. Log in if there's a user.
    my $stash = $c->stash;
    $stash->{template} = 'page/edit.tt';
    $c->req->params->{login}=$c->req->params->{creator};
    $c->forward('/user/login') if $c->req->params->{pass} && 
                                 ! $c->req->{user_id};

    my $user = $c->req->{user_id} || 0;
    $c->log->info("user is $user");

    my ( $path_pages, $proto_pages ) = @$stash{qw/ path_pages proto_pages /};

    # we should always have at least "/" in path pages. if we don't,
    # we must not have had these structures in the stash
    unless ($path_pages) {
        ( $path_pages, $proto_pages ) = $m_page_class->path_pages($path);
    }

    # the page we're editing is at the end of either path_pages or 
    # proto_pages, # depending on whether or not the page already exists
    my $page =
      (   @$proto_pages > 0
        ? $proto_pages->[ @$proto_pages - 1 ]
        : $path_pages->[ @$path_pages - 1 ] );

    # this should never happen!
    die "Cannot determine what page to edit for path: $path" unless $page;
    @$stash{qw/ path_pages proto_pages /} = ( $path_pages, $proto_pages );

    $c->form(
        # may need to add more required fields...
        required => [qw/body/],
        defaults => { creator => $user, }
    );

    # if we have missing or invalid fields, display the edit form.
    # this will always happen on the initial request
    if ( $c->form->has_missing || $c->form->has_invalid ) {
        $stash->{page}    = $page;
        # Note that this isn't a real Content object, just a proto object!!!
        # It's just a hash, not blessed into the Content package.
        $stash->{content} = MojoMojo::M::Core::Content->create_proto($page);
        $stash->{content}->{creator} = $user;
        return;
    }

    if ($user == 0 && ! $c->pref('anonymous_user')) {
      $c->stash->{message} ||= 'Anonymous Edit disabled';
      return;
    }
    # else, update the page and redirect to highlight, which will forward to view:
    my $valid   = $c->form->valid;
    my $unknown = $c->form->unknown;

    if (@$proto_pages)    # page doesn't exist yet
    {
        $path_pages = $m_page_class->create_path_pages(
            path_pages  => $path_pages,
            proto_pages => $proto_pages,
            creator     => $user,
        );
        $page = $path_pages->[ @$path_pages - 1 ];
    }
    $page->update_content( %$valid, %$unknown );

    # update the search index with the new content
    my $p = MojoMojo::Search::Plucene->open( $c->config->{home} . "/plucene" );
    $p->update_index( $page );

    $c->res->redirect( $c->req->base . $page->path . '.highlight' );

} # end sub edit

=item search

This action is called as .search on the current page when the user 
performs a search.  The user can choose whether or not to search
the entire site or a subtree starting from the current page.

=cut

sub search : Global {
    my ( $self, $c, $path ) = @_;

    # number of search results to show per page
    my $results_per_page = 10;

    my $stash = $c->stash;
    $stash->{template} = 'page/search.tt';

    my ( $path_pages, $proto_pages ) = @$stash{qw/ path_pages proto_pages /};

    # we should always have at least "/" in path pages. if we don't,
    # we must not have had these structures in the stash
    unless ($path_pages) {
        ( $path_pages, $proto_pages ) = $m_page_class->path_pages($path);
        @$stash{qw/ path_pages proto_pages /} = ( $path_pages, $proto_pages );
    }

    my $page = $path_pages->[ @$path_pages - 1 ];
    $stash->{page} = $page;

    my $q = $c->req->params->{query};
    my $search_type = $c->req->params->{search_type} || "subtree";
    $stash->{query} = $q;
    $stash->{search_type} = $search_type;

    my $p = MojoMojo::Search::Plucene->open( MojoMojo->config->{home} . "/plucene" );

    my $strip = HTML::Strip->new;

    # FIXME: Cache search results.  This will require creating a new data structure since it's
    #      not safe to cache $page objects.
    my $results = [];

    # for subtree searches, add the path info to the query, replacing slashes with X
    my $real_query = $q;    # this is for context matching later
    if ( $search_type eq "subtree" ) {
        my $fixed_path = $page->path;
        $fixed_path =~ s/\//X/g;
        $q = "_path:$fixed_path* AND " . $q;
    }

    foreach my $key ( $p->search( $q ) ) {
        # skip results outside of this subtree
        # FIXME: Remove this code if the new _path query seems to work OK
#        if ($search_type eq "subtree") {
#            my $path = $page->path;
#            if ( $key !~ /^$path/ ) {
#                next;
#            }
#        }

        my $page = $m_page_class->get_page( $key );
        # add a snippet of text containing the search query
        my $content = $strip->parse( $page->content->formatted );
        $strip->eof;

        # FIXME: Bug? Some snippet text doesn't get displayed properly by Text::Context
        my $snippet = Text::Context->new( $content, split(/ /, $real_query) );

        my $result = {
            snippet => $snippet->as_html,
            page => $page,
        };
        push @$results, $result;
    }

    my $result_count = scalar @$results;
    if ( $result_count ) {
        # Paginate the results
        # This is done even with even 1 page of results so the template doesn't need to do
        # two separate things
        my $pager = Data::Page->new;
        $pager->total_entries( $result_count );
        $pager->entries_per_page( $results_per_page );
        $pager->current_page( $c->req->params->{p} || 1 );

        if ( $result_count > $results_per_page ) {
            # trim down the results to just this page
            @$results = $pager->splice( $results );
        }

        $c->stash->{pager} = $pager;
        my $last_page = ( $pager->last_page > 10 ) ? 10 : $pager->last_page;
        $c->stash->{pages_to_link} = [ 1 .. $last_page ];
        $c->stash->{results} = $results;
        $c->stash->{result_count} = $result_count;
    }
}

=item print

this action is the same as the view action, with another template

=cut

sub print : Global {
    my ( $self, $c, $page ) = @_;
    $c->stash->{template} = 'page/print.tt';
    $c->forward('view');
}


sub tags : Global {
    my ( $self, $c, $page, $highlight ) = @_;
    $c->stash->{template}  = 'page/tags.tt';
    $c->stash->{highlight} = $highlight;
    unless ( ref $c->stash->{page} ) {
        $c->stash->{page}=MojoMojo::M::Core::Page->retrieve($page);
    } 
    $page = $c->stash->{page};
    die '"'.$page .'" not found' unless ref $page;
    if ($c->req->{user}) {
    my @tags = $page->others_tags( $c->req->{user_id} );
    $c->stash->{others_tags} = [@tags];
    @tags                    = $page->user_tags( $c->req->{user_id} );
    $c->stash->{taglist}     = ' ' . join( ' ', map { $_->tag } @tags ) . ' ';
    $c->stash->{tags}        = [@tags];
    } else {
      $c->stash->{others_tags}      = [ $page->tags ];
    }
}

sub list : Global {
    my ( $self, $c, $page, $tag ) = @_;
    $page=$c->stash->{page};
    return $c->forward('/tag/list') if $tag;
    $c->stash->{template} = 'page/list.tt';
    $c->stash->{pages}    =  [ $page->descendants ];

    # FIXME - real data here please
    $c->stash->{orphans} = [];
    $c->stash->{wanted}  = [];
    $c->stash->{tags}    = [ MojoMojo::M::Core::Tag->search_most_used() ];
}

sub recent : Global {
    my ( $self, $c, $page, $tag ) = @_;
    $page=$c->stash->{page};
    return $c->forward('/tag/recent') if $tag;
    $c->stash->{template} = 'page/recent.tt';
    $c->stash->{tags}     = [ MojoMojo::M::Core::Tag->search_most_used ];
    $c->stash->{pages}    = [ $page->descendants_by_date ];

    # FIXME - needs to be populated even without tags
}

sub feeds  : Global {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'feeds.tt';
}

sub rss : Global {
    my ( $self, $c ) = @_;
    $c->forward('recent');
    $c->stash->{template} = 'page/rss.tt';
}

sub atom : Global {
    my ( $self, $c ) = @_;
    $c->forward('recent');
    $c->stash->{template} = 'page/atom.tt';
}

sub rss_full : Global {
    my ( $self, $c ) = @_;
    $c->forward('recent');
    $c->stash->{template} = 'page/rss_full.tt';
}

sub highlight : Global {
    my ( $self, $c ) = @_;
    $c->stash->{render} =  'highlight';
    $c->forward('view');
}

sub export : Global {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'export.tt';
}

sub rollback : Global {
    my ( $self, $c, $page ) = @_;
    $c->forward('view');
    if ($c->stash->{rev}) {
      $c->stash->{page}->content_version($c->stash->{rev});
      $c->stash->{page}->update;
      undef $c->stash->{rev};
    }
}



=head1 AUTHOR

Marcus Ramberg <mramberg@cpan.org>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
