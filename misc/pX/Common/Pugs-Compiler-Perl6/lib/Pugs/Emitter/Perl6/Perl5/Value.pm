use strict;
use warnings;
# Compile-time Perl 5 thing, with hardcoded, autoboxed  methods

# operator name mangler:
# perl Runtime::Common -e ' print Pugs::Runtime::Common::mangle_ident("==") '


package Pugs::Emitter::Perl6::Perl5::Value;
    use base 'Pugs::Emitter::Perl6::Perl5::Any';
package Pugs::Emitter::Perl6::Perl5::Bool;
    use base 'Pugs::Emitter::Perl6::Perl5::Value';
    use overload (
        '""'     => sub { $_[0]->{name} ? '1' : '0' },
        fallback => 1,
    );
    sub WHAT { 
        return Pugs::Emitter::Perl6::Perl5::Str->new( { name => 'Bool' } );
    }
    sub str {
        return Pugs::Emitter::Perl6::Perl5::Str->new( 
            { name => ( $_[0]->{name} ? '1' : '0' ) } );
    }
    sub int {
        return Pugs::Emitter::Perl6::Perl5::Int->new( 
            { name => ( $_[0]->{name} ? '1' : '0' ) } );
    }
    sub num {
        return Pugs::Emitter::Perl6::Perl5::Num->new( 
            { name => ( $_[0]->{name} ? '1' : '0' ) } );
    }
    sub perl {
        $_[0]->str;
    }
    sub true {
        $_[0]
    }
    sub not {
        $_[0]->{name} 
        ? Pugs::Emitter::Perl6::Perl5::Bool->new( { name => 0 } ) 
        : Pugs::Emitter::Perl6::Perl5::Bool->new( { name => 1 } )
    }
    sub _61__61_ {  # ==
        $_[0]->int->_61__61_( $_[1] );
    }
package Pugs::Emitter::Perl6::Perl5::Str;
    use base 'Pugs::Emitter::Perl6::Perl5::Value';
    use overload (
        '""'     => sub { "'" . $_[0]->{name} . "'" },
        fallback => 1,
    );
    sub WHAT { 
        return Pugs::Emitter::Perl6::Perl5::Str->new( { name => 'Str' } );
    }
    sub str {
        $_[0]
    }
    sub perl {
        $_[0]
    }
    sub scalar {
        return Pugs::Emitter::Perl6::Perl5::Perl5Scalar->new( {
            name => 'bless \\' . $_[0]->perl . 
                    ", 'Pugs::Runtime::Perl6::Str'" 
        } );
    }
    sub eq {
        Pugs::Emitter::Perl6::Perl5::BoolExpression->new( 
            { name => $_[0] . " eq " . $_[1]->str } );
    }
package Pugs::Emitter::Perl6::Perl5::Int;
    use base 'Pugs::Emitter::Perl6::Perl5::Value';
    use overload (
        '""'     => sub { $_[0]->{name} },
        fallback => 1,
    );
    sub WHAT { 
        return Pugs::Emitter::Perl6::Perl5::Str->new( { name => 'Int' } );
    }
    sub str {
        return Pugs::Emitter::Perl6::Perl5::Str->new( { name => $_[0]->{name} } );
    }
    sub num {
        return Pugs::Emitter::Perl6::Perl5::Num->new( { name => $_[0]->{name} } );
    }
    sub perl {
        $_[0]->str
    }
    sub _61__61_ {  # ==
        $_[0]->num->_61__61_( $_[1] );
    }
package Pugs::Emitter::Perl6::Perl5::Num;
    use base 'Pugs::Emitter::Perl6::Perl5::Value';
    use overload (
        '""'     => sub { $_[0]->{name} },
        fallback => 1,
    );
    sub WHAT { 
        return Pugs::Emitter::Perl6::Perl5::Str->new( { name => 'Num' } );
    }
    sub str {
        return Pugs::Emitter::Perl6::Perl5::Str->new( { name => $_[0]->{name} } );
    }
    sub perl {
        $_[0]->str
    }
    sub _61__61_ {  # ==
        my $tmp = $_[1]->num;
        return Pugs::Emitter::Perl6::Perl5::Bool->new( 
            { name => ( $_[0] == $tmp ) } )
            if ref( $tmp ) eq 'Pugs::Emitter::Perl6::Perl5::Num';
        return Pugs::Emitter::Perl6::Perl5::BoolExpression->new( 
            { name => $_[0] . " == " . $tmp } );
    }
package Pugs::Emitter::Perl6::Perl5::Code;
    use base 'Pugs::Emitter::Perl6::Perl5::Value';
    use overload (
        '""'     => sub { 'sub { ' . $_[0]->{name} . ' } ' },
        fallback => 1,
    );
    sub WHAT { 
        return Pugs::Emitter::Perl6::Perl5::Str->new( { name => 'Code' } );
    }
    sub str {
        return Pugs::Emitter::Perl6::Perl5::Str->new( { name => $_[0]->{name} } );
    }
    sub perl {
        $_[0]->str
    }

1;
