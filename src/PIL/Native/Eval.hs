{-# OPTIONS_GHC -fglasgow-exts -fno-warn-orphans -funbox-strict-fields #-}

module PIL.Native.Eval (evalNativeLang, resumeNativeLang, EvalResult(..)) where
import PIL.Native.Prims
import PIL.Native.Types
import PIL.Native.Pretty
import PIL.Native.Coerce
import PIL.Native.Objects
import PIL.Native.Parser
import PIL.Native.Bootstrap
import Data.FunctorM
import Data.Dynamic
import Data.Maybe
import Control.Monad.State
import Control.Monad.Reader
import Control.Exception

{-| 

PIL.Native.Eval

This is an evaluator for the core runtime mini-language.

See Also:

  PIL.Native.Parser
  PIL.Native.Prims  
  PIL.Native.Pretty  

-}

type Eval = StateT ObjectSpace (ReaderT Pad IO)
data EvalResult = MkEvalResult
    { result_value  :: !Native
    , result_pad    :: !Pad
    , result_objs   :: !ObjectSpace
    }
    deriving (Typeable)

instance MonadSTM Eval where
    liftSTM = lift . lift . liftSTM

evalNativeLang :: [NativeLangExpression] -> IO EvalResult
evalNativeLang exps = do
    res <- handleResult .  (`runReaderT` empty) . (`runStateT` empty) $ bootstrap
    resumeNativeLang res exps

bootstrap :: Eval Native
bootstrap = bootstrapClass $ evalExps (fromJust $ parseNativeLang __BOOTSTRAP__)

resumeNativeLang :: EvalResult -> [NativeLangExpression] -> IO EvalResult
resumeNativeLang res exps = do
    handleResult . (`runReaderT` result_pad res) .
                   (`runStateT` result_objs res) . evalExps $ exps

handleResult :: IO (Native, ObjectSpace) -> IO EvalResult
handleResult f = do
    (NError err, objs) <- f
    let (val, pad) = fromJust . fromDynamic . fromJust . dynExceptions $ err
    return $ MkEvalResult val pad objs

bootstrapClass :: Eval a -> Eval a
bootstrapClass x = mdo
    clsNull   <- createOpaque clsNull  $ mkClassMethods "" []
    clsClass  <- createOpaque clsClass $ mkClassMethods "Class" [("add_method", addMethod)]
    -- clsBoxes  <- mapM (newBoxedClass clsClass) unboxedTypes
    enterLex ( ("^", clsNull) : ("^Class", clsClass)
    --          : (unboxedTypes `zip` clsBoxes)
                :[]
             ) x
    where
    addMethod = parseSub
        "-> $name, &method { self`set_attr_hash('%!methods', $name, &method) }"
    mkClassMethods :: String -> [(String, Native)] -> NativeMap
    mkClassMethods name meths = mkMap
        [ ("$!name",            toNative name)
        , ("@!MRO",             emptySeq)
        , ("@!subclasses",      emptySeq)
        , ("@!superclasses",    emptySeq)
        , ("%!private_methods", emptyMap)
        , ("%!attributes",      emptyMap)
        , ("%!methods", toNative $ mkMap meths)
        ]
{-
    newBoxedClass cls name = newObject cls $
        mkClassMethods (tail name) [("unbox", parseSub "->{ self`get_attr('') }")]
    unboxedTypes = map ('^':) $ words "Bit Int Num Str Seq Map Sub"
    newContainerClass cls name gen = registerClass $ do
        obj <- genObject cls $ mkClassMethods name []
        return (addRepr obj "create" gen)
-}

infixl ...
(...) :: IsNative a => NativeObj -> String -> Eval a
obj ... str = liftSTM (fmap fromNative $ callRepr (o_repr obj) _get_attr (mkSeq [toNative str]))

enterLex :: IsNative a => [(String, a)] -> Eval b -> Eval b
enterLex = local . append . mkPad

mkPad :: IsNative a => [(String, a)] -> Pad
mkPad = mkMap . map (\(x, y) -> (x, toNative y))

evalExps :: [NativeLangExpression] -> Eval Native
evalExps []       = return nil
evalExps [x]      = evalExp x
evalExps (x:ESaveContinuation:_) = do
    pad <- ask
    val <- evalExp x
    return . toNative $ mkErr (val, pad)
evalExps (x:xs)   = evalExp x >> evalExps xs

evalExp :: NativeLangExpression -> Eval Native
evalExp ESaveContinuation = do
    pad <- ask
    return . toNative $ mkErr (nil, pad)
evalExp (ELit (NSub s)) = do
    pad <- ask -- close over current scope
    return $ NSub s{ s_pad = pad }
evalExp (ELit n) = return n
evalExp (EVar s) = do
    pad <- ask
    case pad `fetch` s of
        Just v  -> return v
        Nothing -> failWith "No such variable" s
evalExp (ECall { c_type = ctyp, c_obj = objExp, c_meth = meth, c_args = argsExp }) = do
    obj  <- evalExp objExp
    args <- fmapM evalExp argsExp
    case ctyp of
        CPrim    -> primCall obj meth args
        CPublic  -> sendCall obj meth args
        CPrivate -> privCall obj meth args

primCall :: Native -> NativeLangMethod -> NativeSeq -> Eval Native
primCall inv meth args
    | meth == mkStr "trace"         = traceObject inv args
    | otherwise = case anyPrims `fetch` meth of
        Just f  -> return $ f inv args
        Nothing -> case inv of
            NError {}   -> errMethodMissing
            NBit x | meth == mkStr "if_else"
                        -> callConditional x args
            NBit x      -> callPrim bitPrims x args
            NInt x      -> callPrim intPrims x args
            NNum x      -> callPrim numPrims x args
            NStr x      -> callPrim strPrims x args
            NSeq x      -> callPrim seqPrims x args
            NMap x      -> callPrim mapPrims x args
            NSub x      -> callSubWith (toString meth) x args
            NObj obj    -> case objPrims `fetch` meth of
                Just f  -> f obj args
                Nothing -> liftSTM $ callRepr (o_repr obj) meth args
                {-
                case Map.lookup meth (o_repr obj) of
                    Just f  -> liftSTM (f args)
                    Nothing -> errMethodMissing
                -}
    where
    errMethodMissing = failWith "No such method" meth
    callPrim :: MapOf (a -> NativeSeq -> Native) -> a -> NativeSeq -> Eval Native
    callPrim prims x args = case prims `fetch` meth of
        Nothing -> errMethodMissing
        Just f  -> return $ f x args

enterObj :: NativeObj -> (NativeObj -> Eval a) -> Eval a
enterObj obj f = enterLex [("&self", obj), ("$?CLASS", cls)] (f cls)
    where
    cls = o_class obj

privCall :: Native -> NativeLangMethod -> NativeSeq -> Eval Native
privCall inv meth args = case inv of
    NObj obj    -> enterObj obj $ \cls -> do
        meths <- cls ... "%!private_methods" :: Eval NativeMap
        case meths `fetch` meth of
            Just x  -> callSub (fromNative x) args
            Nothing -> errMethodMissing
    _           -> errMethodMissing
    where
    errMethodMissing = failWith "No such method" meth

sendCall :: Native -> NativeLangMethod -> NativeSeq -> Eval Native
sendCall inv meth args = case inv of
    NObj obj    -> callObject obj meth args
    NError{}    -> errMethodMissing
    NBit x      -> callAutoboxed x
    NInt x      -> callAutoboxed x
    NNum x      -> callAutoboxed x
    NStr x      -> callAutoboxed x
    NSeq x      -> callAutoboxed x
    NMap x      -> callAutoboxed x
    NSub x      -> callAutoboxed x
    where
    errMethodMissing = failWith "No such method" meth
    callAutoboxed _ = errMethodMissing
    {-
    callAutoboxed x = do
        cls <- fmap fromNative $ evalExp (EVar $ boxType x)
        obj <- autobox x cls
        callObject obj meth args
    -}

callSub :: NativeSub -> NativeSeq -> Eval Native
callSub sub args = do
    when (size args /= size prms) $ do
        fail $ "Invalid number of args " ++ show (elems args)
            ++ " vs params " ++ show (elems prms)
            ++ " in subroutine:\n"
            ++ (pretty $ s_exps sub)
    local (append lex . append (s_pad sub)) $ do
        evalExps (elems $ s_exps sub)
    where
    prms = s_params sub
    lex = fromAssocs ((mkStr "&?SUB", toNative sub):elems prms `zip` elems args)

callSubWith :: String -> NativeSub -> NativeSeq -> Eval Native
callSubWith ""          sub args = callSub sub args
callSubWith "do_if"     sub args = if fromNative (args ! 0) then callSub sub empty else return nil
callSubWith "do_unless" sub args = if fromNative (args ! 0) then return nil else callSub sub empty
callSubWith "do_for"    sub args = fmap toNative $ fmapM (callSub sub . mkSeq . (:[])) (fromNative (args ! 0) :: NativeSeq)
callSubWith _ _ _ = fail "autoboxing for Sub not yet implemented"
{-
callSubWith str x args = do
    cls <- fmap fromNative $ evalExp (EVar $ boxType x)
    obj <- autobox x cls
    callObject obj (mkStr str) args
-}

callConditional :: NativeBit -> NativeSeq -> Eval Native
callConditional x args = callSub (fromNative $ args ! fromEnum (not x)) empty

traceObject :: Native -> NativeSeq -> Eval Native
traceObject obj args = liftIO $ do
    mapM_ doTrace (obj: elems args)
    return obj
    where
    doTrace x = do
        p <- prettyM x
        putStrLn $ "#trace# " ++ unwords (words (unwords (lines p)))

callObject :: NativeObj -> NativeStr -> NativeSeq -> Eval Native
callObject obj meth args = enterLex lex $ do
    mros    <- getMRO
    rv      <- findMRO mros
    case rv of
        Nothing -> failWith "No such method" meth
        Just (this, mros') -> do
            rv' <- genNext mros'
            case rv' of
                Just next -> enterLex [("&?NEXT", toNative next)] $
                    callSub this args
                Nothing -> callSub this args
    where
    lex = [("&self", obj), ("$?CLASS", cls)]
    cls = o_class obj
    genNext mros = do
        rv <- findMRO mros
        case rv of
            Nothing -> return Nothing
            Just (next, mros') -> do
                rv' <- genNext mros'
                let next' = maybe nil toNative rv'
                return $ Just next
                    { s_pad = s_pad next
                                `append` mkPad lex
                                `append` mkPad [("&?NEXT", next')]
                    }
    getMRO = do
        mro <- cls ... "@!MRO" :: Eval NativeSeq
        if isEmpty mro
            then do
                sups <- cls ... "@!superclasses"
                return (cls:map fromNative sups)
            else return (map fromNative $ elems mro)
    findMRO [] = return Nothing
    findMRO (c:cs) = do
        meths <- c ... "%!methods" :: Eval NativeMap
        case meths `fetch` meth of
            Just x  -> return $ Just (fromNative x, cs)
            _       -> findMRO cs

mroMerge :: Eq a => [[a]] -> [a]
mroMerge = reverse . doMerge []
    where
    doMerge res seqs
        | seqs'@(_:_) <- filter (not . null) seqs
        , (cand:_) <- [ s | (s:_) <- seqs', all (not . elem s . tail) seqs']
        = doMerge (cand:res) [ if s == cand then rest else full | full@(s:rest) <- seqs' ]
    doMerge res _ = res

__superclasses, __MRO :: NativeLangMethod
__superclasses  = mkStr "superclasses"
__MRO           = mkStr "MRO"

objPrims :: MapOf (NativeObj -> NativeSeq -> Eval Native)
objPrims = mkMap
    [ ("id", \obj _ -> return (toNative $ o_id obj))
    , ("meta", \obj _ -> return (toNative $ o_class obj))
    , ("repr", \obj _ -> return (toNative $ objectReprName obj))
    , ("create", \cls args -> do
        let repr = fromNative (args ! 0)
            init = (args ! 1)
        fmap toNative (createObject cls repr init))
    -- XXX - move away the two prims below!
    , ("mro_merge", \cls _ -> do
        supers <- fmap fromNative $ callObject cls __superclasses empty
            :: Eval [NativeObj]
        mros   <- fmapM (\c -> fmap fromNative $ callObject c __MRO empty) supers
            :: Eval [[NativeObj]]
        let seqs = filter (not . null) $ ([cls]:mros) ++ [supers]
        return . toNative $ mkSeq (mroMerge seqs)
      )
    ]
