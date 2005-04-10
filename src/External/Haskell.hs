{-# OPTIONS_GHC -fglasgow-exts -fth -cpp -package plugins #-}

module External.Haskell where
import AST

#undef PUGS_HAVE_TH
#include "../pugs_config.h"
#ifndef PUGS_HAVE_TH
externalizeHaskell :: String -> String -> IO String
externalizeHaskell  = error "Template Haskell support not compiled in"
loadHaskell :: FilePath -> IO [(String, [Val] -> Eval Val)]
loadHaskell         = error "Template Haskell support not compiled in"
#else

import Internals
import Language.Haskell.TH as TH
import Language.Haskell.Parser
import Language.Haskell.Syntax
import Plugins
-- import Plugins.Package

{- ourPackageConfigs :: [PackageConfig]
ourPackageConfigs = [
    PackageConfig {
        hs_libraries = ["Unicode.o"]
        extra_libraries = ["UnicodeC.o"]
    }
] -}
ourPackageConfigs = []

loadHaskell :: FilePath -> IO [(String, [Val] -> Eval Val)]
loadHaskell file = do
    loadRawObject "/usr/src/pugs/blib6/arch/CORE/pugs/UnicodeC.o"
    loadRawObject "/usr/src/pugs/blib6/arch/CORE/pugs/pcre/pcre.o"
    load "/usr/src/pugs/blib6/arch/CORE/pugs/Compat.o" ["/usr/src/pugs/blib6/arch/CORE/pugs/", "/usr/src/SHA1/src/"] ourPackageConfigs ""

    externstat <- load "/usr/src/SHA1/SHA1__0_0_1.o"  ["/usr/src/pugs/blib6/arch/CORE/pugs/", "/usr/src/SHA1/src/"] ourPackageConfigs "extern__"
    (extern :: [String]) <- case externstat of
        LoadFailure _   -> error "load failed"
        LoadSuccess _ v -> return v
    print (">"++(show extern)++"<")
    (`mapM` extern) $ \name -> do
        funcstat <- load "/usr/src/SHA1/SHA1__0_0_1.o"  ["/usr/src/pugs/blib6/arch/CORE/pugs/", "/usr/src/SHA1/src/"] ourPackageConfigs ("extern__" ++ name)
        func <- case funcstat of
            LoadFailure _   -> error ("load of extern__"++name++" failed")
            LoadSuccess _ v -> return v
        return (name, func)

externalizeHaskell :: String -> String -> IO String
externalizeHaskell mod code = do
    let names = map snd exports
    symTable <- runQ [d| extern__ = names |]
    symDecls <- mapM wrap names
    return $ unlines $
        [ "module " ++ mod ++ " where"
        , "import Internals"
        , "import GHC.Base"
        , "import AST"
        , ""
        , code
        , ""
        , "-- below are automatically generated by Pugs --"
        , TH.pprint symTable
        , TH.pprint symDecls
        ] 
    where
    exports :: [(HsQualType, String)]
    exports = concat [ [ (typ, name) | HsIdent name <- names ]
                     | HsTypeSig _ names typ <- parsed
                     ]
    parsed = case parseModule code of
        ParseOk (HsModule _ _ _ _ decls) -> decls
        ParseFailed _ err -> error err

wrap :: String -> IO Dec
wrap fun = do
    [quoted] <- runQ [d|
            name = \[v] -> do
                s <- fromVal v
                return (castV ($(dyn fun) s))
        |]
    return $ munge quoted ("extern__" ++ fun)

munge (ValD _ x y) name = ValD (VarP (mkName name)) x y
munge _ _ = error "impossible"



#endif
