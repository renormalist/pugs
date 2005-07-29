#!/usr/bin/pugs
use v6;

require URI;
use URI::Escape <uri_unescape>;

require HTTP::Request;
require HTTP::Query;

class HTTP::Request::CGI-0.0.1[?::URI_CLASS = URI] {
    is HTTP::Request[::URI_CLASS];
    
    our Bool $.PARSE_ARGV = bool::false;
    
    has $.method;
    has $.uri;
    has $.query_string;
    
    has HTTP::Query $.query handles «
        param params
        :delete_param<delete> :delete_params<clear>
        keywords
    » = { HTTP::Query.new() };
    
    has @:keywords;
    has %:params;
    
    submethod BUILD ($self: ) {
        $.method = %*ENV<REQUEST_METHOD>;
        $.uri    = ::URI_CLASS.new(%*ENV<REQUEST_URI>);
        
        my %pairs = (
            'Content-Length' => 'CONTENT_LENGTH',
            'Content-Type'   => 'CONTENT_TYPE',
            'Referer'        => 'HTTP_REFERER'
        )
        
        for %pairs.kv -> $name, $key {
            my $val = %*ENV{$key};
            
            $:headers.header($name => $val) if $val.defined;
        }
        
        $.query = HTTP::Query.new();
        
        $self.:load_params();
    }
    
    method :load_params ($self: ) {
        if ($.method.lc() eq 'get'|'head') {
            $.query_string = %*ENV<QUERY_STRING> // %*ENV<REDIRECT_QUERY_STRING>;
            
            if ($.query_string ~~ /<[;&=]>/) {
                $.query.parse_params($.query_string);
            } else {
                $.query.parse_keywords($.query_string);
            }
        } elsif ($.method.lc() eq 'post') {
            my $type = $self.header('Content-Type');
            
            if (!$type || $type eq 'application/x-www-form-urlencoded') {
                my $content;
                $.query.:parse_params($content);
            }
        } elsif ($.PARSE_ARGV && (@*ARGS.elems > 0)) {
            $.query.:parse_params([~] @*ARGS);
        } else {
            # XXX
        }
    }
}

=pod

=head1 NAME

HTTP::Request::CGI - Subclass of HTTP::Request for dealing with CGI-generated requests.

=head1 SYNOPSIS

    require HTTP::Request::CGI;
    
    my $r = HTTP::Request::CGI.new();
    
    say "Request method: " ~ $r.method;
    say "Request URI: "    ~ $r.uri;
    say "Query string: "   ~ $r.query_string;

=head1 DESCRIPTION

An object of this class represents a client's request.  It also contains extra
information passed on by the HTTP server, useful to the authors of CGI scripts.

=head2 Request Details

An HTTP::Request::CGI object has the following public attributes:

=over 8

=item C<$r.method>

The request method used (for example, 'GET').

=item C<$r.uri>

The request URI.

=item C<$r.query_string>

The query string portion of the request URI.

=back

In addition, the following request headers are set on the HTTP::Headers object,
if they are present:

=over 8

=item 1. Content-Length

=item 2. Content-Type

=item 3. Referer

=back

=head2 Parameters

The parameters of the request are accessible through the HTTP::Query object that
is part of every HTTP::Request::CGI object (accessible as C<$r.query>, where
C<$r> is the HTTP::Request::CGI object).  The following methods are delegated
to the query object:

=over 8

=item C<param>

=item C<params>

=item C<keywords>

=item C<delete_param> -> C<delete>

=item C<delete_params> -> C<clear>

=back

Please read the HTTP::Query documentation for more information on these methods.

=head1 AUTHORS

"Aankhen"

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
