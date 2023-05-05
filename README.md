# perl-Authen-TOTP-WebApp

Proof of concept for creating an extensible TOTP 2FA web app. This
project will create a Bootstrap application that allows you to create
a secret key for use with two factor authentication.  You enter your
username and a QR code will and secret will appear. Use that secret or
scan the QR code on your phone using something like Google
Authenticator.

The application will store your secret and allow you test your
access code.

# Dependencies

* `docker`
* `docker-compose`
* `make`
* Perl modules

## Perl module dependencies

__...and possibly more__

* `Archive::Tar`
* `IO::Zlib`
* `Authen::OATH`
* `Cache::FileCache` 
* `CGI::Minimal`
* `Class::Accessor::Fast`
* `Convert::Base32`
* `Imager::QRCode`
* `IO::Scalar`
* `JSON`
* `Readonly`
* `Template`
* `URI::Encode`

> Building `Imager` will require `libpng-devel` on Redhat base systems.

The web application consists of a Perl CGI, a configuration file and
Javascript file. You should be able to get this working by creating a
Docker container and running `docker-compose`.

# Building the Docker Container

```
git clone https://github.com/rlauer6/perl-Authen-TOTP-WebApp
cd perl-Authen-TOTP-WebApp
cd docker
make
```

After running `make` you should have a Docker image
(`authen-totp-webapp`). Now bring up the application.

```
docker-compose up
```

In your browser visit:

http://localhost:8080/cgi-bin/qrcode.cgi

This will bring up the app where you can enter a username.  Click the
"Submit" button to get the QR code and secret.

Click 'Try It!' to test your access code.

You can also visit http://localhost:8080/cgi-bin/qrcode.cgi?login=1 to test your
access code.

# License

Copyright (c) 2023 Robert Lauer. All rights reserved. This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
