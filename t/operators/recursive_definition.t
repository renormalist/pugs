#!/usr/bin/pugs

use v6;
use Test;

plan 1;

sub postfix:<!>($arg) {
	if ($arg == 0) { 1;}
	else { ($arg-1)! * $arg;}
}

ok(5! == 120, "recursive factorial works");
