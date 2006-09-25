use v6-alpha;
use Test;

=pod

This file was derived from the perl5 CPAN module Perl6::Rules,
version 0.3 (12 Apr 2004), file t/newline.t.

It has (hopefully) been, and should continue to be, updated to
be valid perl6.

=cut

skip_rest "This file was in t_disabled/.  Remove this SKIP when it works.";
=begin END

plan 15;

if !eval('("a" ~~ /a/)') {
  skip_rest "skipped tests - rules support appears to be missing";
} else {

ok("\n" ~~ m/\n/, '\n');

ok("\o15\o12" ~~ m/\n/, 'CR/LF');
ok("\o12" ~~ m/\n/, 'LF');
ok("a\o12" ~~ m/\n/, 'aLF');
ok("\o15" ~~ m/\n/, 'CR');
ok("\x85" ~~ m/\n/, 'NEL');
ok("\x2028" ~~ m/\n/, 'LINE SEP');

ok(!( "abc" ~~ m/\n/ ), 'not abc');

ok(!( "\n" ~~ m/\N/ ), 'not \n');

ok(!( "\o12" ~~ m/\N/ ), 'not LF');
ok(!( "\o15\o12" ~~ m/\N/ ), 'not CR/LF');
ok(!( "\o15" ~~ m/\N/ ), 'not CR');
ok(!( "\x85" ~~ m/\N/ ), 'not NEL');
ok(!( "\x2028" ~~ m/\N/ ), 'not LINE SEP');

ok("abc" ~~ m/\N/, 'abc');

}
