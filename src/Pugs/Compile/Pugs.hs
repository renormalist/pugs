{-# OPTIONS_GHC -cpp -fglasgow-exts -fth #-}

#include "../pugs_config.h"

module Pugs.Compile.Pugs (genPugs) where
import Pugs.AST
import Pugs.Types
import Pugs.Internals
import Text.PrettyPrint

class (Show x) => Compile x where
    compile :: x -> Eval Doc
    compile x = fail ("Unrecognized construct: " ++ show x)
    compileList :: [x] -> Eval Doc
    compileList = fmap prettyList . mapM compile

instance (Compile x) => Compile [x] where
    compile = compileList

sep1 :: Doc -> Doc -> Doc
sep1 a b = sep [a, b]

prettyList :: [Doc] -> Doc
prettyList = brackets . vcat . punctuate comma

prettyDo :: [Doc] -> Doc
prettyDo docs = parens $ sep (text "do":punctuate semi docs)

prettyRecord :: String -> [(String, Doc)] -> Doc
prettyRecord con = (text con <+>) . braces . sep . punctuate comma . map assign
    where assign (name, val) = text name <+> char '=' <+> val

prettyBind :: String -> Doc -> Doc
prettyBind var doc = text var `sep1` nest 1 (text "<-" <+> doc)


instance Compile (Maybe Exp) where
    compile Nothing = return $ text "return Nothing"
    compile (Just exp) = do
        expC <- compile exp
        return $ prettyDo 
            [ prettyBind "exp" expC
            , text "return (Just exp)"
            ]

instance Compile Exp where
    compile (App exp1 exp2 exps) = do
        exp1C <- compile exp1
        exp2C <- compile exp2
        expsC <- compileList exps
        return $ prettyDo 
            [ prettyBind "exp1" exp1C
            , prettyBind "exp2" exp2C
            , prettyBind "exps" (text "sequence" `sep1` expsC)
            , text "return (App exp1 exp2 exps)"
            ]
    compile (Syn syn exps) = do
        expsC <- compileList exps
        return $ prettyDo
            [ prettyBind "exps" (text "sequence" `sep1` expsC)
            , text "return" <+> parens (text $ "Syn " ++ show syn ++ " exps")
            ]
    compile (Cxt cxt exp) = compileShow2 "Cxt" cxt exp
    compile (Pos pos exp) = compileShow2 "Pos" pos exp
    compile (Pad scope pad exp) = do
        padC <- compile pad
        expC <- compile exp
        return $ prettyDo
            [ prettyBind "pad" padC
            , prettyBind "exp" expC
            , text ("return (Pad " ++ show scope ++ " pad exp)")
            ]
    compile (Stmts exp1 exp2) = do
        exp1C <- compile exp1
        exp2C <- compile exp2
        return $ prettyDo 
            [ prettyBind "exp1" exp1C
            , prettyBind "exp2" exp2C
            , text "return (Stmts exp1 exp2)"
            ]
    compile (Val val) = do
        valC <- compile val
        return $ prettyDo 
            [ prettyBind "val" valC
            , text "return (Val val)"
            ]
    compile exp = return $ text "return" $+$ parens (text $ show exp)

compileShow2 :: Show a => String -> a -> Exp -> Eval Doc
compileShow2 con anno exp = do
    expC <- compile exp
    return $ prettyDo
        [ prettyBind "exp" expC
        , text ("return (" ++ con ++ " (" ++ show anno ++ ") exp)")
        ]

instance Compile Pad where
    compile pad = do
        symsC <- mapM compile syms
        return $ text "fmap mkPad . sequence $ "
            $+$ nest 4 (prettyList $ filter (not . isEmpty) symsC)
        where
        syms = padToList pad

instance Compile (String, [(TVar Bool, TVar VRef)]) where
    compile ((_:'?':_), _) = return empty -- XXX - @?S etc; punt for now
    compile ((_:'*':_), _) = return empty -- XXX - @*INIT etc; punt for now
    compile ((_:'=':_), _) = return empty -- XXX - @=POS etc; punt for now
    compile (n, tvars) = do
        tvarsC <- compile tvars
        return $ prettyDo 
                [ prettyBind "tvars" (text "sequence" `sep1` tvarsC)
                , text ("return (" ++ show n ++ ", tvars)")
                ]

instance (Typeable a) => Compile (Maybe (TVar a)) where
    compile = const . return $ text "Nothing"

instance Compile (TVar Bool, TVar VRef) where
    compile (fresh, tvar) = do
        freshC <- compile fresh
        tvarC  <- compile tvar
        return $ prettyDo 
                [ prettyBind "fresh" freshC
                , prettyBind "tvar" tvarC
                , text "return (fresh, tvar)"
                ]

instance Compile (TVar Bool) where
    compile fresh = do
        bool <- liftSTM $ readTVar fresh
        return $ text "liftSTM" <+> parens (text "newTVar" <+> text (show bool))

instance Compile (TVar VRef) where
    compile fresh = do
        vref    <- liftSTM $ readTVar fresh
        vrefC   <- compile vref
        return $ prettyDo
            [ prettyBind "vref" vrefC
            , text "liftSTM (newTVar vref)"
            ]

instance Compile VRef where
    compile (MkRef (ICode cv)) = do
        vsub    <- code_fetch cv
        vsubC   <- compile vsub
        return $ prettyDo
            [ prettyBind "vsub" vsubC
            , text "return (MkRef $ ICode vsub)"
            ]
    compile (MkRef (IScalar sv)) | scalar_iType sv == mkType "Scalar::Const" = do
        sv  <- scalar_fetch sv
        svC <- compile sv
        return $ prettyDo
            [ prettyBind "sv" svC
            , text "return (MkRef $ IScalar sv)"
            ]
    compile ref = do
        return $ text $ "newObject (mkType \"" ++ showType (refType ref) ++ "\")"

instance Compile Val where
    compile (VCode code) = do
        codeC <- compile code
        return $ prettyDo
            [ prettyBind "code" codeC
            , text "return $ VCode code"
            ]
    compile x = return $ text "return" $+$ parens (text $ show x)

-- This wants a total rewrite.  I strongly want Data.Generics at this point now.

-- Haddock can't cope with Template Haskell
instance Compile VCode where
    compile MkCode{ subBody = Prim _ } = return $ text "return mkPrim"
    compile code = do 
        bodyC <- compile $ subBody code
        let comp :: Show a => (VCode -> a) -> Doc
            comp f = text $ show (f code)
            vsub = prettyRecord "MkCode" $
                [ ("isMulti",       comp isMulti)
                , ("subName",       comp subName)
                , ("subType",       comp subType)
                , ("subEnv",        text "Nothing")
                , ("subAssoc",      comp subAssoc)
                , ("subParams",     comp subParams)
                , ("subBindings",   comp subBindings)
                , ("subSlurpLimit", comp subSlurpLimit)
                , ("subReturns",    comp subReturns)
                , ("subLValue",     comp subLValue)
                , ("subBody",       text "body")
                , ("subCont",       text "Nothing")
                ]
        return $ prettyDo
            [ prettyBind "body" bodyC
            , text "return" <+> parens vsub
            ]

genPugs :: Eval Val
genPugs = do
    exp     <- asks envBody
    glob    <- askGlobal
    globC   <- compile glob
    expC    <- compile exp
    return . VStr . unlines $
        [ "{-# OPTIONS_GHC -fglasgow-exts -fno-warn-unused-imports -fno-warn-unused-binds -O #-}"
        , "module MainCC where"
        , "import Pugs.Run"
        , "import Pugs.AST"
        , "import Pugs.Types"
        , "import Pugs.Internals"
        , ""
        , "mainCC = do"
        , "    glob <- globC"
        , "    exp  <- expC"
        , "    runAST glob exp"
        , ""
        , renderStyle (Style PageMode 100 0) $ text "globC =" <+> globC
        , ""
        , renderStyle (Style PageMode 100 0) $ text "expC =" <+> expC
        , ""
        ]
