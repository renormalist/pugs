#!/usr/bin/perl -w

use strict;
use IPC::Open2;
use Getopt::Long;
use Config ();

# helper code to inline the Standard Prelude in pugs.

# Sets up either the Null Prelude placeholder, or a real precompiled
# AST of Prelude.pm.

our %Config;
our $TEMP_PRELUDE = "Prelude.pm"; # XXX: move this to config.yml?
END { unlink $TEMP_PRELUDE unless $Config{keep} };

GetOptions \%Config, qw(--null --pugs|p=s --inline|i=s@ --verbose|v --touch --output|o=s --keep|k);
setup_output();

touch() if $Config{touch};

precomp(), exit 0 if $Config{inline};
null(), exit 0 if $Config{null};
usage();
exit 1;

sub setup_output {
    if ($Config{output}) {
        open OUT, "> $Config{output}" or
            die "open: $Config{output}: $!";
    } else {
        *OUT = *STDOUT;
    }
}

sub touch {
    # XXX: *ugly* hack! ghc doesn't spot that the include file was changed,
    #      so we need to mark as stale some obj files to trigger a rebuild.
    #      The alternative seems to be to delete them *and* the pugs
    #      executable.
    print STDERR "Triggering rebuild... " if $Config{verbose};
    unlink "src/Pugs/Run.hi";
    unlink "src/Pugs/Run.o";
    unlink "dist/build/Pugs/Run.hi";
    unlink "dist/build/Pugs/Run.o";
    unlink "dist/build/src/Pugs/Run.hi";
    unlink "dist/build/src/Pugs/Run.o";
    #unlink "pugs$Config::Config{_exe}";
    print STDERR "done.\n" if $Config{verbose};
}

sub null {
    print STDERR "Generating null Prelude... " if $Config{verbose};
    open NP, "src/Pugs/PreludePC.hs-null" or
        die "Couldn't open null Prelude (src/Pugs/PreludePC.hs-null): $!";
    print OUT <NP>;
    print STDERR "done.\n" if $Config{verbose};
}

# concatenate source files. hardcode special treatment to the Prelude,
# which is assumed to be the first module in the list.
sub gen_source {
    my($target) = @_;
    open my $ofh, ">", $target or die "open: $target: $!";

    {
        my $prelude = shift @{ $Config{inline} };
        warn "*** warning: Prelude.pm should probably be the first --include\n"
            unless $prelude =~ /Prelude/;
        open my $ifh, $prelude or die "open: $prelude: $!";
        print $ofh $_ while <$ifh>;
    }

    # manhandle the rest of the inlined modules.
    # we make a guess about what to put in %*INC. it's not perfect.
    # When module return values are specced, we can make this much
    # less hacky :-)
    for my $file (@{ $Config{inline} }) {
        my $module; # guess what to put in %*INC
        open my $ifh, $file or die "open: $file: $!";
        
        print $ofh "\n{\n";
        while (<$ifh>) {
            $module ||= $1 if /^(?:package|module|class) \s+ ([^-;]+)/x;
            print $ofh $_;
        }
        die "could not guess module name: $file" unless $module;
        print STDERR ", $module" if $Config{verbose};
        $module =~ s#::#/#g;
        print $ofh "\n};\n%*INC<${module}.pm> = '<precompiled>';\n\n";
        # (the need for a semicolon in "};" is probably a bug.)
    }
    print STDERR "... " if $Config{verbose};
}

sub precomp {
    print STDERR "Generating precompiled Prelude" if $Config{verbose};
    die "*** Error: $0 needs an already compiled Pugs to precompile the Prelude\n"
        unless $Config{pugs};
    gen_source($TEMP_PRELUDE);
    $ENV{PUGS_COMPILE_PRELUDE} = 1;

    my ($rh, $wh);
    my $pid = open2($rh, $wh, $Config{pugs}, -C => 'Pugs', $TEMP_PRELUDE);
    my $program = do { local $/; <$rh> };
    waitpid($pid, 0);

    exit 1 unless length $program;

    print OUT <<'.';
{-# OPTIONS_GHC -fglasgow-exts -fno-full-laziness -fno-cse #-}
{-
    *** NOTE ***
    DO NOT EDIT THIS FILE.
    This module is automatically generated by util/gen_prelude.pl.
-}

{-
    Perl 6 Prelude.
 
>   The world was fair, the mountains tall,
>   In Eldar Days before the fall
>   Of mighty kings in Nargothrond
>   And Gondolin, who now beyond
>   The Western Seas have passed away:
>   The world was fair in Durin's day.
 
-}

{-# NOINLINE _BypassPreludePC #-}
_BypassPreludePC :: IORef Bool
_BypassPreludePC = unsafePerformIO $ do
    bypass <- getEnv "PUGS_BYPASS_PRELUDE"
    newIORef $ case bypass of
        Nothing     -> False
        Just ""     -> False
        Just "0"    -> False
        _           -> True

{-# NOINLINE initPreludePC #-}
initPreludePC :: Env -> IO Env
initPreludePC env = do
    bypass <- readIORef _BypassPreludePC
    if bypass then return env else do
        -- Display the progress of loading the Prelude, but only in interactive
        -- mode (similar to GHCi):
        -- "Loading Prelude... done."
        let dispProgress = (posName . envPos $ env) == "<interactive>"
        when dispProgress $ putStr "Loading Prelude... "
        ast <- astPCP                  -- what pugs -CPugs Prelude.pm gives,
        glob <- globPCP                -- made available here.
        globRef <- liftSTM $ do
            glob' <- readTVar $ envGlobal env
            newTVar (glob `unionPads` glob')
        runEnv env{ envBody = ast, envGlobal = globRef, envDebug = Nothing }
        when dispProgress $ putStrLn "done."
        return env{ envGlobal = globRef }

.

    $program =~ s/.*^globC/globPCP :: IO Pad\nglobPCP/ms;
    $program =~ s/^expC/astPCP :: IO Exp\nastPCP/ms;
    print OUT $program;

    die "Pugs ".(($?&255)?"killed by signal $?"
         :"exited with error code ".($?>>8)) if $?;
    print STDERR "done.\n" if $Config{verbose};
}

sub usage {
    print STDERR <<".";
usage: $0 --null [options]
       $0 --inline src/perl6/Prelude.pm --pugs ./pugs.exe [options]

Creates a PreludePC.hs file (written to stdout), to be included by Run.hs.

In the first build phase, a "null" Prelude with only placeholder functions
is used. In the second phase, the Standard Prelude is precompiled and
inlined into the resulting pugs executable.

Additional options:
    --verbose, -v     print progress to stderr
    --touch,   -t     mark Run.hi and Run.o stale, triggering pugs rebuild
    --output,  -o     file to write output to (stdout by default)
.
}
