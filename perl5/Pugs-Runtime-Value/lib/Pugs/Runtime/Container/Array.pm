
# This is a Perl5 file

# ChangeLog
#
# 2005-10-06
# * Fixed perlification of arrays -- basically it used to be
#     join ",", map { ~$_ }     @elems;  # it's now:
#     join ",", map { $_.perl } @elems;
# * Don't output "..." to create ranges, but "..", so .perl will return valid
#   Perl 6 code for lazy/infinite arrays:
#     (1, 2 ... 42)  # wrong
#     (1, 2 .. 42)   # correct
# * The perlification of an array containing only one element is now ($item,)
#   instead of ($item) (($item) is not an array, but ($item,) is).
#
# 2005-09-12
# * several fixes: @a[1,2].delete; @a.uniq; (-Inf..Inf); (-Inf..0) 
#
# 2005-09-08
# * finite sub-slices work: ($x,@a[1..3])=(1,2,3,4)
#
# 2005-09-05
# * delete slice
#
# 2005-08-31
# * New methods: keys(), values(), pairs(), kv(), pick()
#
# 2005-08-29
# * Lazy lists are deep cloned when Array is cloned
#
# 2005-08-29
# * Full support for lazy splicing and sparse array
# * Added support for store() past the end of the array
# * Simplified fetch()
#
# 2005-08-27
# * Fixed fetch/store single elements from a lazy slice
# * Fixed fetch/store of whole lazy slice
#   supports syntax: @a = (0..Inf); @a[1,10,100..10000] = @a[500..30000]
#   (needs optimization)
# * New method tied()
# * Fixed binding of fetched result
# * Fixed stringification of unboxed values
# * New parameter 'max' in perl() and str() methods - controls how many elements
#   of the lazy array are stringified.
# * Array is stringified using parenthesis.
#
# 2005-08-26
# * New internal class 'Pugs::Runtime::Slice'
#   supports syntax: @a = (2,3,4,5); @a[1,2] = @a[0,3]
#
# 2005-08-12
# * store(List) actually means store([List])
# * fixed new(), elems(), pop(), shift(), fetch()
# * fixed "defined $i" to "elems == 0" in push/pop
#
# 2005-08-11
# * fixed some syntax errors
#
# 2005-08-10
# * Ported from Perl6 version

# BUGS
# - Infinite sub slices are not supported yet:
#   ($x,@a[1..99])=(1,2,3,4)   - ok - non-finite sub-slice
#   (@a[1..Inf])=(1,2,3,4)     - ok - not a sub-slice
#   ($x,@a[1..Inf])=(1,2,3,4)  - not supported

# RECENTLY FIXED
#   @a[10,100,1000,10000,100000]=(1..9999999) 
#        returned undef (the list went into array element zero)

# TODO - @a[1].delete doesn't work

# TODO - tied arrays should use the standard Perl 5 interface
#        test push, scalar, etc - with @INC

# TODO - PIL-Run - (1,undef,2) returns (1,2) - but (1,\undef,2) works
# TODO - PIL-Run - grep() using 'Code'

# TODO - finish lazy slices
#        @a[1..100000000]=@b[1..20000000]
#        (@a[1..100],@b[1..50])=(@a[1..50],@b[1..100])

# TODO - check specification of Array, Hash, Pair stringification

# TODO - sum()
# TODO - there are too many methods under AUTOLOAD - upgrade them to real methods
#
# TODO - optimize Eager array to O(1)
#      - currently disabled with "if 0 &&" (Pugs::Runtime::Container::Array)
#
# TODO - ($a,undef,$b) = @a - fixed, add test
#      - (@a[1..10],$a,undef,$b) = @a
#      - ($a,@x[1,2])=(4,5,6)
#
# TODO - @a[1] == Scalar
# TODO - test - @a[1] := $x

# TODO - tied arrays are copied in "Eager" mode?
#        (PerlJam) - well, I wouldn't think you'd have to copy them all at once.
#        Each element of @a would be sort of a lazy proxy for each element in the tied array @b

# TODO - @a[1..2]=(1,2) 
#        &postcircumfix:<[ ]> has to be "is rw"
#        &infix:<,> has to be is rw, too (think ($a, undef, $b) = (1,2,3))

# TODO - store(List) actually means store([List]), Perl6 version
# TODO - fix "defined $i" to "elems == 0" in push/pop, Perl6 version
# TODO - splice() should accept a 'List' object, Perl6 version too
#
# TODO - Tests: - add to t/data_types/lazy_lists.t
# TODO - fetch/store should not destroy binding
# TODO - test splice offset == 0, 1, 2, -1, -2, -Inf, Inf
# TODO - test splice length == 0, 1, 2, Inf, negative
# TODO - test splice list == (), (1), (1,2), Iterators, ...
# TODO - test splice an empty array
# TODO - test multi-dimensional array

# Notes:
# * Cell is implemented in the Pugs::Runtime::Container::Scalar package

use strict;
use Carp;

use Moose;
use Pugs::Runtime::Value;
use Pugs::Runtime::Container::Scalar;

use constant Inf => Pugs::Runtime::Value::Num::Inf;

my $class_description = '-0.0.1-cpan:FGLOCK';

# ------ Pugs::Runtime::Slice -----

sub Pugs::Runtime::Slice::new { 
    my $class = shift;
    my %param = @_;  
    #warn "NEW SLICE: ".Pugs::Runtime::Value::stringify($param{array})." -- ".Pugs::Runtime::Value::stringify($param{slice})."\n";
    bless { %param }, $class;
} 
sub Pugs::Runtime::Slice::clone { 
    my $self = shift;
    return $self->unbind;
    #my $a = Array->new;
    #$a->push( $self->items );
    #$a = $a->clone;
    #return $a;
} 
sub Pugs::Runtime::Slice::items {
    my $self = shift;
    #warn "SLICE ITEMS: ".Pugs::Runtime::Value::stringify($self->{array})." -- ".Pugs::Runtime::Value::stringify($self->{slice})."\n";
    #$self->{array}->items;
    my @a;
    warn "Infinite sub-slices are not supported yet" 
        if Pugs::Runtime::Value::numify( $self->is_infinite );
    for ( 0 .. Pugs::Runtime::Value::numify( $self->elems ) - 1 ) {
        push @a, $self->fetch( $_ );
    }
    # warn "    items: @a\n";
    return @a;
}
sub Pugs::Runtime::Slice::fetch {
    my $self = shift;
    my $i = shift;
    my $pos = Pugs::Runtime::Value::numify( $self->{slice}->fetch( $i ) );
    #warn "SLICE FETCH: at ($i) $pos -- @_ -- ".Pugs::Runtime::Value::stringify($self->{array}->fetch( $pos, @_ ))."\n";
    return unless defined $pos && $pos >= 0;
    $self->{array}->fetch( $pos, @_ );
}
sub Pugs::Runtime::Slice::store {
    my $self = shift;
    my $i = shift;
    my $pos = Pugs::Runtime::Value::numify( $self->{slice}->fetch( $i ) );
    #warn "SLICE STORE: at ($i) $pos -- @_"."\n";
    return unless defined $pos && $pos >= 0;
    $self->{array}->store( $pos, @_ );
}
sub Pugs::Runtime::Slice::is_infinite {
    my $self = shift; 
    $self->{slice}->is_infinite()->unboxed;
}
sub Pugs::Runtime::Slice::elems {
    my $self = shift; 
    $self->{slice}->elems()->unboxed;
}
sub Pugs::Runtime::Slice::unbind {
    # creates a new Array - not bound to the original array/slice
    my $self = shift; 
    #warn "SLICE UNBIND: ".Pugs::Runtime::Value::stringify($self->{array})." -- ".Pugs::Runtime::Value::stringify($self->{slice})."\n";
    my $ary = $self->{array};
    my @idx = $self->{slice}->items;
    my $result = Array->new;
    my $pos = 0;
    for my $i ( @idx ) {
        # warn "unbind() loop...";
        if ( UNIVERSAL::isa( $i, 'Pugs::Runtime::Value::List' ) ) {
            die "Not implemented: instantiate lazy slice using a non-contiguous list"
                unless $i->is_contiguous;
            my $start = $i->start;
            my $end =   $i->end;
            die "Slice start/end is not defined"
                unless defined $end && defined $start;
            die "Not implemented: instantiate lazy slice using a reversed list"
                unless $end >= $start;
            #warn "unbind: Index: ". $i->str . "\n";
            # warn "Slicing from $start to $end";
            my $slice = $ary->splice( $start, ( $end - $start + 1 ) );
            my $elems = $slice->elems->unboxed;
            # warn "splice 2 - elems = $elems - slice isa $slice";
            $ary->splice( $start, 0, $slice );
            # warn "splice done";
            # items should be cloned before storing
            my @items = $slice->unboxed->items;
            @items = map {
                        # warn "unbind - elems ". $_->elems . "\n";
                        UNIVERSAL::isa( $_, 'Pugs::Runtime::Value::List' ) ? $_->clone : $_
                    } @items;
            $result->push( @items );
            if ( $elems < ( $end - $start + 1 ) ) {
                my $diff = $end - $start + 1 - $elems;
                # warn "Missing $diff elements";
                $result->push( Pugs::Runtime::Value::List->from_x( item => undef, count => $diff ) );
            }
            $pos = $pos + $end - $start + 1;
            # warn "pos = $pos";
        }
        else {
            # non-lazy slicing
            my $tmp = $ary->fetch( $i )->fetch;
            $result->store( $pos, $tmp );
            $pos++;            
        }
    }
    return $result;
}
sub Pugs::Runtime::Slice::write_thru {
    # writes back to the bound Array using the slice as an index
    my $self = shift; 
    my $other = shift;
    #warn "SLICE WRITE THROUGH: ".Pugs::Runtime::Value::stringify($self->{array})." -- ".Pugs::Runtime::Value::stringify($self->{slice})."\n";
    #warn "               FROM: ".Pugs::Runtime::Value::stringify($other)."\n";
    #warn "SLICE WRITE THROUGH: ".$self->{array}." -- ".$self->{slice}."\n";
    #warn "               FROM: ".$other."\n";
    my $ary = $self->{array};
    my @idx = $self->{slice}->items;
    my $pos = 0;
    for my $i ( @idx ) {
        #warn "write loop... ". Pugs::Runtime::Value::stringify($i)." -- $i\n";
        if ( UNIVERSAL::isa( $i, 'Pugs::Runtime::Value::List' ) ) {
            # warn "List -- ". $i->is_contiguous;
            die "Not implemented: instantiate lazy slice using a non-contiguous list"
                unless $i->is_contiguous;
            my $start = $i->start;
            my $end =   $i->end;
            die "Slice start/end is not defined"
                unless defined $end && defined $start;
            die "Not implemented: instantiate lazy slice using a reversed list"
                unless $end >= $start;
            #warn "write_thru: Slicing from position $pos to ( $start .. $end )\n";
            #warn "    Index: ". $i->str . "\n";
            # items should be cloned before storing
            #my $ary_elems = $ary->elems->unboxed;
            #warn "other.elems = ".$other->elems->unboxed."\n";
            my $max_ary_elems = $ary->elems->unboxed - $start;
            #warn "array has $ary_elems elements, starts in $start, max = $max_ary_elems\n";
            my $slice_size = $end - $start + 1;
            $slice_size = $max_ary_elems if $slice_size > $max_ary_elems;
            my $slice = $other->splice( $pos, $slice_size );
            my $elems = $slice->elems->unboxed;
            # warn "splice 3 - elems = $elems - slice isa $slice";
            my @items = $slice->unboxed->items;
            if ( $elems < $slice_size ) {
                my $diff = $slice_size - $elems;
                #warn "Missing $diff elements";
                push @items, Pugs::Runtime::Value::List->from_x( item => undef, count => $diff )
                    if $diff > 0;
            }
            #warn "  STORE SLICE pos $pos to $start, $slice_size, @items";
            # TODO - XXX - don't use splice on slices, because it drops bindings
            $ary->splice( $start, $slice_size, @items );
            $pos = $pos + $slice_size;
            #warn "pos = $pos";
        }
        else {
            # non-lazy slicing
            my $tmp = $other->fetch( $pos )->fetch;
            $ary->store( $i, $tmp );
            $pos++;            
        }
    }
    return;
}

# ------ end Pugs::Runtime::Slice -----

class1 'Array'.$class_description => {
    is => [ $::Object ],
    class => {
        attrs => [],
        methods => {}
    },
    instance => {
        attrs => [ [ '$:cell' => { 
                        access => 'rw', 
                        build => sub { 
                            # warn " ---- new @_ ---- ";
                            my $cell = Pugs::Runtime::Cell->new;
                            my $h = Pugs::Runtime::Container::Array->new( items => [ @_ ] );
                            $cell->{v} = $h;
                            $cell->{type} = 'Array';
                            return $cell;
                        } } ] ],
        DESTROY => sub {
            # _('$:cell' => undef); # XXX - MM2.0 gc workaround
        },
        methods => { 

            # @a := @b 
            'bind' =>     sub {
                my ( $self, $thing ) = @_;
                die "argument to Array bind() must be a Array"
                    unless $thing->cell->{type} eq 'Array';
                _('$:cell', $thing->cell);
                return $self;
            },
            'cell' =>     sub { _('$:cell') },  # cell() is used by bind() / XXX - just rename $:cell to $.cell
            'id' =>       sub { _('$:cell')->{id} },  

            'tieable' =>  sub { _('$:cell')->{tieable} != 0 },
            'tie' =>      sub { shift; _('$:cell')->tie(@_) },
            'untie' =>    sub { _('$:cell')->untie },
            'tied' =>     sub { _('$:cell')->{tied} },

             # See perl5/Perl6-MetaModel/t/14_AUTOLOAD.t  
            'isa' =>      sub { ::next_METHOD() },
            'does' =>     sub { ::next_METHOD() },
            'ref' =>      sub { $::CLASS }, 
            'unboxed' =>  sub { 
                _('$:cell')->{tied} ? _('$:cell')->{tied} : _('$:cell')->{v}
            },
            'undefine' => sub { (shift)->store( Array->new ) },
            'delete' =>   sub {
                # delete a slice, returns deleted items
                my ( $self, @list ) = @_;
                #warn "Trying to delete() a non-slice" unless $self->tied;

                if ( UNIVERSAL::isa( $self->tied, 'Pugs::Runtime::Slice' ) ) {
                    # delete from slice
                    my $ret = Array->new();
                    $ret = $self->clone;
                    $self->store( Pugs::Runtime::Value::List->from_x( item => undef, count => Inf ) );
                    return $ret;
                }

                #warn "DELETE LIST @list";
                $self->slice( @list )->delete( 
                    Pugs::Runtime::Value::List->from_num_range( start => 0, end => Inf ) 
                );
                
            },
            'slice' =>    sub {
                # Returns an array whose fetch/store are bound to this array
                my ( $self, @list ) = @_;

                my $list = $list[0];
                if ( !Pugs::Runtime::Value::p6v_isa($list,'Array') ) {
                    $list = Array->new();
                    $list->push( $_ ) for @list;
                }

                # given $list = (4,5,6)
                # given an index $i = 1
                #   get $list[$i] == 5
                #   ignore request if index == undef
                #   store/fetch from array[$list[$i]] == array[5]
                my $ret = Array->new();
                $ret->cell->{tieable} = 1;
                my $proxy = Pugs::Runtime::Slice->new( 
                    array => $self, 
                    slice => $list,   
                );
                $ret->tie( $proxy );
                return $ret;
            },
            'zip' => sub {
                my ( $array, @array_list ) = map {
                        Pugs::Runtime::Value::p6v_isa( $_, 'Array' ) ? 
                        $_->to_list : 
                        warn "Argument to zip() must be an Array"; 
                    } @_; 
                my $res = Array->new;
                $res->push( $array->zip( @array_list ) );
                return $res;
            },
            'map' => sub {
                my $array = shift;  $array = $array->clone->to_list;
                my $code = shift;
                die "Argument to map() must be a Code" unless Pugs::Runtime::Value::p6v_isa( $code, 'Code' );
                my $res = Array->new;
                $res->push( $array->map( $code ) );
                return $res;
            },
            'kv' => sub  { 
                my $array = shift; 
                my $keys = $array->keys;
                my $values = $array->values;
                return $keys->zip( $values );
            },
            'pairs' => sub  { 
                my $array = shift; 
                $array = $array->clone;
                my $shifted = 0;
                my $popped = $array->elems->unboxed - 1;
                my $ret = Array->new();
                # XXX - rewrite this using map()
                $ret->push(
                    # XXX - TODO - optimization - shift_n, pop_n
                    Pugs::Runtime::Value::List->new(
                        cstart => sub { 
                            return Pair->new( 
                                '$.key' =>   $shifted++, 
                                '$.value' => $array->shift )
                        },
                        cend =>   sub { 
                            return Pair->new( 
                                '$.key' =>   $popped--, 
                                '$.value' => $array->pop )
                        },
                        celems => sub { $array->elems->unboxed },
                        is_lazy => 1,
                    )
                );
                return $ret;
            },
            'values' => sub  { 
                my $array = shift; 
                return $array->clone;
            },
            'keys' => sub  { 
                my $array = shift; 
                my $ret = Array->new();
                $ret->push(
                    Pugs::Runtime::Value::List->from_num_range( 
                        start => 0, 
                        end =>   $array->elems->unboxed - 1 ) ); 
                return $ret;
            },
            'pick' => sub  { 
                my $array = shift; 
                my $n = $array->elems->unboxed;
                $n = 10E9 if $n == &Inf;
                return $array->fetch( int( rand( $n ) ) );
            },
            'AUTOLOAD' => sub {
                my ($self, @param) = @_;
                my $method = __('$AUTOLOAD');
                my $tmp = $self->unboxed;
                # warn "AUTOLOAD ",ref($tmp), ' ', $method, " @param == " . $tmp->$method( @param );

                @param = 
                    map {
                        # Pugs::Runtime::Value::p6v_isa( $_, 'Array' ) ? $_->unboxed->items :  
                        Pugs::Runtime::Value::p6v_isa( $_, 'List' ) ? $_->unboxed :  
                        UNIVERSAL::isa( $_, 'Pugs::Runtime::Container::Array' ) ? $_->items : 
                        $_ 
                    } @param;
                
                if ( $method eq 'clone' || $method eq 'splice' || $method eq 'reverse' ) {
                    my $ret = Array->new();
                    my @result = $tmp->$method( @param )->items;
                    $ret->unboxed->push( @result );
                    #warn "-- @result "; # . Pugs::Runtime::Value::stringify($result->shift). " ... ". Pugs::Runtime::Value::stringify($result->pop);
                    #warn "reversed: ".$ret->str->unboxed;
                    #use Data::Dumper; $Data::Dumper::Indent=1;
                    #print Dumper($ret);
                    return $ret;
                }
                
                if ( $method eq 'push'   || $method eq 'unshift' || $method eq 'store' ) {
                    #warn "STORING THINGS $method @param";
                    if ( $method eq 'store' && @param == 1 ) {
                        # whole Array store
                        #warn "WHOLE ARRAY STORE";
                        # XXX - what if the array is tied?
                        #  @a = (2,3,4,5); @a[1,2] = @a[0,3]
                        my $other = $param[0];
                        # if ( $self->cell->{tied} ||
                        #      $other->cell->{tied} ) 
                        
                        # if ( $other->is_infinite->unboxed ) {
                        #    die "Infinite slices and tied arrays are not yet fully supported";
                        # }

                        if ( Pugs::Runtime::Value::p6v_isa( $other, 'Array' ) ) {
                            if ( UNIVERSAL::isa( $other->tied, 'Pugs::Runtime::Slice' ) ) {
                                # unbind the slice from the original arrays
                                $other = $other->tied->unbind;
                            }
                        }
                        else {
                            my $tmp = Array->new();
                            $tmp->push( $other );
                            $other = $tmp;
                        }

                        my @items = $other->unboxed->items;  
                        if ( UNIVERSAL::isa( $self->tied, 'Pugs::Runtime::Slice' ) ) {
                            #warn "WRITE THROUGH ".Pugs::Runtime::Value::stringify($other);
                            $self->tied->write_thru( $other );
                            return $other;
                            #return $self;
                        }
                        #warn "got @items - current = ". $self->cell->{v};

                        # unbind cells
                        @items = map {
                                Pugs::Runtime::Value::p6v_isa($_,'Scalar') ? $_->fetch : $_
                            } @items;

                        my $ret = Pugs::Runtime::Container::Array->from_list( @items );
                        $self->cell->{v} = $ret;
                        return $self;
                    }

                    if ( $method eq 'store' ) {
                        #warn "STORING @param";
                        my $pos = shift @param;
                        my $elem = $tmp->fetch( $pos );
                        if ( Pugs::Runtime::Value::p6v_isa( $elem, 'Scalar' ) ) {
                            #warn "CELL TO STORE IS A SCALAR: $elem";
                            $elem->store( @param );
                        }
                        else
                        {
                            #warn "CELL TO STORE IS NOT YET A SCALAR: $elem";
                            my $scalar = Scalar->new();
                            $scalar->store( @param );
                            $tmp->store( $pos, $scalar );
                        }
                        return $self;
                    }

                    #for ( @param ) {
                    #    next if UNIVERSAL::isa( $_, 'Pugs::Runtime::Value::List' );
                    #    next if Pugs::Runtime::Value::p6v_isa( $_, 'Scalar' );
                    #    next if Pugs::Runtime::Value::p6v_isa( $_, 'Array' );
                    #    next if Pugs::Runtime::Value::p6v_isa( $_, 'Hash' );
                    #    my $tmp = $_;
                    #    $_ = Scalar->new();
                    #    $_->store( $tmp );
                    #    warn " SCALAR ",$_->str->unboxed;
                    #};
                    #warn "Array.$method PARAM @param\n";
                    $tmp->$method( @param );
                    return $self;
                }

                if ( $method eq 'fetch' ) {
                    # warn "FETCHING THINGS @param";
                    if ( @param == 0 ) {
                        # whole Array fetch
                        return $self;
                    }
                    my $elem = $tmp->$method( @param );
                    my $scalar;
                    if ( Pugs::Runtime::Value::p6v_isa( $elem, 'Scalar' ) ) {
                        #warn "FETCHED CELL IS A SCALAR: $elem";
                        $scalar = $elem;
                    }
                    else
                    {
                        #warn "FETCHED CELL IS NOT YET A SCALAR: $elem [ @param ]";
                        $scalar = Scalar->new();
                        $scalar->store( $elem );
                        # replace Value with Scalar
                        #warn "STORE = @param, $scalar";
                        # XXX - TODO - test with multi-dim fetch
                        $self->store( @param, $scalar );
                        $scalar = $tmp->$method( @param );
                    }
                    return $scalar;
                    #my $ret = Scalar->new();
                    #$ret->bind( $scalar );
                    #return $ret;
                }

                if ( $method eq 'pop'   || $method eq 'shift' ) {
                    my $elem = $tmp->$method( @param );
                    unless ( Pugs::Runtime::Value::p6v_isa( $elem, 'Scalar' ) ) {
                        # XXX - I think only fetch() need to return Scalar 
                        my $scalar = Scalar->new();
                        $scalar->store( $elem );
                        return $scalar;
                    }
                    return $elem;
                }

                if ( $method eq 'elems' || $method eq 'int' || $method eq 'num' ) {
                    return Int->new( '$.unboxed' => $tmp->elems( @param ) )
                }
                if ( $method eq 'exists' ) {
                    # XXX - TODO - recursive to other dimensions
                    return Bit->new( '$.unboxed' => ($tmp->elems > Pugs::Runtime::Value::numify($param[0]) ) )
                }
                if ( $method eq 'is_infinite' ) {
                    return Bit->new( '$.unboxed' => $tmp->$method( @param ) )
                }
                
                return $tmp->$method( @param );
            },
            
            str => sub {
                #warn "PRINT @_\n";
                my $self = shift;
                my %param = @_;
                my $samples = $param{'max'};
                # my $self = $array->unboxed; # _('$:cell')->{tied} ? _('$:cell')->{tied} : _('$:cell')->{v};
                # warn "ELEMS ",$self->elems;
                $samples-- if defined $samples;
                $samples = 100 unless defined $samples || $self->is_infinite; 
                $samples = 2   unless defined $samples;
                my @start;
                my @end;
                my $tmp;
                for ( 0 .. $samples ) {
                    no warnings 'numeric';
                    last if $_ >= Pugs::Runtime::Value::numify( $self->elems );
                    $tmp = $self->fetch( $_ );
                    $tmp = Pugs::Runtime::Value::stringify( $tmp );
                    push @start, $tmp;
                    last if $tmp eq 'Inf' || $tmp eq '-Inf';
                }
                for ( map { - $_ - 1 } 0 .. $samples ) {
                    no warnings 'numeric';
                    # warn "  UNSHIFT: ".$self->elems->unboxed." ".Pugs::Runtime::Value::numify( $self->elems )." + $_ >= scalar ".(scalar @start)."\n";
                    last unless Pugs::Runtime::Value::numify( $self->elems ) + $_ >= scalar @start;
                    $tmp = $self->fetch( $_ );
                    $tmp = Pugs::Runtime::Value::stringify( $tmp );
                    unshift @end, $tmp;
                    last if $tmp eq 'Inf' || $tmp eq '-Inf';
                }
                my $str = '';
                if ( @start > 0 ) {
                    if ( Pugs::Runtime::Value::numify( $self->elems ) == ( scalar @start + scalar @end ) ) {
                        $str =  join( ' ', map { Pugs::Runtime::Value::stringify($_) } @start, @end );
                    }
                    else {
                        $str =  join( ' ', map { Pugs::Runtime::Value::stringify($_) } @start ) .
                                ' .. ' . 
                                join( ' ', map { Pugs::Runtime::Value::stringify($_) } @end );
                    }
                }
                return Str->new( '$.unboxed' => $str );                
            },
            perl => sub {
                #warn "PRINT @_\n";
                my $self = shift;
                my %param = @_;
                my $samples = $param{'max'};
                # my $self = $array->unboxed; # _('$:cell')->{tied} ? _('$:cell')->{tied} : _('$:cell')->{v};
                # warn "ELEMS ",$self->elems;
                $samples-- if defined $samples;
                $samples = 100 unless defined $samples || $self->is_infinite; 
                $samples = 2   unless defined $samples;
                my @start;
                my @end;
                my $tmp;
                for ( 0 .. $samples ) {
                    no warnings 'numeric';
                    last if $_ >= Pugs::Runtime::Value::numify( $self->elems );
                    $tmp = $self->fetch( $_ );
                    $tmp = Pugs::Runtime::Value::stringify( $tmp->perl );
                    push @start, $tmp;
                    last if $tmp eq 'Inf' || $tmp eq '-Inf';
                }
                for ( map { - $_ - 1 } 0 .. $samples ) {
                    no warnings 'numeric';
                    # warn "  UNSHIFT: ".$self->elems->unboxed." ".Pugs::Runtime::Value::numify( $self->elems )." + $_ >= scalar ".(scalar @start)."\n";
                    last unless Pugs::Runtime::Value::numify( $self->elems ) + $_ >= scalar @start;
                    $tmp = $self->fetch( $_ );
                    $tmp = Pugs::Runtime::Value::stringify( $tmp->perl );
                    unshift @end, $tmp;
                    last if $tmp eq 'Inf' || $tmp eq '-Inf';
                }
                my $str = '';
                if ( @start > 0 ) {
                    if ( Pugs::Runtime::Value::numify( $self->elems ) == ( scalar @start + scalar @end ) ) {
                        $str =  join( ', ', @start, @end );
                    }
                    else {
                        $str =  join( ', ', @start ) .
                                ' .. ' . 
                                join( ', ', @end );
                    }
                }
                # Ensure that ($only_one_item,).perl gets perlificated
                # correctly (i.e. not ($item), but ($item,)).
                $str .= "," if Pugs::Runtime::Value::numify( $self->elems ) == 1;
                return Str->new( '$.unboxed' => '(' . $str . ')' );                
            },
        },
    }
};

# ----- unboxed functions

package Pugs::Runtime::Container::Array;

use strict;
use Pugs::Runtime::Value;
use Pugs::Runtime::Value::List;
use Carp;

use constant Inf => Pugs::Runtime::Value::Num::Inf;

sub new {
    my $class = shift;
    my %param = @_;
    my @items = @{$param{items}};
    # warn "-- new -- @items --";
    return bless { items => \@items }, $class;
}

sub clone { 
    # XXX - TODO - clone Scalars
    my $self = bless { %{ $_[0] } }, ref $_[0];
    @{$self->{items}} = map {
            UNIVERSAL::isa( $_, 'Pugs::Runtime::Value::List' ) ? $_->clone : $_
        } @{$self->{items}};
    return $self;
}

sub sum { 
    my $self = shift;
    my $sum = 0;
    for ( @{$self->{items}} ) {
        if ( UNIVERSAL::isa( $_, 'Pugs::Runtime::Value::List' ) ) {
            $sum += $_->sum
        }
        elsif ( ref( $_ ) ) {
            $sum += $_->num->unboxed
        }
        else {
            $sum += $_
        }
    }
    return $sum;
}

sub items {
    my $self = shift;
    # my @x = %$self;  warn "-- items -- @x --";
    return @{$self->{items}};
}

sub from_list {
    my $class = shift;
    $class->new( items => [@_] );
}

sub _shift_n { 
    my $array = shift;
    my $length = shift;
    my @ret;
    my @tmp = @{$array->{items}};
    if ( $length == Inf ) {
        my $len = $array->elems;
        @{$array->{items}} = ();
        return ( $len, @tmp );
    }
    my $ret_length = 0;
    while ( @tmp ) {
        # warn "ret $ret_length == ".scalar(@ret)." length $length";
        last if $ret_length >= $length;
        if ( 0 && UNIVERSAL::isa( $tmp[0], 'ARRAY') ) {
            if ( @{$tmp[0]} ) {
                my $diff = $length - $ret_length;
                my @i = splice( @{$tmp[0]}, 0, $diff );
                push @ret, \@i;
                $ret_length += @i;
                last if $ret_length >= $length;
            }
            else {
                shift @tmp;
            }
            next;
        }
        if ( UNIVERSAL::isa( $tmp[0], 'Pugs::Runtime::Value::List') ) {
            if ( $tmp[0]->elems > 0 ) {
                # my $i = $tmp[0]->shift;
                my $li = $tmp[0];
                my $diff = $length - $ret_length;
                my $i = $li->shift_n( $diff );
                push @ret, $i;
                if ( UNIVERSAL::isa( $i, 'Pugs::Runtime::Value::List') ) {
                    $ret_length += $i->elems;
                }
                else {
                    $ret_length++;
                }
                # warn "push list ". $i->start . ".." . $i->end . " now length=$ret_length";
                last if $ret_length >= $length;
            }
            else {
                shift @tmp;
            }
            next;
        }
        push @ret, shift @tmp;
        $ret_length++;
    };
    @{$array->{items}} = @tmp;
    # warn "ret @ret ; array @tmp ";
    return ( $ret_length, @ret );
}

sub _pop_n {
    my $array = shift;
    my $length = shift;
    my @ret;
    my @tmp = @{$array->{items}};
    if ( $length == Inf ) {
        my $len = $array->elems;
        @{$array->{items}} = ();
        return ( $len, @tmp );
    }
    my $ret_length = 0;
    while ( @tmp ) {
        # warn "ret ".scalar(@ret)." length $length";
        last if $ret_length >= $length;
        if ( 0 && UNIVERSAL::isa( $tmp[0], 'ARRAY') ) {
            if ( @{$tmp[0]} ) {
                my $diff = $length - $ret_length;
                my @i = splice( @{$tmp[0]}, -$diff, $diff );
                push @ret, \@i;
                $ret_length += @i;
                last if $ret_length >= $length;
            }
            else {
                shift @tmp;
            }
            next;
        }
        if ( UNIVERSAL::isa( $tmp[-1], 'Pugs::Runtime::Value::List') ) {
            if ( $tmp[-1]->elems > 0 ) {
                # my $i = $tmp[-1]->pop;
                # unshift @ret, $i;
                my $li = $tmp[-1];
                my $diff = $length - $ret_length;
                my $i = $li->pop_n( $diff );
                unshift @ret, $i;
                if ( UNIVERSAL::isa( $i, 'Pugs::Runtime::Value::List') ) {
                    $ret_length += $i->elems;
                }
                else {
                    $ret_length++;
                }
                # warn "pop list ". $i->start . ".." . $i->end . " now length=$ret_length";
                last if $ret_length >= $length;
            }
            else {
                pop @tmp;
            }
            next;
        }
        unshift @ret, pop @tmp;
        $ret_length++;
    };
    @{$array->{items}} = @tmp;
    # warn "ret @ret ; array @tmp ";
    return ( $ret_length, @ret );
}

sub elems {
    my $array = shift;
    my $count = 0;
    for ( @{$array->{items}} ) {
        $count += UNIVERSAL::isa( $_, 'ARRAY') ? 0 + @$_ :
                  UNIVERSAL::isa( $_, 'Pugs::Runtime::Value::List') ? $_->elems  :
                  1;
    }
    $count;
}

sub is_infinite {
    my $array = shift;
    for ( @{$array->{items}} ) {
        return 1 if UNIVERSAL::isa( $_, 'Pugs::Runtime::Value::List') && $_->is_infinite;
    }
    0;
}

sub is_lazy {
    my $array = shift;
    for ( @{$array->{items}} ) {
        return 1 if UNIVERSAL::isa( $_, 'Pugs::Runtime::Value::List') && $_->is_lazy;
    }
    0;
}

sub flatten {
    # this needs optimization
    my $array = shift;
    my $ret = $array->clone;
    for ( @{$ret->{items}} ) {
        $_ = $_->flatten() if UNIVERSAL::isa( $_, 'Pugs::Runtime::Value::List') && $_->is_lazy;
    }
    $ret;
}

sub splice { 
    my $array =  shift;
    my $offset = shift; $offset = Pugs::Runtime::Value::numify( $offset ); $offset = 0   unless defined $offset;
    my $length = shift; $length = Pugs::Runtime::Value::numify( $length ); $length = Inf unless defined $length;
    my @list = @_;
    my $class = ref($array);
    my ( @head, @body, @tail );
    my ( $len_head, $len_body, $len_tail );
    # print "items: ", $array->items, " splice: $offset, $length, ", @list, "\n";
    # print 'insert: ', $_, ' ', $_->ref for @list, "\n";
    # print " offset $offset length $length \n";
    if ( $offset >= 0 ) {
        ( $len_head, @head ) = $array->_shift_n( $offset );
        if ( $length >= 0 ) {
            #  head=shift offset -> body=shift length -> tail=remaining
            ( $len_body, @body ) = $array->_shift_n( $length );
            ( $len_tail, @tail ) = $array->_shift_n( Inf );
        }
        else {
            #  tail=pop length -> head=shift offset -> body=remaining 
            ( $len_tail, @tail ) = $array->_pop_n( -$length );
            ( $len_body, @body ) = $array->_shift_n( Inf );
        }
    }
    else {
        ( $len_tail, @tail ) = $array->_pop_n( -$offset );
        ( $len_head, @head ) = $array->_shift_n( Inf );
        if ( $length >= 0 ) {
            # negative offset, positive length
            #  tail=pop length -> head=remaining -> body=shift tail until body == length
            # make $#body = $length
            my $tail = $class->from_list( @tail );
            ( $len_body, @body ) = $tail->_shift_n( $length );
            @tail = $tail->items;
        }
        else {
            # negative offset, negative length
            #  tail=pop length -> head=remaining -> body=shift tail until tail == length
            # make $#tail = -$length
            my $body = $class->from_list( @tail );
            ( $len_tail, @tail ) = $body->_pop_n( -$length );
            @body = $body->items;
        }
    };
    # print "off: $offset len: $length head: @head body: @body tail: @tail list: @list\n";
    @{$array->{items}} = ( @head, @list, @tail );
    return $class->from_list( @body );
}

sub end  {
    my $array = shift;
    return unless $array->elems;
    my $x = $array->pop;
    $array->push( $x );
    return $x;
}

sub fetch {
    # XXX - this is inefficient because it needs 2 splices
    # see also: splice()
    my $array = shift;
    my $pos =   shift; $pos = Pugs::Runtime::Value::numify( $pos );
    
    #use Data::Dumper;
    #warn "-- array -- ". Dumper( $array );
    #warn "uninitialized value used in numeric context"
    #    unless defined $pos;  
    return if $pos >= $array->elems;

    my $ret = $array->splice( $pos, 1 );
    ($ret) = @{$ret->{items}};
    $ret = $ret->shift if UNIVERSAL::isa( $ret, 'Pugs::Runtime::Value::List' );
    if ( $pos < 0 ) {
        if ( $pos == -1 ) {
            $array->push( $ret );
        }
        else {
            $array->splice( $pos+1, 0, $ret );
        }
    }
    else {
        $array->splice( $pos, 0, $ret );
    }
    # warn "FETCH $pos returns $ret";
    return $ret;
}

sub store {
    my $array = shift;
    my $pos =   shift; $pos = Pugs::Runtime::Value::numify( $pos );
    my $item  = shift;
    # warn "uninitialized value used in numeric context"
    #    unless defined $pos;  
    if ( UNIVERSAL::isa( $item, 'Pugs::Runtime::Value::List') ) {
        my $class = ref($array);
        $item = $class->new( items => [$item] );
    }
    if ( $pos <= $array->elems ) {
        # 'Array' takes care of proper cell re-binding 
        my $scalar = $array->fetch( $pos );
        if ( Pugs::Runtime::Value::p6v_isa( $scalar, 'Scalar' ) ) {
            # warn "Store to scalar\n";
            $scalar->store( $item );
        }
        else {
            $array->splice( $pos, 1, $item );
        }
        return $array;
    }
    # store after the end 
    my $fill = Pugs::Runtime::Value::List->from_x( item => undef, count => ( $pos - $array->elems ) );
    push @{$array->{items}}, $fill, $item;
    return $array;
}

sub reverse {
    my $array = shift;
    my @rev = reverse @{$array->{items}};
    @rev = map {
            UNIVERSAL::isa( $_, 'ARRAY' ) ? [ reverse( @$_ ) ] : 
            UNIVERSAL::isa( $_, 'Pugs::Runtime::Value::List' ) ? $_->reverse : 
            $_
        } @rev;
    return Pugs::Runtime::Container::Array->from_list( @rev );
}

sub to_list {
    my $array = shift;
    my $ret = $array->clone;
    # XXX - TODO - optimization - return the internal list object, if there is one
    # XXX - TODO - optimization - add shift_n, pop_n closures
    return Pugs::Runtime::Value::List->new(
            cstart => sub { $ret->shift },
            cend =>   sub { $ret->pop },
            celems => sub { $ret->elems },
            is_lazy => $ret->is_lazy,
        )
}

sub unshift {
    my $array = shift;
    unshift @{$array->{items}}, @_;
    return $array;
}

sub push {
    my $array = shift;
    push @{$array->{items}}, @_;
    return $array;
}

sub pop {
    my $array = shift;
    my ( $length, $ret ) = $array->_pop_n( 1 );
    # warn "POP $length -- ". $ret->elems if UNIVERSAL::isa( $ret, 'Pugs::Runtime::Value::List' );
    $ret = $ret->shift if UNIVERSAL::isa( $ret, 'Pugs::Runtime::Value::List' );
    return $ret;
}

sub shift {
    my $array = shift;
    my ( $length, $ret ) = $array->_shift_n( 1 );
    # warn "SHIFT $length -- ". $ret->elems if UNIVERSAL::isa( $ret, 'Pugs::Runtime::Value::List' );
    $ret = $ret->shift if UNIVERSAL::isa( $ret, 'Pugs::Runtime::Value::List' );
    return $ret;
}

package Pugs::Runtime::Container::Array::Native;

sub new {
    my $class = shift;
    # arrayref => \@INC;
    bless { @_ }, $class;
}

sub store {
    my ( $this, $key, $value ) = @_;
    my $s = Pugs::Runtime::Value::numify( $key );
    $this->{arrayref}[$s] = $value->unboxed;
    return $value;
}
sub fetch {
    my ( $this, $key ) = @_;
    my $s = Pugs::Runtime::Value::numify( $key );
    $this->{arrayref}[$s]
}
sub push {
    my ( $this, $value ) = @_;
    push @{$this->{arrayref}}, $value->unboxed;
    return $value;
}
sub unshift {
    my ( $this, $value ) = @_;
    unshift @{$this->{arrayref}}, $value->unboxed;
    return $value;
}
sub pop {
    my ( $this ) = @_;
    return pop @{$this->{arrayref}};
}
sub shift {
    my ( $this ) = @_;
    return shift @{$this->{arrayref}};
}
sub delete {
    my ( $this, $key ) = @_;
    my $s = Pugs::Runtime::Value::numify( $key );
    my $r = delete $this->{arrayref}[$s];
}
sub clear {
    my ( $this ) = @_;
    @{$this->{arrayref}} = ();
}
sub elems {
    my ( $this ) = @_;
    scalar @{$this->{arrayref}};
}
sub items {
    my ( $this ) = @_;
    @{$this->{arrayref}};
}

1;
__END__

=head1 NAME

Pugs::Runtime::Container::Array - Perl extension for Perl6 "Array" class

=head1 SYNOPSIS

  use Pugs::Runtime::Container::Array;

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
