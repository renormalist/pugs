=pod

Perl 6's grammar written as a Perl 6 rules.  A prerequisite for self hosting.

=cut

use v6;

grammar Perl6::Grammar;

# Top level structures

rule code { <-[{}]>* } # a section of code

#rule block { \{ <code> \} } # a block of code
# pugs parsing problem? - 2005 Jul 31
rule block { <[{]> <code> <[}]> } # a block of code

# subs and sub-like structures

rule lexicalsub :w { # from A06
        <lexscope> <type>?
        <submodifer>? <subintro> <subname> <psignature>?
        <trait>*
        <block>
}

rule lexicalsub :w { # from A06
        <lexscope> <type>?
        <submodifer>? <subintro> <subname> <psignature>?
        <trait>*
        <block>
}
rule packagesub :w { # from A06
        <submodifer> <subintro> <subname> <psignature>?
        <trait>*
        <block>
}

rule anonsub :w {
        <subintro> <psignature>?
        <trait>*
        <block>
}

# Pointy subs

rule pointysub :w { # from A06
        -\> <signature> <block>
}

# Variables 
# From A06

rule sigil { <[$@%&]> <[*.?^]>? }   # "What is that, swearing?"
rule variable { <sigil> <nameZZ> [ \( <siglet> \) ]? }

# Bare subs
# from A06

#rule baresub :w {
#        <block> { .find_placeholders() }
#}

# Identifiers

rule name_sec { <-[0..9:.]> <-[:]>* };

rule nameZZ {  <name_sec>
             | [\:\: <name_sec> ]+
             | <name_sec> [\:\: <name_sec> ]+};

## What is the difference between an ident, a name and a subname
## A06 doesn't tell me even though it uses them.  These are guesses
## until we are enlightened.

rule subname { \*? <nameZZ> };

rule identZZ { <nameZZ> };

# Numbers

# base 10

rule natural { <digit> [_* <digit> _*]* };

rule Int {[\+|\-]? <natural>};

rule decimal { <Int> [\. <natural>? ]?
              | [\+|\-]? \. <natural>
             };

rule Rat  { <decimal> [ [e|E] <Int>]? };

# base N

rule binary { 0b <[01]>+ };

rule hex    { 0x <[0..9a..fA..F]>+};

rule oct    { 0o <[0..7]>+};

# any perl style number

rule Num { Int | Rat | binary | hex | oct  };

# these are defined in A06

# Siglets

rule siglet :w {
        [<paramlet> [<[,:]> <paramlet> ]* ]?
}

#rule paramlet :w {
#        [ <type> <zone>? <varlet>? <trait>*     # require type
#        | <zone> <varlet>? <trait>*             # or zone
#        | <varlet> <trait>*                     # or varlet
#        | \[ <siglet> \]        # treat single array ref as an arg list
#        ]
#}
# comments appear to be poisonous - 2005 Jul 31
rule paramlet :w {
        [ <type> <zone>? <varlet>? <trait>*
        | <zone> <varlet>? <trait>*
        | <varlet> <trait>*
        | \[ <siglet> \]
        ]
}

rule varlet :w {
        <sigil> [ \( <siglet> \) ]?
}

# Defaults

rule defval :w { \= <item> }

# Placeholders

rule placeholder { <sigil> \^ <identZZ> }

# Formal parameter syntax

#rule parameter :w {
#        [ <type>? <zone>? <variable> <trait>* <defval>?
#        | \[ <signature> \]     # treat single array ref as an arg list
#        ]
#}
# comments appear to be poisonous - 2005 Jul 31
rule parameter :w {
         [ <type>? <zone>? <variable> <trait>* <defval>?
         | \[ <signature> \]
         ]
}


rule type { yada type }
rule zone { yada zone }

rule signature :w {
        [<parameter> [<[,:]> <parameter> ]* ]?
}

# The sub form

rule subintro { sub | method | submethod | rule | macro }

rule lexscope { my | our }

rule submodifer { multi }

rule psignature :w { \( <signature> \) }

rule psiglet :w { \( <siglet> \) }

rule scopedsubvar :w {
        <lexscope> <type>? &<subname> <psiglet>? <trait>*
}

rule unscopedsubvar :w {
        &<subname> <psiglet>? <trait>*
}

rule trait :w {
          is <identZZ>[\( <traitparam> \)]?
        | will <identZZ> <closure>
        | of <type>
        | returns <type>
}

rule traitparam { yada traitparam }
rule closure { yada closure }
