package Authen::TOTP::WebApp;

use strict;
use warnings;

use lib q{.};

use Authen::OATH;
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

Readonly our $DEFAULT_SECRETS_MANAGER => 'FileCache';

use parent qw(Authen::TOTP::QRCode);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
  qw(
    access_code
    appname
    config
    config_path
    include_path
    secret
    secrets_manager
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
  $options{appname}      //= 'authen-totp-webapp';
  $options{include_path} //= cwd;

  my $self = $class->SUPER::new( \%options );

  $self->_fetch_config();

  $self->set_issuer( $self->get_config->{app}->{issuer} );

  my $secrets_manager = $self->get_config->{app}->{secrets_manager}
    || $DEFAULT_SECRETS_MANAGER;

  # short hand
  if ( $secrets_manager !~ /^Authen/xsm ) {
    $secrets_manager = 'Authen::TOTP::SecretsManager::' . $secrets_manager;
  }

  my $class_path = $secrets_manager;

  if ( $class_path =~ /::/xsm ) {
    $class_path =~ s/::/\//gxsm;
    $class_path = "$class_path.pm";
  }
  elsif ( $class_path =~ /[.]pm$/xsm ) {
    die 'classes should be specified using the package name';
  }

  require $class_path;

  $self->set_secrets_manager( $secrets_manager->new($self) );

  if ( $self->get_username && $self->get_access_code ) {
    $self->set_verified( $self->verify_totp() );
  }

  return $self;
}

########################################################################
sub find_secret {
########################################################################
  my ( $self, $username ) = @_;

  return $self->get_secrets_manager->find_secret($username);
}

########################################################################
sub save_secret {
########################################################################
  my ( $self, $key, $secret ) = @_;

  return $self->get_secrets_manager->save_secret( $key, $secret );
}

########################################################################
sub verify_totp {
########################################################################
  my ( $self, $username, $access_code ) = @_;

  $access_code //= $self->get_access_code;

  $username //= $self->get_username;

  die 'no access code'
    if !$access_code;

  die 'no username'
    if !$username;

  my $secret = $self->find_secret($username);

  die 'could not find secret for ' . $username
    if !$secret;

  my $oath = Authen::OATH->new( digest => 'Digest::SHA' );

  return $access_code eq $oath->totp( decode_base32($secret) );
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
sub render_qrcode_form {
#######################################################################
  my ( $self, %options ) = @_;

  my $template_file = $self->get_config->{app}->{template};

  my $template = $self->_fetch_template($template_file);

  my %parameters = ( %options, %{ $self->get_config } );

  return $self->_render_template( $template, \%parameters );
}

########################################################################
sub _fetch_config {
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
sub _render_template {
########################################################################
  my ( $self, $template, $parameters ) = @_;

  my $tt = Template->new(
    { INTERPOLATE  => $TRUE,
      ABSOLUTE     => $TRUE,
      INCLUDE_PATH => $self->get_include_path,
    }
  );

  my $output = $EMPTY;

  if ( !$tt->process( \$template, $parameters, \$output ) ) {
    die $tt->error;
  }

  return $output;
}

########################################################################
sub _fetch_template {
########################################################################
  my ( $self, $fh ) = @_;

  my $is_data;

  if ( !$fh ) {
    $fh      = *DATA;
    $is_data = $TRUE;
    seek $fh, $START_OF_DATA, 0;
  }
  elsif ( !defined openhandle $fh) {
    open $fh, '<', $fh
      or die 'coud not open ' . $fh . ' for reading';
  }

  local $RS = undef;

  my $template = <$fh>;

  if ($is_data) {
    $template =~ s/__END__.*\z//xsm;
  }
  else {
    close $fh;
  }

  return $template;
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
    <title>[% app.title %]</title>
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

      <form id="[% app.form.qrcode.id %]">

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

Authen::TOTP::WebApp - Methods to support two-factor authentication

=head1 SYNOPSIS

  my $cgi = CGI::Minimal->new;

  my $username    = $cgi->param('username');
  my $access_code = $cgi->param('access_code');

  my $app = Authen::TOTP::WebApp->new(
    config_path  => '/var/www/config',
    include_path => '/var/www/include',
    appname      => 'totp',
    username     => $username,
    access_code  => $access_code,
  );

  my $action = 'render';

  my %dispatch_table = (
    render => \&render_form,
    create => \&create_qrcode_secret,
    verify => \&verify_access_code,
  );

  if ( $username && !$access_code ) {
    $action = 'create';
  }
  elsif ( $access_code && $username ) {
    $action = 'verify';
  }

  return $dispatch_table{$action}->( $app, $cgi );

=head1 DESCRIPTION

C<Authen::TOTP::WebApp> provides the scaffolding for supporting
two-factor authentication for your web applications. This class will:

=over 5

=item * create a secret that can be used with L<Authen::OATH> to
return a time-based one-time password (TOTP)

=item * create a QR code PNG image of the secret that can be scanned
using mobil apps

=item * store and retrieve keys

=item * return an HTML form for creating a secret

=back

The module can be used as part of a web application or
stand-alone. This implementation creates a form from a
Template::Toolkit template embedded in the C<DATA> section of the
CGI. The form is implemented using Bootstrap in order support both
desktop and mobile usage. You can provide your own from that will be
delivered by the CGI (See L</render_qrcode_form>).

The module creates a secret associated with a username.  The secret is
then stored so that it can be used later when comparing the password
entered by the user with a password generated using that key by
calling C<Authen::OATH>.

You specify a secrets manager class that should implement a
constructor which will be passed an instance of this class and two
other methods described below (L</find_secret>, L</save_secret>). The
default implementation provided with this project
(L<Authen::TOTP::SecretsManager::FileCache) is used if no secrets
manager class is provided in the configuration.

The project also includes an example secrets manager using AWS Secrets
Manager (L<Authen::TOTP::SecretsManager::AWSSecretsManager>).  .

=head1 CONFIGURATION FILE

The configuration file included with the project has some values that
are specific to the Bootstrap implementation of the key creation and
verification forms. You can however, put anything you want in the
configuration file. The CGI will look for F<totp.json> in the path
pointed to by the environment variable C<CONFIG_PATH>.

The only section required by the application is the C<app> section and
the only value I<really (sort of)> required is C<issuer>. If that is
not found, then the issuer will be set "UNKNOWN".

If you are building your own forms or implementing your own secrets
manager, create your own version of F<totp.json> to suit your needs.

 {
   "app" : {
     "issuer" : "BIGFOOT",
     "title": "2FA Proof of Concept",
     "javascript": {
       "src" : "/javascript/totp.js"
     },
     "stylesheet" : {
       "src" : ""
     },
     "form" : {
       "qrcode" : {
         "id" : "qrcode-form"
       }
     },
     "instructions" : "instructions.txt",
     "secrets_manager" : ""
   },
   "jquery" : {
     "javascript" : {
       "src" : "https://code.jquery.com/jquery-3.6.3.min.js",
       "integrity" : "sha256-pvPw+upLPUjgMXY0G+8O0xUf+/Im1MZjXxxgOcBQBXU=",
       "crossorigin" : "anonymous"
     }
   },
   "bootstrap" : {
     "stylesheet" : {
       "src" : "https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css"},
     "javascript" : {
       "src" : "https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"
     }
   }
 }

=head1 METHODS AND SUBROUTINES

=head2 new

Instantiates a new C<Authen::TOTP::WebApp> instance.

 new(options)

=over 5

=item  config_path

The path to the F<totp.json> configuration file.

default: $ENV{CONFIG_PATH}, cwd

=item  include_path

Path where C<Template> can find files that are included using the C<[%
INCLUDE %]> tag.

=item  appname

Application name.  Used by the reference implementation to define a namespace for the file cache. You can use this for anything.

default: authen-totp-webapp

=item  username

An identifer to be paired with the secret...typically a username. This
can be passed into the constructor or set using the setter
(C<set_username>).

=item  access_code

The access code to verify. This can be passed in the constructor or
set using the setter (C<set_access_code>).

=back

=head2 find_secret

 find_secret([username])

If C<username> is not passed, the method will try C<get_username>.

See L</OVERRIDABLE METHODS>

=head2 gen_secret

Returns a 32 character string composed of the letters A-Z, 2-7.

See L</OVERRIDABLE METHODS>

=head2 init_secret_repo

See L</OVERRIDABLE METHODS>

=head2 render_qrcode_form

Returns an HTML form that implements a simple web application that can
be used to generate a secret key and QR code.

The reference implementation uses a form that is embedded in the CGI,
however you can provide your own form template as well.

You can leverage the scaffolding here by providind your own form. Add a
C<template> value in the C<app> section that points to a
L<Template::Toolkit> template that will be passed the configuration
object when the template is rendered.

=head2 save_secret

See L</OVERRIDABLE METHODS>

=head2 verify_totp

 verify_totp([username, access_code])

Compares the access code provide against a TOTP value generated using
that user's secret.  Return a true value if the user's secret is found
and the access code matches.

The access code to match is calculated using L<Authen::OATH>.

  return $access_code eq $oath->totp( decode_base32($secret) );

=head1 OVERRIDABLE METHODS

The reference implementation that runs in the Docker container uses
C<Cache::FileCache> to store secrets locally by implementing a secrets
manager class named C<Authen::TOTP::SecretsManager::FileCache>. In a
production environment, you'll probably want to use your own secrets
repository.

You can provide your own implementation of a secrets manager or you
can sub-class this class and override C<find_secret> and
C<save_secret>.

=over 5

=item Implement Your own Secrets Manager

Using this method provide three methods, a constructor (C<new>) and
the two methods for finding and saving secrets.

The constructor will be passed an instance of this class which
contains a getter method for retrieving the configuration object. You
can add a section for your secrets manager. Then specify the name of
the class in the C<secrets_manager> config variable.

 package Authen::TOTP::SecretsManager:File;

 sub new {
   my ($class, $authen_totp_webapp) = @_;

   my $self = { filename => $authen_totp_webapp->get_config->{filename} };

   return bless $self, $class;
 }
    
 sub find_secret {
   ...
 }

 sub save_secret {
   ...
 }

 1;

=item Sub-Classing C<Authen::TOTP::WebApp>

Instead of implementing a separate secrets manager class you can
sub-class C<Authen::TOTP::WebApp> and provide the two required methods
(C<find_secret>, C<save_secret>).

 package Authen::TOTP::MyWebApp;

 use parent qw(Authen::TOTP::MyWebApp);

 sub find_secret {
   my ($self, $secret_id) = @_;
   ...
   return $secret_value;
 }

 sub save_secret {
   my ($self, $secret_id, $secret_string) = @_;
   ...
   return $self; # return value is not used by callers
 }

 1;

If you need to initialize anything or store additional data, you'll
need to do that when your methods are called. They may be called in
any order.

 my $my_config;

 sub find_secret {
   if (!$my_config) {
     $my_config = init_my_webapp();
   }
 }

 sub save_secret {
   if (!$my_config) {
     $my_config = init_my_webapp();
   }
 }

 sub init_my_webapp {
   ...
 }

=back

=over 5

=item C<save_secret>

This method will be called if you are using F<qrcode.cgi> as an API
and generating a secret. It is passed the C<username> and the C<secret>.

=item C<find_secret>

This method will be called when you call C<verify_totp> to verify an
access code. You should return the secret or undef if the username is found

=item C<gen_secret>

The reference implementation uses a simple algorithm to create a 32
character secret key composed of the letters A-Z and the numbers 2-7. You can
replace this method to return your own version of a secret. You may
want to check your secret before issuing to make sure it is unique.

=back

=head1 METHODS INHERITED FROM L<Authen::TOTP::QRCode>

=head2 as_mime

Returns a base64 mime encoded version of the image.

=head2 as_string

Returns the image as a string (scalar).

=head2 as_tag

Returns an HTML image tag with the embedded base64 version of the QR
code.

=head2 gen_qrcode

 gen_qrcode([filename])

Generates the QR code image and optionally saves to a file. You can
retrieve the image in one of several ways.

 $app->gen_qrcode();

 my $image = $app->as_string(); # same as $app->get_image();

 my $b64_image = $app->as_mime;

 my $img_tag = $app->as_tag;

=head1 SEE ALSO

L<Authen::OATH>, L<Imager::QRCode>, L<Authen::TOTP::QRCode>

=head1 AUTHOR

Rob Lauer - <rclauer@gmail.com>

=cut
