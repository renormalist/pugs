
use Test::More tests => 6;
use Data::Dumper;
$Data::Dumper::Indent = 1;

use_ok( 'Pugs::Compiler::RegexPerl5' );
no warnings qw( once );

use Pugs::Runtime::Match::Ratchet; # overload doesn't work without this ???

{
    my $rule = Pugs::Compiler::RegexPerl5->compile( '((.).)(.)' );
    my $match = $rule->match( "xyzw" );
    #print "Source: ", do{use Data::Dumper; Dumper($rule->{perl5})};
    #print "Match: ", do{use Data::Dumper; Dumper($match)};
    is( $match?1:0, 1, 'booleanify' );
    is( "$match", "xyz", 'stringify 1' );
    is( "$match->[0]", "xy", 'stringify 2' );
    is( "$match->[1]", "x", 'stringify 3' );
    is( "$match->[2]", "z", 'stringify 4' );
}

# TODO: test :p