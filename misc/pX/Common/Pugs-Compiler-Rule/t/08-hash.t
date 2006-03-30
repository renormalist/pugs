use Test::More tests => 7;
use Data::Dumper;
$Data::Dumper::Indent = 1;

use_ok( 'Pugs::Compiler::Rule' );

{
=for docs - see S05
    *   An interpolated hash matches the longest possible key of the hash as
        a literal, or fails if no key matches. (A "" key will match
        anywhere, provided no longer key matches.)
    *   If the corresponding value of the hash element is a closure, it is executed.
    *   If it is a string or rule object, it is executed as a subrule.
    *   If it has the value 1, nothing special happens beyond the match.
    *   Any other value causes the match to fail.
=cut
    my $match;
    my $v = 0;
    my %test = (
        if =>    2,        # fail (number, not '1')
        iff =>   1,        # match (longer than 'if')
        until => Pugs::Compiler::Rule->compile('(aa)'),  
                           # subrule - match "until(aa)"
        use =>   sub { $v = 1 },   
                           # closure - print "use()"
    );   
    $rule1 = Pugs::Compiler::Rule->compile('%test 123');
    
    $match = $rule1->match("iff123");
    is($match,'iff123',"Matched hash{iff}");

    $match = $rule1->match("if123");
    is($match,'',"fail hash{if} - value != 1");

    is($v,0,"closure not called yet");
    $match = $rule1->match("use");
    is($v,1,"closure was called hash{use}");

    $match = $rule1->match("untilaa123");
    #print Dumper($match);
    is($match,'untilaa123',"subrule hash{until}");
    is($match->(),'untilaa123',"subrule hash{until}");

}