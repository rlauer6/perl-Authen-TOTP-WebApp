package Authen::TOTP::WebApp;

use strict;
use warnings;

use IO::Scalar;
use Imager::QRCode;
use URI::Encode  qw(uri_encode);
use MIME::Base64 qw(encode_base64);

use Readonly;

Readonly our $TRUE  => 1;
Readonly our $FALSE => 0;

Readonly our $OTPAUTH_URI => 'otpauth://totp/%s:%s?secret=%s&issuer=%s';

Readonly our $DEFAULT_QRCODE_SIZE    => 8;
Readonly our $DEFAULT_QRCODE_MARGIN  => 1;
Readonly our $DEFAULT_QRCODE_VERSION => 0;
Readonly our $DEFAULT_QRCODE_LEVEL   => 1;
Readonly our $IMAGE_ELEMENT => '<img src="data:image/png;base64, %s">';

use parent qw(Class::Accessor::Fast);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
  qw(
    size
    margin
    key
    issuer
    image
    username
    level
    version
    secret
  )
);

caller or __PACKAGE__->main();

########################################################################
sub new {
########################################################################
  my ( $class, @args ) = @_;

  my %options = ref $args[0] ? %{ $args[0] } : @args;

  my $self = $class->SUPER::new( \%options );

  return $self;
}

########################################################################
sub gen_qrcode {
########################################################################
  my ( $self, $filename ) = @_;

  my $username = uri_encode( $self->get_username // q{} );

  die 'no username'
    if !$username;

  my $image = q{};

  my $fh = IO::Scalar->new( \$image );

  binmode $fh;

  my $qrcode = Imager::QRCode->new(
    size          => $self->get_size   // $DEFAULT_QRCODE_SIZE,
    margin        => $self->get_margin // $DEFAULT_QRCODE_MARGIN,
    version       => $self->get_margin // $DEFAULT_QRCODE_VERSION,
    level         => $self->get_margin // $DEFAULT_QRCODE_LEVEL,
    casesensitive => $TRUE,
    lightcolor    => Imager::Color->new( 255, 255, 255 ),
    darkcolor     => Imager::Color->new( 0,   0,   0 ),
  );

  my $key = $self->get_secret // $self->gen_secret;

  my $issuer = $self->get_issuer // 'USGN';

  my $qrcode_str = sprintf $OTPAUTH_URI, $issuer, $username, $key, $issuer;

  my $img = $qrcode->plot($qrcode_str);

  $img->write( fh => $fh, type => 'png' )
    or die 'Failed to write: ' . $img->errstr;

  close $fh;

  if ($filename) {
    open my $fh, '>', $filename
      or die 'could not open ' . $filename . ' for writing.';

    binmode $fh;

    print {$fh} $image;

    close $fh;
  }

  $self->set_image($image);

  return $self;
}

########################################################################
sub gen_secret {
########################################################################
  my ($self) = @_;

  my @chars = ( 'A' .. 'Z', '2' .. '7' );

  my $length = scalar @chars;

  my $secret = q{};

  for ( 0 .. 15 ) {
    $secret .= $chars[ rand $length ];
  }

  $self->set_secret($secret);

  return $secret;
}

########################################################################
sub show_qrcode {
########################################################################
  my ($self) = @_;

  my $image = $self->get_image;

  die 'no image'
    if !$image;

  print "Content-Type: image/png\n";

  print sprintf "Content-Length: %d\n\n", length $image;

  print $self->get_image;

  return;
}

########################################################################
sub get_img_base64 {
########################################################################
  my ($self) = @_;

  my $image = $self->get_image;

  die 'no image'
    if !$image;

  return sprintf $IMAGE_ELEMENT, encode_base64($image);
}

########################################################################
sub main {
########################################################################
  my $qrcode = USGN::TOTP::QRCode->new( username => 'rlauer@usgn.net' );

  $qrcode->gen_qrcode('qrcode.png');

  printf "secret: %s\n",    $qrcode->get_secret;
  printf "image tag: %s\n", $qrcode->get_img_base64;

  exit;
}

1;
