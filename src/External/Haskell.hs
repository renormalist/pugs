{-# OPTIONS -fglasgow-exts -fth -cpp -O #-}

module External.Haskell where
import AST
import Internals
import Internals.TH
import Language.Haskell.Parser
import Language.Haskell.Syntax
import External.Haskell.NameLoader

loadHaskell :: FilePath -> IO [(String, [Val] -> Eval Val)]
loadHaskell file = undefined

externalizeHaskell :: String -> String -> IO String
externalizeHaskell mod code = do
    let names = map snd exports
    symTable <- runQ [d| extern__ = names |]
    symDecls <- mapM wrap names
    return $ unlines $
        [ "module " ++ mod ++ " where"
        , "import AST"
        , ""
        , showTH symTable
        , showTH symDecls
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
