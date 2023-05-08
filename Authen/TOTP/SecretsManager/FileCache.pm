package Authen::TOTP::SecretsManager::FileCache;

use strict;
use warnings;

use Cache::FileCache;

use parent qw(Exporter Class::Accessor::Fast);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(cache authen_totp_webapp));

########################################################################
sub new {
########################################################################
  my ( $class, $totp ) = @_;

  my $self = $class->SUPER::new( { authen_totp_webapp => $totp } );

  my $cache = Cache::FileCache->new( { namespace => $totp->get_appname } );

  $self->set_cache($cache);

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

1;
