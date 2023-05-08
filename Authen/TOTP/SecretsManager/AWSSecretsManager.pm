package Authen::TOTP::SecretsManager::AWSSecretsManager;

use strict;
use warnings;

# this is required to resolve the Readonly/ReadonlyX conflict
BEGIN {
  use Module::Loaded;

  mark_as_loaded('ReadonlyX');
}

use Amazon::API::SecretsManager;
use Data::UUID;
use English qw(-no_match_vars);
use parent  qw(Exporter Class::Accessor::Fast);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(secrets_mgr authen_totp_webapp));

########################################################################
sub new {
########################################################################
  my ( $class, $authen_totp_webapp ) = @_;

  my $self
    = $class->SUPER::new( { authen_totp_webapp => $authen_totp_webapp } );

  my $aws_config = $authen_totp_webapp->get_config->{aws};

  my $secrets_mgr = Amazon::API::SecretsManager->new(
    protocol    => $aws_config->{protocol},
    url         => $aws_config->{url},
    credentials => Amazon::Credentials->new(
      { aws_access_key_id     => $aws_config->{aws_access_key_id},
        aws_secret_access_key => $aws_config->{aws_secret_access_key},
      }
    ),
  );

  $self->set_secrets_mgr($secrets_mgr);

  return $self;
}

########################################################################
sub create_secret {
########################################################################
  my ( $self, $secret_id, $secret_string ) = @_;

  my $secrets_mgr = $self->get_secrets_mgr;

  my $client_request_token = Data::UUID->new->create_str;

  my $result = $secrets_mgr->CreateSecret(
    { Name               => $secret_id,
      SecretString       => $secret_string,
      ClientRequestToken => $client_request_token,
    }
  );

  return $result;
}

########################################################################
sub save_secret {
########################################################################
  my ( $self, $secret_id, $secret_value ) = @_;

  my $secrets_mgr = $self->get_secrets_mgr;

  my $value = eval { $self->find_secret($secret_id); };

  if ( !$value || $EVAL_ERROR ) {
    if ( ref($EVAL_ERROR) && ref($EVAL_ERROR) =~ /API::Error/xsm ) {
      if ( $EVAL_ERROR->get_error eq '400' ) {
        $self->create_secret( $secret_id, $secret_value );
      }
      else {
        die $EVAL_ERROR;
      }
    }
    else {
      die $EVAL_ERROR;
    }
  }
  else {
    $secrets_mgr->PutSecretValue(
      { SecretId     => $secret_id,
        SecretString => $secret_value
      }
    );
  }

  return $secret_id;
}

########################################################################
sub find_secret {
########################################################################
  my ( $self, $secret_id ) = @_;

  my $secrets_mgr = $self->get_secrets_mgr;

  my $secret = $secrets_mgr->GetSecretValue( { SecretId => $secret_id } );

  return $secret->{SecretString};
}

1;

## no critic (RequirePodSections)

__END__

=pod

=head1 NAME

Authen::TOTP::SecretsManager::AWSSecretsManager - implementation of
secret storage using AWS SecretsManager

=head1 SYNOPSIS

 # set the class name in the config file
 "secrets_manager" : "AWSSecretsManager"

=head1 DESCRIPTION

This class is an implementation of a secrets manager to support the
C<Authen::TOTP::WebApp> class. The implementation provides the two
required methods necessary to store and retrieve secrets used to
generate the time-based on-time password (TOTP) used for two factor
authentication.

You add the name of this class to the F<totp.json> configuration
file. You can use the full class name or just the suffix.

Update the other parameters in an C<aws> section of the configuration
file if necessary (see below).

=head1 METHODS AND SUBROUTINES

=head1 new

 new(app)

The new method is passed an instance of C<Authen::TOTP::WebApp>. This
is guaranteed to provide at least the C<get_config> method that
contains the configuration object. The configuration object for this
implementation can contain an C<aws> section described below:

 ...
 "aws" : {
    "aws_access_key_id" : "access-key-id",
    "aws_secret_access_key" : "secret-access-key",
    "url" : "localstack_main:4566",
    "protocol" : "http"
  }
  ...

=over 5

=item aws_access_key_id

The AWS access key id.

=item aws_secret_access_key

The AWS secret access key.

=item protocol

HTTP protocol (http or https).

default: http:

=item url

The base url for AWS services.

default: amazonaws.com

=back

The C<aws> section itself, along with all of the values, are
optional. AWS credentials should generally be stored in the environment
or as part of the container or EC2 instance's metadata. If you are
using a service like LocalStack you'll want to create an C<aws>
section similar to the configuration shown above.

=head1 save_secret

 save_secret(secret-id, secret-string)

=head1 find_secret

 find_secret(secret-id)

=head1 SEE ALSO

L<Authen::TOTP::WebApp>

=head1 AUTHOR

Rob Lauer - <rlauer6@comcast.net>

=cut
