package CGI::Easy::Util;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('1.0.0');    # REMINDER: update Changes

# REMINDER: update dependencies in Makefile.PL
use Perl6::Export::Attrs;
use URI::Escape qw( uri_unescape uri_escape_utf8 );


sub date_http :Export {
    my ($tick) = @_;
    return _date($tick, 'http');
}

sub date_cookie :Export {
    my ($tick) = @_;
    return _date($tick, 'cookie');
}

sub _date {
	my ($tick, $format) = @_;
    my $sp = $format eq 'cookie' ? q{-} : q{ };
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime $tick;
	my $wkday = qw(Sun Mon Tue Wed Thu Fri Sat)[$wday];
	my $month = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$mon];
	return sprintf "%s, %02d$sp%s$sp%s %02d:%02d:%02d GMT",
        $wkday, $mday, $month, $year+1900, $hour, $min, $sec;   ## no critic(ProhibitMagicNumbers)
}

sub make_cookie :Export {
    my ($opt) = @_;
    return q{} if !defined $opt->{name};

    my $name    = $opt->{name};
    my $value   = defined $opt->{value} ? $opt->{value} : q{};
    my $domain  = $opt->{domain};
    my $path    = defined $opt->{path}  ? $opt->{path}  : q{/}; # IE require it
    my $expires = defined $opt->{expires} && $opt->{expires} =~ /\A\d+\z/xms ?
        date_cookie($opt->{expires}) : $opt->{expires};
    my $set_cookie = 'Set-Cookie: ';
    $set_cookie .= uri_escape_utf8($name) . q{=} . uri_escape_utf8($value);
    $set_cookie .= "; domain=$domain"   if defined $domain; ## no critic(ProhibitPostfixControls)
    $set_cookie .= "; path=$path";
    $set_cookie .= "; expires=$expires" if defined $expires;## no critic(ProhibitPostfixControls)
    $set_cookie .= '; secure'           if $opt->{secure};  ## no critic(ProhibitPostfixControls)
    $set_cookie .= "\r\n";
    return $set_cookie;
}

sub uri_unescape_plus :Export {
    my ($s) = @_;
    $s =~ s/[+]/ /xmsg;
    return uri_unescape($s);
}

sub burst_urlencoded :Export {
	my ($buffer) = @_;
    my %param;
    if (defined $buffer) {
        foreach my $pair (split /[&;]/xms, $buffer) {
            my ($name, $data) = split /=/xms, $pair, 2;
            $name = !defined $name ? q{} : uri_unescape_plus($name);
            $data = !defined $data ? q{} : uri_unescape_plus($data);
            push @{ $param{$name} }, $data;
        }
    }
    return \%param;
}

# This function derived from CGI::Minimal (1.29) by
#     Benjamin Franz <snowhare@nihongo.org>
#     Copyright (c) Benjamin Franz. All rights reserved.
sub burst_multipart :Export {
    ## no critic
	my ($buffer, $bdry) = @_;

	# Special case boundaries causing problems with 'split'
	if ($bdry =~ m#[^A-Za-z0-9',-./:=]#s) {
		my $nbdry = $bdry;
		$nbdry =~ s/([^A-Za-z0-9',-.\/:=])/ord($1)/egs;
		my $quoted_boundary = quotemeta ($nbdry);
		while ($buffer =~ m/$quoted_boundary/s) {
			$nbdry .= chr(int(rand(25))+65);
			$quoted_boundary = quotemeta ($nbdry);
		}
		my $old_boundary = quotemeta($bdry);
		$buffer =~ s/$old_boundary/$nbdry/gs;
		$bdry   = $nbdry;
	}

	$bdry = "--$bdry(--)?\015\012";
	my @pairs = split(/$bdry/, $buffer);

    my (%param, %filename, %mimetype);
	foreach my $pair (@pairs) {
		next if (! defined $pair);
		chop $pair; # Trailing \015 
		chop $pair; # Trailing \012
		last if ($pair eq "--");
		next if (! $pair);

		my ($header, $data) = split(/\015\012\015\012/s,$pair,2);

		# parse the header
		$header =~ s/\015\012/\012/osg;
		my @headerlines = split(/\012/so,$header);
		my ($name, $filename, $mimetype);

		foreach my $headfield (@headerlines) {
			my ($fname,$fdata) = split(/: /,$headfield,2);
			if ($fname =~ m/^Content-Type$/io) {
				$mimetype=$fdata;
			}
			if ($fname =~ m/^Content-Disposition$/io) {
				my @dispositionlist = split(/; /,$fdata);
				foreach my $dispitem (@dispositionlist) {
					next if ($dispitem eq 'form-data');
					my ($dispfield,$dispdata) = split(/=/,$dispitem,2);
					$dispdata =~ s/^\"//o;
					$dispdata =~ s/\"$//o;
					$name = $dispdata if ($dispfield eq 'name');
					$filename = $dispdata if ($dispfield eq 'filename');
				}
			}
		}
        next if !defined $name;
        next if !defined $data;

        push @{ $param{$name}    }, $data;
        push @{ $filename{$name} }, $filename;
        push @{ $mimetype{$name} }, $mimetype;
	}
    return (\%param, \%filename, \%mimetype);
}


### Unrelated to CGI, and thus internal/undocumented

sub _quote {
    my ($s) = @_;
    croak 'can\'t quote undefined value' if !defined $s;
    if ($s =~ / \s | ' | \A\z /xms) {
        $s =~ s/'/''/xmsg;
        $s = "'$s'";
    }
    return $s;
}

sub _unquote {
    my ($s) = @_;
    if ($s =~ s/\A'(.*)'\z/$1/xms) {
        $s =~ s/''/'/xmsg;
    }
    return $s;
}

sub quote_list :Export {    ## no critic(RequireArgUnpacking)
    return join q{ }, map {_quote($_)} @_;
}

sub unquote_list :Export {
    my ($s) = @_;
    return if !defined $s;
    my @w;
    while ($s =~ /\G ( [^'\s]+ | '[^']*(?:''[^']*)*' ) (?:\s+|\z)/xmsgc) {
        my $w = $1;
        push @w, _unquote($w);
    }
    return if $s !~ /\G\z/xmsg;
    return \@w;
}

sub unquote_hash :Export {  ## no critic(RequireArgUnpacking)
    my $w = unquote_list(@_);
    return $w && $#{$w} % 2 ? { @{$w} } : undef;
}


1; # Magic true value required at end of module
__END__

=encoding utf8

=head1 NAME

CGI::Easy::Util - low-level helpers for HTTP/CGI


=head1 SYNOPSIS

    use CGI::Easy::Util qw( date_http date_cookie make_cookie );

    my $mtime = (stat '/some/file')[9];
    printf "Last-Modified: %s\r\n", date_http($mtime);

    printf "Set-Cookie: a=5; expires=%s\r\n", date_cookie(time+86400);

    printf make_cookie({ name=>'a', value=>5, expires=>time+86400 });


    use CGI::Easy::Util qw( uri_unescape_plus
                            burst_urlencoded burst_multipart );

    my $s = uri_unescape_plus('a+b%20c');   # $s is 'a b c'

    my %param = %{ burst_urlencoded($ENV{QUERY_STRING}) };
    my $a = $param{a}[0];

    ($params, $filenames, $mimetypes) = burst_multipart($STDIN_data, $1)
        if $ENV{CONTENT_TYPE} =~ m/;\s+boundary=(.*)/xms;
    my $avatar_image    = $params->{avatar}[0];
    my $avatar_filename = $filenames->{avatar}[0];
    my $avatar_mimetype = $mimetypes->{avatar}[0];


=head1 DESCRIPTION

This module contain low-level function which you usually doesn't need -
use L<CGI::Easy::Request> and L<CGI::Easy::Headers> instead.


=head1 EXPORTS

Nothing by default, but all documented functions can be explicitly imported.


=head1 INTERFACE 

=over

=item date_http( $seconds )

Convert given time into text format suitable for sending in HTTP headers.

Return date string.


=item date_cookie( $seconds )

Convert given time into text format suitable for sending in HTTP header
Set-Cookie's "expires" option.

Return date string.


=item make_cookie( \%cookie )

Convert HASHREF with cookie properties to "Set-Cookie: ..." HTTP header.

Possible keys in %cookie:

    name        REQUIRED STRING
    value       OPTIONAL STRING (default "")
    domain      OPTIONAL STRING (default "")
    path        OPTIONAL STRING (default "/")
    expires     OPTIONAL STRING or SECONDS
    secure      OPTIONAL BOOL

Format for "expires" should be either correct date 
'Thu, 01-Jan-1970 00:00:00 GMT' or time in seconds.

Return HTTP header string.


=item uri_unescape_plus( $uri_escaped_value )

Same as uri_unescape from L<URI::Escape> but additionally replace '+' with space.

Return unescaped string.

=item burst_urlencoded( $url_encoded_name_value_pairs )

Unpack name/value pairs from url-encoded string (like $ENV{QUERY_STRING}
or STDIN content for non-multipart forms sent using POST method).

Return HASHREF with params, each param's value will be ARRAYREF
(because there can be more than one value for any parameter in source string).

=item burst_multipart( $buffer, $boundary )

Unpack buffer with name/value pairs in multipart/form-data format.
This format usually used to upload files from forms, and each name/value
pair may additionally contain 'file name' and 'mime type' properties.

Return three HASHREF (with param's values, with param's file names, and
with param's mime types), all values in all three HASHREF are ARRAYREF
(because there can be more than one value for any parameter in source string).
For non-file-upload parameters corresponding values in last two hashes
(with file names and mime types) will be undef().

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

This module also include some code derived from

=over

=item CGI::Minimal (1.29)

by Benjamin Franz <snowhare@nihongo.org>.
Copyright (c) Benjamin Franz. All rights reserved.

=back

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

