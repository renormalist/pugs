module Prelude::JS {}
# XXX pugs can't emit PIL for module Foo {...}, where ... is non-empty.

# JS::Root is the * of the JavaScript code later.
# Why not simply use * here too? Because we don't want to overwrite core subs
# (&defined, &time, operators, etc.) with calls to &JS::inline, as then modules
# (which are called at compile-time) won't work.

# &JS::inline("...") is a pseudo sub: &JS::inline's first param is directly
# inlined (with no escaping) into the resulting JavaScript code.

# new PIL2JS.Box(...) boxes a value. That is, it is packed in an Object with
# the property .FETCH() holding the original value. This is necessary to
# emulate pass by ref (needed for is rw and is ref).

use Prelude::JS::Code;
use Prelude::JS::Continuations;
use Prelude::JS::ControlFlow;
use Prelude::JS::IO;
use Prelude::JS::Junc;
use Prelude::JS::Str;
use Prelude::JS::Bool;
use Prelude::JS::Keyed;
use Prelude::JS::Pair;
use Prelude::JS::Ref;
use Prelude::JS::Hash;
use Prelude::JS::Array;
use Prelude::JS::Context;
use Prelude::JS::Math;
use Prelude::JS::JSAN;
use Prelude::JS::Perl5;
use Prelude::JS::Rules;
use Prelude::JS::Smartmatch;
use Prelude::JS::OO;
use Prelude::JS::Proxy;

method JS::Root::undefine($a is rw:) {
  $a = undef;
}

sub JS::Root::time() is primitive {
  JS::inline "new PIL2JS.Box.Constant((new Date()).getTime() / 1000 - 946684800)";
}

sub infix:<=:=>($a, $b) is primitive { JS::inline('new PIL2JS.Box.Constant(
  function (args) {
    var cxt = args.shift();
    var cc  = args.pop();

    if(args[0].uid && args[1].uid) {
      cc(new PIL2JS.Box.Constant(args[0].uid == args[1].uid));
    } else {
      cc(new PIL2JS.Box.Constant(false));
    }
  }
)')($a, $b) }

sub infix:<===>($a, $b) is primitive { JS::inline('new PIL2JS.Box.Constant(
  function (args) {
    var cxt = args.shift(),  cc  = args.pop();
    var a = args[0].FETCH(), b = args[1].FETCH();

    if(a instanceof PIL2JS.Ref && b instanceof PIL2JS.Ref) {
      cc(new PIL2JS.Box.Constant(a.referencee == b.referencee));
    } else if(!(a instanceof PIL2JS.Ref) && !(b instanceof PIL2JS.Ref)) {
      cc(new PIL2JS.Box.Constant(a == b));
    } else {
      cc(new PIL2JS.Box.Constant(false));
    }
  }
)')($a, $b) }

sub prefix:<*>(Array|Pair|Hash $thing) {
  JS::inline('new PIL2JS.Box.Constant(function (args) {
    var cc    = args.pop();
    var thing = args[1].FETCH();
    if(thing.referencee && thing.autoderef) thing = thing.referencee.FETCH();

    if(thing instanceof PIL2JS.Pair) {
      cc(new PIL2JS.Box.Constant(new PIL2JS.NamedPair(
        thing.key.toNative(),
        thing.value
      )));
    } else if(thing instanceof Array) {
      // We\'ve to [].concat here so we don\'t set .flatten_me of caller\'s
      // original array.
      var array = [].concat(thing);

      array.flatten_me = true;
      cc(new PIL2JS.Box.Constant(array));
    } else if(thing instanceof PIL2JS.Hash) {
      var pairs = thing.pairs();
      var hash  = new PIL2JS.Hash;
      for(var i = 0; i < pairs.length; i++)
        hash.add_pair(pairs[i]);
      hash.flatten_me = true;
      cc(new PIL2JS.Box.Constant(hash));
    } else {
      PIL2JS.die("&prefix:<*> only works on arrays, hashes, and pairs!");
    }
  })')($thing);
}

sub JS::Root::eval(Str $code?, Str :$lang = 'Perl6') {
  if (lc($lang) eq 'perl5') {
    # TODO: do try here and handle $!
    return JS::inline('(
  function (str) {
    if (!Perl5) throw "Perl5 required.";
    return Perl5.perl_eval(str);
  })')($code);
  }
  $! = "&eval does not work under PIL2JS.";
  undef;
}

# Stub.
method perl(Any $self:) { ".perl not yet implemented in PIL2JS" }

# We load the operator definitions lastly because they'll override *our*
# operators.
use Prelude::JS::Operators;

# XXX! EVIL HACK! !!! When stringifying the pair (a => 1), and we'd name the
# parameters $a and $b, $a would get the 1, not the pair (a => 1). As this is
# partly a bug/oddity in Perl 6's design and it's too early to implement
# typechecking etc. I renamed the parameters to $__a and $__b. HAAACK!
sub infix:<~>(Str $__a, Str $__b) is primitive {
  JS::inline('new PIL2JS.Box.Constant(function (args) {
    var a = args[1].FETCH(), b = args[2].FETCH(), cc = args.pop();
    cc(new PIL2JS.Box.Constant(String(a) + String(b)));
  })')(~$__a, ~$__b);
}

sub Pugs::Internals::symbolic_deref (Str $sigil, Str *@parts) is rw {
  JS::inline('new PIL2JS.Box.Constant(function (args) {
    var varname = args[1].toNative(), cc = args.pop();
    cc(PIL2JS.resolve_callervar(1, varname));
  })')($sigil ~ join "::", @parts);
}

sub Pugs::Internals::but_block ($obj is rw, Code $code) is primitive {
  $code($obj);
  $obj;
}
