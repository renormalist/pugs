# pX/Common/p6rule.pl - fglock
#
# experimental implementation of p6-regex parser
#
# see: README

# TODO $var := (capture)

use strict;
use warnings;

use Data::Dumper;

require 'iterator_engine.pl';
require 'p6rule_lib.pl';

my $namespace = 'grammar1::';

{
  package grammar1;

  use Data::Dumper;
  no warnings 'once';

sub subrule {
    my ( $code, $tail ) = $_[0] =~ /^\<(.*?)\>(.*)$/s;
    return unless defined $code;
    #print "parsing subrule $code\n";
    return { 
        bool  => 1,
        match => { code => $code },
        tail  => $tail,
        capture => [ { subrule => $code } ],
    }
}

# XXX - compile non_capturing_subrule using a rule
# XXX - set non-capture flag
sub non_capturing_subrule {
    my ( $code, $tail ) = $_[0] =~ /^\<\?(.*?)\>(.*)$/s;
    return unless defined $code;
    # print "non_capturing_subrule $code - $1\n";
    return { 
        bool  => 1,
        match => { code => $code },
        tail  => $tail,
        capture => [ { non_capturing_subrule => $code } ],
    }
}

# XXX - compile negated_subrule using a rule
sub negated_subrule {
    my ( $code, $tail ) = $_[0] =~ /^\<\!(.*?)\>(.*)$/s;
    return unless defined $code;
    # print "negated_subrule $code - $1\n";
    return { 
        bool  => 1,
        match => { code => $code },
        tail  => $tail,
        capture => [ { negated_subrule => $code } ],
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
        ruleop::capture( 'constant',
            ruleop::non_greedy_star( \&any ),
        ),
        ruleop::constant( "\'>" ),
    ),
    ruleop::capture( 'constant', \&word ),
    ruleop::capture( 'constant', \&escaped_char )
);

use vars qw( @rule_terms );
@rule_terms = (
    \&capturing_group,
    @literals,
    \&negated_subrule,
    \&non_capturing_subrule,
    \&subrule,
    \&dot,
    # more items are pushed later - see below 
);

# <ws>* [ <closure> | <subrule> | ... ]
*term = 
    ruleop::concat(
        \&ws_star,
        ruleop::alternation( \@rule_terms ),
        \&ws_star,
    );

# XXX - allow whitespace everywhere

# [ <term>[\*|\+] | <term> 
# note: <term>\* creates a term named 'star'
*quantifier = 
    ruleop::alternation( [
        ruleop::capture( 'star', 
            ruleop::concat(
                ruleop::capture( 'term', \&term ),
                ruleop::capture( 'literal',
                    ruleop::alternation( [
                        ruleop::constant( '??' ),
                        ruleop::constant( '?' ),
                        ruleop::constant( '*?' ),
                        ruleop::constant( '+?' ),
                        ruleop::constant( '*' ),
                        ruleop::constant( '+' ),
                    ] ),
                ),
                \&ws_star,
            ),
        ),
        \&term,
    ] );

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

# [<rule>]
*non_capturing_group = ::compile_rule( ' \[ <rule> \] ', {print_program=>0} );
push @rule_terms, \&non_capturing_group;

# { code }
    # p5 code is called using: "rule { xyz { v5; ... } }" (audreyt on #perl6)
    #   (but TimToady said it's not)
    # or: "rule { ... [:perl5:: this is p5 ] ... }"
    # or: "[:perl5(1) this is perl5 ]" (putter on #perl6)
    
# XXX - this is veeery slow - the actual implementation is in file
#       p6rule_lib.pl and uses Text::Balanced
# *code = ::compile_rule( '\{[<code>|.]*?\}' );
unshift @rule_terms, ruleop::capture( 
    'closure', \&code );
    
# $var
# -- ident, variable moved to p6rule_lib.pl
#*ident =    ::compile_rule( '[[\:\:]?<word>]+', {print_ast=>0} );
#*variable = ::compile_rule( '[\$|\%|\@]<ident>' );
#push @rule_terms, ruleop::capture( 'variable',\&variable );
unshift @rule_terms, ruleop::capture( 
    'variable', \&variable );
    #ruleop::wrap( { 
    #        before => sub { print "matching variable: $_[0]\n" },
    #        after  => sub { $_[0]->{bool} ? print "variable matched\n" : print "no variable match\n" },
    #    },
    #    \&variable
    #);

# <@var> is a run-time alternation (TimToady on #perl6)
*runtime_alternation = ::compile_rule( 
    '\< <variable> \>' );
unshift @rule_terms, ruleop::capture( 
    'runtime_alternation',\&runtime_alternation );

# $xxx := (capture)
*named_capture = ::compile_rule( 
    '\$ <ident> <?ws>? \:\= <?ws>? \( <rule> \)' );  # XXX - accept % @
unshift @rule_terms, ruleop::capture( 
    'named_capture',\&named_capture );

}

#------ match functions

=for reference - see S05 "Return values from matches"
    $/    
        the match 
        Inside a closure, refers to the current match, even if there is another
        match inside the closure
    $/()  
        just the capture - what's returned in { return ... }
    $/0
        the first submatch
Alternate names:        
    $()   
        the same as $/()
Submatches:
    $/[0] 
        the first submatch
    $0 
        the same as $/[0]
    $()<a>
        If the capture object return()-ed were a hash:
        the value $x in { return { a => $x ,} }
Named captures:
    $a := (.*?)  
        $a is something in the outer lexical scope (TimToady on #perl6)
            XXX - E05 says it is a hypothetical variable, referred as $0<a>
    $<a> := (.*?)  
        $<a> is a named capture in the match
    let $a := (.*?)
        $a is a hypothetical variable
                (\d+)     # Match and capture one-or-more digits
                { let $digits := $1 }
=cut

sub match::get {
    my $match =   $_[0];
    my $name =    $_[1];
    
    return $match->{capture}  if $name eq '$/()' || $name eq '$()';
    
    # XXX - wrong, but bug-compatible with previous versions
    return $match->{capture}  if $name eq '$/<>' || $name eq '$<>';
    
    return $match->{match}    if $name eq '$/';
    
    #print "get var $name\n";
    
    # XXX - wrong, but bug-compatible with previous versions
    # $/<0>, $/<1>
    # $<0>, $<1>
    if ( $name =~ /^ \$ \/? <(\d+)> $/x ) {
        my $num = $1;
        my $n = 0;
        for ( @{ match::get( $match, '$/()' ) } ) {
            next unless ref($_) eq 'HASH';
            if ( $num == $n ) {
                my (undef, $capture) = each %$_;
                #print "cap\n", Dumper( $capture );
                return $capture;
            }
            $n++;
        }
        return;
    }
    
    # $/()<name>
    # $()<name>
    if ( $name =~ /^ \$ \/? \( \) <(.+)> $/x ) {
        my $n = $1;
        for ( @{ match::get( $match, '$/()' ) } ) {
            next unless ref($_) eq 'HASH';
            if ( exists $_->{$n} ) {
                #print "cap\n", Dumper( $_->{$n} );
                return $_->{$n};
            }
        }
        return;
    }

    # XXX - wrong, but bug-compatible with previous versions
    # $/<name>
    # $<name>
    if ( $name =~ /^ \$ \/? <(.+)> $/x ) {
        my $n = $1;
        for ( @{ match::get( $match, '$()' ) } ) {
            next unless ref($_) eq 'HASH';
            if ( exists $_->{$n} ) {
                #print "cap\n", Dumper( $_->{$n} );
                return $_->{$n};
            }
        }
        return;
    }

    die "match variable $name is not implemented";
    # die "no submatch like $name in " . Dumper( $match->{match} );
}

sub match::str {
    my $match = $_[0];
    #print "STR: ", ref( $match ), " ", Dumper( $match ), "\n";
    return join( '', map { match::str( $_ ) } @$match )
        if ref( $match ) eq 'ARRAY';
    return join( '', map { match::str( $_ ) } values %$match )
        if ref( $match ) eq 'HASH';
    return $match;
}

#------ rule emitter

# compile_rule( $source, {flag=>value} );
#
# flags:
#   print_program=>1 - prints the generated program
#
sub compile_rule {
    local $Data::Dumper::Indent = 1;
    #print "compile_rule: $_[0]\n";
    my $match = grammar1::rule->( $_[0] );
    my $flags = $_[1];
    print "ast:\n", Dumper( $match->{capture} ) if $flags->{print_ast};
    die "syntax error in rule '$_[0]' at '" . $match->{tail} . "'\n"
        if $match->{tail};
    die "syntax error in rule '$_[0]'\n"
        unless $match->{bool};
    my $program = main::emit_rule( $match->{capture} );
    print "generated rule:\n$program" if $flags->{print_program};
    my $code = eval($program); die $@ if $@;
    return $code;
}

sub emit_rule_node {
    die "unknow node type:$_[0]" unless $node::{$_[0]};
    no strict 'refs';
    my $code = &{"node::$_[0]"}($_[1],$_[2]);
#   print Dumper(@_,$code),"\n";
    return $code;
}
sub return_block_hack {
	my $tab = shift;
	my @s =   @_;
        if (@s && $s[-1] =~ /^#return-block#(.*)/s ) {
            #print "return block\n";
            my $code = $1;
            #print "Code: $code\n";
            pop @s;
            my $program;
            if ( @s == 1 ) {
                $program = $s[0];
            }
            else {
                $program = "$tab ruleop::concat(\n" . 
                            ( join '', @s ) . 
                            "$tab )\n";
            }
            #print "program $program\n";
            my $return;
            $return = "
    sub { 
        my \$rule = \n$program    ;
        my \$match = \$rule->( \@_ );
        return unless \$match;
        my \$capture_block = sub " . $code . "; 
        #use Data::Dumper;
        #print \"capture was: \", Dumper( \$match->{capture} );
        return { 
            \%\$match,
            capture => [ \$capture_block->( \$match ) ],
        }; 
    }\n";
            return $return;
        }
        return $s[0] if @s == 1;
        return "$tab ruleop::concat(\n" . 
               ( join '', @s ) . 
               "$tab )\n";
}
sub emit_rule {
    my $n = $_[0];
    my $tab = $_[1] || '    '; 
    $tab .= '  ';
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

        # XXX XXX XXX - source-filter 
        #    temporary hacks to translate p6 to p5 -- see 'closure' node
	
	return return_block_hack($tab,@s);
    }
    elsif ( ref( $n ) eq 'HASH' ) 
    {
        my ( $k, $v ) = each %$n;
        # print "$tab $k => $v \n";
        return '' unless defined $v;  # XXX a bug?
	emit_rule_node($k,$v,$tab);
    }
    else 
    {
        die "unknown node: ", Dumper( $n );
    }
}

#rule nodes
sub node::rule {
    return emit_rule( $_[0], $_[1] );
    #return "$_[1] ruleop::capture( '$_[2]',\n" .
    #       emit_rule( $_[0], $_[1] ) . "$_[1] )\n";
}        
sub node::capturing_group {
    return "$_[1] ruleop::capture( 'capturing_group',\n" .
           emit_rule( $_[0], $_[1] ) . "$_[1] )\n";
}        
sub node::non_capturing_group {
    return emit_rule( $_[0], $_[1] );
}        
sub node::star {
    local $Data::Dumper::Indent = 1;
    my $term = $_[0]->[0]{'term'};
    #print "*** \$term:\n",Dumper $term;
    my $quantifier = $_[0]->[1]{'literal'}[0];
    my $sub = { 
            '*' =>'greedy_star',     
            '+' =>'greedy_plus',
            '*?'=>'non_greedy_star', 
            '+?'=>'non_greedy_plus',
            '?' =>'optional',
            '??' =>'null_or_optional',
        }->{$quantifier};
    # print "*** \$quantifier:\n",Dumper $quantifier;
    die "quantifier not implemented: $quantifier" 
        unless $sub;
    return "$_[1] ruleop::$sub(\n" .
           emit_rule( $term, $_[1] ) . "$_[1] )\n";
}        
sub node::alt {
    # local $Data::Dumper::Indent = 1;
    # print "*** \$_[0]:\n",Dumper $_[0];
    my @s;
    for ( @{$_[0]} ) { 
        my $tmp = emit_rule( $_, $_[1] );
        push @s, $tmp if $tmp;   
    }
    return "$_[1] ruleop::alternation( [\n" . 
           join( '', @s ) .
           "$_[1] ] )\n";
}        
sub node::term {
    return emit_rule( $_[0], $_[1] );
}        
sub node::code {
    # return "$_[1] # XXX code - compile '$_[0]' ?\n";
    return "$_[1] $_[0]  # XXX - code\n";  
}        
sub node::dot {
    return "$_[1] \\&{'${namespace}any'}\n";
}
sub node::subrule {
    my $name = $_[0];
    $name = $namespace . $_[0] unless $_[0] =~ /::/;
    return "$_[1] ruleop::capture( '$_[0]', \\&{'$name'} )\n";
}
sub node::non_capturing_subrule {
    return "$_[1] \\&{'$namespace$_[0]'}\n";
}
sub node::negated_subrule {
    return "$_[1] ruleop::negate( \\&{'$namespace$_[0]'} )\n";
}
sub node::constant {
    my $literal = shift;
    my $name = quotemeta(join('',@$literal));
    return "$_[0] ruleop::constant( \"$name\" )\n";
}
sub node::variable {
    my $name = match::str( $_[0] );
    # print "var name: ", match::str( $_[0] ), "\n";
    my $value = "sub { die 'not implemented: $name' }\n";
    $value = eval $name if $name =~ /^\$/;
    $value = join('', eval $name) if $name =~ /^\@/;

    # XXX - what hash/code interpolate to?
    # $value = join('', eval $name) if $name =~ /^\%/;

    return "$_[1] ruleop::constant( '" . $value . "' )\n";
}
sub node::closure {
    my $code = match::str( $_[0] ); 
    
    # XXX XXX XXX - source-filter - temporary hacks to translate p6 to p5
    # $()<name>
    $code =~ s/ ([^']) \$ \( \) < (.*?) > /$1 match::get( \$_[0], '\$()<$2>' ) /sgx;
    # $<name>
    $code =~ s/ ([^']) \$ < (.*?) > /$1 match::get( \$_[0], '\$<$2>' ) /sgx;
    # $()
    $code =~ s/ ([^']) \$ \( \) /$1 match::get( \$_[0], '\$()' ) /sgx;
    #print "Code: $code\n";
    
    return "$_[1] sub {\n" . 
           "$_[1]     $code;\n" . 
           "$_[1]     return { bool => 1, tail => \$_[0] } }\n"
        unless $code =~ /return/;
    return "#return-block#" . $code;
}
sub node::runtime_alternation {
    my $code = match::str( match::get( 
        { capture => $_[0] }, 
        '$<variable>'
    ) );
    return "$_[1] ruleop::alternation( \\$code )\n";
}
sub node::named_capture {
    my $name = match::str( match::get( 
        { capture => $_[0] }, 
        '$<ident>'
    ) );
    my $program = emit_rule(
            match::get( 
                { capture => $_[0] }, 
                '$<rule>'
            ), $_[1] );
    return "$_[1] ruleop::capture( '$name', \n" . $program . "$_[1] )\n";
}
1;
