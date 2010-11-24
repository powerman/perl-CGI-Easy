package CGI::Easy::Session;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('1.0.0');    # REMINDER: update Changes

# REMINDER: update dependencies in Makefile.PL
use Data::UUID;
use CGI::Easy::Util qw( quote_list unquote_hash );

use constant SESSION_EXPIRE => 365*24*60*60; # 1 year

my $UG;


sub new {
    my ($class, $r, $h) = @_;
    my $self = {
        id      => undef,
        perm    => undef,
        temp    => undef,
        _r      => $r,
        _h      => $h,
    };
    bless $self, $class;
    $self->_init;
    return $self;
}

sub _init {
    my ($self) = @_;
    my $r = $self->{_r};
    my $c = $r->{cookie};
    if ($c->{sid}) {
        $self->{id} = $c->{sid};
    }
    else {
        my $referer = $r->{ENV}{HTTP_REFERER} || q{};
        if ($referer !~ m{\A\w+://\Q$r->{host}\E[:/]}xms) {
            $UG ||= Data::UUID->new();
            $self->{id} = $UG->create_b64();
        }
    }
    if ($self->{id}) {
        $self->{_h}->add_cookie({
            name    => 'sid',
            value   => $self->{id},
            expires => time + SESSION_EXPIRE,
        });
    }
    $self->{perm} = unquote_hash($c->{perm}) || {};
    $self->{temp} = unquote_hash($c->{temp}) || {};
    return;
}

sub save {
    my ($self) = @_;
    my $h = $self->{_h};
    my @other_cookies = grep {$_->{name} ne 'perm' && $_->{name} ne 'temp'}
        @{ $h->{'Set-Cookie'} };
    $h->{'Set-Cookie'} = [
        @other_cookies,
        {
            name    => 'perm',
            value   => quote_list(%{ $self->{perm} }),
            expires => time + SESSION_EXPIRE,
        },
        {
            name    => 'temp',
            value   => quote_list(%{ $self->{temp} }),
        },
    ];
    return;
}


1; # Magic true value required at end of module
__END__

=encoding utf8

=head1 NAME

CGI::Easy::Session - Support unique session ID and session data in cookies


=head1 SYNOPSIS

    use CGI::Easy::Request;
    use CGI::Easy::Headers;
    use CGI::Easy::Session;

    my $r = CGI::Easy::Request->new();
    my $h = CGI::Easy::Headers->new();
    my $sess = CGI::Easy::Session->new($r, $h);

    if (defined $sess->{id}) {
        printf "Session ID: %s\n", $sess->{id};
    } else {
        print "User has no cookie support\n";
    }
    printf "Permanent var 'a': %s\n", $sess->{perm}{a};
    printf "Temporary var 'a': %s\n", $sess->{temp}{a};

    $sess->{perm}{b} = 'data';
    $sess->{temp}{answer} = 42;
    $sess->save();                  # BEFORE $h->compose()


=head1 DESCRIPTION

Manage session for CGI applications.

Detect is user has cookie support.
Generate unique session ID for each user.
Store persistent and temporary (until browser closes) data in cookies.

This module will set cookies C< sid >, C< perm > and C< temp >, so you
shouldn't use cookies with these names if you using this module.


=head1 INTERFACE

=over

=item new( $r, $h )

Take $r (CGI::Easy::Request object) and $h (CGI::Easy::Headers object)
and create new CGI::Easy::Session object with these public fields:

    id      STRING (unique session ID or undef if no cookie support)
    perm    HASHREF (simple hash with scalar-only values)
    temp    HASHREF (simple hash with scalar-only values)

You can both read existing session data in {perm} and {temp} and
add/update new data there, but keep in mind overall cookie size is limited
(usual limit is few kilobytes and it differ between browsers).
After changing {perm} or {temp} don't forget to call save().

Complex data structures in {perm} and {temp} doesn't supported (you can
manually pack/unpack them using any data serialization tool).

Will set cookie "sid" (with session ID) in 'Set-Cookie' header, which will
expire in 1 YEAR after last visit.

Return created CGI::Easy::Session object.


=item save()

Set/update 'Set-Cookie' header with current {perm} and {temp} values.
Should be called before sending reply to user (with C<< $h->compose() >>)
if {perm} or {temp} was modified.

Cookie "perm" (with hash {perm} data) will expire in 1 YEAR after last visit.
Cookie "temp" (with hash {temp} data) will expire when browser will be closed.

Return nothing.


=back


=head1 BUGS AND LIMITATIONS

No bugs have been reported.


=head1 SUPPORT

Please report any bugs or feature requests through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CGI-Easy>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

You can also look for information at:

=over

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CGI-Easy>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/CGI-Easy>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/CGI-Easy>

=item * Search CPAN

L<http://search.cpan.org/dist/CGI-Easy/>

=back


=head1 AUTHOR

Alex Efros  C<< <powerman-asdf@ya.ru> >>


=head1 LICENSE AND COPYRIGHT

Copyright 2009-2010 Alex Efros <powerman-asdf@ya.ru>.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

