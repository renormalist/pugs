#!/usr/bin/pugs

use v6;
use Test;

=kwid

I/O tests

=cut

plan 1;

if $*OS eq "browser" {
  skip_rest "Programs running in browsers don't have access to regular IO.";
  exit;
}

my $filename = 'tempfile';

# Following test is spread across io_finalize_part1.t and io_finalize_part2.t
# Writes to a filehandle without explicit close do not output even after
# program termination.  tempfile is created here and deleted in part2

my $fh = open($filename, :w);
isa_ok($fh, IO);
$fh.say("Hello World");
