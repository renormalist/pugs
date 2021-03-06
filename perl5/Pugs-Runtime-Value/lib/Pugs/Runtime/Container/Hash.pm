
# This is a Perl5 file

# ChangeLog
#
# 2005-09-06
# * new class Pugs::Runtime::Container::Hash::Native
#
# 2005-09-05
# * delete hash element
#
# 2005-08-31
# * New methods: tied(), keys(), values(), pairs(), kv()
# * Fixed elems(), buckets() to return boxed Int, Str
# * hash iterator (firstkey/nextkey) works
#
# 2005-08-19
# * New Perl6 class 'Hash'
#
# 2005-08-18
# * New Perl5 class "Pugs::Runtime::Container::Hash::Object"
#   implements a hash in which the keys can be objects
#
# 2005-08-14
# * added functions clone(), elems(), buckets()


# TODO - warn for odd number of elements, on construction
# TODO - keys(), values(), pairs(), kv() - lazy (non-infinite)
# TODO - each() methods
# TODO - hash cells with rw, ro, binding hash elements
# TODO - tied hashes

# TODO - delete hash slice

# TODO - %a = %b - whole hash fetch/store
#        PIL-Run - %a = { a=>'b', c=>'d' } generates: {({(c, d), (a, b)}, undef)}
# TODO - pick()
#        Does pick remove the element? (Hash and Array)

# TODO - (iblech) probably with a warning "uninitialized warning used in numeric contect"
#        (Same for hashes: %h{undef} =:= %h{""})
# TODO - is (undef=>undef) a valid Pair?
#        fglock PIL-Run currently prints {('undef', undef)}
#        buu fglock: For which?
#        fglock for { undef=>undef }
#        iblech fglock: Right, I'd think so (and this is how I've implemented it in PIL2JS). 
#        But: By default, hash can autoconvert their keys to Strs, so {undef()=>undef} would have 
#        the same effect as {""=>undef}. But if a hash is declared with shape(Any), {undef()=>undef} 
#        should create a hash with .pairs[0].key being undef

# TODO - (for PIL-Run)
#        buu iblech: Er, let me rephrase. Why did it print an error message?
#        iblech buu: Because {undef,undef} is not a hash, but a Code, and Pugs tried to coerce 
#        the Code into a Hash, but failed
#        buu Er, so how do you create a hash ref?
#        iblech buu: \hash(undef,undef), {undef() => undef}, {pair undef, undef}, etc.

# TODO - test - how does a scalar that contains a hash is accessed?
# TODO - test $x := %hash - 'undefine $x'
# TODO - test %hash := $x - error if $x is not bound to a hash
# TODO - tieable hash - cleanup AUTOLOAD
# TODO - test 'readonly'

# Notes:
# * Cell is implemented in the Pugs::Runtime::Container::Scalar package

use strict;

use Moose;
use Pugs::Runtime::Value;
use Pugs::Runtime::Container::Scalar;

my $class_description = '-0.0.1-cpan:FGLOCK';

class1 'Hash'.$class_description => {
    is => [ $::Object ],
    class => {
        attrs => [],
        methods => {}
    },
    instance => {
        attrs => [ [ '$:cell' => { 
                        access => 'rw', 
                        build => sub { 
                            my $cell = Pugs::Runtime::Cell->new;
                            my $h = bless {}, 'Pugs::Runtime::Container::Hash::Object';
                            $cell->{v} = $h;
                            $cell->{type} = 'Hash';
                            return $cell;
                        } } ] ],
        DESTROY => sub {
            # _('$:cell' => undef); # XXX - MM2.0 gc workaround
        },
        methods => { 

            # %a := %b 
            'bind' =>     sub {
                my ( $self, $thing ) = @_;
                die "argument to Hash bind() must be a Hash"
                    unless $thing->cell->{type} eq 'Hash';
                _('$:cell', $thing->cell);
                return $self;
            },
            'cell' =>     sub { _('$:cell') },  # cell() is used by bind()
            'id' =>       sub { _('$:cell')->{id} },  

            'undefine' => sub { _('$:cell')->{v}->clear },

            'tieable' =>  sub { _('$:cell')->{tieable} != 0 },
            'tie' =>      sub { shift; _('$:cell')->tie(@_) },
            'untie' =>    sub { _('$:cell')->untie },
            'tied' =>     sub { _('$:cell')->{tied} },

             # See perl5/Perl6-MetaModel/t/14_AUTOLOAD.t  
            'isa' =>      sub { ::next_METHOD() },
            'does' =>     sub { ::next_METHOD() },
            'ref' =>      sub { $::CLASS }, 

            'elems' =>    sub { Int->new( '$.unboxed' =>
                                _('$:cell')->{tied} ? 
                                _('$:cell')->{tied}->elems :
                                Pugs::Runtime::Container::Hash::elems( _('$:cell')->{v} ) )
            },
            'buckets' =>  sub { Str->new( '$.unboxed' =>
                                _('$:cell')->{tied} ? 
                                _('$:cell')->{tied}->buckets :
                                Pugs::Runtime::Container::Hash::buckets( _('$:cell')->{v} ) )
            },
            'pairs' => sub { 
                my $key = $_[0]->firstkey;
                my $ary = Array->new;
                while ( defined $key ) {
                    $ary->push( Pair->new( 
                        '$.key' =>   $key, 
                        '$.value' => $_[0]->fetch( $key ) ) );
                    $key = $_[0]->nextkey;
                }
                return $ary;
            },
            'kv' => sub { 
                my $key = $_[0]->firstkey;
                my $ary = Array->new;
                while ( defined $key ) {
                    $ary->push( $key, $_[0]->fetch( $key ) );
                    $key = $_[0]->nextkey;
                }
                return $ary;
            },
            'keys' => sub { 
                my $key = $_[0]->firstkey;
                my $ary = Array->new;
                while ( defined $key ) {
                    $ary->push( $key );
                    $key = $_[0]->nextkey;
                }
                return $ary;
            },
            'values' => sub { 
                my $key = $_[0]->firstkey;
                my $ary = Array->new;
                while ( defined $key ) {
                    $ary->push( $_[0]->fetch( $key ) );
                    $key = $_[0]->nextkey;
                }
                return $ary;
            },
            'str' => sub { 
                my $key = $_[0]->firstkey;
                my $value;
                my @pairs;
                while ( defined $key ) {
                    $value = $_[0]->fetch( $key );
                    my $p = Pair->new( '$.key'=>$key, '$.value'=>$value );
                    push @pairs, $p->str->unboxed;
                    $key = $_[0]->nextkey;
                }
                Str->new( '$.unboxed' => 
                    '{' . 
                    join(', ', @pairs) . 
                    '}' 
                );
            },
            'perl' => sub { $_[0]->str },

            # TODO - XXX - remove this after implementing hash slice
            'postcircumfix:{}' => sub { (shift)->fetch( @_ ) },
            'fetch' => sub {
                my ($self, @param) = @_;
                #warn "FETCH: @param\n";
                my $tmp = _('$:cell')->{tied} ? _('$:cell')->{tied} : _('$:cell')->{v};
                my $key = shift @param;
                if ( Pugs::Runtime::Value::p6v_isa( $key, 'Array' ) ) {
                    #warn "Hash slice $key\n";
                    warn "Infinite hash slice not supported\n" 
                        if Pugs::Runtime::Value::numify( $key->is_infinite );
                    #warn "not implemented";
                    my $a = Array->new();
                    for ( 0 .. Pugs::Runtime::Value::numify( $key->elems ) - 1 ) {
                        my $k = $key->fetch( $_ );
                        $a->push( $self->fetch( $k ) );
                        #warn "push $_ - ",Pugs::Runtime::Value::stringify( $a ),"\n";
                        #warn "bind $_ -- $k \n";
                        #$a->fetch( $_ )->bind( $self->fetch( $k ) );
                    }
                    #warn $a->fetch( 1 );
                    #warn $self->fetch( 1 );
                    #$a->fetch( 1 )->bind( $self->fetch( 1 ) );
                    return $a->slice( 0 .. Pugs::Runtime::Value::numify( $a->elems ) - 1 );
                }
                my $v = $tmp->fetch( $key );
                if ( ! Pugs::Runtime::Value::p6v_isa( $v, 'Scalar' ) ) {
                    #warn "autovivify - $key - $v\n";
                    my $s = Scalar->new;
                    $s->store( $v );
                    $tmp->store( $key, $s );
                    return $s;
                }
                return $v;
            },
            'store' => sub {
                my ($self, @param) = @_;
                my $tmp = _('$:cell')->{tied} ? _('$:cell')->{tied} : _('$:cell')->{v};
                if ( scalar @param == 1 ) {
                    # store whole hash
                    if ( Pugs::Runtime::Value::p6v_isa( $param[0], 'Hash' ) ) {
                        $self->clear;
                        my $key = $param[0]->firstkey;
                        while ( defined $key ) {
                            my $tmp = $param[0]->fetch( $key )->fetch;
                            $self->store( $key, $tmp );
                            $key = $param[0]->nextkey;
                        }
                        return $self;
                    }
                    if ( Pugs::Runtime::Value::p6v_isa( $param[0], 'Array' ) ) {
                        $self->clear;
                        for ( 0 .. $param[0]->elems->unboxed - 1 ) {
                            my $pair = $param[0]->fetch( $_ );
                            $self->store( $pair->key, $pair->value );
                        }
                        return $self;
                    }
                    if ( Pugs::Runtime::Value::p6v_isa( $param[0], 'Pair' ) ) {
                        $self->clear;
                        my $pair = $param[0];
                        $self->store( $pair->key, $pair->value );
                        return $self;
                    }
                    warn "Don't know how to store @param into a Hash";
                }
                my $key = shift @param;
                my $s = $self->fetch( $key );
                # fetch should always return Scalar
                if ( ! Pugs::Runtime::Value::p6v_isa( $tmp, 'Scalar' ) ) {
                    #warn "creating scalar";
                    $s = Scalar->new;
                    $tmp->store( $key, $s );
                }
                $s->store( @param );
                return @param;
            },
            'AUTOLOAD' => sub {
                my ($self, @param) = @_;
                my $method = __('$AUTOLOAD');
                # TODO - add support for tied hash
                # TODO - check if scalar := hash works properly
                my $tmp = _('$:cell')->{tied} ? _('$:cell')->{tied} : _('$:cell')->{v};
                # warn ref($tmp), ' ', $method, " @param == " . $tmp->$method( @param );
                return $tmp->$method( @param );
            },
        },
    }
};

# ----- unboxed functions

package Pugs::Runtime::Container::Hash::Object;

sub store {
    my ( $this, $key, $value ) = @_;
    $key = $key->fetch if Pugs::Runtime::Value::p6v_isa( $key, 'Scalar' );
    my $s = Pugs::Runtime::Value::identify( $key );
    $this->{$s} = [ $key, $value ];
    return $value;
}
sub fetch {
    my ( $this, $key ) = @_;
    $key = $key->fetch if Pugs::Runtime::Value::p6v_isa( $key, 'Scalar' );
    my $s = Pugs::Runtime::Value::identify( $key );
    $this->{$s}[1];
    # warn "fetching " . $this->{$s}[1];
}
sub firstkey {
    my ( $this ) = @_;
    keys %$this;  # force reset the iterator
    my $s = each %$this;
    return unless defined $s;
    $this->{$s}[0];
}
sub nextkey {
    my ( $this, $key ) = @_;
    my $s = each %$this;
    return unless defined $s;
    $this->{$s}[0];
}
sub exists {
    my ( $this, $key ) = @_;
    $key = $key->fetch if Pugs::Runtime::Value::p6v_isa( $key, 'Scalar' );
    my $s = Pugs::Runtime::Value::identify( $key );
    exists $this->{$s};
}
sub delete {
    my ( $this, $key ) = @_;
    $key = $key->fetch if Pugs::Runtime::Value::p6v_isa( $key, 'Scalar' );
    my $s = Pugs::Runtime::Value::identify( $key );
    my $r = delete $this->{$s};
    $r->[1];
}
sub clear {
    my ( $this ) = @_;
    %$this = ();
}
sub scalar {
    my ( $this ) = @_;
    0 + %$this;
}

package Pugs::Runtime::Container::Hash::Native;

sub new {
    my $class = shift;
    # hashref => \%ENV;
    my %param = @_;
    $param{hashref} = {} unless defined $param{hashref};
    bless { %param }, $class;
}

sub store {
    my ( $this, $key, $value ) = @_;
    my $s = Pugs::Runtime::Value::identify( $key );
    my $v;
    $v = $value->unboxed if ref( $value );
    no warnings 'uninitialized';
    $this->{hashref}{$s} = $v;
    return $value;
}
sub fetch {
    my ( $this, $key ) = @_;
    my $s = Pugs::Runtime::Value::identify( $key );
    $this->{hashref}{$s}
    # warn "fetching " . $this->{$s}[1];
}
sub firstkey {
    my ( $this ) = @_;
    keys %{$this->{hashref}};  # force reset the iterator
    each %{$this->{hashref}};
}
sub nextkey {
    my ( $this, $key ) = @_;
    each %{$this->{hashref}};
}
sub exists {
    my ( $this, $key ) = @_;
    my $s = Pugs::Runtime::Value::identify( $key );
    exists $this->{hashref}{$s};
}
sub delete {
    my ( $this, $key ) = @_;
    my $s = Pugs::Runtime::Value::identify( $key );
    my $r = delete $this->{hashref}{$s};
}
sub clear {
    my ( $this ) = @_;
    %{$this->{hashref}} = ();
}
sub scalar {
    my ( $this ) = @_;
    0 + %{$this->{hashref}};
}

package Pugs::Runtime::Container::Hash;

sub clone { 
    my $tmp = { %{ $_[0] } };
    $tmp;
}

sub elems {
    my @tmp = %{ $_[0] };
    @tmp / 2
}

sub buckets { scalar %{ $_[0] } }

1;
__END__

=head1 NAME

Pugs::Runtime::Container::Hash - Perl extension for Perl6 "Hash" class

=head1 SYNOPSIS

  use Pugs::Runtime::Container::Hash;

  ...

=head1 DESCRIPTION

...


=head1 SEE ALSO

Pugs

=head1 AUTHOR

Flavio S. Glock, E<lt>fglock@gmail.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Flavio S. Glock

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
