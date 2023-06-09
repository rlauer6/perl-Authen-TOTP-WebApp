# perl-Authen-TOTP-WebApp

> Caution: This is a _work-in-progress_, classes and methods may
> be subject to change!

Proof of concept for creating an extensible TOTP 2FA web app. This
project creates a Bootstrap web application running in Docker
container that allows you to create
a secret key for use with two factor authentication.

<img src="authen-totp-webapp-1.png" style="display: inline-block; max-width:250px; margin: 0 auto;">

* Enter your username, click "Submit".

---

<img src="authen-totp-webapp-2.png" style="display: inline-block; max-width:250px; margin: 0 auto;">

* A QR code and secret will be retrieved from the API.
* The application will store your secret locally.
* Enter the secret or scan the QR code to your 2FA authentication app
(e.g. Google Authenticator)

---

<img src="authen-totp-webapp-3.png" style="display: inline-block; max-width:250px; margin: 0 auto;">

* Enter the access code from your app and see if it matches!

---

# Other Features

The Perl module behind the scenes `Authen::TOTP::WebApp` is designed
so you can sub-class or compose in methods to modify the behaviors for
providing your own forms and your own key storage mechanism.  See the
documentation for [`Authen::TOTP::WebApp`](/Authen/TOTP/WebApp.pod) for more details.

The reference implementation uses `Cache::FileCache` to store secrets
on the local Docker container, so you will lose these each time you
bring up the container.

You can also see how an example of using AWS
Secrets Manager as your backend secret repository. The
`docker-compose.yaml` file will also bring up LocalStack which is used
t emulate AWS Secrets Manager.  To exercise the AWS Secrets Manager
version, update the `secrets_manager` entry in the `totp.json`.

```
 "secrets_manager" : "AWSSecretsManager"
```

The secret repository is not persistent. When LocalStack is taken
down you will lose any secrets you have stored. __This is a POC
afterall...__

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
* `Data::UUID`
* `Imager::QRCode`
* `IO::Scalar`
* `JSON`
* `Readonly`
* `Template`
* `URI::Encode`

> Building `Imager` will require `libpng-devel` on Redhat base systems.

The web application consists of two Perl modules, a Perl CGI, a
configuration file and a Javascript file. You should be able to get
this working by creating a Docker container and running
`docker-compose`.

# How It Works

The CGI will deliver a form to your browser where you can enter a
username. A secret key and a QR code will be returned.

The form is actually created by a Perl CGI, however you can deliver your
own form and use the Perl CGI's API methods instead.

## Endpoints

Apache configuration to create convenient endpoints (all endpoints point to `qrcode.cgi`).

```
RewriteRule ^/2fa              /cgi-bin/qrcode.cgi  [PT]
RewriteRule ^/qrcode/([^/]+)$  /cgi-bin/qrcode.cgi?username=$1 [PT]
RewriteRule ^/login            /cgi-bin/qrcode.cgi?login=1 [PT]
RewriteRule ^/verify$          /cgi-bin/qrcode.cgi?username=$1&access_code=$2 [PT]

AllowEncodedSlashes On
```


| Endpoint | Description | Method | Parameters | 
| -------- | ----------- | ------ | ---------- | 
| /qrcode/{username} | returns a JSON payload with a base64 encoded QR code | GET | username |
| /2fa  | returns an HTML form for creating a secret and QR code | GET |
| /verify | returns a JSON payload with "matched" - a boolean that indicates if the access code is valid | POST | username, access_code |
| /login | returns an HTML form for entering username and access code | GET | |

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

http://localhost:8080/2fa

This will bring up the app where you can enter a username.  Click the
"Submit" button to get the QR code and secret. Scan the QR code or
enter the key in your authentication app.

Click "Try It!" to test your access code.

You can also visit http://localhost:8080/login to test your
access code.

# License

Copyright (c) 2023 Robert Lauer. All rights reserved. This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
