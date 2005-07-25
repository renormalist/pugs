module Prelude::JS {}
# XXX pugs can't emit PIL for module Foo {...}, where ... is non-empty.

# JS::Root is the * of the JavaScript code later.
# Why not simply use * here too? Because we don't want to overwrite core subs
# (&defined, &time, operators, etc.) with calls to &JS::inline, as then modules
# (which are called at compile-time) won't work.

# &JS::inline("...") is a pseudo sub: &JS::inline's first param is directly
# inlined (with no escaping) into the resulting JavaScript code.

# new PIL2JS.Box(...) boxes a value. That is, it is packed in an Object with
# the property .GET() holding the original value. This is necessary to emulate
# pass by ref (needed for is rw and is ref).

use Prelude::JS::Code;
use Prelude::JS::ControlFlow;
use Prelude::JS::IO;
use Prelude::JS::Str;
use Prelude::JS::Bool;
use Prelude::JS::OO;
use Prelude::JS::Keyed;
use Prelude::JS::Pair;
use Prelude::JS::Ref;
use Prelude::JS::Hash;
use Prelude::JS::Array;

method JS::Root::undefine($a is rw:) {
  $a = undef;
}

sub JS::Root::time() is primitive {
  JS::inline "new PIL2JS.Box.Constant((new Date()).getTime() / 1000 - 946684800)";
}

sub infix:<=:=>($a, $b) is primitive { JS::inline('new PIL2JS.Box.Constant(
  function (args) {
    var cxt = args.shift();
    if(args[0].uid && args[1].uid) {
      return new PIL2JS.Box.Constant(args[0].uid == args[1].uid);
    } else if(!args[0].uid && !args[1].uid) {
      return new PIL2JS.Box.Constant(args[0].GET() == args[1].GET());
    } else {
      return new PIL2JS.Box.Constant(false);
    }
  }
)')($a, $b) }

# Pending support for multi subs.
sub prefix:<~>($thing) is primitive {
  if(not defined $thing) {
    "";
  } elsif($thing.isa("Str")) {
    JS::inline('new PIL2JS.Box.Constant(
      function (args) {
        var thing = args[1].GET();
        return new PIL2JS.Box.Constant(String(thing).toString());
      }
    )')($thing);
  } elsif($thing.isa("Array")) {
    $thing.map:{ ~$_ }.join(" ");
  } elsif($thing.isa("Hash")) {
    $thing.kv.map:{ "$^key\t$^value" }.join("\n");
  } elsif($thing.isa("Bool")) {
    $thing ?? "bool::true" :: "bool::false";
  } elsif($thing.isa("Num")) {
    JS::inline('function (thing) { return Number(thing).toString() }')($thing);
  } elsif($thing.isa("Ref")) {
    ~PIL2JS::Internals::generic_deref($thing);
  } else {
    die "Stringification for objects of class {$other.ref} not yet implemented!\n";
  }
}

sub prefix:<+>($thing) is primitive {
  if($thing.isa("Str")) {
    JS::inline('function (thing) { return Number(thing) }')($thing);
  } elsif($thing.isa("Array")) {
    $thing.elems;
  } elsif($thing.isa("Hash")) {
    +$thing.keys;
  } elsif($thing.isa("Bool")) {
    $thing ?? 1 :: 0;
  } elsif($thing.isa("Num")) {
    JS::inline('function (thing) { return Number(thing) }')($thing);
  } elsif($thing.isa("Ref")) {
    +PIL2JS::Internals::generic_deref($thing);
  } else {
    die "Numification for objects of class {$other.ref} not yet implemented!\n";
  }
}

sub prefix:<*>(*@args) is primitive {
  JS::inline('new PIL2JS.Box.Constant(function (args) {
    var array = args[1];
    array.GET().flatten_me = true;
    return array;
  })')(@args);
}

# We load the operator definitions lastly because they'll override *our*
# operators.
use Prelude::JS::Operators;
