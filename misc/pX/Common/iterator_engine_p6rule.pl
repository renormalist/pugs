# pX/Common/iterator_engine_p6rule.pl - fglock
#
# experimental implementation of p6-regex parser
#
# see: iterator_engine_README

use strict;
use warnings;

require 'iterator_engine.pl';

{
  package grammar1;

sub any { 
    return unless $_[0];
    return { 
        bool  => 1,
        match => { '.'=> substr($_[0],0,1) },
        tail  => substr($_[0],1),
        ( $_[2]->{capture} ? ( capture => [ substr($_[0],0,1) ] ) : () ),
    };
}
sub ws {
    return unless $_[0];
    return { 
        bool  => 1,
        match => { 'ws'=> $1 },
        tail  => substr($_[0],1),
        ( $_[2]->{capture} ? ( capture => [ $1 ] ) : () ),
    }
        if $_[0] =~ /^(\s)/s;
    return;
};
sub escaped_char {
    return unless $_[0];
    return { 
        bool  => 1,
        match => { 'escaped_char'=> $1 },
        tail  => substr($_[0],2),
        ( $_[2]->{capture} ? ( capture => [ $1 ] ) : () ),
    }
        if $_[0] =~ /^(\\.)/s;
    return;
};
sub word { 
    return unless $_[0];
    return { 
        bool  => 1,
        match => { 'word'=> $1 },
        tail  => $2,
        ( $_[2]->{capture} ? ( capture => [ $1 ] ) : () ),
    }
        if $_[0] =~ /^([_[:alnum:]]+)(.*)/s;
    return;
};

sub closure {
    # p5 code is called using: "rule { xyz { v5; ... } }" (audreyt on #perl6)
    # or: "rule { ... [:perl5:: this is p5 ] ... }"
    # or: "[:perl5(1) this is perl5 ]" (putter on #perl6)

    my ( $code, $tail ) = $_[0] =~ /^\{(.*?)\}(.*)/s;
    return unless defined $code;
    #print "parsing $code - $tail\n";
    my $result = eval $code;
    return { 
        bool  => 1,
        match => { code => $result },
        tail  => $tail,
        capture => [ { closure => $result } ],
    }
}

sub subrule {
    my ( $code, $tail ) = $_[0] =~ /^\<(.*?)\>(.*)/s;
    return unless defined $code;
    #print "parsing subrule $code\n";
    return { 
        bool  => 1,
        match => { code => $code },
        tail  => $tail,
        capture => [ { subrule => $code } ],
    }
}

*non_capturing_group =
    ruleop::capture( 'non_capturing_group',
      ruleop::concat(
        ruleop::constant( '[' ),
        \&rule,
        ruleop::constant( ']' )
      ),
    );

*capturing_group = 
    ruleop::capture( 'capturing_group',
      ruleop::concat(
        ruleop::constant( '(' ),
        \&rule,
        ruleop::constant( ')' )
      ),
    );

*dot = 
    ruleop::capture( 'dot', 
        ruleop::constant( '.' ),
    );

# <'literal'>
*literal = 
    ruleop::capture( 'literal',
        ruleop::concat(    
            ruleop::constant( "<\'" ),
            ruleop::non_greedy_star( \&any ),
            ruleop::constant( "\'>" ),
        ),
    );

use vars qw( @rule_terms );
@rule_terms = (
            \&closure,
            \&subrule,
            \&capturing_group,
            \&non_capturing_group,
            \&word,
            \&escaped_char,
            \&literal,
            \&dot,
);

# <ws>* [ <closure> | <subrule> | ... ]
*term = 
    ruleop::concat(
        ruleop::greedy_star( \&ws ),
        ruleop::alternation( \@rule_terms ),
    );

# XXX - allow whitespace everywhere

# [ <term>[\*|\+] | <term> 
# note: <term>\* creates a term named 'star'
*quantifier = 
    ruleop::alternation( 
      [
        ruleop::capture( 'star', 
            ruleop::concat(
                \&term,
                ruleop::alternation( [
                    ruleop::constant( '?' ),
                    ruleop::constant( '*?' ),
                    ruleop::constant( '+?' ),
                    ruleop::constant( '*' ),
                    ruleop::constant( '+' ),
                ] ),
            ),
        ),
        \&term,
      ]
    );

# [ <term> [ \| <term> ]+ | <term> ]* 
# note: <term>|<term> creates a term named 'alt'
# XXX - 'alt' position is wrong
*rule = 
    ruleop::greedy_star (
        ruleop::alternation( 
          [
            ruleop::capture( 'alt', 
                ruleop::concat(
                    \&quantifier,
                    ruleop::greedy_plus(
                        ruleop::concat(
                            ruleop::constant( '|' ),
                            \&quantifier,
                        ),
                    ),
                ),
            ),                
            \&quantifier,
          ]
        ),
    );

}

#------ rule emitter

my $namespace = 'grammar1::';
sub emit_rule {
    my $n = $_[0];
    my $tab = $_[1]; $tab .= '  ';
    local $Data::Dumper::Indent = 0;
    #print "emit_rule: ", ref($n)," ",Dumper( $n ), "\n";

    # XXX - not all nodes are actually used

    if ( $n eq 'null' ) {
        # <null> match
        return;
    }
    if ( ref( $n ) eq 'ARRAY' ) {
        my @s;
        for ( @$n ) {
            #print "emitting array item\n";
            push @s, emit_rule( $_, $tab );
        }
        return $s[0] unless $s[1];
        return $s[1] unless $s[0];

        return $s[0].$s[1] unless $s[0];
        return $s[0].$s[1] unless $s[1];

        return "$tab ruleop::concat(\n" . 
               $s[0] . "$tab ,\n" . $s[1] . "$tab )\n";
    }
    elsif ( ref( $n ) eq 'HASH' ) 
    {
        my ( $k, $v ) = each %$n;
        #print "$tab $k => $v \n";
        if ( $k eq 'capturing_group' ) {
            $v = $v->[1][0];  # remove '( )'
            return "$tab ruleop::capture(\n" .
                   emit_rule( $v, $tab ) . "$tab )\n";
        }        
        elsif ( $k eq 'non_capturing_group' ) {
            local $Data::Dumper::Indent = 1;
            # print "*** \$v:\n",Dumper $v;
            $v = $v->[1][0];  # remove '[ ]'
            # print "*** \$v:\n",Dumper $v;
            return emit_rule( $v, $tab );
        }        
        elsif ( $k eq 'star' ) {
            my $quantifier = pop @$v;  # '*' or '+'
            $quantifier = $quantifier->{'constant'};
            my $sub = { 
                    '*' =>'greedy_star',     
                    '+' =>'greedy_plus',
                    '*?'=>'non_greedy_star', 
                    '+?'=>'non_greedy_plus',
                    '?' =>'optional',
                }->{$quantifier};
            # print "*** \$quantifier:\n",Dumper $quantifier;
            die "quantifier not implemented: $quantifier" 
                unless $sub;
            return "$tab ruleop::$sub(\n" .
                   emit_rule( $v, $tab ) . "$tab )\n";
        }        
        elsif ( $k eq 'alt' ) {
            # local $Data::Dumper::Indent = 1;
            my @alt = ( $v->[0] );
            # print "*** \$v:\n",Dumper $v;
            while(1) {
                $v = $v->[1];
                last unless defined $v->[0][1];
                push @alt, $v->[0][1];
            }
            #print "*** \@alt:\n",Dumper @alt;

            my @emit = map { 
                   emit_rule( $_, $tab ) .
                   "$tab ,\n" 
                 } @alt;

            return "$tab ruleop::alternation( [\n" . 
                   join( '', @emit ) .
                   "$tab ] )\n";
        }        
        elsif ( $k eq 'code' ) {
            # return "$tab # XXX code - compile '$v' ?\n";
            return "$tab $v  # XXX - code\n";  
        }        
        elsif ( $k eq 'ws' ) {
            return;
        }
        elsif ( $k eq 'dot' ) {
            return "$tab \\&{'${namespace}any'}\n";
        }
        elsif ( $k eq 'subrule' ) {
            return "$tab \\&{'$namespace$v'}\n";
        }
        elsif ( $k eq 'constant' ) {
            return "$tab ruleop::constant( '$v' )\n";
        }
        elsif ( $k eq 'escaped_char' ) {
            return "$tab ruleop::constant( '". substr( $v, 1 ) ."' )\n";
        }
        elsif ( $k eq 'word' ) {
            return "$tab ruleop::constant( '$v' )\n";
        }
        else {
            die "unknown node: ", Dumper( $n );
        }
    }
    else 
    {
        die "unknown node: ", Dumper( $n );
    }
}

1;
