method say   (Str $text:) { say   $text }
method print (Str $text:) { print $text }

sub JS::Root::say(Str *@text)   is primitive { print *@text, "\n" }
sub JS::Root::print(Str *@text) is primitive {
  JS::inline('(
    function (msg) {
      // Rest copied from
      // http://openjsan.org/doc/t/th/theory/Test/Simple/0.11/lib/Test/Builder.html.
      // --iblech
      // I\'m sure that there must be a more efficient way to do this,
      // but if I store the node in a variable outside of this function
      // and refer to it via the closure, then things don\'t work right
      // --the order of output can become all screwed up (see
      // buffer.html).  I have no idea why this is.
      var node = document.getElementById("__pil2js_tty");
      if (node) {
          // This approach is neater, but causes buffering problems when
          // mixed with document.write. See tests/buffer.html.
          //node.appendChild(document.createTextNode(msg));
          //return;
          for (var i = 0; i < node.childNodes.length; i++) {
              if (node.childNodes[i].nodeType == 3 /* Text Node */) {
                  // Append to the node and scroll down.
                  node.childNodes[i].appendData(msg);
                  window.scrollTo(0, document.body.offsetHeight
                                  || document.body.scrollHeight);
                  return;
              }
          }

          // If there was no text node, add one.
          node.appendChild(document.createTextNode(msg));
          window.scrollTo(0, document.body.offsetHeight
                          || document.body.scrollHeight);
          return;
      }

      // Default to the normal write and scroll down...
      document.write(msg);
      window.scrollTo(0, document.body.offsetHeight
                      || document.body.scrollHeight);
    }
  )')(@text.join(""));
  ?1;
}

sub JS::Root::slurp(Str $filename) is primitive {
  JS::inline('(
    function (filename) {
        if (!Perl5) throw "Perl5 required.";
        Perl5.perl_use("IO::File");
        return Perl5.perl_eval("(sub { local $/; my $f = IO::File->new(\'<\'.$_[0]) or die $!; return <$f>})")(filename);
    }
  )')($filename)
}

sub JS::Root::unlink(Str $filename) is primitive {
  JS::inline('(
    function (filename) {
        if (!Perl5) throw "Perl5 required.";
        return Perl5.perl_eval("(sub { unlink($_[0]) or die $! })")(filename);
    }
  )')($filename)
}

sub JS::Root::system(Str *@command) is primitive {
  JS::inline('(
    function (arguments) {
        if (!Perl5) throw "Perl5 required.";
        var system = Perl5.perl_eval("sub {system(@_)}");
        return system.apply(system, arguments);
    }
  )')(@command)
}

