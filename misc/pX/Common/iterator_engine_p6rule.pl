# pX/Common/iterator_engine_p6rule.pl - fglock
#
# experimental implementation of p6-regex parser
#
# see: iterator_engine_README

# TODO $var := (capture)

use strict;
use warnings;

require 'iterator_engine.pl';
require 'iterator_engine_p6rule_lib.pl';

my $namespace = 'grammar1::';

{
  package grammar1;

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

*capturing_group = 
    ruleop::concat(
        ruleop::constant( '(' ),
        ruleop::capture( 'capturing_group',
            \&rule,
        ),
        ruleop::constant( ')' )
    );

*dot = 
    ruleop::capture( 'dot', 
        ruleop::constant( '.' ),
    );

# <'literal'> literal \*
my @literals = (
    ruleop::concat(    
        ruleop::constant( "<\'" ),
        ruleop::capture( 'literal',
            ruleop::non_greedy_star( \&any ),
        ),
        ruleop::constant( "\'>" ),
    ),
    ruleop::capture( 'literal', \&word ),
    ruleop::capture( 'literal', \&escaped_char )
);

use vars qw( @rule_terms );
@rule_terms = (
            \&closure,
            \&capturing_group,
            # \&non_capturing_group,
            @literals,
            \&subrule,
            \&dot,
);

# <ws>* [ <closure> | <subrule> | ... ]
*term = 
    ruleop::concat(
        ruleop::greedy_star( \&ws ),
        ruleop::alternation( \@rule_terms ),
        ruleop::greedy_star( \&ws ),
    );

# XXX - allow whitespace everywhere

# [ <term>[\*|\+] | <term> 
# note: <term>\* creates a term named 'star'
*quantifier = 
    ruleop::alternation( 
      [
        ruleop::capture( 'star', 
            ruleop::concat(
                ruleop::capture( 'term', \&term ),
                ruleop::capture( 'literal',
                  ruleop::alternation( [
                    ruleop::constant( '?' ),
                    ruleop::constant( '*?' ),
                    ruleop::constant( '+?' ),
                    ruleop::constant( '*' ),
                    ruleop::constant( '+' ),
                  ] ),
                ),
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
                    ruleop::capture( 'term', \&quantifier ),
                    ruleop::greedy_plus(
                        ruleop::concat(
                            ruleop::constant( '|' ),
                            ruleop::capture( 'term', \&quantifier ),
                        ),
                    ),
                ),
            ),                
            \&quantifier,
          ]
        ),
    );

*non_capturing_group = ::compile_rule( ' \[ <rule> \] ' );
push @rule_terms, \&non_capturing_group;

}

#------ rule emitter

sub compile_rule {
    my $match = grammar1::rule->( $_[0] );
    die "syntax error in rule '$_[0]' at '" . $match->{tail} . "'\n"
        if $match->{tail};
    my $program = main::emit_rule( $match->{capture} );
    #print "generated rule:\n$program";
    my $code = eval($program); die $@ if $@;
    return $code;
}

sub emit_rule {
    my $n = $_[0];
    my $tab = $_[1]; $tab .= '  ';
    local $Data::Dumper::Indent = 0;
    #print "emit_rule: ", ref($n)," ",Dumper( $n ), "\n";

    # XXX - not all nodes are actually used

    if ( ref($n) eq '' ) {
        # XXX - this should not happen, but it does
        return '';
    }
    if ( ref( $n ) eq 'ARRAY' ) {
        my @s;
        for ( @$n ) {
            #print "emitting array item\n";
            my $tmp = emit_rule( $_, $tab );
            push @s, $tmp . "$tab ,\n" if $tmp;
        }
        return $s[0] if @s == 1;

        return "$tab ruleop::concat(\n" . 
               ( join '', @s ) . 
               "$tab )\n";
    }
    elsif ( ref( $n ) eq 'HASH' ) 
    {
        my ( $k, $v ) = each %$n;
        #print "$tab $k => $v \n";
        if ( $k eq 'capturing_group' ) {
            return "$tab ruleop::capture( 'capturing_group',\n" .
                   emit_rule( $v, $tab ) . "$tab )\n";
        }        
        elsif ( $k eq 'non_capturing_group' ) {
            return emit_rule( $v, $tab );
        }        
        elsif ( $k eq 'star' ) {
            local $Data::Dumper::Indent = 1;
            my $term = $v->[0]{'term'};
            #print "*** \$term:\n",Dumper $term;
            my $quantifier = $v->[1]{'literal'}[0];
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
                   emit_rule( $term, $tab ) . "$tab )\n";
        }        
        elsif ( $k eq 'alt' ) {
            # local $Data::Dumper::Indent = 1;
            # print "*** \$v:\n",Dumper $v;
            my @s;
            for ( @$v ) { 
                my $tmp = emit_rule( $_, $tab );
                push @s, $tmp if $tmp;   
            }
            return "$tab ruleop::alternation( [\n" . 
                   join( '', @s ) .
                   "$tab ] )\n";
        }        
        elsif ( $k eq 'term' ) {
            return emit_rule( $v, $tab );
        }        
        elsif ( $k eq 'code' ) {
            # return "$tab # XXX code - compile '$v' ?\n";
            return "$tab $v  # XXX - code\n";  
        }        
        elsif ( $k eq 'dot' ) {
            return "$tab \\&{'${namespace}any'}\n";
        }
        elsif ( $k eq 'subrule' ) {
            #print Dumper $v;
            return "$tab \\&{'$namespace$v'}\n";
        }
        elsif ( $k eq 'literal' ) {
            #print "literal:", Dumper($v);
            return "$tab ruleop::constant( '" . join('',@$v) . "' )\n";
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
