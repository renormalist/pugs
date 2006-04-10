
use Test::More tests => 2;
use Data::Dumper;

use_ok( 'Pugs::Grammar::Prefix' );

{
    my $match = Pugs::Grammar::Prefix->parse( q(-) );
    #print Dumper $match->();
    is_deeply( $match->(), 
        {
            'op' => 'prefix:<->',
        }, 
        'prefix:<->' );
}
