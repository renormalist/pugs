{-# OPTIONS_GHC -fglasgow-exts -fallow-undecidable-instances -fno-warn-orphans -funbox-strict-fields -cpp #-}
{-# OPTIONS_GHC -#include "UnicodeC.h" #-}

{-|
    This module provides 'genPIR', a function which compiles the current
    environment to PIR code.

    The general plan is to first compile the environment (subroutines,
    statements, etc.) to an abstract syntax tree ('PIL' -- Pugs Intermediate
    Language) using the 'compile' function and 'Compile' class, and then
    translate the PIL to a data structure of type 'PIR' using the 'trans'
    function and 'Translate' class. This data structure is then reduced to
    final PIR code by "Emit.PIR".
-}

module Pugs.Compile.PIR (genPIR) where
import Pugs.Internals
import Pugs.AST
import Pugs.AST.Internals
import Emit.Common
import Pugs.Types
import Pugs.Eval
import Emit.PIR
import Pugs.Pretty
import Text.PrettyPrint
import Pugs.Compile.PIR.Prelude (preludeStr)
import Pugs.Prim.Eval

#ifndef HADDOCK
-- Type-indexed with GADT; it is a bit too baroque -- refactor toward ANF?
data (Typeable a) => PIL a where
    PNil        :: PIL [a]
    PNoop       :: PIL Stmt

    PRawName    :: !VarName -> PIL Expression -- XXX HACK!

    PExp        :: !(PIL LValue) -> PIL Expression 
    PLit        :: !(PIL Literal) -> PIL Expression
    PPos        :: !Pos -> !Exp -> !(PIL a) -> PIL a
    PStmt       :: !(PIL Expression) -> PIL Stmt 
    PThunk      :: !(PIL Expression) -> PIL Expression 
    PCode       :: !SubType -> ![TParam] -> !(PIL [Stmt]) -> PIL Expression 

    PVal        :: !Val -> PIL Literal
    PVar        :: !VarName -> PIL LValue

    PStmts      :: !(PIL Stmt) -> !(PIL [Stmt]) -> PIL [Stmt]
    PApp        :: !TCxt -> !(PIL Expression) -> ![PIL Expression] -> PIL LValue
    PAssign     :: ![PIL LValue] -> !(PIL Expression) -> PIL LValue
    PBind       :: ![PIL LValue] -> !(PIL Expression) -> PIL LValue
    PPad        :: !Scope -> ![(VarName, PIL Expression)] -> !(PIL [Stmt]) -> PIL [Stmt]

    PSub        :: !SubName -> !SubType -> ![TParam] -> !(PIL [Stmt]) -> PIL Decl
#endif

data TParam = MkTParam
    { tpParam   :: !Param
    , tpDefault :: !(Maybe (PIL Expression))
    }
    deriving (Show, Typeable)

data TCxt
    = TCxtVoid | TCxtLValue !Type | TCxtItem !Type | TCxtSlurpy !Type
    | TTailCall !TCxt
    deriving (Show, Eq, Typeable)

tcVoid, tcLValue :: TCxt
tcVoid      = TCxtVoid
tcLValue    = TCxtLValue anyType

{-
tcItem, tcSlurpy :: TCxt
tcItem      = TCxtItem anyType
tcSlurpy    = TCxtSlurpy anyType
-}

instance Show (PIL a) where
    show (PVal x) = "(PVal " ++ show x ++ ")"
    show (PVar x) = "(PVar " ++ show x ++ ")"
    show (PLit x) = "(PLit " ++ show x ++ ")"
    show (PStmts x y) = "(PStmts " ++ show x ++ " " ++ show y ++ ")"
    show PNil = "PNil"
    show PNoop = "PNoop"
    show (PPos x y z) = "(PPos " ++ show x ++ " " ++ show y ++ " " ++ show z ++ ")"
    show (PApp x y z) = "(PApp " ++ show x ++ " " ++ show y ++ " " ++ show z ++ ")"
    show (PExp x) = "(PExp " ++ show x ++ ")"
    show (PStmt x) = "(PStmt " ++ show x ++ ")"
    show (PAssign x y) = "(PAssign " ++ show x ++ " " ++ show y ++ ")"
    show (PBind x y) = "(PBind " ++ show x ++ " " ++ show y ++ ")"
    show (PThunk x) = "(PThunk " ++ show x ++ ")"
    show (PRawName x) = "(PRawName " ++ show x ++ ")"
    show (PPad x y z) = unwords ["(PPad", show x, show y, show z, ")"]
    show (PCode x y z) = unwords ["(PCode", show x, show y, show z, ")"]
    show (PSub x y z w) = unwords ["(PSub", show x, show y, show z, show w, ")"]

data TEnv = MkTEnv
    { tLexDepth :: !Int                 -- ^ Lexical scope depth
    , tTokDepth :: !Int                 -- ^ Exp nesting depth
    , tCxt      :: !TCxt                -- ^ Current context
    , tReg      :: !(TVar (Int, String))-- ^ Register name supply
    , tLabel    :: !(TVar Int)          -- ^ Label name supply
    }
    deriving (Show, Eq)

type Comp a = Eval a
type CompMonad = EvalT (ContT Val (ReaderT Env SIO))
type Trans a = WriterT [Stmt] (ReaderT TEnv IO) a
type TransMonad = WriterT [Stmt] (ReaderT TEnv IO)

{-| Currently only 'Exp' → 'PIL' -}
class (Show a, Typeable b) => Compile a b where
    compile :: a -> Comp b
    compile x = fail ("Unrecognized construct: " ++ show x)

{-| Currently only 'PIL' → 'PIR' -}
class (Show a, Typeable b) => Translate a b | a -> b where
    trans :: a -> Trans b
    trans _ = fail "Untranslatable construct!"

instance Compile (Var, [(TVar Bool, TVar VRef)]) (PIL Decl) where
    compile = compError

instance Compile Param TParam where
    compile prm = do
        defC <- if isOptional prm
            then fmap Just $ compile (paramDefault prm)
            else return Nothing
        return $ MkTParam
            { tpParam = prm
            , tpDefault = defC
            }

{-| Compiles a 'Pad' to a list of 'PIL Decl's. Currently, only subroutines and
    @\@*END@ are compiled. -}
instance Compile Pad [PIL Decl] where
    compile pad = do
        entries' <- mapM canCompile entries
        return $ concat entries'
        where
        entries = sortBy padSort $ padToList pad
        canCompile (name@('&':_), [(_, sym)]) = do
            ref <- liftSTM $ readTVar sym
            case ref of
                MkRef (ICode cv)
                    -> doCode name =<< code_fetch cv
                MkRef (IScalar sv) | scalar_iType sv == mkType "Scalar::Const"
                    -> doCode name =<< fromVal =<< scalar_fetch sv
                _ -> return []
        canCompile ("@*END", [(_, sym)]) = do
            ref     <- liftSTM $ readTVar sym
            cvList  <- fromVals =<< readRef ref :: Comp [VCode]
            decls   <- eachM cvList $ \(i, cv) -> do
                compile (("&*END_" ++ show i), cv) :: Comp [PIL Decl]
            compile ("&*END", concat decls)
        canCompile ((_:twigil:_), _) | not (isAlphaNum twigil) = return []
        canCompile (name, [(_, sym)]) = do
            -- translate them into store_global calls?
            -- placing them each into one separate init function?
            val     <- readRef =<< liftSTM (readTVar sym)
            valC    <- compile val
            let assignC = PAssign [PVar name'] valC
                bodyC   = PStmts (PStmt . PExp $ assignC) PNil
                initL   = "__init_" ++ (render $ varText name)
                name' | ':' `elem` name = name
                      | otherwise = "main::" ++ name -- XXX wrong
            return [PSub initL SubPrim [] bodyC]
        canCompile _ = return []
        doCode name vsub = case subBody vsub of
            Prim _  -> return []
            _       -> compile (name, vsub)

eachM :: (Monad m) => [a] -> ((Int, a) -> m b) -> m [b]
eachM = forM . ([0..] `zip`)

instance Compile (SubName, [PIL Decl]) [PIL Decl] where
    compile (name, decls) = do
        let bodyC = [ PStmts . PStmt . PExp $ PApp tcVoid (PExp (PVar sub)) []
                    | PSub sub _ _ _ <- decls
                    ]
        return (PSub name SubPrim [] (combine bodyC PNil):decls)

instance Compile (SubName, VCode) [PIL Decl] where
    compile (name, vsub) | packageOf name /= packageOf (subName vsub) = do
        let storeC  = PAssign [PVar $ qualify name] (PExp . PVar . qualify $ subName vsub)
            bodyC   = PStmts (PStmt . PExp $ storeC) PNil
            exportL = "__export_" ++ (render $ varText name)
        return [PSub exportL SubPrim [] bodyC]
    compile (name, vsub) = do
        bodyC   <- enter cxtItemAny . compile $ case subBody vsub of
            Syn "block" [body]  -> body
            body                -> body
        paramsC <- compile $ subParams vsub
        return [PSub name (subType vsub) paramsC bodyC]

instance Compile (String, [(TVar Bool, TVar VRef)]) (PIL Expression) where
    compile (name, _) = return $ PRawName name

instance Compile Exp (PIL [Stmt]) where
    compile (Pos pos rest) = fmap (PPos pos rest) $ compile rest
    compile (Cxt cxt rest) = enter cxt $ compile rest
    compile (Stmts (Pad SOur _ exp) rest) = do
        compile $ mergeStmts exp rest
    compile (Stmts (Pad _ pad exp) rest) = do
        expC    <- compile $ mergeStmts exp rest
        padC    <- compile $ padToList pad
        return $ PPad SMy ((map fst $ padToList pad) `zip` padC) expC
    compile exp = compileStmts exp

class EnterClass m a where
    enter :: a -> m b -> m b

instance EnterClass CompMonad VCode where
    enter sub = local (\e -> e{ envLValue = subLValue sub, envContext = CxtItem (subReturns sub) })

instance EnterClass CompMonad Cxt where
    enter cxt = local (\e -> e{ envContext = cxt })

instance EnterClass TransMonad TCxt where
    enter cxt = local (\e -> e{ tCxt = cxt })

compileStmts :: Exp -> Comp (PIL [Stmt])
compileStmts exp = case exp of
    Stmts this Noop -> do
        thisC   <- compile this
        return $ PStmts (tailCall thisC) PNil
        where
        tailCall (PStmt (PExp (PApp cxt fun args)))
            = PStmt $ PExp $ PApp (TTailCall cxt) fun args
        tailCall (PPos pos exp x) = PPos pos exp (tailCall x)
        tailCall x = x
    Stmts this rest -> do
        thisC   <- enter cxtVoid $ compile this
        restC   <- compileStmts rest
        return $ PStmts thisC restC
    Noop        -> return PNil
    _           -> compile (Stmts exp Noop)

instance Compile Val (PIL Stmt) where
    compile = fmap PStmt . compile . Val

instance Compile Val (PIL Expression) where
    compile = compile . Val

instance Compile Exp (PIL Stmt) where
    compile (Pos pos rest) = fmap (PPos pos rest) $ compile rest
    compile (Cxt cxt rest) = enter cxt $ compile rest
    compile Noop = return PNoop
    compile (Val val) = do
        cxt     <- asks envContext
        if isVoidCxt cxt
            then case val of
                VBool True      -> compile Noop
                _               -> do
                    warn "Useless use of a constant in void context" val
                    compile Noop
            else compile val
    compile (Syn "loop" [exp]) =
        compile (Syn "loop" $ [emptyExp, Val (VBool True), emptyExp, exp])
    compile (Syn "loop" [pre, cond, post, (Syn "block" [body])]) = do
        preC    <- compile pre
        condC   <- compile cond
        bodyC   <- compile body
        postC   <- compile post
        funC    <- compile (Var "&statement_control:loop")
        return . PStmt . PExp $ PApp TCxtVoid funC
            [preC, pBlock condC, pBlock bodyC, pBlock postC]
    compile exp@(Syn "unless" _) = fmap (PStmt . PExp) $ compConditional exp
    compile exp@(Syn "while" _) = compLoop exp
    compile exp@(Syn "until" _) = compLoop exp
    compile exp@(Syn "postwhile" _) = compLoop exp
    compile exp@(Syn "postuntil" _) = compLoop exp
    compile (Syn "for" [exp, body]) = do
        expC    <- compile exp
        bodyC   <- compile body
        funC    <- compile (Var "&statement_control:for")
        return . PStmt . PExp $ PApp TCxtVoid funC [expC, bodyC]
    compile (Syn "given" _) = compile (Var "$_") -- XXX
    compile (Syn "when" _) = compile (Var "$_") -- XXX
    compile exp = fmap PStmt $ compile exp

pBlock :: PIL [Stmt] -> PIL Expression
pBlock = PCode SubBlock []

{-
subTCxt :: VCode -> Eval TCxt
subTCxt sub = return $ if subLValue sub
    then TCxtLValue (subReturns sub)
    else TCxtItem (subReturns sub)
-}

askTCxt :: Eval TCxt
askTCxt = do
    env <- ask
    return $ if envLValue env
        then TCxtLValue (typeOfCxt $ envContext env)
        else case envContext env of
            CxtVoid         -> TCxtVoid
            CxtItem typ     -> TCxtItem typ
            CxtSlurpy typ   -> TCxtSlurpy typ

instance (Show (m a), FunctorM m, Typeable1 m, Compile a b) => Compile (m a) (m b) where
    compile = fmapM compile

instance (Compile a b, Compile a c) => Compile [a] (b, c) where
    compile [x, y] = do { x' <- compile x ; y' <- compile y; return (x', y') }
    compile x = compError x

instance (Compile a b, Compile a c, Compile a d) => Compile [a] (b, c, d) where
    compile [x, y, z] = do { x' <- compile x ; y' <- compile y; z' <- compile z; return (x', y', z') }
    compile x = compError x

instance Compile Exp (PIL LValue) where
    compile (Pos pos rest) = fmap (PPos pos rest) $ compile rest
    compile (Cxt cxt rest) = enter cxt $ compile rest
    compile (Var name) = return $ PVar name
    compile (Syn (sigil:"::()") exps) = do
        compile $ App (Var "&Pugs::Internals::symbolic_deref") Nothing $
            (Val . VStr $ sigil:""):exps
    compile (App (Var "&goto") (Just inv) args) = do
        cxt     <- askTCxt
        funC    <- compile inv
        argsC   <- enter cxtItemAny $ compile args
        return $ PApp (TTailCall cxt) funC argsC
    compile (App fun (Just inv) args) = do
        compile (App fun Nothing (inv:args)) -- XXX WRONG
    compile (App fun Nothing args) = do
        cxt     <- askTCxt
        funC    <- compile fun
        argsC   <- enter cxtItemAny $ compile args
        return $ PApp cxt funC argsC
    compile exp@(Syn "if" _) = compConditional exp
    compile (Syn "{}" (x:xs)) = compile $ App (Var "&postcircumfix:{}") (Just x) xs
    compile (Syn "[]" (x:xs)) = do
        compile (App (Var "&postcircumfix:[]") (Just x) xs)
    compile (Syn "," exps) = do
        compile (App (Var "&infix:,") Nothing exps)
    compile (Syn "\\[]" exps) = do
        compile (App (Var "&circumfix:[]") Nothing exps)
    compile (Syn "\\{}" exps) = do
        compile (App (Var "&circumfix:{}") Nothing exps)
    compile (Syn "=" [lhs, rhs]) = do
        lhsC <- enterLValue $ compile lhs
        rhsC <- enterRValue $ compile rhs
        return $ PAssign [lhsC] rhsC
    compile (Syn ":=" exps) = do
        (lhsC, rhsC) <- enterLValue $ compile exps
        return $ PBind [lhsC] rhsC
    compile (Syn syn [lhs, exp]) | last syn == '=' = do
        let op = "&infix:" ++ init syn
        compile $ Syn "=" [lhs, App (Var op) Nothing [lhs, exp]]
    compile exp = compError exp

compLoop :: Exp -> Comp (PIL Stmt)
compLoop (Syn name [cond, body]) = do
    cxt     <- askTCxt
    condC   <- enter (CxtItem $ mkType "Bool") $ compile cond
    bodyC   <- enter CxtVoid $ compile body
    funC    <- compile (Var $ "&statement_control:" ++ name)
    return . PStmt . PExp $ PApp cxt funC [pBlock condC, pBlock bodyC]
compLoop exp = compError exp

{-| Compiles a conditional 'Syn' (@if@ and @unless@) to a call to an
    appropriate function call (@&statement_control:if@ or
    @&statement_control:unless@). -}
compConditional :: Exp -> Comp (PIL LValue)
compConditional (Syn name exps) = do
    [condC, trueC, falseC] <- compile exps
    funC    <- compile $ Var ("&statement_control:" ++ name)
    cxt     <- askTCxt
    return $ PApp cxt funC [condC, PThunk trueC, PThunk falseC]
compConditional exp = compError exp

{-| Compiles various 'Exp's to 'PIL Expression's. -}
instance Compile Exp (PIL Expression) where
    compile (Pos pos rest) = fmap (PPos pos rest) $ compile rest
    compile (Cxt cxt rest) = enter cxt $ compile rest
    compile (Var name) = return . PExp $ PVar name
    compile exp@(Val (VCode _)) = compile $ Syn "sub" [exp]
    compile (Val val) = fmap PLit $ compile val
    compile Noop = compile (Val undef)
    compile (Syn "block" [body]) = do
        cxt     <- askTCxt
        bodyC   <- compile body
        return $ PExp $ PApp cxt (pBlock bodyC) []
    compile (Syn "sub" [Val (VCode sub)]) = do
        bodyC   <- enter sub $ compile $ case subBody sub of
            Syn "block" [exp]   -> exp
            exp                 -> exp
        paramsC <- compile $ subParams sub
        return $ PCode (subType sub) paramsC bodyC
    compile (Syn "module" _) = compile Noop
    compile (Syn "match" exp) = compile $ Syn "rx" exp -- wrong
    compile (Syn "//" exp) = compile $ Syn "rx" exp
    compile (Syn "rx" [exp, _]) = compile exp -- XXX WRONG - use PCRE
    compile (Syn "subst" [exp, _, _]) = compile exp -- XXX WRONG - use PCRE
    compile exp@(App _ _ _) = fmap PExp $ compile exp
    compile exp@(Syn _ _) = fmap PExp $ compile exp
    compile exp = compError exp

compError :: forall a b. Compile a b => a -> Comp b
compError = die $ "Compile error -- invalid "
    ++ (show $ typeOf (undefined :: b))

transError :: forall a b. Translate a b => a -> Trans b
transError = die $ "Translate error -- invalid "
    ++ (show $ typeOf (undefined :: b))

{-| Compiles a 'Val' to a 'PIL Literal'. -}
instance Compile Val (PIL Literal) where
    compile val = return $ PVal val

die :: (MonadIO m, Show a) => String -> a -> m b
die x y = do
    warn x y
    liftIO $ exitFailure

warn :: (MonadIO m, Show a) => String -> a -> m ()
warn str val = liftIO $ do
    hPutStrLn stderr $ "*** " ++ str ++ ":\n    " ++ show val

instance Typeable1 PIL where
    typeOf1 _ = typeOf ()

instance (Typeable a) => Translate (PIL a) a where
    trans PNil = return []
    trans PNoop = return (StmtComment "")
    trans (PPos pos exp rest) = do
        dep     <- asks tTokDepth
        tell [StmtComment $ (replicate dep ' ') ++ "{{{ " ++ pretty exp]
        expC    <- local (\e -> e{ tTokDepth = dep + 1 }) $ trans rest
        tell [StmtComment $ (replicate dep ' ') ++ "}}} " ++ pretty pos]
        return expC
    trans (PLit (PVal VUndef)) = do
        pmc     <- genLV "undef"
        return $ ExpLV pmc
    trans (PLit lit) = do
        -- generate fresh supply and things...
        litC    <- trans lit
        pmc     <- genLV "lit"
        tellIns $ pmc <== ExpLit litC
        return $ ExpLV pmc
    trans (PVal (VBool bool)) = return $ LitInt (toInteger $ fromEnum bool)
    trans (PVal (VStr str)) = return $ LitStr str
    trans (PVal (VInt int)) = return $ LitInt int
    trans (PVal (VNum num)) = return $ LitNum num
    trans (PVal (VRat rat)) = return $ LitNum (ratToNum rat)
    trans val@(PVal _) = transError val
    trans (PVar name) | Just (pkg, name') <- isQualified name = do
        -- XXX - this is terribly ugly.  Fix at parrot side perhaps?
        pmc     <- genLV "glob"
        let initL   = "init_" ++ pmcStr
            doneL   = "done_" ++ pmcStr
            pmcStr  = render (emit pmc)
        tellIns $ "push_eh" .- [bare initL]
        tellIns $ pmc <-- "find_global" $ [lit pkg, lit name']
        tellIns $ "goto" .- [bare doneL]
        tellLabel initL
        tellIns $ "store_global" .- [lit pkg, lit name', reg pmc]
        tellLabel doneL
        tellIns $ "clear_eh" .- []
        return pmc
    trans (PVar name) = do
        pmc     <- genLV "lex"
        tellIns $ pmc <-- "find_name" $ [lit $ possiblyFixOperatorName name]
        return pmc
    trans (PStmt (PLit (PVal VUndef))) = return $ StmtComment ""
    trans (PStmt exp) = do
        expC    <- trans exp
        return $ StmtIns $ InsExp expC
    trans (PAssign [lhs] rhs) = do
        lhsC    <- enter tcLValue $ trans lhs
        rhsC    <- trans rhs
        tellIns $ lhsC <== rhsC
        return lhsC
    trans (PBind [lhs] rhs) = do
        lhsC    <- enter tcLValue $ trans lhs
        rhsC    <- trans rhs
        tellIns $ lhsC <:= rhsC
        return lhsC
    trans (PStmts this rest) = do
        thisC   <- trans this
        tell [thisC]
        trans rest
    trans (PApp _ exp@(PCode _ _ _) []) = do
        blockC  <- trans exp
        tellIns $ [reg tempPMC] <-& blockC $ []
        return tempPMC
    trans (PApp (TCxtLValue _) (PExp (PVar "&postcircumfix:[]")) [PExp lhs, rhs]) = do
        lhsC    <- trans lhs
        rhsC    <- trans rhs
        return $ lhsC `KEYED` rhsC
    trans (PApp cxt fun args) = do
        funC    <- trans fun {- case fun of
            PExp (PVar name) -> return $ lit name
            _           -> trans fun
        -}
        argsC   <- if isLogicalLazy fun
            then mapM trans (head args : map PThunk (tail args))
            else mapM trans args
        case cxt of
            TTailCall _ -> do
                tellIns $ InsTailFun funC argsC
                return nullPMC
            _ -> do
                pmc     <- genLV "app"
                -- XXX - probe if funC is slurpy, then modify ExpLV pmc accordingly
                tellIns $ [reg pmc] <-& funC $ argsC
                return pmc
        where
        -- XXX HACK
        isLogicalLazy (PExp (PVar "&infix:or"))     = True
        isLogicalLazy (PExp (PVar "&infix:and"))    = True
        isLogicalLazy (PExp (PVar "&infix:||"))     = True
        isLogicalLazy (PExp (PVar "&infix:&&"))     = True
        isLogicalLazy _ = False
    trans (PPad SMy pad exps) = do
        valsC   <- mapM trans (map snd pad)
        pass $ do
            expsC   <- trans exps
            return ([], (StmtPad (map fst pad `zip` valsC) expsC:))
    trans (PExp exp) = fmap ExpLV $ trans exp
    trans (PCode styp params body) = do
        [begL, endL] <- genLabel ["blockBegin", "blockEnd"]
        this    <- genPMC "block"
        tellIns $ "newsub" .- [reg this, bare ".Closure", bare begL]
        tellIns $ "goto" .- [bare endL]
        tellLabel begL
        let prms = map tpParam params
        mapM_ (tellIns . InsLocal RegPMC . prmToIdent) prms
        tellIns $ "get_params" .- sigList (map prmToSig prms)
        tellIns $ "new_pad" .- [lit curPad]
        wrapSub styp $ do
            mapM storeLex params
            trans body  -- XXX - consistency check
            bodyC   <- lastPMC
            tellIns $ "set_returns" .- retSigList [bodyC]
            tellIns $ "returncc" .- []
        tellLabel endL
        return (ExpLV this)
    trans (PThunk exp) = do
        [begL, sndL, retL, endL] <- genLabel ["thunkBegin", "thunkAgain", "thunkReturn", "thunkEnd"]
        this    <- genPMC "block"
        tellIns $ "newsub" .- [reg this, bare ".Continuation", bare begL]
        tellIns $ "goto" .- [bare endL]
        tellLabel begL
        cc      <- genPMC "cc"
        fetchCC cc (reg this)
        expC    <- trans exp
        tellIns $ "set_addr" .- [reg this, bare sndL]
        tellIns $ "goto" .- [bare retL]
        tellLabel sndL
        fetchCC cc (reg this)
        tellLabel retL
        tellIns $ if parrotBrokenXXX
            then "store_global" .- [tempSTR, expC]
            else "set_args" .- [lit "(0b10)", expC]
        tellIns $ "invoke" .- [reg cc]
        tellLabel endL
        return (ExpLV this)
    trans (PRawName name) = fmap ExpLV $ genName name
    trans (PSub name styp params body) | Just (pkg, name') <- isQualified name = do
        declC <- trans $ PSub name' styp params body
        return $ DeclNS pkg [declC]
    trans (PSub name styp params body) = do
        (_, stmts)  <- listen $ do
            let prms = map tpParam params
            mapM_ (tellIns . InsLocal RegPMC . prmToIdent) prms
            tellIns $ "get_params" .- sigList (map prmToSig prms)
            tellIns $ "new_pad" .- [lit curPad]
            wrapSub styp $ do
                mapM storeLex params
                trans body
                bodyC <- lastPMC
                tellIns $ "set_returns" .- retSigList [bodyC]
                tellIns $ "returncc" .- []
        return (DeclSub name [] stmts)
    trans x = transError x

packageOf :: String -> String
packageOf name = case isQualified name of
    Just (pkg, _)   -> pkg
    _               -> "main"

qualify :: String -> String
qualify name = case isQualified name of
    Just _  -> name
    _       -> let (sigil, name') = span (not . isAlphaNum) name
        in sigil ++ "main::" ++ name'

isQualified :: String -> Maybe (String, String)
isQualified name | Just (post, pre) <- breakOnGlue "::" (reverse name) =
    let (sigil, pkg) = span (not . isAlphaNum) preName
        name'       = possiblyFixOperatorName (sigil ++ postName)
        preName     = reverse pre
        postName    = reverse post
    in Just (pkg, name')
isQualified _ = Nothing

fetchCC :: LValue -> Expression -> Trans ()
fetchCC cc begL | parrotBrokenXXX = do
    tellIns $ tempINT   <-- "get_addr" $ [begL]
    tellIns $ tempSTR   <:= tempINT
    tellIns $ "find_global" .- [reg cc, tempSTR]
fetchCC cc _ = do
    tellIns $ "get_params" .- sigList [reg cc]

-- XXX - slow way of implementing "return"
wrapSub :: SubType -> Trans () -> Trans ()
wrapSub SubPrim = id
wrapSub SubBlock = id -- XXX not really
wrapSub _ = \body -> do
    [retL, errL] <- genLabel ["returnHandler", "errHandler"]
    tellIns $ "push_eh" .- [bare retL]
    body
    tellLabel retL
    tellIns $ tempPMC <:= ExpLV (errPMC `KEYED` lit False)
    tellIns $ "clear_eh" .- []
    tellIns $ tempSTR <-- "typeof" $ [errPMC]
    tellIns $ "eq" .- [tempSTR, lit "Exception", bare errL]
    tellIns $ "set_returns" .- sigList [tempPMC]
    tellIns $ "returncc" .- []
    tellLabel errL
    tellIns $ "throw" .- [errPMC]

prmToSig :: Param -> Sig
prmToSig prm = MkSig (prmToArgs prm) . bare $ prmToIdent prm

prmToArgs :: Param -> [ArgFlag]
prmToArgs prm = combine 
    [ isSlurpy   ==> MkArgSlurpyArray
    , isOptional ==> MkArgOptional
    ] []
    where
    f ==> arg = if f prm then (arg:) else id

prmToIdent :: Param -> String
prmToIdent = render . varText . paramName

storeLex :: TParam -> Trans ()
storeLex param = do
    when (isOptional prm) $ do
        [defC] <- genLabel ["defaultDone"]
        tellIns $ "unless_null" .- [bare name, bare defC]
        case tpDefault param of
            Nothing     -> tellIns $ InsNew (VAR name) PerlScalar
            (Just exp)  -> do
                expC <- trans exp
                -- compile it away
                tellIns $ VAR name <:= expC
        tellLabel defC
    tellIns $ "store_lex" .- [lit curPad, lit var, bare name]
    where
    var     = paramName prm
    name    = prmToIdent prm
    prm     = tpParam param

tellIns :: Ins -> Trans ()
tellIns = tell . (:[]) . StmtIns

{-| Inserts a label. -}
tellLabel :: String -> Trans ()
tellLabel name = tellIns $ InsLabel name

lastPMC :: (RegClass a) => Trans a
lastPMC = do
    tvar    <- asks tReg
    name'   <- liftIO $ liftSTM $ do
        (cur, name) <- readTVar tvar
        return $ ('P':show cur) ++ (if null name then name else ('_':name))
    return $ reg (VAR name')

genPMC :: (RegClass a) => String -> Trans a
genPMC name = do
    tvar    <- asks tReg
    name'   <- liftIO $ liftSTM $ do
        (cur, _) <- readTVar tvar
        writeTVar tvar (cur + 1, name)
        return $ ('P':show (cur + 1)) ++ ('_':name)
    tellIns $ InsLocal RegPMC name'
    return $ reg (VAR name')

genLV :: (RegClass a) => String -> Trans a
genLV name = do
    pmc <- genPMC name
    tellIns $ InsNew pmc PerlScalar
    return $ reg pmc

genLabel :: [String] -> Trans [LabelName]
genLabel names = do
    tvar    <- asks tLabel
    cnt     <- liftIO $ liftSTM $ do
        cur <- readTVar tvar
        writeTVar tvar (cur + 1)
        return cur
    return $ map (\name -> "LABEL_" ++ show cnt ++ ('_':name)) names

genName :: (RegClass a) => String -> Trans a
genName name = do
    let var = render $ varText name
    tellIns $ InsLocal RegPMC var
    tellIns $ InsNew (VAR var) (read $ render $ varInit name)
    return $ reg (VAR var)

padSort :: (Var, [(TVar Bool, TVar VRef)]) -> (String, [(a, b)]) -> Ordering
padSort (a, [(_, _)]) (b, [(_, _)])
    | (head a == ':' && head b == '&') = LT
    | (head b == ':' && head a == '&') = GT
    | otherwise = GT
padSort _ _ = EQ

varText :: String -> Doc
varText ('$':name)  = text $ "s__" ++ escaped name
varText ('@':name)  = text $ "a__" ++ escaped name
varText ('%':name)  = text $ "h__" ++ escaped name
varText ('&':name)  = text $ "c__" ++ escaped name
varText x           = error $ "invalid name: " ++ x

varInit :: String -> Doc
varInit ('$':_) = text $ "PerlScalar"
varInit ('@':_) = text $ "PerlArray"
varInit ('%':_) = text $ "PerlHash"
varInit ('&':_) = text $ "PerlScalar"
varInit x       = error $ "invalid name: " ++ x

{-| Compiles the current environment to PIR code. -}
genPIR :: Eval Val
genPIR = do
    tenv        <- initTEnv
    -- Load the PIR Prelude.
    local (\env -> env{ envDebug = Nothing }) $ do
        opEval style "<prelude-pir>" preludeStr
    glob        <- askGlobal
    main        <- asks envBody
    globPIL     <- compile glob
    mainPIL     <- compile main
    globPIR     <- runTransGlob tenv globPIL
    mainPIR     <- runTransMain tenv mainPIL
    return . VStr . unlines $
        [ "#!/usr/bin/env parrot"
        , renderStyle (Style PageMode 0 0) $ preludePIR $+$ vcat
        -- Namespaces have bugs in both pugs and parrot.
        [ emit globPIR
        , emit $ DeclNS "main"
        [ DeclSub "init" [SubMAIN, SubANON] $ map StmtIns
            -- Eventually, we'll have to write our own find_name wrapper (or
            -- fix Parrot's find_name appropriately). See Pugs.Eval.Var.
            -- For now, we simply store $P0 twice.
            [ "new_pad" .- [lit0]
            , InsNew tempPMC PerlEnv
            , "store_global"    .- [lit "%*ENV", tempPMC]
            , "store_global"    .- [lit "%ENV", tempPMC]
            , InsNew tempPMC PerlArray
            , "store_global"    .- [lit "@*END", tempPMC]
            , "store_global"    .- [lit "@END", tempPMC]
            , "getstdin"        .- [tempPMC]
            , "store_global"    .- [lit "$*IN", tempPMC]
            , "store_global"    .- [lit "$IN", tempPMC]
            , "getstdout"       .- [tempPMC]
            , "store_global"    .- [lit "$*OUT", tempPMC]
            , "store_global"    .- [lit "$OUT", tempPMC]
            , "getstderr"       .- [tempPMC]
            , "store_global"    .- [lit "$*ERR", tempPMC]
            , "store_global"    .- [lit "$ERR", tempPMC]
            , "getinterp"       .- [tempPMC]
            , tempPMC   <:= ExpLV (tempPMC `KEYED` bare ".IGLOBALS_ARGV_LIST")
            , tempPMC2  <-- "shift" $ [tempPMC]
            , "store_global"    .- [lit "@*ARGS", tempPMC]
            , "store_global"    .- [lit "@ARGS", tempPMC]
            , "store_global"    .- [lit "$*PROGRAM_NAME", tempPMC2]
            , "store_global"    .- [lit "$PROGRAM_NAME", tempPMC2]
            -- XXX wrong, should be lexical
            , InsNew tempPMC PerlScalar
            , "store_global"    .- [lit "$_", tempPMC]
            ] ++ [ StmtRaw (text (name ++ "()")) | PSub name@('_':'_':_) _ _ _ <- globPIL ] ++
            [ StmtRaw (text "main()")
            , StmtIns ("exit" .- [lit0])
            ]
        , DeclSub "main" [SubANON] [ StmtRaw $ emit mainPIR ]
        ] ] ]
    where
    style = MkEvalStyle
        { evalResult = EvalResultModule
        , evalError  = EvalErrorFatal
        }

runTransGlob :: TEnv -> [PIL Decl] -> Eval [Decl]
runTransGlob tenv = mapM $ fmap fst . liftIO . (`runReaderT` tenv) . runWriterT . trans

runTransMain :: TEnv -> PIL [Stmt] -> Eval [Stmt]
runTransMain tenv = fmap snd . liftIO . (`runReaderT` tenv) . runWriterT . trans

initTEnv :: Eval TEnv
initTEnv = do
    initReg <- liftSTM $ newTVar (0, "")
    initLbl <- liftSTM $ newTVar 0
    return $ MkTEnv
        { tLexDepth = 0
        , tTokDepth = 0
        , tCxt      = tcVoid
        , tReg      = initReg
        , tLabel    = initLbl
        }

