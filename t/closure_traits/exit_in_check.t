use v6-alpha;

use Test;

# $failed is set to 0 (actually to undef) at compiletime.
my $failed;
# At run time, if we ever reach runtime, $failed is set to 1.
$failed = 1;

# When we end, we check if $failed is still 0. If yes, we've never reached runtime.
END {
  ok 0, 'END {...} should not be invoked';
}

CHECK {
  # Output the TAP header...
  plan 1;
  is $failed, undef, 'exit() works in CHECK {}';
  # ...and exit, which does _not_ call END.
  exit;
}
