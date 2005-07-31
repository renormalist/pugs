# EVIL hacks here! E.g. method map and sub JS::Root::map!

method JS::Root::shift(@self:) {
  JS::inline('new PIL2JS.Box.Constant(function (args) {
    var array = args[1].GET();
    var ret   = array.shift();
    return ret == undefined ? new PIL2JS.Box.Constant(undefined) : ret;
  })')(@self);
}

method JS::Root::pop(@self:) {
  JS::inline('new PIL2JS.Box.Constant(function (args) {
    var array = args[1].GET();
    var ret   = array.pop();
    return ret == undefined ? new PIL2JS.Box.Constant(undefined) : ret;
  })')(@self);
}

method JS::Root::unshift(@self: *@things) {
  JS::inline('new PIL2JS.Box.Constant(function (args) {
    var array = args[1].GET(), add = args[2].GET();
    for(var i = add.length - 1; i >= 0; i--) {
      array.unshift(new PIL2JS.Box(add[i].GET()));
    }
    return new PIL2JS.Box.Constant(array.length);
  })')(@self, @things);
}

method JS::Root::push(@self: *@things) {
  JS::inline('new PIL2JS.Box.Constant(function (args) {
    var array = args[1].GET(), add = args[2].GET();
    for(var i = 0; i < add.length; i++) {
      array.push(new PIL2JS.Box(add[i].GET()));
    }
    return new PIL2JS.Box.Constant(array.length);
  })')(@self, @things);
}

method join(@self: Str $sep) { join $sep, *@self }
sub JS::Root::join(Str $sep, *@things) is primitive {
  JS::inline('
    function (arr, sep) {
      return arr.join(String(sep));
    }
  ')(@things.map:{ ~$_ }, $sep);
}

method JS::Root::elems(@self:) {
  JS::inline('function (arr) { return arr.length }')(@self);
}

method JS::Root::end(@self:) {
  JS::inline('function (arr) { return arr.length - 1 }')(@self);
}

method map(@self is rw: Code $code) { map $code, *@self }
sub JS::Root::map(Code $code, *@array is rw) is primitive {
  die "&map needs a Code as first argument!" unless $code.isa("Code");
  my $arity = $code.arity;
  # die "Can't use 0-ary subroutine as \"map\" body!" if $arity == 0;
  $arity ||= 1;

  my @res;
  while +@array > 0 {
    my @args = ();
    my $i; loop $i = 0; $i < $arity; $i++ {
      # Slighly hacky
      push @args: undef;
      @args[-1] := @array.shift;
    }
    push @res, $code(*@args);
  }

  @res;
}

method sort(@self: Code ?$cmp = &infix:<cmp>) { sort $cmp, *@self }
sub JS::Root::sort(Code ?$cmp is copy = &infix:<cmp>, *@array) is primitive {
  # Hack
  unless $cmp.isa("Code") {
    unshift @array, @$cmp;
    $cmp := &infix:<cmp>;
    # Hack: $cmp = &infix:<cmp> should work, too, but doesn't, as $cmp is an
    # array, *not* an arrayref! (Therefore, that's rewritten as $cmp =
    # (&infix:<cmp>), causing $cmp to stay an Array and only $cmp[0] to be the
    # Code object we want. Fixing this would require a more intelligent
    # parameter binding routine or separate PIL2JS.Box.Scalar,
    # PIL2JS.Box.Array, etc. (later!)
  }

  die "&sort needs a Code as first argument!" unless $cmp.isa("Code");
  my $arity = $cmp.arity;
  $arity ||= 2; # hack
  die "Can't use $arity-ary subroutine as comparator block for &sort!"
    unless $arity == 2;

  JS::inline('new PIL2JS.Box.Constant(function (args) {
    // [].concat(...): Defeat modifying of the original array.
    var array = [].concat(args[1].GET()), cmp = args[2].GET();
    var jscmp = function (a, b) {
      return cmp([PIL2JS.Context.ItemAny, a, b]).toNative();
    };
    array.sort(jscmp);
    return new PIL2JS.Box.Constant(array);
  })')(@array, $cmp);
}

method reduce(@self: Code $code) { reduce $code, *@self }
sub JS::Root::reduce(Code $code, *@array) is primitive {
  die "&reduce needs a Code as first argument!" unless $code.isa("Code");
  my $arity = $code.arity;
  die "Can't use an unary or nullary block for &reduce!" if $arity < 2;

  my $ret = @array.shift;
  while +@array > 0 {
    my @args;
    my $i; loop $i = 0; $i < $arity - 1; $i++ {
      # Slighly hacky
      push @args: undef;
      @args[-1] := @array.shift;
    }
    $ret = $code($ret, *@args);
  }

  $ret;
}

method min(@self: Code ?$cmp = &infix:«<=>») { min $cmp, *@self }
method max(@self: Code ?$cmp = &infix:«<=>») { max $cmp, *@self }
sub JS::Root::min(Code ?$cmp = &infix:«<=>», *@array) is primitive {
  # Hack, see comment at &sort.
  unless $cmp.isa("Code") {
    unshift @array, @$cmp;
    $cmp := &infix:«<=>»;
  }
  @array.max:{ $cmp($^b, $^a) };
}
sub JS::Root::max(Code ?$cmp = &infix:«<=>», *@array) is primitive {
  # Hack, see comment at &sort.
  unless $cmp.isa("Code") {
    unshift @array, @$cmp;
    $cmp := &infix:«<=>»;
  }

  my $max = @array.shift;
  $max = ($cmp($max, $_)) < 0 ?? $_ :: $max for @array;
  $max;
}

method grep(@self: Code $code) { grep $code, *@self }
sub JS::Root::grep(Code $code, *@array) is primitive {
  die "Code block for \"grep\" must be unary!" unless $code.arity == 1;

  my @res;
  for @array -> $item is rw {
    push @res, $item if $code($item);
  }
  @res;
}

method sum(@self:) { sum *@self }
sub JS::Root::sum(*@vals) is primitive {
  my $sum = 0;
  $sum += +$_ for @vals;
  $sum;
}

sub infix:<..>(Num $from is copy, Num $to) is primitive {
  my @array = ($from,);

  while(($from += 1) <= $to) {
    push @array: $from;
  }

  @array;
}
sub infix:<^..>  (Num $from, Num $to) is primitive { ($from + 1)..$to }
sub infix:<..^>  (Num $from, Num $to) is primitive { $from..($to - 1) }
sub infix:<^..^> (Num $from, Num $to) is primitive { ($from + 1)..($to - 1) }

sub infix:<,>(*@xs is rw) is primitive is rw {
  JS::inline('new PIL2JS.Box.Constant(function (args) {
    var cxt   = args.shift();
    var iarr  = args[0].GET();

    var array = [];
    for(var i = 0; i < iarr.length; i++) {
      // The extra new PIL2JS.Box is necessary to make the contents of arrays
      // readwrite, i.e. my @a = (0,1,2); @a[1] = ... should work.
      array[i] = new PIL2JS.Box(iarr[i].GET());
    }

    // Proxy needed for ($a, $b) = (3, 4) which really is
    // &infix:<,>($a, $b) = (3, 4);
    var proxy = new PIL2JS.Box.Proxy(
      function ()  { return array },
      function (n) {
        var marray = [];
        for(var i = 0; i < iarr.length; i++) {
          marray[i] = new PIL2JS.Box(undefined).BINDTO(
            // Slighly hacky way to determine if iarr[i] is undef, i.e.
            // it\'s needed to make
            //   my ($a, undef, $b) = (3,4,5);
            // work.
            iarr[i].constant && iarr[i].GET() == undefined
              ? new PIL2JS.Box(undefined)
              : iarr[i]
          );
        }

        var arr = new PIL2JS.Box([]).STORE(n).GET();
        for(var i = 0; i < arr.length; i++) {
          if(marray[i]) marray[i].STORE(arr[i]);
        }

        return this;
      }
    );

    return proxy;
  })')(@xs);
}

sub circumfix:<[]>(*@xs) is primitive { \@xs }
method postcircumfix:<[]>(@self: Int $idx is copy) is rw {
  die "Can't use object of type {@self.ref} as an array!"
    unless @self.isa("Array");

  # *Important*: We have to calculate the idx only *once*:
  #   my @a  = (1,2,3,4);
  #   my $z := @a[-1];
  #   say $z;               # 4
  #   push @a, 5;
  #   say $z;               # 4 (!!)
  $idx = +@self + $idx if $idx < 0;
  JS::inline('new PIL2JS.Box.Constant(function (args) {
    var cxt   = args.shift();
    var array = args[0].GET();
    var idx   = Number(args[1].toNative());

    // Relay .GET and .STORE to array[idx].
    var ret = new PIL2JS.Box.Proxy(
      function () {
        var ret = array[idx];
        return ret == undefined ? undefined : ret.GET();
      },
      function (n) {
        if(array[idx] == undefined)
          array[idx] = new PIL2JS.Box(undefined);
        array[idx].STORE(n);
        return n;
      }
    );

    ret.uid = array[idx] == undefined ? undefined : array[idx].uid;

    // .BINDTO is special: @a[$idx] := $foo should work, but @a[1000], with +@a
    // < 1000, should not.
    ret.BINDTO = function (other) {
      if(array[idx] == undefined)
        PIL2JS.die("Can\'t rebind undefined!");

      return array[idx].BINDTO(other);
    };

    return ret;
  })')(@self, $idx);
}
