use strict;

my %rules;

# internal functions

sub _greedy { 
    my $node_name = shift;
    my @matches;
    my @tail = @_;
    my $match;
    while (1) {
        my @last_tail = @tail;
        ($match, @tail) = $rules{ $node_name }(@tail);
        return ( { $node_name . '_greedy' => [ @matches ] }, @last_tail ) if ! $match;
        push @matches, $match;
    }
}


# Prelude - precompiled rules, such as <word>, \x, etc.

%rules = (
  'slashed_char' => sub {
      return ( { 'slashed_char' => [ $_[0], $_[1] ] }, @_[2..$#_] ) if $_[0] eq '\\';
      return undef;
  },
  'word_char' => sub { 
      return ( { 'char'=>[ $_[0] ] }, @_[1..$#_] ) if $_[0] =~ m/[a-zA-Z0-9\_]/;  
      return undef;
  },

# more definitions

  'a' => sub { 
      return ( { 'a'=>[ $_[0] ] }, @_[1..$#_] ) if $_[0] eq 'a';
      return undef;
  },
  'ab' => sub { 
      return ( { 'ab'=>[ @_[0,1] ] }, @_[2..$#_] ) if $_[0] eq 'a' && $_[1] eq 'b';
      return undef;
  },
  'cd' => sub { 
      return ( { 'cd'=>[ @_[0,1] ] }, @_[2..$#_] ) if $_[0] eq 'c' && $_[1] eq 'd';
      return undef;
  },
  'abb' => sub { 
      my ($match, @tail) = $rules{'ab'}(@_);
      return undef unless $match;
      return ( { 'abb'=>[ $match, 'b' ] }, @tail[1..$#tail] ) if $tail[0] eq 'b'; 
      return undef;
  },
  '.' => sub { 
      return ( { '.'=>[ $_[0] ] }, @_[1..$#_] ) if @_;
      return undef;
  },
  'ab|cd' => sub {
      my ($match, @tail) = $rules{'ab'}(@_);
      return ( { 'ab|cd'=>$match }, @tail) if $match;
      ($match, @tail) = $rules{'cd'}(@_);
      return ( { 'ab|cd'=>$match }, @tail) if $match;
      return undef;
  },
  'a*' => sub { 
      _greedy( 'a', @_ );
      
      #my @matches;
      #my @tail = @_;
      #my $match;
      #while (1) {
      #    my @last_tail = @tail;
      #    ($match, @tail) = $rules{'a'}(@tail);
      #    return ( { 'a*' => [ @matches ] }, @last_tail ) if ! $match;
      #    push @matches, $match;
      #}
  },
  'a*.' => sub { 
      my @matches;
      my @tail;
      my $match;
      
      ($match, @tail) = $rules{'a*'}(@_);
      # return undef unless $match;   # '*' always matches
      print Dumper [ $match, @tail ];
      
      while (1) {
          my $iterations = @{ $match->{'a_greedy'} };
          warn "iterations to go: $iterations";
      
          @matches = ();
          push @matches, $match;
          
          my $match2;
          ($match2, @tail) = $rules{'.'}(@tail);
          push @matches, $match2 if $match2;
      
          return ( { 'a*.'=>[ @matches ] }, @tail) if $match2;
          
          return undef unless @{ $match->{'a_greedy'} };
          
          my $last = pop @{ $match->{'a_greedy'} };
          unshift @tail, $last;
      }
  },
);

use Data::Dumper;
my @in = qw( a b b a b c c d );
print Dumper( $rules{'.'}(@in) );
print Dumper( $rules{'abb'}(@in) );
print Dumper( $rules{'ab|cd'}( qw(a b c) ) );
print Dumper( $rules{'a*'}( qw(a a a b c) ) );
print Dumper( $rules{'a*.'}( qw(a a a a) ) );
print Dumper( $rules{'a*.'}( qw(b a a a a) ) );
