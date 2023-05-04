package Authen::TOTP::WebApp;

use strict;
use warnings;

use lib '.';

use Authen::OATH;
use Cache::FileCache;
use Cwd;
use Convert::Base32 qw(decode_base32);
use Data::Dumper;
use English qw(-no_match_vars);
use JSON    qw(decode_json);
use Template;

use Readonly;

Readonly our $TRUE  => 1;
Readonly our $FALSE => 0;
Readonly our $EMPTY => qw{};

use parent qw(Authen::TOTP::QRCode);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
  qw(
    access_code
    appname
    cache
    config
    config_path
    include_path
    secret
    username
    verified
  )

);

our $START_OF_DATA = tell *DATA;

caller or __PACKAGE__->main();

########################################################################
sub new {
########################################################################
  my ( $class, @args ) = @_;

  my %options = ref $args[0] ? %{ $args[0] } : @args;

  $options{config_path}  //= $ENV{CONFIG_PATH} // cwd;
  $options{appname}      //= 'webapp';
  $options{include_path} //= cwd;

  my $self = $class->SUPER::new( \%options );

  $self->fetch_config();

  my $cache = Cache::FileCache->new( { namespace => $self->get_appname } );

  print {*STDERR} Dumper( [ time => scalar time, cache => $cache ] );

  $self->set_cache($cache);

  if ( $self->get_username && $self->get_access_code ) {
    $self->set_verified( $self->verify_totp() );
  }

  return $self;
}

########################################################################
sub fetch_config {
########################################################################
  my ($self) = @_;

  my $config_file = sprintf '%s/%s.json', $self->get_config_path,
    $self->get_appname;

  open my $fh, '<', $config_file
    or die 'could not open ' . $config_file . ' for reading.';

  local $RS = undef;

  $self->set_config( decode_json(<$fh>) );

  close $fh;

  return $self;
}

########################################################################
sub find_secret {
########################################################################
  my ( $self, $username ) = @_;

  $username //= $self->get_username;

  my $cache = $self->get_cache;

  return $cache->get($username);
}

########################################################################
sub save_secret {
########################################################################
  my ( $self, $key, $secret ) = @_;

  return $self->get_cache->set( $key, $secret );
}

########################################################################
sub verify_totp {
########################################################################
  my ($self) = @_;

  die 'no access code'
    if !$self->get_access_code;

  die 'no username'
    if !$self->get_username;

  my $secret = $self->find_secret( $self->get_username );

  die 'could not find secret for ' . $self->get_username
    if !$secret;

  my $oath = Authen::OATH->new( digest => 'Digest::SHA' );

  return $self->get_access_code eq $oath->totp( decode_base32($secret) );
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
sub render_template {
########################################################################
  my ( $self, $template, $parameters ) = @_;

  my $tt = Template->new(
    { INTERPOLATE  => $TRUE,
      ABSOLUTE     => $TRUE,
      INCLUDE_PATH => $self->get_include_path,
    }
  );

  my $output = $EMPTY;

  print {*STDERR} Dumper(
    [ template   => $template,
      parameters => $parameters
    ]
  );

  if ( !$tt->process( \$template, $parameters, \$output ) ) {
    die $tt->error;
  }

  return $output;
}

########################################################################
sub fetch_template {
########################################################################
  my ( $self, $fh ) = @_;

  $fh //= *DATA;

  seek $fh, $START_OF_DATA, 0;

  local $RS = undef;

  my $template = <$fh>;

  $template =~ s/__END__.*\z//xsm;

  return $template;
}

########################################################################
sub render_qrcode_form {
#######################################################################
  my ( $self, %options ) = @_;

  my $template = $self->fetch_template;

  my %parameters = ( %options, %{ $self->get_config } );

  print {*STDERR} Dumper( [ parameters => \%parameters ] );

  return $self->render_template( $template, \%parameters );
}

########################################################################
sub main {
########################################################################
  my $app = Authen::TOTP::WebApp->new;

  print $app->render_qrcode_form;

  exit;
}

1;

__DATA__
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>[% title %]</title>
    <link rel="stylesheet" href="[% bootstrap.stylesheet.src %]" type="text/css" />
    [% IF app.stylesheet.src %]
    <link rel="stylesheet" href="[% app.stylesheet.src %]" type="text/css" />
    [% END %]
    
    <script type="text/javascript" src="[% jquery.javascript.src %]"
        integrity="[% jquery.javascript.integrity %]"
        crossorigin="[% jquery.javascript.crossorigin %]"></script>
    [% IF app.javascript %]
    <script type="text/javascript" src="[% app.javascript.src %]"></script>
    [% END %]
  </head>

  <body style="height:100%">
    <div id="alert-placeholder"></div>

    <div class="container d-flex vh-100 justify-content-center align-items-center">

      <form id="[% app.form.qrcode.id %]" action="[% app.form.qrcode.url %]">

        <div class="row mb-3" id="qrcode-container" style="display:none;">
          <div id="qrcode" class="col-12" style="text-align:center">
          </div>
        </div>

        <div class="row mb-3" id="secret-container" style="display:none;">
          <div class="col-12">
            <div class="input-group mb-3">
              <span class="input-group-text">Secret</span>
              <input class="form-control text-center" type="text" id="secret" name="secret" placeholder="secret" disabled>
            </div>
          </div>
        </div>
         
        <div class="row mt-3" id="username-container">
          <div class="col-12 mb-3">
            <input class="form-control" type="text" id="username" name="username" placeholder="Username">
          </div>
        </div>
  
        <div class="row mt-3" id="access-code-container" [% IF NOT login_page %]style="display: none;"[% END %]>
          <div class="col-12 mb-3 justify-contents-center">
            <input class="form-control" type="text" id="access_code" name="access_code" placeholder="Access Code">
          </div>
        </div>

        <div class="row" id="instructions-container" style="display:none;">
          <div class="col-12 mt-3 mb-3 text-center">
           <p id="instructions">[% INCLUDE "instructions.txt" %]</p>
          </div>
        </div>

        <div class="row" id="submit-btn-container" [% IF login_page %]style="display:none;"[% END %]>
          <div class="col-12 mt-3 mb-3 text-center">
            <div class="d-grid gap-2">
              <button class="btn btn-primary btn-lg" id="submit-btn" [% IF login_page %]disabled[% END %]>Submit</button>
            </div>
          </div>
        </div>

        <div class="row" id="tryit-btn-container" style="display:none;">
          <div class="col-12 mt-3 mb-3 text-center">
            <div class="d-grid gap-2">
              <button class="btn btn-primary btn-lg" id="tryit-btn" disabled>Try It!</button>
            </div>
          </div>
        </div>

        <div class="row" id="login-btn-container" [% IF NOT login_page %]style="display:none;"[% END %]>
          <div class="col-12 mt-3 mb-3 text-center">
            <div class="d-grid gap-2">
              <button  type="submit" class="btn btn-primary btn-lg" id="login-btn" [% IF NOT login_page %]disabled[% END %]>Login</button>
            </div>
          </div>
        </div>
        
      </form>

    </div>
  </body>

  <!-- login_page = [% login_page %] -->
  
<script type="text/javascript" src="[% bootstrap.javascript.src %]"></script>
</html>

__END__

=pod

=head1 NAME

Authen::TOTP::WebApp - 

=head1 SYNOPSIS

 my $totp = Authen::TOTP::WebApp->new;

=head1 DESCRIPTION

=head1 METHODS AND SUBROUTINES

=head1 SEE ALSO

L<Authen::OATH>, L<Imager::QRCode>, L<Authen::TOTP::QRCode>

=head1 AUTHOR

Rob Lauer - <rclauer@gmail.com>

=cut
