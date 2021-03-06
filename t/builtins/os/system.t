use v6-alpha;
use Test;

# L<S29/"OS"/"=item run">
# system may be re-named to run, so link there. 

plan 3;

if $*OS eq "browser" {
  skip_rest "Programs running in browsers don't have access to regular IO.";
  exit;
}

my $pugs = $*OS eq any <MSWin32 mingw msys cygwin> 
         ?? 'pugs.exe'
         !! './pugs';

my $res;

$res = system($pugs,'-e1');
ok($res,"system() to an existing program does not die (and returns something true)", :todo<feature>, :depends<0 but True>);

$res = system("program_that_does_not_exist_ignore_this_error_please.exe");
ok(!$res, "system() to a nonexisting program does not die (and returns something false)");

if $*OS ~~ any <cygwin MSWin32 msys> {
    skip 1, "skip crashing test on win32";
} else {
    $res = system("program_that_does_not_exist_ignore_errors_please.exe","a","b");
    ok(!$res, "system() to a nonexisting program with an argument list does not die (and returns something false)");
}
