use Test::More tests => 6;
use Data::Dumper;
$Data::Dumper::Indent = 1;

use_ok( 'Pugs::Compiler::Rule' );
no warnings qw( once );

{
    *{'Test123::rule1'} = Pugs::Compiler::Rule->compile('\w')->code();
    *{'Test123::rule2'} = Pugs::Compiler::Rule->compile('(<rule1>*)')->code();
    my $match = Test123->rule2("abc");
    is($match,'abc',"Matched...");
    is(@{$match}[0],"a","Capture 1...");
    is(@{$match}[1],"b","Capture 2...");
    is(@{$match}[2],"c","Capture 3...");
    is(@{$match}[3],undef,"No more captures");
}