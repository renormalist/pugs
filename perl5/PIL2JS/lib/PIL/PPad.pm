# my $x = ...
package PIL::PPad;

use warnings;
use strict;

sub fixup {
  my $self = shift;

  die unless keys %$self == 3;
  # A SOur should never reach use (SOurs are compiled into __init_ subs).
  die if     $self->{pScope} eq "SOur";
  die unless ref $self->{pSyms} eq "ARRAY";
  die unless $self->{pStmts}->isa("PIL::PStmts");

  # Skip creating a new sub-pad if
  #   a) we're in a subroutine (in this case, we use JS' lexicals) or
  #   b) we're compiling a SLet, STemp, or SState (which all use an existing
  #      variable).
  if($PIL::IN_SUBLIKE or $self->{pScope} =~ /^(SLet|STemp|SState)$/) {
    return bless {
      pScope => $self->{pScope},
      pSyms  => [map {{ fixed => PIL::lookup_var($_->[0]), user => $_->[0] }} @{ $self->{pSyms} }],
      pStmts => $self->{pStmts}->fixup,
    } => "PIL::PPad";
  }

  my $scopeid = $PIL::CUR_LEXSCOPE_ID++;
  my $pad     = {
    map {
      push @PIL::ALL_LEXICALS, "$_->[0]_${scopeid}_$PIL::LEXSCOPE_PREFIX";
      ($_->[0] => "$_->[0]_${scopeid}_$PIL::LEXSCOPE_PREFIX");
    } @{ $self->{pSyms} }
  };

  local @PIL::CUR_LEXSCOPES = (@PIL::CUR_LEXSCOPES, $pad);

  return bless {
    pScope => $self->{pScope},
    pSyms  => [ map {{
      fixed => "$_->[0]_${scopeid}_$PIL::LEXSCOPE_PREFIX",
      user  => $_->[0],
    }} @{ $self->{pSyms} } ],
    pStmts => $self->{pStmts}->fixup,
  } => "PIL::PPad";
}

sub as_js {
  my $self = shift;

  push @PIL::VARS_TO_BACKUP, map { $_->{fixed} } @{ $self->{pSyms} }
    unless $PIL::IN_SUBLIKE;

  # Emit appropriate foo = new PIL2JS.Box(undefined) statements.
  local $_;
  my $decl = $PIL::IN_SUBLIKE ? "var " : "";
  return
    join("; ", map {
      my ($jsname, $qname, $undef) = (
        PIL::name_mangle($_->{fixed}),
        PIL::doublequote($_->{user}),
        PIL::undef_of($_->{fixed}),
      );

      if($self->{pScope} eq "SMy") {
        "$decl$jsname = $undef; pad[$qname] = $jsname";
      } elsif($self->{pScope} eq "STemp") {
        PIL::fail("Can't use temp variable declarator outside a sub-scope!")
          unless $PIL::IN_SUBLIKE;
        <<EOF;
(function () {
  var backup = $jsname.FETCH();
  block_leave_hooks.push(function () {
    $jsname.STORE(new PIL2JS.Box.Constant(backup));
  });
})()
EOF
      } elsif($self->{pScope} eq "SLet") {
        PIL::fail("Can't use temp variable declarator outside a sub-scope!")
          unless $PIL::IN_SUBLIKE;
        <<EOF;
(function () {
  var backup = $jsname.FETCH();
  block_leave_hooks.push(function (retval) {
    if(!PIL2JS.cps2normal(
      _26main_3a_3aprefix_3a_3f.FETCH(),
      [PIL2JS.Context.ItemAny, retval]
    ).FETCH())
      $jsname.STORE(new PIL2JS.Box.Constant(backup));
  });
})()
EOF
      } else {
        die;
      }
    } @{ $self->{pSyms} }) .
    ";\n" .
    $self->{pStmts}->as_js;
}

1;
