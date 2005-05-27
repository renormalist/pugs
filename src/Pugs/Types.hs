{-# OPTIONS_GHC -fglasgow-exts -fno-warn-orphans -funbox-strict-fields #-}

{-|
    Implementation Types.

>   Three Rings for the Elven-kings under the sky,
>   Seven for the Dwarf-lords in their halls of stone,
>   Nine for Mortal Men doomed to die,
>   One for the Dark Lord on his dark throne
>   In the Land of Mordor where the Shadows lie.
-}

module Pugs.Types where
import Pugs.Internals

data Type
    = MkType !String      -- ^ A regular type
    | TypeOr  !Type !Type -- ^ The disjunction (|) of two types
    | TypeAnd !Type !Type -- ^ The conjunction (&) of two types
    deriving (Eq, Ord, Typeable)

instance Show Type where
    show t = "(mkType \"" ++ showType t ++ "\")"

showType :: Type -> String
showType (MkType typ)    = typ
showType (TypeOr t1 t2)  = showType t1 ++ "|" ++ showType t2
showType (TypeAnd t1 t2) = showType t1 ++ "&" ++ showType t2

type ClassTree = Tree Type


data Cxt = CxtVoid         -- ^ Context that isn't expecting any values
         | CxtItem !Type   -- ^ Context expecting a value of the specified type
         | CxtSlurpy !Type -- ^ Context expecting multiple values of the
                           --     specified type
    deriving (Eq, Show, Ord)

anyType :: Type
anyType = mkType "Any"

cxtItem   :: String -> Cxt
cxtItem   = CxtItem . mkType
cxtSlurpy :: String -> Cxt
cxtSlurpy = CxtItem . mkType
cxtVoid   :: Cxt
cxtVoid   = CxtVoid

typeOfCxt :: Cxt -> Type
typeOfCxt CxtVoid           = anyType
typeOfCxt (CxtItem typ)     = typ
typeOfCxt (CxtSlurpy typ)   = typ

-- | Return a 'Cxt' indicating a context expecting a scalar of any type
cxtItemAny :: Cxt
cxtItemAny   = CxtItem anyType
-- | Return a 'Cxt' indicating a context expecting a list of any type
cxtSlurpyAny :: Cxt
cxtSlurpyAny = CxtSlurpy anyType

{-|
Return true if the given 'Cxt' (context) is 'CxtSlurpy', rather than
'CxtItem' or 'CxtVoid'.
-}
isSlurpyCxt :: Cxt -> Bool
isSlurpyCxt (CxtSlurpy _) = True
isSlurpyCxt _             = False
{-|
Return true if the given 'Cxt' (context) is 'CxtItem', rather than
'CxtSlurpy' or 'CxtVoid'.
-}
isItemCxt :: Cxt -> Bool
isItemCxt   (CxtItem _)   = True
isItemCxt   _             = False
{-|
Return true if the given 'Cxt' (context) is 'CxtVoid', rather than
'CxtSlurpy' or 'CxtItem'.
-}
isVoidCxt :: Cxt -> Bool
isVoidCxt   CxtVoid       = True
isVoidCxt   _             = False

-- | Return the Perl 5 calling convention bit value for the context.
enumCxt :: (Num a) => Cxt -> a
enumCxt CxtVoid       = 128
enumCxt (CxtItem _)   = 0
enumCxt (CxtSlurpy _) = 1

-- | Return the 'Cxt' corresponding to the given P5 calling convention bits.
cxtEnum :: (Show a, Num a) => a -> Cxt
cxtEnum 128 = CxtVoid
cxtEnum 0   = cxtItemAny
cxtEnum 1   = cxtSlurpyAny
cxtEnum n   = error ("Invalid cxt: " ++ show n)

{-|
Make a type value representing the type with the specified name.

Recognises conjunctive (&) and disjunctive (|) types.
-}
mkType :: String -- ^ Name of the type, e.g. \"Hash\" or \"Str|Int\"
       -> Type
mkType str
    | (t1, (_:t2)) <- span (/= '|') str
    = TypeOr (MkType t1) (mkType t2)
    | (t1, (_:t2)) <- span (/= '&') str
    = TypeAnd (MkType t1) (mkType t2)
    | otherwise
    = MkType str

-- | Variable name.
type Var   = String
-- | Uses Haskell's underlying representation for strings.
type VStr  = String
-- | Uses Haskell's underlying representation for booleans.
type VBool = Bool
-- | Uses Haskell's underlying representation for integers.
type VInt  = Integer
-- | Uses Haskell's underlying representation for rational numbers.
type VRat  = Rational
-- | Uses Haskell's 'Double' type to represent arbitrary numbers.
type VNum  = Double
-- | Uses Haskell's underlying representation for complex numbers.
type VComplex = Complex VNum
-- | Uses Haskell's underlying representation for filehandles.
type VHandle = Handle
-- | Uses Haskell's underlying representation for sockets.
type VSocket = Socket
-- | Uses Haskell's underlying representation for threads.
data VThread a = MkThread
    { threadId      :: ThreadId
    , threadLock    :: TMVar a
    }
    deriving (Show, Eq, Ord, Typeable)

-- | Rule Match object from PGE
data MatchPGE
    = PGE_Match !Int !Int ![MatchPGE] ![(VStr, MatchPGE)]
    | PGE_Array ![MatchPGE]
    | PGE_Fail
    deriving (Show, Eq, Ord, Read, Typeable)


{-|
Representation for rules (i.e. regexes).

Currently there are two types of rules: Perl 5 rules, implemented with PCRE,
and Perl 6 rules, implemented with PGE.
-}
data VRule
    = MkRulePCRE -- ^ Perl5-compatible regular expression
        { rxRegex     :: !Regex -- ^ The \'regular\' expression (as a PCRE
                                --     'Regex' object)
        , rxGlobal    :: !Bool  -- ^ Flag indicating \'global\' (match-all)
	    , rxStringify :: !Bool
        }
    | MkRulePGE  -- ^ Parrot Grammar Engine rule
        { rxRule      :: !String -- ^ The rule string
        , rxGlobal    :: !Bool   -- ^ Flag indicating \'global\' (match-all)
	    , rxStringify :: !Bool
        }
    deriving (Show, Eq, Ord, Typeable)

instance Ord VHandle where
    compare _ _ = EQ
instance Ord VSocket where
    compare x y = compare (show x) (show y)
instance (Ord a) => Ord (Tree a) where
    compare _ _ = EQ
instance Ord (TMVar a) where
    compare x y = compare (show x) (show y)
instance Eq (TMVar a) where
    _ == _ = True
instance Show (TMVar a) where
    show _ = "<tmvar>"

