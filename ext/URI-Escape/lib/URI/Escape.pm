#!/usr/bin/pugs
use v6;

module URI::Escape-0.0.1;

our %escapes;

for 0..255 -> $char {
    %escapes{chr($char)} = sprintf('%%%02X', $char);
}

# XXX need to handle the Rule case -- must check that $0 is being set
#multi sub uri_escape (Str $string is copy, Rule $unsafe) returns Str is export {
#    ...
#}

multi sub uri_escape (Str $string is copy, Str $unsafe, Bool +$negate) returns Str is export {
    my $pattern;
    
    $pattern = ($negate) ?? rx:P5/([^$unsafe])/ :: rx:P5/([$unsafe])/;
    
    $string ~~ s:P5:g/$pattern/{ %escapes{$0} || fail_hi($0) }/;
    
    return $string;
}

multi sub uri_escape (Str $string is copy) returns Str is export {
    $string = uri_escape($string, "A-Za-z0-9\-_.!~*'()", negate => bool::true);
}

multi sub uri_escape_utf8 (Str $string is copy, Rule $unsafe) returns Str is export {
    ...
}

multi sub uri_escape_utf8 (Str $string is copy, Str $unsafe) returns Str is export {
    ...
}

multi sub uri_escape_utf8 (Str $string is copy) returns Str is export {
    ...
}

sub uri_unescape (Str $string is copy) returns Str is export {
    ...
}

sub fail_hi (Str $char) {
    ...
}