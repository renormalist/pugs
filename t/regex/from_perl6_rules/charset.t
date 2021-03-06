use v6-alpha;

use Test;

=pod

This file was derived from the perl5 CPAN module Perl6::Rules,
version 0.3 (12 Apr 2004), file t/charset.t.

It has (hopefully) been, and should continue to be, updated to
be valid perl6.

=cut

plan 24;

if !eval('("a" ~~ /a/)') {
  skip_rest "skipped tests - rules support appears to be missing";
} else {

ok("zyxaxyz" ~~ m/(<[aeiou]>)/, 'Simple set');
is($0, 'a', 'Simple set capture');
ok(!( "a" ~~ m/<-[aeiou]>/ ), 'Simple neg set failure');
ok("f" ~~ m/(<-[aeiou]>)/, 'Simple neg set match');
is($0, 'f', 'Simple neg set capture');

ok(!( "a" ~~ m/(<[a..z]-[aeiou]>)/ ), 'Difference set failure');
ok("y" ~~ m/(<[a..z]-[aeiou]>)/, 'Difference set match', :todo<feature>);
is($0, 'y', 'Difference set capture', :todo<feature>);
ok(!( "a" ~~ m/(<+<?alpha>-[aeiou]>)/ ), 'Named difference set failure');
ok("y" ~~ m/(<+<?alpha>-[aeiou]>)/, 'Named difference set match', :todo<feature>);
is($0, 'y', 'Named difference set capture', :todo<feature>);
ok(!( "y" ~~ m/(<[a..z]-[aeiou]-[y]>)/ ), 'Multi-difference set failure');
ok("f" ~~ m/(<[a..z]-[aeiou]-[y]>)/, 'Multi-difference set match', :todo<feature>);
is($0, 'f', 'Multi-difference set capture', :todo<feature>);

ok(']' ~~ m/(<[]]>)/, 'LSB match');
is($0, ']', 'LSB capture');
ok(']' ~~ m/(<[\]]>)/, 'quoted close LSB match');
is($0, ']', 'quoted close LSB capture');
ok('[' ~~ m/(<[\[]>)/, 'quoted open LSB match');
is($0, '[', 'quoted open LSB capture');
ok('{' ~~ m/(<[\{]>)/, 'quoted open LCB match');
is($0, '{', 'quoted open LCB capture');
ok('}' ~~ m/(<[\}]>)/, 'quoted close LCB match');
is($0, '}', 'quoted close LCB capture');

}
