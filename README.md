# perl-Authen-TOTP-WebApp

Proof of concept for creating an extensible TOTP 2FA web app.

Currently, to make this work you would need to:

* have an Apache server running
* have the correct Perl modules installed

IOW, if you can get this working on your own congrats...

Assuming you have a somewhat standard Apache setup here are some
clues:

* copy `config.json` file to `/var/www/config`
* copy `qrcode.cgi` to `/var/www/cgi-bin`
* copy `totp.js` to `/var/www/html/javascript`
* copy the `.pm` files to one of Perl's paths

# Dependencies

A partial list of dependencies...

## Perl Modules

* `CGI::Minimal`
* `Imager`
* `Imager::QRCode`
* `Convert::Base32`
* `Authen::OATH`

> Building `Imager` will require `libpng-devel` on Redhat base systems.

# License

Copyright: Copyright (c) 2023 Robert Lauer. All rights reserved. This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
