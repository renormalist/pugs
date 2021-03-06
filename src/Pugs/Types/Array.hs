type ArrayIndex = Int

class (Typeable a) => ArrayClass a where
    array_iType :: a -> Type
    array_iType = const $ mkType "Array"
    array_fetch       :: a -> Eval VArray
    array_fetch av = do
        size <- array_fetchSize av
        mapM (array_fetchVal av) [0..size-1]
    array_store       :: a -> VArray -> Eval ()
    array_store av list = do
        forM_ ([0..] `zip` list) $ \(idx, val) -> do
            sv <- array_fetchElem av idx
            writeIVar sv val
        array_storeSize av (length list)
    array_fetchKeys   :: a -> Eval [ArrayIndex]
    array_fetchKeys av = do
        svList <- array_fetch av
        return $ zipWith const [0..] svList
    array_fetchElemAll :: a -> Eval [IVar VScalar]
    array_fetchElemAll av = do
        size <- array_fetchSize av
        mapM (array_fetchElem av) [0..size-1]
    array_fetchElem   :: a -> ArrayIndex -> Eval (IVar VScalar) -- autovivify
    array_fetchElem av idx = do
        return $ proxyScalar (array_fetchVal av idx) (array_storeVal av idx)
    array_storeElem   :: a -> ArrayIndex -> IVar VScalar -> Eval () -- binding
    array_storeElem av idx sv = do
        val <- readIVar sv
        array_storeVal av idx val
    array_fetchVal    :: a -> ArrayIndex -> Eval Val
    array_fetchVal av idx = do
        rv <- array_existsElem av idx
        if rv then readIVar =<< array_fetchElem av idx
              else return undef
    array_storeVal    :: a -> ArrayIndex -> Val -> Eval ()
    array_storeVal av idx val = do
        sv <- array_fetchElem av idx
        writeIVar sv val
    array_fetchSize   :: a -> Eval ArrayIndex
    array_fetchSize av = do
        vals <- array_fetch av
        return $ length vals
    array_storeSize   :: a -> ArrayIndex -> Eval ()
    array_storeSize av sz = do
        size <- array_fetchSize av
        case size `compare` sz of
            GT -> mapM_ (const $ array_pop av) [size .. sz-1]
            EQ -> return () -- no need to do anything
            LT -> mapM_ (\idx -> array_storeElem av idx lazyUndef) [size .. sz-1]
    array_extendSize  :: a -> ArrayIndex -> Eval ()
    array_extendSize _ 0 = return ()
    array_extendSize av sz = do
        size <- array_fetchSize av
        when (size < sz) $ do
            mapM_ (\idx -> array_storeElem av idx lazyUndef) [size .. sz-1]
    array_deleteElem  :: a -> ArrayIndex -> Eval ()
    array_deleteElem av idx = do
        size <- array_fetchSize av
        let idx' = if idx < 0 then idx `mod` size else idx
        case (size - 1) `compare` idx' of
            GT -> return ()                             -- no such index
            EQ -> array_storeSize av (size - 1)               -- truncate
            LT -> array_storeElem av idx' lazyUndef            -- set to undef
    array_existsElem  :: a -> ArrayIndex -> Eval VBool
    array_existsElem av idx = do
        size <- array_fetchSize av
        return $ size > (if idx < 0 then idx `mod` size else idx)
    array_clear       :: a -> Eval ()
    array_clear av = array_storeSize av 0
    array_push        :: a -> [Val] -> Eval ()
    array_push av vals = do
        size <- array_fetchSize av
        forM_ ([size..] `zip` vals) $ \(idx, val) -> do
            array_storeElem av idx (lazyScalar val)
    array_pop         :: a -> Eval Val
    array_pop av = do
        size <- array_fetchSize av
        if size == 0
            then return undef
            else do
                sv <- array_fetchElem av $ size - 1
                array_storeSize av $ size - 1
                readIVar sv
    array_shift       :: a -> Eval Val
    array_shift av = do
        vals <- array_splice av 0 1 []
        return $ last (undef:vals)
    array_unshift     :: a -> [Val] -> Eval ()
    array_unshift av vals = do
        array_splice av 0 0 vals
        return ()
    array_splice      :: a -> ArrayIndex -> ArrayIndex -> [Val] -> Eval [Val]
    array_splice av off len vals = do
        size <- array_fetchSize av
        let off' = if off < 0 then off + size else off
            len' = if len < 0 then len + size - off' else len
        result <- mapM (array_fetchElem av) [off' .. off' + len' - 1]
        let off = if off' > size then size else off'
            len = if off + len' > size then size - off else len'
            cnt = length vals
        case cnt `compare` len of
            GT -> do
                -- Move items up to make room
                let delta = cnt - len
                array_extendSize av (size + delta)
                (`mapM_` reverse [off + len .. size - 1]) $ \idx -> do
                    val <- array_fetchElem av idx
                    array_storeElem av (idx + delta) val
            LT -> do
                let delta = len - cnt
                (`mapM_` [off + len .. size - 1]) $ \idx -> do
                    val <- array_fetchElem av idx
                    array_storeElem av (idx - delta) val
                array_storeSize av (size - delta)
            _ -> return ()
        forM_ ([0..] `zip` vals) $ \(idx, val) -> do
            array_storeElem av (off + idx) (lazyScalar val)
        mapM readIVar result

instance ArrayClass IArraySlice where
    array_iType = const $ mkType "Array::Slice"
    array_store av vals = mapM_ (uncurry writeIVar) (zip av (vals ++ repeat undef))
    array_fetchSize = return . length
    array_fetchElem av idx = getIndex idx Nothing (return av) Nothing
    array_storeSize _ _ = return () -- XXX error?
    array_storeElem _ _ _ = retConstError undef

instance ArrayClass IArray where
    array_store (MkIArray av s) vals = liftIO $ do
        new <- C.new
        C.swapMaps new av
        mapM_ (\(k, v) -> C.insert k (lazyScalar v) av) ([0..] `zip` vals)
        writeIORef s (length vals)
    array_fetchSize MkIArray{ a_size = s } = liftIO $ do
        readIORef s
    array_storeSize (MkIArray av s) sz = liftIO $ do
        size <- readIORef s
        case size `compare` sz of
            GT -> do new <- C.fromList =<< I.takeFirst sz av
                     C.swapMaps new av
                     writeIORef s sz
            EQ -> return ()
            LT -> writeIORef s sz
    array_shift (MkIArray av s) = join . liftIO $ do
        size <- readIORef s
        case size of
            0 -> return (return undef)
            _ -> do
                writeIORef s (size-1)
                [(k, v)] <- I.takeFirst 1 av
                case k of
                    0 -> do
                        C.delete k av
                        l   <- C.mapToList (\k v -> (k-1,v)) av
                        new <- C.fromList l
                        C.swapMaps new av
                        return (readIVar v)
                    _ -> do
                        l   <- C.mapToList (\k v -> (k-1,v)) av
                        new <- C.fromList l
                        C.swapMaps new av
                        return (return undef)
    array_unshift (MkIArray av s) vals = liftIO $ do
        let sz = length vals
        l   <- C.mapToList (\k v -> (k+sz,v)) av
        new <- C.fromList $ ([0..] `zip` (map lazyScalar vals)) ++ l
        C.swapMaps new av
        modifyIORef s (+sz)
    array_pop (MkIArray av s) = join . liftIO $ do
        size <- readIORef s
        case size of
            0 -> return (return undef)
            _ -> do
                writeIORef s (size-1)
                e <- C.lookup (size-1) av
                case e of
                    Nothing -> return (return undef)
                    Just x -> do
                        C.delete (size-1) av
                        return (readIVar x)
    array_push (MkIArray av s) vals = liftIO $ do
        size <- readIORef s
        writeIORef s (size + (length vals))
        mapM_ (\(k,v) -> C.insert k v av) $ [size..] `zip` (map lazyScalar vals)
    array_extendSize MkIArray{ a_size = s } sz = liftIO $ do
        modifyIORef s $ \size -> if size >= sz then size else sz
    array_fetchVal arr idx = do
        readIVar =<< getArrayIndex idx (Just $ constScalar undef)
            (return arr)
             Nothing -- don't bother extending
    array_fetchKeys MkIArray{ a_data = av } = liftIO $ C.keys av
    array_fetchElem arr@(MkIArray av s) idx = do
        sv <- getArrayIndex idx Nothing
            (return arr)
            (Just (array_extendSize arr $ idx+1))
        if refType (MkRef sv) == mkType "Scalar::Lazy"
            then do
                val <- readIVar sv
                sv' <- newScalar val
                liftIO $ do
                    size <- readIORef s
                    let idx' = idx `mod` size
                    C.insert idx' sv' av
                    return sv'
            else return sv
    array_existsElem arr idx | idx < 0 = array_existsElem arr (abs idx - 1)    -- FIXME: missing mod?
    array_existsElem MkIArray{ a_data = av } idx = liftIO $ C.member idx av
    array_deleteElem (MkIArray av s) idx = liftIO $ do
        size <- readIORef s
        let idx' | idx < 0   = idx `mod` size        --- XXX wrong; wraparound => what do you mean?
                 | otherwise = idx
        case (size-1) `compare` idx' of
            LT -> return ()
            EQ -> do
                writeIORef s (size-1)
                C.delete idx' av
                return ()
            GT -> do
                C.delete idx' av
                return ()
    array_storeElem (MkIArray av s) idx sv = liftIO $ do
        size <- readIORef s
        let idx' | idx < 0   = idx `mod` size        --- XXX wrong; wraparound => what do you mean?
                 | otherwise = idx
        C.insert idx' sv av
        if size > idx'
            then return ()
            else writeIORef s (idx'+1)

instance ArrayClass VArray where
    array_iType = const $ mkType "Array::Const"
    array_store [] _ = return ()
    array_store (VUndef:as) (_:vs) = array_store as vs
    array_store as [] = forM_ as $ \a -> do
        -- clear out everything
        env <- ask
        ref <- fromVal a
        if isaType (envClasses env) "List" (refType ref)
            then writeRef ref (VList [])
            else writeRef ref VUndef
    array_store (a:as) vals@(v:vs) = do
        env <- ask
        ref <- fromVal a
        if isaType (envClasses env) "List" (refType ref)
            then do
                writeRef ref (VList vals)
                array_store as []
            else do
                writeRef ref v
                array_store as vs
    array_fetch = return
    array_fetchSize = return . length
    array_fetchVal av idx = getIndex idx (Just undef) (return av) Nothing
    array_fetchElemAll av = return $ map constScalar av
    array_fetchElem av idx = do
        val <- array_fetchVal av idx
        return $ constScalar val
    array_storeVal _ _ _ = retConstError undef
    array_storeElem _ _ _ = retConstError undef
    array_existsElem av idx = return . not . null $ drop idx av

instance ArrayClass (IVar VPair) where
    array_iType = const $ mkType "Pair"
    array_fetch pv = do
        (k, v)  <- readIVar pv
        return [k, v]
    array_existsElem _ idx = return (idx >= -2 || idx <= 1)
    array_fetchSize        = const $ return 2
    array_fetchVal pv (-2) = return . fst =<< readIVar pv
    array_fetchVal pv (-1) = return . snd =<< readIVar pv
    array_fetchVal pv 0    = return . fst =<< readIVar pv
    array_fetchVal pv 1    = return . snd =<< readIVar pv
    array_fetchVal _  _    = return undef
    array_storeVal a _ _   = retConstError $ VStr $ show a
    array_storeElem a _ _  = retConstError $ VStr $ show a
    array_deleteElem a _   = retConstError $ VStr $ show a

perl5EvalApply :: String -> [PerlSV] -> Eval Val
perl5EvalApply code args = do
    env     <- ask
    envSV   <- liftIO $ mkVal env
    subSV   <- liftIO $ evalPerl5 code envSV (enumCxt cxtItemAny)
    runInvokePerl5 subSV nullSV args

instance ArrayClass PerlSV where
    array_iType = const $ mkType "Array::Perl"
    array_fetchVal sv idx = do
        idxSV   <- fromVal $ castV idx
        perl5EvalApply "sub { $_[0]->[$_[1]] }" [sv, idxSV]
    array_clear sv = do
        perl5EvalApply "sub { undef @{$_[0]} }" [sv]
        return ()
    array_storeVal sv idx val = do
        idxSV   <- fromVal $ castV idx
        valSV   <- fromVal val
        perl5EvalApply "sub { $_[0]->[$_[1]] = $_[2] }" [sv, idxSV, valSV]
        return ()
    array_deleteElem sv idx = do
        idxSV   <- fromVal $ castV idx
        perl5EvalApply "sub { delete $_[0]->[$_[1]] }" [sv, idxSV]
        return ()
