
class Perl::Param;

# from src/Pugs/AST/Internals.hs (see line starting "data Param")

has Bool $isInvocant;
has Bool $isOptional;
has Bool $isNamed;
has Bool $isLValue;    # not is copy
has Bool $isWritable;  # is rw
has Bool $isLazy;
has Str $paramName;
has Perl::Cxt $paramContext;
has Any $paramDefault;

# deriving (Show, Eq, Ord)
method Show {
    ...
}

method &infix:«==»($self, Perl::Param $other) {
    ...
}

method &infix:«<»($self, Perl::Param $other) {
    ...
}

# maybe something like  this?
type Perl::Params Array of Perl::Param;
