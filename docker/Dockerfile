FROM amazonlinux:2

# ADD perl-aws.repo /etc/yum.repos.d/perl-aws.repo
RUN amazon-linux-extras install epel -y

RUN yum install -y perl-core less tree gcc make procps curl \
    iputils net-tools tar automake autoconf \
    openssl openssl-devel expat expat-devel libpng-devel

# Apache
RUN yum install -y httpd mod_perl 'perl(Apache2::Request)'

# cpanm
RUN curl -L https://cpanmin.us | perl - App::cpanminus

COPY requirements.txt /tmp

RUN for a in $(cat /tmp/requirements.txt|awk '{print $1}'); do \
      cpanm -v -n $a; \
    done

# cleanup 
RUN yum clean all && rm -rf /var/cache/yum

RUN mkdir -p /var/www/{log,html,spool,include,config,session}
RUN mkdir /var/www/html/{css,javascript,img}

COPY totp.conf /etc/httpd/conf.d/
COPY authen-totp-webapp.tar.gz /tmp

COPY install.pl /usr/local/bin/install.pl

RUN /usr/local/bin/install.pl -t /tmp/authen-totp-webapp.tar.gz \
      -v install --owner apache

RUN chmod +x /var/www/cgi-bin/qrcode.cgi

CMD /usr/sbin/apachectl -D FOREGROUND
