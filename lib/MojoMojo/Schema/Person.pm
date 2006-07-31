package MojoMojo::Schema::Person;

# Created by DBIx::Class::Schema::Loader v0.03003 @ 2006-06-18 12:23:29

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/DateTime::Epoch ResultSetManager PK::Auto Core/);
__PACKAGE__->table("person");
__PACKAGE__->add_columns(
  "id",
  "active",
  "registered" => {data_type => 'bigint', epoch => 'ctime'},
  "views",
  "photo",
  "login",
  "name",
  "email",
  "pass",
  "timezone",
  "born" => {data_type => 'bigint', epoch => 1},
  "gender",
  "occupation",
  "industry",
  "interests",
  "movies",
  "music",
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many("entries", "Entry", { "foreign.author" => "self.id" });
__PACKAGE__->has_many("tags", "Tag", { "foreign.person" => "self.id" });
__PACKAGE__->has_many("comments", "Comment", { "foreign.poster" => "self.id" });
__PACKAGE__->has_many(
  "role_members",
  "RoleMember",
  { "foreign.person" => "self.id" },
);
__PACKAGE__->has_many(
  "page_versions",
  "PageVersion",
  { "foreign.creator" => "self.id" },
);
__PACKAGE__->has_many("contents", "Content", { "foreign.creator" => "self.id" });

sub get_person : ResultSet {
    my ($self,$login) = @_;
    my ($person) = $self->search({login=>$login});
}

sub is_admin {
    my $self   =shift;
    my $admins = MojoMojo->pref('admins');
    my $login = $self->login;
    return 1 if $login && $admins =~m/\b$login\b/ ;
    return 0;
}

sub link {
   my ($self) = @_;
   #FIXME: Link to profile here?
   return lc "/".($self->login || MojoMojo->pref('anonymous_user'));
}

=item can_edit <path>

Checks if a user has rights to edit a given path.

=cut

sub can_edit {
    my ( $self, $page ) = @_;
    return 0 unless $self->active;
     # allow admins, and users editing their pages
    return 1 if $self->is_admin;
    my $link=$self->link;
    return 1 if $page =~ m|^$link\b|i;
    return 0;
}

sub get_user :ResultSet {
    my ($self,$user) = @_;
    return $self->search({login=>$user})->next();
}

sub pages {
    my ($self) = @_;
    my @pages=$self->result_source->related_source('page_versions')->
	related_source('page')->resultset->search({
	    'versions.creator' => $self->id,
	},{
	    join     => [qw/versions/],
	    order_by => ['me.name'],
	    group_by => ['me.id'],
	    having   => { 'versions.version' => \'=MAX(versions.version)' },
	})->all;
    return $self->result_source->related_source('page_versions')->
	related_source('page')->resultset->set_paths(@pages);
}

=item registration_profile

returns a L<Data::FormValidator> profile for registration.

=cut

sub registration_profile :ResultSet { 
    my ($self,$schema)=@_;
    return {
         email => { constraint => 'email',
                    name       => 'Invalid format'},
         login =>[{ constraint => qr/^\w{3,10}$/,
                    name       => 'only letters, 3-10 chars'},
                  { constraint => sub { $self->user_free($schema,@_) } ,
                    name       => 'Username taken'}],
         name  => { constraint => qr/^\S+\s+\S+/,
                    name       => 'Full name please'},
      pass     => { constraint => \&pass_matches,
                     params    => [ qw( pass confirm)],
                     name      => "Password doesn't match"}
   };
}

=item pass_matches <pass1> <pass2>

Returns true if pass1 eq pass2. For
validation

=cut

sub pass_matches {
    return 1 if ($_[0] eq $_[1]);
    return 0
}

=item  valid_pass <password>

check password against database.

=cut

sub valid_pass {
    my ( $self,$pass )=@_;
    return 1 if $self->pass eq $pass;
    return 0;
}

sub user_free :ResultSet {
    my ( $class, $schema, $login) = @_;
    $login ||=$class;
    my $user= $class->result_source->resultset->get_user( $login );
    return ( $user ? 0 : 1 ) ;
}

1;