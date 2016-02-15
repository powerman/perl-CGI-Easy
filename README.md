[![Build Status](https://travis-ci.org/powerman/perl-CGI-Easy.svg?branch=master)](https://travis-ci.org/powerman/perl-CGI-Easy)
[![Coverage Status](https://coveralls.io/repos/powerman/perl-CGI-Easy/badge.svg?branch=master)](https://coveralls.io/r/powerman/perl-CGI-Easy?branch=master)

# NAME

CGI::Easy - simple and straightforward helpers to make CGI easy

# VERSION

This document describes CGI::Easy version v2.0.0

# SYNOPSIS

    use CGI::Easy::Request;
    use CGI::Easy::Headers;
    use CGI::Easy::Session;

    my $r    = CGI::Easy::Request->new();
    my $h    = CGI::Easy::Headers->new();
    my $sess = CGI::Easy::Session->new($r, $h);

    # -- access basic GET request details
    my $url = "$r->{scheme}://$r->{host}:$r->{port}$r->{path}";
    my $param_name  = $r->{GET}{name};
    my @param_color = @{ $r->{GET}{'color[]'} };
    my $cookie_some = $r->{cookie}{some};

    # -- file upload
    my $avatar_image    = $r->{POST}{avatar};
    my $avatar_filename = $r->{filename}{avatar};
    my $avatar_mimetype = $r->{mimetype}{avatar};

    # -- easy way to identify visitors and get data stored in cookies
    my $session_id  = $sess->{id};
    my $tempcookie_x= $sess->{temp}{x};
    my $permcookie_y= $sess->{perm}{y};

    # -- set custom HTTP headers and cookies
    $h->{Expires} = 'Sat, 01 Jan 2000 00:00:00 GMT';
    $h->add_cookie({
        name    => 'some',
        value   => 'custom cookie',
        domain  => '.example.com',
        expires => time+86400,
    });

    # -- easy way to store data in cookies
    $sess->{temp}{x} = 'available until browser closes';
    $sess->{perm}{y} = 'available for 1 year';
    $sess->save();

    # -- output all HTTP headers and html page
    print $h->compose();
    print "<html>...</html>";

    # -- output redirect
    $h->redirect('http://example.com/');
    print $h->compose();

    # -- output custom reply
    $h->{Status} = '500 Internal Server Error';
    $h->{'Content-Type'} = 'text/plain; charset=utf-8';
    print $h->compose(), "Please try again later\n";

# DESCRIPTION

This documentation is an overview of CGI::Easy::\* modules. For detailed
information about corner cases and available features you should consult
corresponding module documentation: [CGI::Easy::Request](https://metacpan.org/pod/CGI::Easy::Request),
[CGI::Easy::Headers](https://metacpan.org/pod/CGI::Easy::Headers), [CGI::Easy::Session](https://metacpan.org/pod/CGI::Easy::Session). If you wanna work with
CGI/HTTP on lower level, you can look at [CGI::Easy::Util](https://metacpan.org/pod/CGI::Easy::Util).  There also
some other useful modules available separately: [CGI::Easy::URLconf](https://metacpan.org/pod/CGI::Easy::URLconf),
[CGI::Easy::SendFile](https://metacpan.org/pod/CGI::Easy::SendFile).

CGI::Easy designed to help you do what you want with CGI/HTTP without
forcing you to learn _one more_ huge and complex API specific to some
module, or limiting you to do your tasks _only in way_ provided by this
module. With CGI::Easy you got all you need in **simple hashes**, and
you're free to **do anything you like** with this data, because it's 
**your data**.

CGI::Easy consist of three main parts:

- CGI::Easy::Request object

    This object actually is simple hash populated with all data related to
    current CGI request - GET/POST parameters, cookies, url path, … When you
    create this object with new(), current request will be parsed (from ` %ENV `
    and ` STDIN `), all useful things will be stored in that object/hash, and
    now you're free to do anything you want with this object/hash - modify it
    contents in any way, etc. You don't need special methods to access trivial
    data like some GET parameter or cookie anymore.

    Here is list of keys in that hash prepared for you:

        # -- URL info
        scheme       'http' OR 'https'
        host         'example.com'
        port         80
        path         '/' OR '/index.php' OR '/articles/2008/'
        # -- CGI parameters
        GET          { name => 'powerman', 'color[]' => ['red','green'], … }
        POST         { name => 'powerman', avatar => '…binary image data…', … }
        filename     { name => undef, avatar => 'C:\\Documents\\avatar.png', … }
        mimetype     { name => undef, avatar => 'image/png', … }
        cookie       { somevar => 'someval', … }
        # -- USER details
        REMOTE_ADDR  192.168.2.1
        REMOTE_PORT  12345
        AUTH_TYPE    Basic
        REMOTE_USER  'powerman'
        REMOTE_PASS  'secret'
        # -- original request data
        ENV          { REQUEST_METHOD => 'POST', … }
        STDIN        'name=powerman&color[]=red&color[]=green'
        # -- request parsing status
        error        '' OR 'POST body too large' etc.

- CGI::Easy::Headers object

    This object is also very simple hash - keys are HTTP header names and
    values are HTTP header values. When you call new() this hash populated
    with few headers (notably `'Status'=>'200 OK'` and
    `'Content-Type'=>'text/html; charset=utf-8'`), but you're free to
    change these keys/headers and add your own headers. When you ready to
    output all headers from this object/hash you should call compose() method,
    and it will return string with all HTTP headers suitable for sending to
    browser.

    There one exception: value for key 'Set-Cookie' is ARRAYREF with HASHREFs,
    where each HASHREF keep cookie details:

        $h->{'Set-Cookie'} = [
            { name=>'mycookie1', value=>'myvalue1' },
            { name=>'x', value=>5,
              domain=>'.example.com', expires=>time+86400 }
        ];

    To make it ease for you to work with this key there helper add\_cookie()
    method available, but you're free to modify this key manually if you like.

    There also some helper methods in this object (like redirect()), but they
    all just modify some keys/headers in this hash.

- CGI::Easy::Session object

    This object make working with cookies even more ease than already provided
    by CGI::Easy::Request and CGI::Easy::Headers way:

        my $somevalue = $r->{cookie}{somename};
        $h->add_cookie({ name => 'somename', value => $somename });

    If you will use CGI::Easy::Session, then it will read/write values for
    three cookies: `sid`, `perm` and `temp`. Cookie `sid` will contain
    automatically generated ID unique to this visitor, cookies `perm` and
    `temp` will contain simple perl hashes (automatically serialized to
    strings for storing in cookies) with different lifetime: `perm` will
    expire in 1 year, `temp` will expire when browser closes.

    CGI::Easy::Session object will provide you with three keys:

        id          undef OR '…unique string…'
        perm        { x=>5, somename=>'somevalue', … }
        temp        { y=>7, … }

    Field `id` will contain undef() in case user has no cookie support.
    To serialize hashes in fields `perm` and `temp` to cookies you'll have
    to call save() method before `$h->compose()`. Example:

        if (!defined $sess->{id}) {
            warn "user has no cookie support";
        }
        $sess->{perm}{x} = 5;
        $sess->{perm}{somename} = 'somevalue';
        $sess->{temp}{y}++;
        $sess->save();
        print $h->compose();

You don't have to use all these three parts - for example, you can use
only CGI::Easy::Request and output HTTP headers manually, or use only
CGI::Easy::Headers and parse CGI parameters using standard [CGI](https://metacpan.org/pod/CGI) module,
etc.

## Unicode

These modules by default support Unicode with UTF8 encoding. If you need
another encoding or wanna disable Unicode look at ` raw ` option for
CGI::Easy::Request->new() and modify default ` 'Content-Type' ` header
provided by CGI::Easy::Headers->new().

# EXAMPLES

## CGI with Session

    use CGI::Easy::Request;
    use CGI::Easy::Headers;
    use CGI::Easy::Session;

    my $r = CGI::Easy::Request->new();
    my $h = CGI::Easy::Headers->new();
    my $sess = CGI::Easy::Session->new($r, $h);

    $sess->{perm}{create_time} ||= time;
    $sess->{temp}{counter} ||= 0;
    $sess->{temp}{counter}++;
    $sess->save();

    print $h->compose();

    if ($sess->{id}) {
        printf "<p>Your ID is: %s</p>\n", $sess->{id};
        printf "<p>Your session was created at: %s</p>\n",
            scalar gmtime $sess->{perm}{create_time};
        printf "<p>This is your %d page view</p>\n",
            $sess->{temp}{counter};
    } else {
        printf "<p>You browser doesn't support cookies</p>\n";
    }

## FCGI with cookies

    use FCGI;
    use CGI::Easy::Request;
    use CGI::Easy::Headers;

    my $count = 0;

    my $request = FCGI::Request();
    while($request->Accept() >= 0) {
        my $r = CGI::Easy::Request->new();
        my $h = CGI::Easy::Headers->new();

        $h->{Expires} = 'Sat, 01 Jan 2000 00:00:00 GMT';
        $h->add_cookie({ 
            name    => 'counter',
            value   => ($r->{cookie}{counter} || 0) + 1,
            expires => time+10,
        });

        print $h->compose();

        printf "<p>This is request number: %d</p>\n", ++$count;
        printf "<p>This is your %d page view</p>\n", $r->{cookie}{counter};
    }

## FCGI::EV with manual Basic HTTP auth

    # -- you'll need something like this in .htaccess
    #    to catch any url with your FastCGI script
    #    and handle Basic HTTP auth manually in script
    RewriteEngine On
    RewriteBase /
    RewriteCond %{REQUEST_URI} !(fcgi_std)
    RewriteRule ^(.*)$ /fcgi_std/$1 [L]
    RewriteCond %{REQUEST_URI} (fcgi_std)
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization},L]

    # -- mod_fastcgi should be configured like this
    FastCGIExternalServer /var/www/example.com/fcgi_std -socket /tmp/fcgi_std.sock

    # -- standard code from FCGI::EV documentation
    use Socket;
    use Fcntl;
    use EV;
    use FCGI::EV;
    use FCGI::EV::Std;
    use CGI::Easy::Request;
    use CGI::Easy::Headers;
    my $path = '/tmp/fcgi_std.sock';
    socket my $srvsock, AF_UNIX, SOCK_STREAM, 0;
    unlink $path;
    my $umask = umask 0;   # ensure 0777 perms for unix socket
    bind $srvsock, sockaddr_un($path);
    umask $umask;
    listen $srvsock, SOMAXCONN;
    fcntl $srvsock, F_SETFL, O_NONBLOCK;
    my $w = EV::io $srvsock, EV::READ, sub {
        accept my($sock), $srvsock;
        fcntl $sock, F_SETFL, O_NONBLOCK;
        FCGI::EV->new($sock, 'FCGI::EV::Std');
    };
    EV::loop;

    # -- most interesting part: handle FastCGI requests
    sub main {
        my $r = CGI::Easy::Request->new();
        my $h = CGI::Easy::Headers->new();

        my $reply = q{};
        if ($r->{path} =~ m{\A/private/}xms) {
            if ($r->{REMOTE_USER} ne 'powerman' || $r->{REMOTE_PASS} ne 'secret') {
                $h->require_basic_auth('Private Area');
            }
            else {
                $reply = sprintf "<p>Welcome to private area, %s</p>\n",
                    $r->{REMOTE_USER};
            }
        }
        else {
            $reply = "<p>Welcome to public area, guest</p>\n";
        }

        print $h->compose(), $reply;
    }

# SEE ALSO

[CGI::Easy::Request](https://metacpan.org/pod/CGI::Easy::Request),
[CGI::Easy::Headers](https://metacpan.org/pod/CGI::Easy::Headers),
[CGI::Easy::Session](https://metacpan.org/pod/CGI::Easy::Session),
[CGI::Easy::Util](https://metacpan.org/pod/CGI::Easy::Util),
[CGI::Easy::URLconf](https://metacpan.org/pod/CGI::Easy::URLconf),
[CGI::Easy::SendFile](https://metacpan.org/pod/CGI::Easy::SendFile).

# SUPPORT

## Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at [https://github.com/powerman/perl-CGI-Easy/issues](https://github.com/powerman/perl-CGI-Easy/issues).
You will be notified automatically of any progress on your issue.

## Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.
Feel free to fork the repository and submit pull requests.

[https://github.com/powerman/perl-CGI-Easy](https://github.com/powerman/perl-CGI-Easy)

    git clone https://github.com/powerman/perl-CGI-Easy.git

## Resources

- MetaCPAN Search

    [https://metacpan.org/search?q=CGI-Easy](https://metacpan.org/search?q=CGI-Easy)

- CPAN Ratings

    [http://cpanratings.perl.org/dist/CGI-Easy](http://cpanratings.perl.org/dist/CGI-Easy)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/CGI-Easy](http://annocpan.org/dist/CGI-Easy)

- CPAN Testers Matrix

    [http://matrix.cpantesters.org/?dist=CGI-Easy](http://matrix.cpantesters.org/?dist=CGI-Easy)

- CPANTS: A CPAN Testing Service (Kwalitee)

    [http://cpants.cpanauthors.org/dist/CGI-Easy](http://cpants.cpanauthors.org/dist/CGI-Easy)

# AUTHOR

Alex Efros &lt;powerman@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2009-2010 by Alex Efros &lt;powerman@cpan.org>.

This is free software, licensed under:

    The MIT (X11) License
