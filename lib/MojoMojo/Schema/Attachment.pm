package MojoMojo::Schema::Attachment;

# Created by DBIx::Class::Schema::Loader v0.03003 @ 2006-06-18 12:23:29

use strict;
use warnings;

use base 'DBIx::Class';
use File::MimeInfo::Magic;

__PACKAGE__->load_components(qw/ResultSetManager DateTime::Epoch PK::Auto Core/);
__PACKAGE__->table("attachment");
__PACKAGE__->add_columns("id", 
    "uploaded" => {data_type=>'bigint',epoch=>'ctime'},
    "page", 
    "name", 
    "size", 
    "contenttype");
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to("page", "Page", { id => "page" });
__PACKAGE__->might_have("photo", "MojoMojo::Schema::Photo" ); #, {id =>'foreign.id' } );

=item create_from_file (page,filename,storage_callback)

function to create an instance from a given file. Takes a filename,
a page to attach to, and a storage callback. The storage-callback will
be called with a full path to where the file should be stored

=cut

sub create_from_file :ResultSet {
  my ($class,$page,$filename, $storage_callback)=@_;
  my $self=$class->create(
                 { name => $filename,
                 page => $page->id } );
  die "Could not attach $filename to $page"  unless $self;
  &$storage_callback($self->filename);
  unless  (-f $self->filename) {
      warn $self->filename." not found";
      $self->delete();
      return undef;
  }
  $self->contenttype( mimetype($self->filename) );
  $self->size( -s $self->filename );
  $self->update();
  $self-> make_photo if ($self->contenttype =~ m|^image/|);
  return $self;
}

=head2 filename

Full path to this attachment. Can only be called from within an
active mojomojo context.

sub filename {
    my $self=shift;
    my $c=MojoMojo->context;
    return "uploads/" . $self->id unless ref $c;
    return $c->path_to('uploads', $self->id);
}

=cut

sub make_photo {
  my $self = shift;
  my $photo=$self->result_source->related_source('photo')->resultset->new({
    id=>$self->id,
    title=>$self->name});
  $photo->extract_exif($self) if $self->contenttype eq 'image/jpeg';
  $photo->insert();
}

=item filename

returns a full path to the attachment on the filesystem. This function
uses the MojoMojo config, so requires Catalyst to function.

=cut

sub filename {
    my $self=shift;
    my $c=MojoMojo->context;
    return "uploads/" . $self->id unless $c;
    return $c->config->{home} . "/uploads/" . $self->id;
}

=item make_inline

create a resized version of a photo suitable for inline usage
FIXME: should this be moved to photo?

=cut

sub make_inline {
    my ($self)=shift;
    my $img=Imager->new();
    $img->open(file=>$self->filename,type=>'jpeg') or die $img->errstr;
    my ($image,$result);
    $image=$img->scale(xpixels=>700);
    $image->write(file=>$self->filename.'.inline',type=>'jpeg') or die $img->errstr;
}


=item make_thumb

create a thumbnail version of a photo, for gallery views and linking to pages

=cut

sub make_thumb {
    my ($self)=shift;
    my $img=Imager->new();
    $img->open(file=>$self->filename,type=>'jpeg') or die $img->errstr;
    my $h=$img->getheight;
    my $w=$img->getwidth;
    my ($image,$result);
    if ($h>$w) {
        $image=$img->scale(xpixels=>80);
            $h=$image->getheight;
        $result =$image->crop(
                            top=> int(($h-80)/2),
                            left=>0,
                          width=>80,
                            height=>80);
    } else {
        $image=$img->scale(ypixels=>80);
            $w=$image->getwidth;
        $result  =$image->crop(
                          left=> int(($w-80)/2),
                          top=>0,
                            width=>80,
                            height=>80);
    }
    $result->write(file=>$self->filename.'.thumb',type=>'jpeg') or die $img->errstr;
}

1;
