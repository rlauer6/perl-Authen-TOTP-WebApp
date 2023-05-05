#!/usr/bin/env perl

use strict;
use warnings;

use Authen::TOTP::WebApp;
use JSON;
use CGI::Minimal;

use Readonly;

Readonly our $EMPTY   => q{};
Readonly our $SUCCESS => 0;  # shell success

########################################################################
sub main {
########################################################################
  my $cgi = CGI::Minimal->new;

  my $secret      = $cgi->param('secret');
  my $username    = $cgi->param('username');
  my $access_code = $cgi->param('access_code');

  my $app = Authen::TOTP::WebApp->new(
    config_path  => '/var/www/config',
    include_path => '/var/www/include',
    appname      => 'totp',
    secret       => $secret,
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
  elsif ( $access_code && ( $username || $secret ) ) {
    $action = 'verify';
  }

  return $dispatch_table{$action}->( $app, $cgi );
}

########################################################################
sub verify_access_code {
########################################################################
  my ($app) = @_;

  print "Content-type: application/json\n\n";

  print JSON->new->pretty->encode( { matched => $app->get_verified } );

  return $SUCCESS;
}

########################################################################
sub create_qrcode_secret {
########################################################################
  my ($app) = @_;

  $app->gen_qrcode();

  my $payload = {
    secret   => $app->get_secret,
    username => $app->get_username // $EMPTY,
    qrcode   => $app->as_tag,
  };

  if ( $app->get_username ) {
    $app->save_secret( $app->get_username, $app->get_secret );
  }

  print "Content-type: application/json\n\n";
  print JSON->new->pretty->encode($payload);

  return $SUCCESS;
}

########################################################################
sub render_form {
########################################################################
  my ( $app, $cgi ) = @_;

  print "Content-Type: text/html\n\n";

  print $app->render_qrcode_form( login_page => $cgi->param('login') );

  return $SUCCESS;
}

exit main();

1;
